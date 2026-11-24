//
//  MuteSession.swift
//  Deafen
//
//  A tap created with `muteBehavior = .muted` captures a process's output
//  and stops it from reaching the audio hardware. The tap is attached to a
//  private aggregate device that runs an empty IOProc so the mute stays in force.
//

import AudioToolbox
import CoreAudio
import Foundation

/// One active tap + aggregate device that silences a fixed set of processes.
final class MuteSession {
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
                throw AudioError(operation: "Read output device UID", status: kAudioHardwareUnknownPropertyError)
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

    /// Tears everything down. Failures here are ignored on purpose: there is
    /// nothing useful to do with them, and the HAL cleans up private objects
    /// when the process exits.
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

/// Creates the realtime IOProc outside of any actor so Swift doesn't insert
/// main-actor isolation checks into a block that runs on the audio thread.
nonisolated private func makeSilentIOProc(on device: AudioObjectID) throws -> AudioDeviceIOProcID {
    var procID: AudioDeviceIOProcID?
    let status = AudioDeviceCreateIOProcIDWithBlock(&procID, device, nil) { _, _, _, _, _ in
        // Intentionally empty: the tap only has to be running.
    }
    try check(status, "Create IOProc")
    guard let procID else { throw AudioError(operation: "Create IOProc", status: kAudioHardwareUnspecifiedError) }
    return procID
}
