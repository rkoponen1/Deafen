//
//  AppMuter.swift
//  Deafen
//

import AppKit
import CoreAudio
import Darwin

/// Keeps the chosen apps silenced while muting, following the apps' audio
/// processes as they come and go and the default output device as it changes.
final class AppMuter {
    /// Called with how many audio processes are silenced, or an error message.
    var onStatusChange: ((_ mutedProcessCount: Int, _ error: String?) -> Void)?

    private(set) var isMuting = false
    private var bundleIDs: [String] = []
    private var session: MuteSession?
    private var listenerError: String?
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

    private func matchingProcesses() throws -> Set<AudioObjectID> {
        let matcher = ProcessMatcher(
            bundleIDs: bundleIDs,
            bundlePaths: bundleIDs.compactMap {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.resolvingSymlinksInPath().path
            }
        )
        let processes = try AudioObjectID.system.readArray(
            kAudioHardwarePropertyProcessObjectList, element: AudioObjectID(kAudioObjectUnknown))

        var matches = Set<AudioObjectID>()
        for process in processes {
            if matcher.matches(bundleID: process.readString(kAudioProcessPropertyBundleID)) {
                matches.insert(process)
            } else if let pid = try? process.read(kAudioProcessPropertyPID, default: pid_t(-1)), pid > 0,
                      let path = executablePath(of: pid),
                      matcher.matches(executablePath: path) {
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
                onStatusChange?(processes.count, listenerError)
                return
            }

            session?.invalidate()
            session = nil
            if !processes.isEmpty, output != kAudioObjectUnknown {
                session = try MuteSession(processes: processes, outputDevice: output)
            }
            onStatusChange?(processes.count, listenerError)
        } catch {
            session?.invalidate()
            session = nil
            onStatusChange?(0, error.localizedDescription)
        }
    }

    // MARK: Listeners

    private func installListeners() {
        guard processListener == nil else { return }

        let process: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        let device: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        processListener = process
        deviceListener = device

        // The listener API requires a dispatch queue; `.main` keeps callbacks on the main actor.
        var processAddr = AudioObjectID.system.address(kAudioHardwarePropertyProcessObjectList)
        var deviceAddr = AudioObjectID.system.address(kAudioHardwarePropertyDefaultOutputDevice)
        do {
            try check(AudioObjectAddPropertyListenerBlock(.system, &processAddr, .main, process),
                      "Watch for apps starting audio")
            try check(AudioObjectAddPropertyListenerBlock(.system, &deviceAddr, .main, device),
                      "Watch for output device changes")
            listenerError = nil
        } catch {
            listenerError = "\(error.localizedDescription). Apps that start playing later may not be silenced."
        }
    }

    private func removeListeners() {
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
        listenerError = nil
    }
}

private func executablePath(of pid: pid_t) -> String? {
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    return String(cString: buffer)
}
