import Foundation
import OppoPodsCore

/// 一个降噪主模式及其可选子档位（深度/中度/轻度/智能动态、自适应范围、通透强化人声）。
struct NoiseModeGroup: Equatable {
    let main: NoiseMainMode
    /// 顶层条目的 protocolIndex；未选择子档位时使用。
    let groupIndex: Int
    /// 可选子档位（不含强化人声）。
    let levels: [NoiseLevelOption]
    /// 通透模式的强化人声档（childrenMode 中 modeType == 6）。
    let vocalEnhancementIndex: Int?

    var hasVocalEnhancement: Bool { vocalEnhancementIndex != nil }

    /// 默认子档位：优先智能动态（7），否则取第一个。
    var defaultLevelIndex: Int {
        if let smart = levels.first(where: { $0.modeType == 7 }) { return smart.id }
        return levels.first?.id ?? groupIndex
    }
}

struct DeviceCapabilities: Equatable {
    let modelID: String
    let modelName: String
    let noiseModeByIndex: [Int: NoiseControlMode]
    let indexByNoiseMode: [NoiseControlMode: Int]
    let noiseGroups: [NoiseModeGroup]
    let selectionByIndex: [Int: NoiseSelection]
    let hasAdaptiveANC: Bool
    let hasNoiseLevels: Bool
    let hasVocalEnhancement: Bool
    let hasGameMode: Bool
    let hasSpatialSound: Bool
    let hasSpatialAudioModes: Bool
    let hasWearDetection: Bool
    let hasDualDevice: Bool
    let equalizerPresets: [EqualizerPreset]
    let hasCustomEQ: Bool
    let customEQFrequencies: [Int]
    let customEQMaximumPresets: Int

    static let generic = DeviceCapabilities(
        modelID: "",
        modelName: "未识别型号",
        noiseModeByIndex: [:],
        indexByNoiseMode: [:],
        noiseGroups: [],
        selectionByIndex: [:],
        hasAdaptiveANC: true,
        hasNoiseLevels: false,
        hasVocalEnhancement: false,
        hasGameMode: true,
        hasSpatialSound: true,
        hasSpatialAudioModes: false,
        hasWearDetection: false,
        hasDualDevice: false,
        equalizerPresets: [],
        hasCustomEQ: false,
        customEQFrequencies: [],
        customEQMaximumPresets: 0
    )
}

final class DeviceModelRegistry {
    private struct Root: Decodable { let whiteList: [Model] }
    private struct Model: Decodable {
        let id: String?
        let name: String?
        let supportSpp: Bool?
        let function: Functions?
    }
    private struct Functions: Decodable {
        let noiseReductionMode: [NoiseMode]?
        let spatialTypes: [Int]?
        let multiDevicesConnect: Int?
        let wearDetection: Int?
        let gameMode: Int?
        let gameModeList: [GameModeItem]?
        let gameSoundList: [GameSoundItem]?
        let customEqualizer: Int?
        let customEqFrequency: [Int]?
        let customEqMax: Int?
        let equalizerMode: [EQMode]?
        let equalizerModeCompat: [EQMode]?
        let equalizerModeByVersion: [EQMode]?
    }
    private struct NoiseMode: Decodable {
        let modeType: Int
        let protocolIndex: Int
        let childrenMode: [NoiseMode]?
    }
    private struct GameModeItem: Decodable { let gameMode: Int? }
    private struct GameSoundItem: Decodable { let type: Int? }
    private struct EQMode: Decodable {
        let modeType: Int?
        let protocolIndex: Int?
    }
    private struct EQNames: Decodable { let mapping: [String: String] }

    private var modelsByID: [String: Model] = [:]
    private var eqNames: [Int: String] = [:]

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "device_models", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let root = try? JSONDecoder().decode(Root.self, from: data) {
            modelsByID = Dictionary(uniqueKeysWithValues: root.whiteList.compactMap { model in
                guard let id = model.id?.uppercased(), !id.isEmpty else { return nil }
                return (id, model)
            })
        }
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let resource = language == "zh" ? "eq_mode_names" : "eq_mode_names.en"
        if let url = bundle.url(forResource: resource, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let names = try? JSONDecoder().decode(EQNames.self, from: data) {
            eqNames = Dictionary(uniqueKeysWithValues: names.mapping.compactMap { key, value in
                Int(key).map { ($0, value) }
            })
        }
    }

    var modelCount: Int { modelsByID.count }

