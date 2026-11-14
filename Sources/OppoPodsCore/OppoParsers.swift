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

    /// 从 0x810C / 0x0204 帧里提取当前噪声 protocolIndex 位图（bit n = protocolIndex n）。
    public static func noiseIndexBitmap(from frame: OppoFrame) -> Int? {
        guard frame.command == OppoCommand.ancResponse || frame.command == OppoCommand.activeReport else { return nil }
        let bytes = Array(frame.payload)
        if frame.command == OppoCommand.activeReport,
           let first = bytes.first, first != 0x03, first != 0x04 { return nil }
        guard let index = bytes.indices.dropLast(2).first(where: {
            bytes[$0] == 0x01 && bytes[$0 + 1] == 0x01
        }) else { return nil }
        let low = Int(bytes[index + 2])
        let high = index + 3 < bytes.count ? Int(bytes[index + 3]) : 0
        return low | (high << 8)
    }

    /// 按型号映射表把位图解析为两级噪声选择（主模式 + 子档位）。
    public static func noiseSelection(
        from frame: OppoFrame,
        indexToSelection: [Int: NoiseSelection]
    ) -> NoiseSelection? {
        guard let bitmap = noiseIndexBitmap(from: frame) else { return nil }
        var fallback: NoiseSelection?
        for bit in 0..<16 where bitmap & (1 << bit) != 0 {
            if let selection = indexToSelection[bit] {
                if selection.levelIndex != nil { return selection }
                fallback = fallback ?? selection
            }
        }
        return fallback ?? noiseControl(from: frame).map { NoiseSelection(main: $0.mainMode) }
    }

    /// 解析双联设备列表。
    ///
    /// 0x8112 响应格式（与官方 PollCommandManager 的轮询响应约定一致）：
    /// `[status(1), count(1), elements…]`，首字节为状态码，数据从 offset 1 开始。
    /// 0x0204 type=0x06 事件格式：`[0x06, count(1), elements…]`。
    ///
    /// 元素格式（CommandUtil.parseMultiConnectStateInfo）：
    /// `mac(6, 包内逆序) + recordLen(1) + state(1) + flag(1) + nameLen(1) + name + pad`，
    /// 单条总长 `7 + recordLen`。flag：bit0=当前设备 bit1=主音频 bit2=音频活跃 bits3-5=deviceType。
    public static func multiConnectDevices(from frame: OppoFrame) -> [MultiConnectDevice]? {
        let bytes = Array(frame.payload)
        switch frame.command {
        case OppoCommand.multiConnectResponse:
            // 官方实现从 offset 1 解析（跳过 status）；若固件省略 status 则回退 offset 0。
            return bestMultiConnectParse(bytes, offsets: [1, 0])
        case OppoCommand.activeReport:
            guard bytes.first == 0x06 else { return nil }
            return bestMultiConnectParse(bytes, offsets: [1])
        default:
            return nil
        }
    }

    /// 在多个候选偏移中挑最可信的解析结果：完整消费 payload 且设备数多者优先。
    private static func bestMultiConnectParse(
        _ bytes: [UInt8],
        offsets: [Int]
    ) -> [MultiConnectDevice]? {
        var best: (devices: [MultiConnectDevice], score: Int)?
        for start in offsets {
            guard let parsed = parseMultiConnectDevices(bytes, start: start) else { continue }
            let score = (parsed.exact ? 1_000 : 0)
                + parsed.devices.count * 10
                + min(parsed.consumed, 9)
            if best == nil || score > best!.score {
                best = (parsed.devices, score)
            }
        }
        return best?.devices
    }

    static func parseMultiConnectDevices(
        _ bytes: [UInt8],
        start: Int
    ) -> (devices: [MultiConnectDevice], consumed: Int, exact: Bool)? {
        guard start < bytes.count else { return nil }
        let count = Int(bytes[start])
        guard count <= 16 else { return nil }
        guard count > 0 else {
            let consumed = start + 1
            return ([], consumed, consumed == bytes.count)
        }
        var position = start + 1
        var devices: [MultiConnectDevice] = []
        for _ in 0..<count {
            guard position + 8 <= bytes.count else { return nil }
            let macBytes = bytes[position..<(position + 6)]
            let address = macBytes.reversed().map { String(format: "%02X", $0) }.joined(separator: ":")
            let recordLength = Int(bytes[position + 6])
            let state = Int(bytes[position + 7])
            guard recordLength >= 3, position + 7 + recordLength <= bytes.count else { return nil }
            let flag = Int(bytes[position + 8])
            let nameLength = Int(bytes[position + 9])
            let nameStart = position + 10
            guard nameLength <= recordLength - 3, nameStart + nameLength <= bytes.count else { return nil }
            let name = String(decoding: bytes[nameStart..<(nameStart + nameLength)], as: UTF8.self)
            if address != "00:00:00:00:00:00" {
                devices.append(MultiConnectDevice(
                    address: address,
                    name: name,
                    connectionState: .init(wireValue: state),
                    isCurrentDevice: flag & 0x01 != 0,
                    isMainAudioDevice: flag & 0x02 != 0,
                    isAudioActive: flag & 0x04 != 0,
                    deviceType: ((flag >> 5) & 1) * 4 + ((flag >> 4) & 1) * 2 + ((flag >> 3) & 1)
                ))
            }
            position += 7 + recordLength
        }
        return (devices, position, position == bytes.count)
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
