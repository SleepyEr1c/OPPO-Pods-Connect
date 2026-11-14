import Foundation

public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

public enum NoiseControlMode: Int, CaseIterable, Identifiable, Sendable {
    case off
    case noiseCancellation
    case transparency
    case adaptive

    public var id: Int { rawValue }

    public var mainMode: NoiseMainMode {
        switch self {
        case .off: return .off
        case .noiseCancellation: return .noiseCancellation
        case .transparency: return .transparency
        case .adaptive: return .adaptive
        }
    }
}

/// 降噪主模式。对应白名单 noiseReductionMode 顶层条目：
/// 1=关闭、2=通透、5=降噪、10=自适应（范围）。
public enum NoiseMainMode: Int, CaseIterable, Identifiable, Sendable {
    case off = 1
    case transparency = 2
    case noiseCancellation = 5
    case adaptive = 10

    public var id: Int { rawValue }
}

/// 降噪子档位（childrenMode 条目）。
/// modeType 语义：3=轻度降噪 4=深度降噪 6=强化人声 7=智能动态 8=中度降噪
/// 11=更少噪音 12=标准 13=更多噪音。
public struct NoiseLevelOption: Identifiable, Equatable, Sendable {
    public let id: Int
    public let modeType: Int

    public init(id: Int, modeType: Int) {
        self.id = id
        self.modeType = modeType
    }
}

/// 一次噪声控制选择：主模式 + 可选子档位（子档位用 protocolIndex 表示）。
public struct NoiseSelection: Equatable, Sendable {
    public var main: NoiseMainMode
    public var levelIndex: Int?

    public init(main: NoiseMainMode, levelIndex: Int? = nil) {
        self.main = main
        self.levelIndex = levelIndex
    }
}

/// 双联（多点连接）设备列表条目。
/// connectionState：1=连接中 2=已连接 4=断开中；其余视为未连接。
public struct MultiConnectDevice: Identifiable, Equatable, Sendable {
    public enum ConnectionState: Int, Sendable {
        case idle = 0
        case connecting = 1
        case connected = 2
        case disconnecting = 4

        public init(wireValue: Int) {
            self = ConnectionState(rawValue: wireValue) ?? .idle
        }
    }

    public var id: String { address }
    public let address: String
    public let name: String
    public let connectionState: ConnectionState
    public let isCurrentDevice: Bool
    public let isMainAudioDevice: Bool
    public let isAudioActive: Bool
    public let deviceType: Int

    public init(
        address: String,
        name: String,
        connectionState: ConnectionState,
        isCurrentDevice: Bool,
        isMainAudioDevice: Bool,
        isAudioActive: Bool,
        deviceType: Int
    ) {
        self.address = address
        self.name = name
        self.connectionState = connectionState
        self.isCurrentDevice = isCurrentDevice
        self.isMainAudioDevice = isMainAudioDevice
        self.isAudioActive = isAudioActive
        self.deviceType = deviceType
    }
}

public enum SpatialAudioMode: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case fixed = 1
    case headTracking = 2

    public var id: Int { rawValue }
}

public struct BatteryLevel: Equatable, Sendable {
    public var level: Int
    public var isCharging: Bool

    public init(level: Int, isCharging: Bool) {
        self.level = level
        self.isCharging = isCharging
    }
}

public struct BatteryStatus: Equatable, Sendable {
    public var left: BatteryLevel?
    public var right: BatteryLevel?
    public var chargingCase: BatteryLevel?

    public init(left: BatteryLevel? = nil, right: BatteryLevel? = nil, chargingCase: BatteryLevel? = nil) {
        self.left = left
        self.right = right
        self.chargingCase = chargingCase
    }

    public var menuBarLevel: Int? {
        [left?.level, right?.level].compactMap { $0 }.min()
    }
}

public struct FeatureStatus: Equatable, Sendable {
    public var gameMode: Bool?
    public var lowLatencyMode: Bool?
    public var wearDetection: Bool?
    public var dualDevice: Bool?
    public var spatialSound: Bool?

    public init(gameMode: Bool? = nil, lowLatencyMode: Bool? = nil, wearDetection: Bool? = nil, dualDevice: Bool? = nil, spatialSound: Bool? = nil) {
        self.gameMode = gameMode
        self.lowLatencyMode = lowLatencyMode
        self.wearDetection = wearDetection
        self.dualDevice = dualDevice
        self.spatialSound = spatialSound
    }
}

public struct EqualizerPreset: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

public struct DeviceEqualizerPreset: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let isSelected: Bool
    public let minimumGain: Int
    public let maximumGain: Int
    public let frequencies: [Int]
    public let gains: [Int]

    public init(
        id: Int,
        name: String,
        isSelected: Bool = false,
        minimumGain: Int = -6,
        maximumGain: Int = 6,
        frequencies: [Int] = [],
        gains: [Int] = []
    ) {
        self.id = id
        self.name = name
        self.isSelected = isSelected
        self.minimumGain = minimumGain
        self.maximumGain = maximumGain
        self.frequencies = frequencies
        self.gains = gains
    }
}
