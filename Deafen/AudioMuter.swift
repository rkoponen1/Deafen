//
//  AudioMuter.swift
//  Deafen
//
//  Silences chosen apps using Core Audio process taps. A tap created with
//  `muteBehavior = .muted` captures a process's output and stops it from
//  reaching the audio hardware. We attach the tap to a private aggregate
//  device and keep it running with an empty IOProc so the mute stays in force.
//

import AppKit
import AudioToolbox
import CoreAudio
import Darwin

struct AudioError: LocalizedError {
    let operation: String
    let status: OSStatus

    var errorDescription: String? { "\(operation) failed (OSStatus \(status))" }
}

nonisolated private func check(_ status: OSStatus, _ operation: String) throws {
    guard status == noErr else { throw AudioError(operation: operation, status: status) }
}

// MARK: - Property helpers

private extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    func read<T>(_ selector: AudioObjectPropertySelector, default value: T) throws -> T {
        var addr = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        var result = value
        let status = withUnsafeMutablePointer(to: &result) {
            AudioObjectGetPropertyData(self, &addr, 0, nil, &size, $0)
        }
        try check(status, "Read property \(selector)")
        return result
    }

    func readArray<T>(_ selector: AudioObjectPropertySelector, element: T) throws -> [T] {
        var addr = address(selector)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(self, &addr, 0, nil, &size), "Read size \(selector)")
        let count = Int(size) / MemoryLayout<T>.stride
        guard count > 0 else { return [] }
        var items = [T](repeating: element, count: count)
        let status = items.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(self, &addr, 0, nil, &size, $0.baseAddress!)
        }
        try check(status, "Read list \(selector)")
        return items
    }

    func readString(_ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(self, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

private func executablePath(of pid: pid_t) -> String? {
    var buffer = [CChar](repeating: 0, count: 4096)
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    return String(cString: buffer)
}

/// Creates the realtime IOProc outside of any actor so Swift doesn't insert
/// main-actor isolation checks into a block that runs on the audio thread.
nonisolated private func makeSilentIOProc(on device: AudioObjectID) throws -> AudioDeviceIOProcID {
    var procID: AudioDeviceIOProcID?
    let status = AudioDeviceCreateIOProcIDWithBlock(&procID, device, nil) { _, _, _, _, _ in
        // Intentionally empty: we only need the tap to be running.
    }
    try check(status, "Create IOProc")
    guard let procID else { throw AudioError(operation: "Create IOProc", status: -1) }
    return procID
}

// MARK: - Mute session

/// One active tap + aggregate device that silences a fixed set of processes.
private final class MuteSession {
    let processes: Set<AudioObjectID>
    let outputDevice: AudioObjectID
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?

    init(processes: Set<AudioObjectID>, outputDevice: AudioObjectID) throws {
        self.processes = processes
        self.outputDevice = outputDevice

        do {
            let description = CATapDescription(stereoMixdownOfProcesses: Array(processes))
            description.uuid = UUID()
            description.name = "Deafen"
            description.isPrivate = true
            description.muteBehavior = .muted
            try check(AudioHardwareCreateProcessTap(description, &tapID), "Create process tap")

            guard let outputUID = outputDevice.readString(kAudioDevicePropertyDeviceUID) else {
                throw AudioError(operation: "Read output device UID", status: -1)
            }

            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Deafen",
                kAudioAggregateDeviceUIDKey: "Deafen-\(UUID().uuidString)",
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                ]],
            ]
            try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID),
                      "Create aggregate device")

            let procID = try makeSilentIOProc(on: aggregateID)
            self.procID = procID
            try check(AudioDeviceStart(aggregateID, procID), "Start aggregate device")
        } catch {
            invalidate()
            throw error
        }
    }

    func invalidate() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        procID = nil
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    deinit { invalidate() }
}

// MARK: - AppMuter

