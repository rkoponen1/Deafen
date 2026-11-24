//
//  AudioError.swift
//  Deafen
//

import CoreAudio
import Foundation

/// A failed Core Audio call, with the operation that failed for context.
struct AudioError: LocalizedError {
    let operation: String
    let status: OSStatus

    var errorDescription: String? { "\(operation) failed (OSStatus \(status))" }
}

/// Throws an `AudioError` unless `status` is `noErr`.
nonisolated func check(_ status: OSStatus, _ operation: String) throws {
    guard status == noErr else { throw AudioError(operation: operation, status: status) }
}
