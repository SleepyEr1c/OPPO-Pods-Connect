import SwiftUI
import OppoPodsCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var session: EarbudsSession
    @EnvironmentObject private var devices: BluetoothDeviceRepository

    var body: some View {
        TabView {
            controlsPage
                .tabItem { Label("耳机控制", systemImage: "slider.horizontal.3") }

            Form {
                Picker("首选耳机", selection: $model.selectedDeviceAddress) {
                    Text("未选择").tag("")
                    ForEach(devices.devices) { device in
                        Text(device.isConnected ? device.displayName : "\(device.displayName)（系统未连接）")
                            .tag(device.id)
                    }
                }
                Toggle("耳机已连接时自动建立控制通道", isOn: $model.autoConnect)
                HStack {
                    Button("刷新设备列表", action: model.refreshDevices)
                    Spacer()
                    if session.connectionState == .connected {
                        Button("断开控制", action: session.disconnect)
                    } else {
                        Button("连接控制", action: model.connectSelectedDevice)
                            .disabled(
                                model.selectedDeviceAddress.isEmpty
                                    || !model.selectedDeviceIsSystemConnected
                                    || session.connectionState == .connecting
                            )
                    }
                }
                if !model.selectedDeviceAddress.isEmpty && !model.selectedDeviceIsSystemConnected {
                    Label("请先在 macOS 系统蓝牙中连接耳机", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let message = model.connectionPrerequisiteMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(20)
            .onAppear(perform: model.refreshDevices)
            .tabItem { Label("通用", systemImage: "gearshape") }

            Form {
                LabeledContent("识别型号", value: session.capabilities.modelName)
                if !session.capabilities.modelID.isEmpty {
                    LabeledContent("Product ID", value: session.capabilities.modelID)
                        .monospaced()
                }
                LabeledContent("自适应降噪", value: supportedText(session.capabilities.hasAdaptiveANC))
                LabeledContent("游戏低延迟", value: supportedText(session.capabilities.hasGameMode))
                LabeledContent("空间音效", value: supportedText(session.capabilities.hasSpatialSound || session.capabilities.hasSpatialAudioModes))
                LabeledContent("佩戴检测", value: supportedText(session.capabilities.hasWearDetection))
                LabeledContent("双设备连接", value: supportedText(session.capabilities.hasDualDevice))
                LabeledContent("均衡器", value: supportedText(!session.equalizerPresets.isEmpty || session.capabilities.hasCustomEQ))
                Text("能力来自原项目内置的 HeyMelody 型号白名单，并由耳机 productId 自动匹配。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label("型号能力", systemImage: "earbuds") }

            VStack(spacing: 10) {
                Image(systemName: "earbuds")
                    .font(.system(size: 38))
                Text("OPPOPods for macOS")
                    .font(.title3.weight(.semibold))
                Text("通过 OPPO / HeyMelody RFCOMM 协议控制耳机。")
                    .foregroundStyle(.secondary)
                if let productID = session.productID {
                    Text("当前型号 ID：\(productID)")
                        .font(.caption.monospaced())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
            .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 700, height: 470)
    }

    private var controlsPage: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
                alignment: .leading,
                spacing: 14
            ) {
                if session.capabilities.hasGameMode {
                    SettingsControlCard(title: "游戏低延迟", symbol: "gamecontroller") {
                        Toggle("低延迟模式", isOn: Binding(
                            get: { session.gameMode },
                            set: { session.setGameMode($0) }
                        ))
                        Text("减少游戏声音延迟")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if session.capabilities.hasSpatialSound || session.capabilities.hasSpatialAudioModes {
                    SettingsControlCard(title: "空间音效", symbol: "person.wave.2") {
                        if session.capabilities.hasSpatialAudioModes {
                            Picker("模式", selection: Binding(
                                get: { session.spatialAudio },
                                set: { session.setSpatialAudio($0) }
                            )) {
                                Text("关闭").tag(SpatialAudioMode.off)
                                Text("固定").tag(SpatialAudioMode.fixed)
                                Text("跟踪").tag(SpatialAudioMode.headTracking)
                            }
                            .pickerStyle(.segmented)
                        } else {
                            Toggle("启用空间音效", isOn: Binding(
                                get: { session.spatialSound },
                                set: { session.setSpatialSound($0) }
                            ))
                        }
                    }
                }

                if !session.equalizerPresets.isEmpty || session.capabilities.hasCustomEQ {
                    SettingsControlCard(title: "声音效果", symbol: "speaker.wave.2") {
                        if !session.equalizerPresets.isEmpty {
                            Picker("均衡器", selection: Binding(
                                get: { session.selectedEQ },
                                set: { session.setEQ($0) }
                            )) {
                                ForEach(session.equalizerPresets) { preset in
                                    Text(preset.name).tag(preset.id)
                                }
                            }
                        }
                        if session.capabilities.hasCustomEQ {
                            Text("支持自定义均衡器")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if session.capabilities.hasWearDetection || session.capabilities.hasDualDevice {
                    SettingsControlCard(title: "设备控制", symbol: "earbuds") {
                        if session.capabilities.hasWearDetection {
                            Toggle("佩戴检测", isOn: Binding(
                                get: { session.wearDetection },
                                set: { session.setWearDetection($0) }
                            ))
                        }
                        if session.capabilities.hasDualDevice {
                            Toggle("双设备连接", isOn: Binding(
                                get: { session.dualDevice },
                                set: { session.setDualDevice($0) }
                            ))
                        }
                    }
                }

                SettingsControlCard(title: "当前耳机", symbol: "info.circle") {
                    LabeledContent("型号", value: session.capabilities.modelName)
                    if !session.capabilities.modelID.isEmpty {
                        LabeledContent("ID", value: session.capabilities.modelID)
                            .monospaced()
                    }
                }
            }
            .padding(20)
        }
        .overlay {
            if session.connectionState != .connected {
                ContentUnavailableView(
                    "耳机未连接",
                    systemImage: "earbuds.case",
                    description: Text("连接耳机后显示该型号支持的控制项目。")
                )
                .background(.background)
            }
        }
    }

    private func supportedText(_ supported: Bool) -> String {
        supported ? "支持" : "不支持或未声明"
    }
}

private struct SettingsControlCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
            Divider()
            content
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
