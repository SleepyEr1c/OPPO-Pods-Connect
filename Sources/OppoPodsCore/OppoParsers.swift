import Foundation

public enum OppoParsers {
    public static func battery(from frame: OppoFrame) -> BatteryStatus? {
        var bytes: ArraySlice<UInt8>
        switch frame.command {
        case OppoCommand.batteryResponse:
            bytes = Array(frame.payload)[...]
        case OppoCommand.activeReport:
            let payload = Array(frame.payload)
            guard payload.count >= 2, payload[0] == 0x01 else { return nil }
            let count = min(Int(payload[1]), (payload.count - 2) / 2)
            bytes = payload.dropFirst(2).prefix(count * 2)
        default:
            return nil
        }

        var status = BatteryStatus()
        while bytes.count >= 2 {
            let component = bytes.removeFirst()
            let raw = bytes.removeFirst()
            let value = BatteryLevel(level: Int(raw & 0x7F), isCharging: raw & 0x80 != 0)
            switch component {
            case 1: status.left = value
            case 2: status.right = value
            case 3: status.chargingCase = value
            default: break
            }
        }
        return status
    }

    public static func productID(from frame: OppoFrame) -> String? {
        let bytes = Array(frame.payload)
        guard frame.command == OppoCommand.productIDResponse,
              bytes.count == 4, bytes[0] == 0 else { return nil }
        let identifier = Int(bytes[1]) | (Int(bytes[2]) << 8) | (Int(bytes[3]) << 16)
        return String(format: "%06X", identifier)
    }

    public static func noiseControl(from frame: OppoFrame) -> NoiseControlMode? {
        guard frame.command == OppoCommand.ancResponse || frame.command == OppoCommand.activeReport else { return nil }
        let bytes = Array(frame.payload)
        if frame.command == OppoCommand.activeReport,
           let first = bytes.first, first != 0x03, first != 0x04 { return nil }

        guard let index = bytes.indices.dropLast(2).first(where: {
            bytes[$0] == 0x01 && bytes[$0 + 1] == 0x01
        }) else { return nil }
        let low = bytes[index + 2]
        let high = index + 3 < bytes.count ? bytes[index + 3] : 0
        switch (low, high) {
        case (0x10, 0x00), (0x20, 0x00), (0x40, 0x00), (0x80, 0x00): return .noiseCancellation
        case (0x00, 0x01): return .transparency
        case (0x08, 0x00): return .off
        case (0x00, 0x08): return .adaptive
        default: return nil
        }
    }

    public static func noiseControl(
        from frame: OppoFrame,
        indexToMode: [Int: NoiseControlMode]
    ) -> NoiseControlMode? {
        guard !indexToMode.isEmpty,
              frame.command == OppoCommand.ancResponse || frame.command == OppoCommand.activeReport else {
            return noiseControl(from: frame)
        }
        let bytes = Array(frame.payload)
        guard let index = bytes.indices.dropLast(2).first(where: {
            bytes[$0] == 0x01 && bytes[$0 + 1] == 0x01
        }) else { return nil }
        let low = Int(bytes[index + 2])
        let high = index + 3 < bytes.count ? Int(bytes[index + 3]) : 0
        let bitmap = low | (high << 8)
        for bit in 0..<16 where bitmap & (1 << bit) != 0 {
            if let mode = indexToMode[bit] { return mode }
        }
        return noiseControl(from: frame)
    }

    public static func featureStatus(from frame: OppoFrame) -> FeatureStatus? {
        guard frame.command == OppoCommand.statusResponse else { return nil }
        let bytes = Array(frame.payload)
        var pairs: [(UInt8, UInt8)] = []
        if bytes.count >= 2, bytes[0] == 0, bytes.count >= 2 + Int(bytes[1]) * 2 {
            for index in 0..<Int(bytes[1]) {
                let offset = 2 + index * 2
                pairs.append((bytes[offset], bytes[offset + 1]))
            }
        } else {
            for index in 0..<max(0, bytes.count - 1) where bytes[index + 1] <= 1 {
                pairs.append((bytes[index], bytes[index + 1]))
            }
        }
        var result = FeatureStatus()
        for (feature, rawValue) in pairs {
            let enabled = rawValue == 1
            switch feature {
            case 0x28: result.gameMode = enabled
            case 0x06: result.lowLatencyMode = enabled
            case 0x04: result.wearDetection = enabled
            case 0x11: result.dualDevice = enabled
            case 0x1B: result.spatialSound = enabled
            default: break
            }
        }
        return result == FeatureStatus() ? nil : result
    }

    public static func spatialAudio(from frame: OppoFrame) -> SpatialAudioMode? {
        guard frame.command == OppoCommand.spatialAudioNotify,
              let raw = frame.payload.first else { return nil }
        return SpatialAudioMode(rawValue: Int(raw))
    }

    public static func broadcastCodes(from frame: OppoFrame) -> [UInt8]? {
        let bytes = Array(frame.payload)
        guard frame.command == OppoCommand.broadcastCodesResponse, bytes.count >= 2, bytes[0] == 0 else { return nil }
        return Array(bytes.dropFirst(2).prefix(Int(bytes[1])))
    }

    public static func currentEQ(from frame: OppoFrame) -> Int? {
        let bytes = Array(frame.payload)
        guard frame.command == OppoCommand.eqResponse, bytes.count >= 2, bytes[0] == 0 else { return nil }
        return Int(bytes[1])
    }

    public static func allEqualizers(from frame: OppoFrame) -> [DeviceEqualizerPreset]? {
        guard frame.command == OppoCommand.allEQResponse else { return nil }
        let bytes = Array(frame.payload)
        guard bytes.count >= 2, bytes[0] == 0 else { return nil }

        let expectedCount = Int(bytes[1])
        var position = 2
        var presets: [DeviceEqualizerPreset] = []
        while presets.count < expectedCount {
            guard position + 5 <= bytes.count else { return nil }
            let selected = bytes[position] != 0
            let minimumGain = Int(Int8(bitPattern: bytes[position + 1]))
            let maximumGain = Int(Int8(bitPattern: bytes[position + 2]))
            let presetID = Int(bytes[position + 3])
            let nameLength = Int(bytes[position + 4])
            position += 5
            guard position + nameLength <= bytes.count else { return nil }
            let name = String(decoding: bytes[position..<(position + nameLength)], as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            position += nameLength

            guard position < bytes.count else { return nil }
            let frequencyCount = Int(bytes[position])
            position += 1
            guard position + frequencyCount * 3 <= bytes.count else { return nil }
            var frequencies: [Int] = []
            var gains: [Int] = []
            for _ in 0..<frequencyCount {
                frequencies.append(Int(bytes[position]) | (Int(bytes[position + 1]) << 8))
                gains.append(Int(Int8(bitPattern: bytes[position + 2])))
                position += 3
            }
            presets.append(DeviceEqualizerPreset(
                id: presetID,
                name: name,
                isSelected: selected,
                minimumGain: minimumGain,
                maximumGain: maximumGain,
                frequencies: frequencies,
                gains: gains
            ))
        }
        return presets
    }
}