/// Keeps the chosen apps silenced while `isMuting` is true, following the
/// apps' audio processes as they come and go and the default output device
/// as it changes.
final class AppMuter {
    /// Called on the main thread with a human-readable status or error.
    var onStatusChange: ((_ mutedProcessCount: Int, _ error: String?) -> Void)?

    private(set) var isMuting = false
    private var bundleIDs: [String] = []
    private var session: MuteSession?
    private var listenersInstalled = false
    private var processListener: AudioObjectPropertyListenerBlock?
    private var deviceListener: AudioObjectPropertyListenerBlock?

    func start(bundleIDs: [String]) {
        self.bundleIDs = bundleIDs
        isMuting = true
        installListeners()
        refresh()
    }

    func update(bundleIDs: [String]) {
        self.bundleIDs = bundleIDs
        if isMuting { refresh() }
    }

    func stop() {
        isMuting = false
        session?.invalidate()
        session = nil
        removeListeners()
        onStatusChange?(0, nil)
    }

    // MARK: Matching

    /// Audio process objects that belong to the target apps, including helper
    /// processes (e.g. Electron's "Slack Helper") nested inside the app bundle.
    private func matchingProcesses() throws -> Set<AudioObjectID> {
        let bundlePaths = bundleIDs.compactMap {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.resolvingSymlinksInPath().path
        }
        let processes = try AudioObjectID.system.readArray(
            kAudioHardwarePropertyProcessObjectList, element: AudioObjectID(kAudioObjectUnknown))

        var matches = Set<AudioObjectID>()
        for process in processes {
            if let bundleID = process.readString(kAudioProcessPropertyBundleID),
               bundleIDs.contains(where: { bundleID == $0 || bundleID.hasPrefix($0 + ".") }) {
                matches.insert(process)
                continue
            }
            if let pid = try? process.read(kAudioProcessPropertyPID, default: pid_t(-1)), pid > 0,
               let path = executablePath(of: pid),
               bundlePaths.contains(where: { path.hasPrefix($0 + "/") }) {
                matches.insert(process)
            }
        }
        return matches
    }

    // MARK: Session management

    private func refresh() {
        guard isMuting else { return }
        do {
            let processes = try matchingProcesses()
            let output = try AudioObjectID.system.read(
                kAudioHardwarePropertyDefaultOutputDevice, default: AudioObjectID(kAudioObjectUnknown))

            if let session, session.processes == processes, session.outputDevice == output {
                onStatusChange?(processes.count, nil)
                return
            }

            session?.invalidate()
            session = nil
            if !processes.isEmpty, output != kAudioObjectUnknown {
                session = try MuteSession(processes: processes, outputDevice: output)
            }
            onStatusChange?(processes.count, nil)
        } catch {
            session?.invalidate()
            session = nil
            onStatusChange?(0, error.localizedDescription)
        }
    }

    // MARK: Listeners

    private func installListeners() {
        guard !listenersInstalled else { return }
        listenersInstalled = true

        let process: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        let device: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        processListener = process
        deviceListener = device

        var processAddr = AudioObjectID.system.address(kAudioHardwarePropertyProcessObjectList)
        var deviceAddr = AudioObjectID.system.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(.system, &processAddr, .main, process)
        AudioObjectAddPropertyListenerBlock(.system, &deviceAddr, .main, device)
    }

    private func removeListeners() {
        guard listenersInstalled else { return }
        listenersInstalled = false
        var processAddr = AudioObjectID.system.address(kAudioHardwarePropertyProcessObjectList)
        var deviceAddr = AudioObjectID.system.address(kAudioHardwarePropertyDefaultOutputDevice)
        if let processListener {
            AudioObjectRemovePropertyListenerBlock(.system, &processAddr, .main, processListener)
        }
        if let deviceListener {
            AudioObjectRemovePropertyListenerBlock(.system, &deviceAddr, .main, deviceListener)
        }
        processListener = nil
        deviceListener = nil
    }
}
