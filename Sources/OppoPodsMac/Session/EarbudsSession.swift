import Foundation
import IOBluetooth
import OppoPodsCore

@MainActor
final class EarbudsSession: ObservableObject {
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var deviceName = "未连接"
    @Published private(set) var productID: String?
    @Published private(set) var battery = BatteryStatus()
    @Published private(set) var noiseControl: NoiseControlMode = .off
    @Published private(set) var spatialAudio: SpatialAudioMode = .off
    @Published private(set) var gameMode = false
    @Published private(set) var wearDetection = false
    @Published private(set) var dualDevice = false
    @Published private(set) var spatialSound = false
    @Published private(set) var selectedEQ = 0
    @Published private(set) var deviceEQPresets: [DeviceEqualizerPreset] = []
    @Published private(set) var capabilities = DeviceCapabilities.generic

    var customEQPresets: [DeviceEqualizerPreset] {
        let builtInIDs = Set(capabilities.equalizerPresets.map(\.id))
        return deviceEQPresets.filter { !builtInIDs.contains($0.id) && !$0.name.isEmpty }
    }

    var equalizerPresets: [EqualizerPreset] {
        capabilities.equalizerPresets + customEQPresets.map { EqualizerPreset(id: $0.id, name: $0.name) }
    }

    var customEQFrequencies: [Int] {
        if let actual = customEQPresets.first(where: { !$0.frequencies.isEmpty })?.frequencies {
            return actual
        }
        return capabilities.customEQFrequencies.isEmpty
            ? [62, 250, 1_000, 4_000, 8_000, 16_000]
            : capabilities.customEQFrequencies
    }

    private let transport = RFCOMMTransport()
    private let commands = OppoCommands()
    private let modelRegistry = DeviceModelRegistry()
    private var framer = OppoPacketFramer()
    private var refreshTimer: Timer?
    private var initializationTasks: [Task<Void, Never>] = []
    private var connectionTimeoutTask: Task<Void, Never>?
    private var equalizerRefreshTask: Task<Void, Never>?
    // 旧设备使用 0x06；回报 0x28 后切换到新设备主开关。
    private var gameModeFeatureID: UInt8 = 0x06

    init() {
        transport.onData = { [weak self] data in self?.receive(data) }
        transport.onClosed = { [weak self] error in self?.didDisconnect(error: error) }
    }

