import SwiftUI
import OppoPodsCore

/// 耳机连接成功后显示在刘海下方的胶囊态弹窗内容。
struct NotchPopupView: View {
    @ObservedObject var session: EarbudsSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "earbuds")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(session.deviceName)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                batteryUnit(symbol: "ear", label: "L", level: session.battery.left)
                batteryUnit(symbol: "ear", label: "R", level: session.battery.right)
                batteryUnit(symbol: "headphones.battery.75", label: "盒", level: session.battery.chargingCase)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 380)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 14, y: 5)
    }

    private var subtitle: String {
        if session.productID != nil {
            return "已连接 · \(batteryText)"
        }
        return "控制通道已连接"
    }

    private var batteryText: String {
        var parts: [String] = []
        if let left = session.battery.left { parts.append("L \(left.level)%") }
        if let right = session.battery.right { parts.append("R \(right.level)%") }
        if let box = session.battery.chargingCase { parts.append("盒 \(box.level)%") }
        return parts.isEmpty ? "读取电量中…" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func batteryUnit(symbol: String, label: String, level: BatteryLevel?) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: level?.isCharging == true ? "bolt.fill" : symbol)
                    .font(.caption2)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(level.map { "\($0.level)%" } ?? "--")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(level == nil ? .secondary : .primary)
        }
    }
}
