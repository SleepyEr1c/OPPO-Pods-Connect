import Foundation
import OppoPodsCore

struct DeviceCapabilities: Equatable {
    let modelID: String
    let modelName: String
    let noiseModeByIndex: [Int: NoiseControlMode]
    let indexByNoiseMode: [NoiseControlMode: Int]
    let hasAdaptiveANC: Bool
    let hasNoiseLevels: Bool
    let hasGameMode: Bool
    let hasSpatialSound: Bool
    let hasSpatialAudioModes: Bool
    let hasWearDetection: Bool
    let hasDualDevice: Bool
    let equalizerPresets: [EqualizerPreset]
    let hasCustomEQ: Bool

    static let generic = DeviceCapabilities(
        modelID: "",
        modelName: "未识别型号",
        noiseModeByIndex: [:],
        indexByNoiseMode: [:],
        hasAdaptiveANC: true,
        hasNoiseLevels: false,
        hasGameMode: true,
        hasSpatialSound: true,
        hasSpatialAudioModes: false,
        hasWearDetection: false,
        hasDualDevice: false,
        equalizerPresets: [],
        hasCustomEQ: false
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
        var hasNoiseLevels = false

        for entry in functions?.noiseReductionMode ?? [] {
            guard let mode = Self.noiseMode(for: entry.modeType) else { continue }
            byIndex[entry.protocolIndex] = mode
            byMode[mode] = entry.protocolIndex
            for child in entry.childrenMode ?? [] {
                if [3, 4, 7, 8].contains(child.modeType) { hasNoiseLevels = true }
                byIndex[child.protocolIndex] = Self.noiseMode(for: child.modeType) ?? mode
            }
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
            hasAdaptiveANC: byMode[.adaptive] != nil,
            hasNoiseLevels: hasNoiseLevels,
            hasGameMode: explicitGame ?? (listGame || gameSound || true),
            hasSpatialSound: !spatialTypes.isEmpty && !spatialTypes.contains(2),
            hasSpatialAudioModes: spatialTypes.contains(2),
            hasWearDetection: (functions?.wearDetection ?? 0) > 0,
            hasDualDevice: (functions?.multiDevicesConnect ?? 0) > 0,
            equalizerPresets: presetsByID.values.sorted { $0.id < $1.id },
            hasCustomEQ: (functions?.customEqualizer ?? 0) > 0
        )
    }

    private static func noiseMode(for type: Int) -> NoiseControlMode? {
        switch type {
        case 1: return .off
        case 2: return .transparency
        case 5, 3, 4, 7, 8: return .noiseCancellation
        case 6, 10: return .adaptive
        default: return nil
        }
    }
}
