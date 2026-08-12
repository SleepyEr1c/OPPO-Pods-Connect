import Foundation
import IOBluetooth

struct PairedBluetoothDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let isConnected: Bool

    var displayName: String { name.isEmpty ? id : name }
}

@MainActor
final class BluetoothDeviceRepository: ObservableObject {
    @Published private(set) var devices: [PairedBluetoothDevice] = []

    func refresh() {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        devices = paired.map {
            PairedBluetoothDevice(
                id: $0.addressString,
                name: $0.name ?? "",
                isConnected: $0.isConnected()
            )
        }.sorted {
            let lhsPreferred = Self.isLikelySupported($0.name)
            let rhsPreferred = Self.isLikelySupported($1.name)
            if lhsPreferred != rhsPreferred { return lhsPreferred }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func device(for address: String) -> IOBluetoothDevice? {
        IOBluetoothDevice(addressString: address)
    }

    private static func isLikelySupported(_ name: String) -> Bool {
        let normalized = name.lowercased()
        return ["oppo", "enco", "oneplus", "realme"].contains { normalized.contains($0) }
    }
}