    func connect(to device: IOBluetoothDevice) {
        guard connectionState != .connecting else { return }
        cancelInitializationTasks()
        connectionTimeoutTask?.cancel()
        connectionState = .connecting
        deviceName = device.name ?? device.addressString
        connectionTimeoutTask = Task { @MainActor [weak self, weak device] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled, let self, self.connectionState == .connecting else { return }
            self.transport.close()
            let systemConnected = device?.isConnected() == true
            self.connectionState = .failed(
                systemConnected
                    ? "控制通道连接超时，请稍后重试。"
                    : "耳机未连接系统蓝牙，请先在系统设置中连接。"
            )
        }
        transport.connect(to: device) { [weak self] result in
            guard let self else { return }
            self.connectionTimeoutTask?.cancel()
            self.connectionTimeoutTask = nil
            switch result {
            case .success:
                self.connectionState = .connected
                self.beginSession()
            case .failure(let error):
                self.connectionState = .failed(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        cancelInitializationTasks()
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        transport.close()
        resetState()
    }

    func refresh() {
        guard connectionState == .connected else { return }
        send(commands.queryStatus())
        send(commands.queryBattery())
        send(commands.queryANC())
        send(commands.queryEQ())
        if capabilities.hasCustomEQ { send(commands.queryAllEQ()) }
    }

    func setNoiseControl(_ mode: NoiseControlMode) {
        noiseControl = mode
        if let index = capabilities.indexByNoiseMode[mode] {
            send(commands.setNoiseControl(protocolIndex: index))
        } else {
            send(commands.setNoiseControl(mode))
        }
    }

    func setSpatialAudio(_ mode: SpatialAudioMode) {
        spatialAudio = mode
        send(commands.setSpatialAudio(mode))
    }

    func setGameMode(_ enabled: Bool) {
        gameMode = enabled
        send(commands.setFeature(gameModeFeatureID, enabled: enabled))
    }

    func setWearDetection(_ enabled: Bool) {
        wearDetection = enabled
        send(commands.setFeature(0x04, enabled: enabled))
    }

    func setDualDevice(_ enabled: Bool) {
        dualDevice = enabled
        send(commands.setFeature(0x11, enabled: enabled))
    }

    func setSpatialSound(_ enabled: Bool) {
        spatialSound = enabled
        send(commands.setFeature(0x1B, enabled: enabled))
    }

    func setEQ(_ presetID: Int) {
        selectedEQ = presetID
        send(commands.setEQ(presetID))
    }

    func refreshCustomEQ() {
        guard capabilities.hasCustomEQ else { return }
        send(commands.queryEQ())
        send(commands.queryAllEQ())
    }

    func saveCustomEQ(
        id: Int,
        name: String,
        frequencies: [Int],
        gains: [Int],
        minimumGain: Int,
        maximumGain: Int
    ) {
        guard capabilities.hasCustomEQ, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        send(commands.saveCustomEQ(
            id: id,
            name: name,
            frequencies: frequencies,
            gains: gains,
            minimumGain: minimumGain,
            maximumGain: maximumGain
        ))
        scheduleEqualizerRefresh()
    }

    func deleteCustomEQ(_ preset: DeviceEqualizerPreset) {
        guard capabilities.hasCustomEQ, preset.id > 0 else { return }
        send(commands.deleteCustomEQ(preset))
        deviceEQPresets.removeAll { $0.id == preset.id }
        scheduleEqualizerRefresh()
    }

    private func beginSession() {
        send(commands.handshake())
        send(commands.queryProductID())
        send(commands.queryBroadcastCodes())
        refresh()

        // 已经由系统建立音频连接时，厂商控制通道有时会延迟进入可查询状态。
        // 分阶段重发初始化查询，不要求用户先断开再连接耳机。
        initializationTasks = [250_000_000, 1_000_000_000, 2_500_000_000].map { delay in
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay))
                guard !Task.isCancelled, let self, self.connectionState == .connected else { return }
                self.send(self.commands.queryProductID())
                self.send(self.commands.queryBroadcastCodes())
                self.refresh()
            }
        }
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func receive(_ data: Data) {
        for packet in framer.append(data) {
            guard let frame = OppoFrame(data: packet) else { continue }
            if let nextBattery = OppoParsers.battery(from: frame) {
                battery = BatteryStatus(
                    left: nextBattery.left ?? battery.left,
                    right: nextBattery.right ?? battery.right,
                    chargingCase: nextBattery.chargingCase ?? battery.chargingCase
                )
            }
            if let id = OppoParsers.productID(from: frame) {
                productID = id
                if let matched = modelRegistry.capabilities(for: id) {
                    if capabilities.modelID != matched.modelID { deviceEQPresets = [] }
                    capabilities = matched
                    deviceName = matched.modelName
                    if matched.hasCustomEQ { send(commands.queryAllEQ()) }
                }
            }
            if let mode = OppoParsers.noiseControl(
                from: frame,
                indexToMode: capabilities.noiseModeByIndex
            ) { noiseControl = mode }
            if let mode = OppoParsers.spatialAudio(from: frame) { spatialAudio = mode }
            if let status = OppoParsers.featureStatus(from: frame) {
                if let mainMode = status.gameMode {
                    gameModeFeatureID = 0x28
                    gameMode = mainMode
                } else if let lowLatencyMode = status.lowLatencyMode {
                    gameModeFeatureID = 0x06
                    gameMode = lowLatencyMode
                }
                wearDetection = status.wearDetection ?? wearDetection
                dualDevice = status.dualDevice ?? dualDevice
                spatialSound = status.spatialSound ?? spatialSound
            }
            if let preset = OppoParsers.currentEQ(from: frame) { selectedEQ = preset }
            if let presets = OppoParsers.allEqualizers(from: frame) {
                deviceEQPresets = presets
                if let selected = presets.first(where: \.isSelected) { selectedEQ = selected.id }
            }
            if let codes = OppoParsers.broadcastCodes(from: frame) {
                send(commands.subscribe(to: codes))
            }
        }
    }

    private func send(_ data: Data) {
        guard connectionState == .connected else { return }
        do { try transport.send(data) }
        catch { connectionState = .failed(error.localizedDescription) }
    }

    private func didDisconnect(error: Error?) {
        cancelInitializationTasks()
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        resetState()
        if let error { connectionState = .failed(error.localizedDescription) }
    }

    private func resetState() {
        connectionState = .disconnected
        deviceName = "未连接"
        productID = nil
        battery = BatteryStatus()
        noiseControl = .off
        spatialAudio = .off
        gameMode = false
        wearDetection = false
        dualDevice = false
        spatialSound = false
        selectedEQ = 0
        deviceEQPresets = []
        gameModeFeatureID = 0x06
        capabilities = .generic
    }

    private func scheduleEqualizerRefresh() {
        equalizerRefreshTask?.cancel()
        equalizerRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self?.refreshCustomEQ()
        }
    }

    private func cancelInitializationTasks() {
        initializationTasks.forEach { $0.cancel() }
        initializationTasks.removeAll()
        equalizerRefreshTask?.cancel()
        equalizerRefreshTask = nil
    }
}
