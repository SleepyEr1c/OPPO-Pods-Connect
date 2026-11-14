import AppKit
import SwiftUI
import OppoPodsCore

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: EarbudsSession
    @EnvironmentObject private var devices: BluetoothDeviceRepository

    @State private var contentHeight: CGFloat = 0

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
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ContentHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ContentHeightPreferenceKey.self) { contentHeight = $0 }
        // MenuBarExtra 的窗口在内容变矮时不会自动收缩，窗口材质与内容错位后
        // 会出现直角和边框线。这里把内容高度同步给窗口，强制窗口跟随内容。
        .background(WindowSizeSync(width: 390, height: contentHeight))
        .onAppear {
            model.refreshDevices()
            // 菜单面板与刘海弹窗可能重叠，打开菜单时先收起弹窗。
            NotchPopupController.shared.hide()
        }
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
                noiseControlContent
            }
        }
    }

    private var orderedNoiseGroups: [NoiseModeGroup] {
        let order: [NoiseMainMode] = [.off, .noiseCancellation, .transparency, .adaptive]
        return order.compactMap { main in
            session.capabilities.noiseGroups.first { $0.main == main }
        }
    }

    @ViewBuilder
    private var noiseControlContent: some View {
        let groups = orderedNoiseGroups
        let currentGroup = groups.first { $0.main == session.noiseSelection.main }

        Picker("噪声控制", selection: Binding(
            get: { session.noiseSelection.main },
            set: { main in
                let group = groups.first { $0.main == main }
                let level = group.flatMap { g in
                    g.levels.isEmpty ? nil : g.defaultLevelIndex
                }
                session.setNoiseSelection(NoiseSelection(main: main, levelIndex: level))
            }
        )) {
            ForEach(groups, id: \.main) { group in
                Text(NoiseNaming.mainName(group.main)).tag(group.main)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)

        if let group = currentGroup, !group.levels.isEmpty {
            Picker("档位", selection: Binding(
                get: { session.noiseSelection.levelIndex ?? group.defaultLevelIndex },
                set: { session.setNoiseLevel($0) }
            )) {
                ForEach(group.levels) { level in
                    Text(NoiseNaming.levelName(modeType: level.modeType)).tag(level.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }

        if session.noiseSelection.main == .transparency,
           let group = currentGroup,
           group.hasVocalEnhancement {
            Toggle("强化人声", isOn: Binding(
                get: { session.isVocalEnhancementOn },
                set: { session.setVocalEnhancement($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
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

private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 把 SwiftUI 内容高度同步给 MenuBarExtra 窗口。
/// 系统窗口在内容变矮时不会自动收缩（高度滞留），导致窗口材质与内容错位，
/// 出现空白、直角和边框线；这里显式调用 setContentSize 强制跟随。
private struct WindowSizeSync: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat

    final class SyncView: NSView {
        var targetWidth: CGFloat = 0
        var targetHeight: CGFloat = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        override func layout() {
            super.layout()
            apply()
        }

        func apply() {
            guard let window, targetWidth > 1, targetHeight > 1 else { return }
            let target = NSSize(width: targetWidth, height: targetHeight)
            guard abs(window.frame.width - target.width) > 1
                || abs(window.frame.height - target.height) > 1 else { return }
            window.setContentSize(target)
            window.invalidateShadow()
        }
    }

    func makeNSView(context: Context) -> SyncView {
        let view = SyncView()
        view.targetWidth = width
        view.targetHeight = height
        DispatchQueue.main.async { view.apply() }
        return view
    }

    func updateNSView(_ nsView: SyncView, context: Context) {
        nsView.targetWidth = width
        nsView.targetHeight = height
        nsView.apply()
    }
}
