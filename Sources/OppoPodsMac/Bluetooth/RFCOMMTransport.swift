import Foundation
import IOBluetooth

enum RFCOMMTransportError: LocalizedError {
    case invalidDevice
    case sdpQueryFailed(IOReturn)
    case serviceNotFound
    case channelOpenFailed(IOReturn)
    case writeFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .invalidDevice: return "无法访问所选蓝牙设备。"
        case .sdpQueryFailed(let status): return "查询耳机服务失败（\(status)）。"
        case .serviceNotFound: return "没有找到 OPPO/HeyMelody RFCOMM 服务。"
        case .channelOpenFailed(let status): return "打开耳机控制通道失败（\(status)）。"
        case .writeFailed(let status): return "向耳机发送指令失败（\(status)）。"
        }
    }
}

@MainActor
final class RFCOMMTransport: NSObject {
    var onData: ((Data) -> Void)?
    var onClosed: ((Error?) -> Void)?

    private static let serviceUUIDStrings = [
        "00001107-D102-11E1-9B23-00025B00A5A5",
        "0000079A-D102-11E1-9B23-00025B00A5A5",
    ]

    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var attemptedFallback = false

    func connect(to device: IOBluetoothDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        close(notify: false)
        self.device = device
        self.completion = completion
        attemptedFallback = false

        let status = device.performSDPQuery(self)
        if status != kIOReturnSuccess {
            open(channelID: 15)
        }
    }

    func send(_ data: Data) throws {
        guard let channel, channel.isOpen() else { throw RFCOMMTransportError.invalidDevice }
        var copy = data
        let status = copy.withUnsafeMutableBytes { rawBuffer -> IOReturn in
            channel.writeSync(rawBuffer.baseAddress, length: UInt16(clamping: rawBuffer.count))
        }
        guard status == kIOReturnSuccess else { throw RFCOMMTransportError.writeFailed(status) }
    }

    func close() {
        close(notify: false)
    }

    private func close(notify: Bool) {
        if channel?.isOpen() == true { _ = channel?.close() }
        channel = nil
        device = nil
        completion = nil
        if notify { onClosed?(nil) }
    }

    @objc(sdpQueryComplete:status:)
    func sdpQueryComplete(_ device: IOBluetoothDevice, status: IOReturn) {
        guard status == kIOReturnSuccess else {
            open(channelID: 15)
            return
        }

        for string in Self.serviceUUIDStrings {
            guard let uuid = Self.sdpUUID(from: string),
                  let record = device.getServiceRecord(for: uuid) else { continue }
            var channelID: BluetoothRFCOMMChannelID = 0
            if record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess {
                open(channelID: channelID)
                return
            }
        }
        open(channelID: 15)
    }

    private func open(channelID: BluetoothRFCOMMChannelID) {
        guard let device else {
            finish(.failure(RFCOMMTransportError.invalidDevice))
            return
        }
        attemptedFallback = channelID == 15
        var openedChannel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelAsync(
            &openedChannel,
            withChannelID: channelID,
            delegate: self
        )
        if status == kIOReturnSuccess {
            channel = openedChannel
        } else if channelID != 15 {
            open(channelID: 15)
        } else {
            finish(.failure(RFCOMMTransportError.channelOpenFailed(status)))
        }
    }

    @objc(rfcommChannelOpenComplete:status:)
    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel, status: IOReturn) {
        if status == kIOReturnSuccess {
            channel = rfcommChannel
            finish(.success(()))
        } else if !attemptedFallback {
            open(channelID: 15)
        } else {
            finish(.failure(RFCOMMTransportError.channelOpenFailed(status)))
        }
    }

    @objc(rfcommChannelData:data:length:)
    func rfcommChannelData(
        _ rfcommChannel: IOBluetoothRFCOMMChannel,
        data dataPointer: UnsafeMutableRawPointer,
        length dataLength: Int
    ) {
        onData?(Data(bytes: dataPointer, count: dataLength))
    }

    @objc(rfcommChannelClosed:)
    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel) {
        channel = nil
        onClosed?(nil)
    }

    private func finish(_ result: Result<Void, Error>) {
        let callback = completion
        completion = nil
        callback?(result)
    }

    private static func sdpUUID(from string: String) -> IOBluetoothSDPUUID? {
        guard let uuid = UUID(uuidString: string) else { return nil }
        var value = uuid.uuid
        let data = withUnsafeBytes(of: &value) { Data($0) }
        return IOBluetoothSDPUUID(data: data)
    }
}