    func capabilities(for productID: String) -> DeviceCapabilities? {
        guard let model = modelsByID[productID.uppercased()], model.supportSpp != false else { return nil }
        let functions = model.function
        var byIndex: [Int: NoiseControlMode] = [:]
        var byMode: [NoiseControlMode: Int] = [:]
        var groups: [NoiseModeGroup] = []
        var selectionByIndex: [Int: NoiseSelection] = [:]
        var hasNoiseLevels = false

        for entry in functions?.noiseReductionMode ?? [] {
            guard let main = Self.mainMode(for: entry.modeType) else { continue }
            byIndex[entry.protocolIndex] = Self.legacyMode(for: main)
            byMode[Self.legacyMode(for: main)] = entry.protocolIndex
            selectionByIndex[entry.protocolIndex] = NoiseSelection(main: main)

            var levels: [NoiseLevelOption] = []
            var vocalIndex: Int?
            for child in entry.childrenMode ?? [] {
                if child.modeType == 6, main == .transparency {
                    vocalIndex = child.protocolIndex
                    selectionByIndex[child.protocolIndex] = NoiseSelection(main: main, levelIndex: child.protocolIndex)
                    continue
                }
                levels.append(NoiseLevelOption(id: child.protocolIndex, modeType: child.modeType))
                byIndex[child.protocolIndex] = Self.legacyMode(for: main)
                selectionByIndex[child.protocolIndex] = NoiseSelection(main: main, levelIndex: child.protocolIndex)
            }
            if levels.contains(where: { [3, 4, 7, 8, 11, 12, 13].contains($0.modeType) }) {
                hasNoiseLevels = true
            }
            groups.append(NoiseModeGroup(
                main: main,
                groupIndex: entry.protocolIndex,
                levels: levels,
                vocalEnhancementIndex: vocalIndex
            ))
        }

        let spatialTypes = functions?.spatialTypes ?? []
        let allEQ = (functions?.equalizerMode ?? [])
            + (functions?.equalizerModeCompat ?? [])
            + (functions?.equalizerModeByVersion ?? [])
        var presetsByID: [Int: EqualizerPreset] = [:]
        for entry in allEQ {
            guard let id = entry.protocolIndex, presetsByID[id] == nil else { continue }
            let name = entry.modeType.flatMap { eqNames[$0] } ?? "M\(id)"
            presetsByID[id] = EqualizerPreset(id: id, name: name)
        }

        let explicitGame = functions?.gameMode.map { $0 > 0 }
        let listGame = functions?.gameModeList?.contains { $0.gameMode == 1 } == true
        let gameSound = functions?.gameSoundList?.contains { ($0.type ?? 0) != 0 } == true

        return DeviceCapabilities(
            modelID: productID.uppercased(),
            modelName: model.name ?? productID.uppercased(),
            noiseModeByIndex: byIndex,
            indexByNoiseMode: byMode,
            noiseGroups: groups,
            selectionByIndex: selectionByIndex,
            hasAdaptiveANC: groups.contains { $0.main == .adaptive },
            hasNoiseLevels: hasNoiseLevels,
            hasVocalEnhancement: groups.contains { $0.hasVocalEnhancement },
            hasGameMode: explicitGame ?? (listGame || gameSound || true),
            hasSpatialSound: !spatialTypes.isEmpty && !spatialTypes.contains(2),
            hasSpatialAudioModes: spatialTypes.contains(2),
            hasWearDetection: (functions?.wearDetection ?? 0) > 0,
            hasDualDevice: (functions?.multiDevicesConnect ?? 0) > 0,
            equalizerPresets: presetsByID.values.sorted { $0.id < $1.id },
            hasCustomEQ: (functions?.customEqualizer ?? 0) > 0,
            customEQFrequencies: (functions?.customEqFrequency ?? []).filter { $0 > 0 },
            customEQMaximumPresets: max(0, functions?.customEqMax ?? 0)
        )
    }

    /// 顶层 noiseReductionMode.modeType → 主模式。
    /// 3/4/7/8 在部分老型号顶层出现时归入降噪；6 顶层出现时归入自适应（老语义）。
    private static func mainMode(for type: Int) -> NoiseMainMode? {
        switch type {
        case 1: return .off
        case 2: return .transparency
        case 5, 3, 4, 7, 8: return .noiseCancellation
        case 10, 6: return .adaptive
        default: return nil
        }
    }

    private static func legacyMode(for main: NoiseMainMode) -> NoiseControlMode {
        switch main {
        case .off: return .off
        case .transparency: return .transparency
        case .noiseCancellation: return .noiseCancellation
        case .adaptive: return .adaptive
        }
    }
}

/// 降噪子档位的中文显示名（modeType 语义来自 HeyMelody NoiseReductionContentUtils）。
enum NoiseNaming {
    static func levelName(modeType: Int) -> String {
        switch modeType {
        case 1: return "关闭"
        case 2: return "通透"
        case 3: return "轻度降噪"
        case 4: return "深度降噪"
        case 6: return "强化人声"
        case 7: return "智能动态"
        case 8: return "中度降噪"
        case 10: return "自适应"
        case 11: return "更少噪音"
        case 12: return "标准"
        case 13: return "更多噪音"
        default: return "档位 \(modeType)"
        }
    }

    static func mainName(_ main: NoiseMainMode) -> String {
        switch main {
        case .off: return "关闭"
        case .transparency: return "通透"
        case .noiseCancellation: return "降噪"
        case .adaptive: return "自适应"
        }
    }
}
