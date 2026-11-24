//
//  AudioObjectID+Properties.swift
//  Deafen
//
//  Small typed wrappers around AudioObjectGetPropertyData.
//

import CoreAudio

extension AudioObjectID {
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
        let status = items.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return kAudioHardwareBadPropertySizeError }
            return AudioObjectGetPropertyData(self, &addr, 0, nil, &size, base)
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
