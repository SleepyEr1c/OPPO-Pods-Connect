import AppKit
import SwiftUI
import OppoPodsCore

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: EarbudsSession
    @EnvironmentObject private var devices: BluetoothDeviceRepository

    var body: some View {
        VStack(spacing: 12) {
            header
            Divider()

            if session.connectionState == .connected {
                connectedContent
            } else {
                disconnectedContent
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 390)
        .onAppear(perform: model.refreshDevices)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "earbuds")
                .font(.title2)
                .frame(width: 32, height: 32)
                .background(.tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.deviceName)
                    .font(.headline)
                Text(connectionDescription)
                    .font(.caption)
                    .foregroundStyle(connectionColor)
            }
            Spacer()
            if session.connectionState == .connected {
                Button { session.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("刷新耳机状态")
            }
        }
    }

    private var connectedContent: some View {
        VStack(spacing: 12) {
            BatteryStatusView(battery: session.battery)

            SectionCard(title: "噪声控制", symbol: "waveform") {
                Picker("噪声控制", selection: Binding(
                    get: { session.noiseControl },
                    set: { session.setNoiseControl($0) }
                )) {
                    Text("关闭").tag(NoiseControlMode.off)
                    Text("降噪").tag(NoiseControlMode.noiseCancellation)
                    Text("通透").tag(NoiseControlMode.transparency)
                    if session.capabilities.hasAdaptiveANC {
                        Text("自适应").tag(NoiseControlMode.adaptive)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }

    private var disconnectedContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "bluetooth")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("选择已经在系统设置中配对的耳机")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("设备", selection: $model.selectedDeviceAddress) {
                Text("选择设备").tag("")
                ForEach(devices.devices) { device in
                    Text(device.isConnected ? device.displayName : "\(device.displayName)（系统未连接）")
                        .tag(device.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Button("连接控制", action: model.connectSelectedDevice)
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.selectedDeviceAddress.isEmpty
                        || !model.selectedDeviceIsSystemConnected
                        || session.connectionState == .connecting
                )

            if !model.selectedDeviceAddress.isEmpty && !model.selectedDeviceIsSystemConnected {
                Label("请先在 macOS 系统蓝牙中连接耳机", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = model.connectionPrerequisiteMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if model.connectionPrerequisiteMessage == nil,
               case .failed(let message) = session.connectionState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 18)
    }

    private var footer: some View {
        HStack {
            SettingsLink { Text("设置…") }
            Spacer()
            if session.connectionState == .connected {
                Button("断开控制", action: session.disconnect)
            }
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    private var connectionDescription: String {
        switch session.connectionState {
        case .disconnected: return "未连接"
        case .connecting: return "正在连接控制通道…"
        case .connected: return session.productID.map { "已连接 · 型号 \($0)" } ?? "已连接"
        case .failed: return "连接失败"
        }
    }

    private var connectionColor: Color {
        switch session.connectionState {
        case .connected: return .green
        case .failed: return .red
        default: return .secondary
        }
    }
}
