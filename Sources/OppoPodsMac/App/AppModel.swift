import Foundation
import IOBluetooth

@MainActor
final class AppModel: NSObject, ObservableObject {
    let devices = BluetoothDeviceRepository()
    let session = EarbudsSession()

    @Published var selectedDeviceAddress: String {
        didSet {
            UserDefaults.standard.set(selectedDeviceAddress, forKey: Keys.selectedDevice)
            connectionPrerequisiteMessage = nil
            devices.refresh()
        }
    }
    @Published var autoConnect: Bool {
        didSet {
            UserDefaults.standard.set(autoConnect, forKey: Keys.autoConnect)
            if autoConnect { scheduleReconnectAttempts() }
        }
    }
    @Published private(set) var connectionPrerequisiteMessage: String?

    var selectedDeviceIsSystemConnected: Bool {
        guard !selectedDeviceAddress.isEmpty else { return false }
        return devices.devices.first {
            $0.id.caseInsensitiveCompare(selectedDeviceAddress) == .orderedSame
        }?.isConnected == true
    }

    private var connectNotification: IOBluetoothUserNotification?
    private var reconnectTasks: [Task<Void, Never>] = []

    private enum Keys {
        static let selectedDevice = "selectedDeviceAddress"
        static let autoConnect = "autoConnect"
    }

    override init() {
        selectedDeviceAddress = UserDefaults.standard.string(forKey: Keys.selectedDevice) ?? ""
        autoConnect = UserDefaults.standard.object(forKey: Keys.autoConnect) as? Bool ?? true
        super.init()

        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(bluetoothDeviceConnected(_:device:))
        )
        devices.refresh()

        if selectedDeviceAddress.isEmpty,
           let suggested = devices.devices.first(where: { device in
               let name = device.name.lowercased()
               return ["oppo", "enco", "oneplus", "realme"].contains { name.contains($0) }
           }) {
            selectedDeviceAddress = suggested.id
        }
        scheduleReconnectAttempts()
    }

    deinit {
        connectNotification?.unregister()
        reconnectTasks.forEach { $0.cancel() }
    }

    func connectSelectedDevice() {
        connectionPrerequisiteMessage = nil
        devices.refresh()

        guard !selectedDeviceAddress.isEmpty else {
            connectionPrerequisiteMessage = "请先选择耳机。"
            return
        }
        guard let device = devices.device(for: selectedDeviceAddress) else {
            connectionPrerequisiteMessage = "无法读取所选蓝牙设备。"
            return
        }
        // RFCOMM 只是厂商控制通道，不能替代 macOS 建立系统蓝牙连接。
        // 每次点击都读取实时状态，避免使用设备列表中的过期快照。
        guard device.isConnected() else {
            devices.refresh()
            connectionPrerequisiteMessage = "请先在 macOS 系统蓝牙中连接耳机，再连接控制。"
            return
        }
        session.connect(to: device)
    }

    func reconnectIfNeeded() {
        guard autoConnect,
              let selected = devices.devices.first(where: { $0.id == selectedDeviceAddress }),
              selected.isConnected else { return }

        switch session.connectionState {
        case .disconnected, .failed:
            break
        case .connecting, .connected:
            return
        }
        connectSelectedDevice()
    }

    func refreshDevices() {
        devices.refresh()
        if selectedDeviceIsSystemConnected {
            connectionPrerequisiteMessage = nil
        }
        reconnectIfNeeded()
    }

    @objc private func bluetoothDeviceConnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        devices.refresh()
        guard device.addressString.caseInsensitiveCompare(selectedDeviceAddress) == .orderedSame else { return }
        connectionPrerequisiteMessage = nil
        // 系统蓝牙链路建立后，耳机的厂商 RFCOMM 服务可能稍晚才就绪。
        scheduleReconnectAttempts(delays: [300_000_000, 1_200_000_000, 3_000_000_000])
    }

    private func scheduleReconnectAttempts(
        delays: [UInt64] = [0, 600_000_000, 1_800_000_000, 4_000_000_000]
    ) {
        reconnectTasks.forEach { $0.cancel() }
        reconnectTasks = delays.map { delay in
            Task { @MainActor [weak self] in
                if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
                guard !Task.isCancelled, let self else { return }
                self.devices.refresh()
                self.reconnectIfNeeded()
            }
        }
    }
}
