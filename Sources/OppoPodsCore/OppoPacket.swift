import Foundation

public enum OppoCommand {
    public static let handshake = 0x0100
    public static let queryProductID = 0x0103
    public static let queryBattery = 0x0106
    public static let queryStatus = 0x010D
    public static let queryANC = 0x010C
    public static let queryEQ = 0x010F
    public static let queryAllEQ = 0x0122
    public static let queryBroadcastCodes = 0x0200
    public static let subscribeBroadcast = 0x0205
    public static let activeReport = 0x0204
    public static let setFeature = 0x0403
    public static let setANC = 0x0404
    public static let setEQ = 0x0406
    public static let setSpatialAudio = 0x0422
    public static let spatialAudioNotify = 0x0510

    public static let productIDResponse = 0x8103
    public static let batteryResponse = 0x8106
    public static let statusResponse = 0x810D
    public static let ancResponse = 0x810C
    public static let eqResponse = 0x810F
    public static let allEQResponse = 0x8122
    public static let broadcastCodesResponse = 0x8200
}

public struct OppoFrame: Equatable, Sendable {
    public let command: Int
    public let sequence: UInt8
    public let payload: Data

    public init(command: Int, sequence: UInt8, payload: Data = Data()) {
        self.command = command
        self.sequence = sequence
        self.payload = payload
    }

    public init?(data: Data) {
        guard data.count >= 9, data[0] == 0xAA else { return nil }
        let totalLength = Int(data[1])
        guard totalLength >= 7, data.count == totalLength + 2 else { return nil }
        let payloadLength = Int(data[7]) | (Int(data[8]) << 8)
        guard payloadLength == totalLength - 7, data.count >= 9 + payloadLength else { return nil }
        command = Int(data[4]) | (Int(data[5]) << 8)
        sequence = data[6]
        payload = data.subdata(in: 9..<(9 + payloadLength))
    }

    public var data: Data {
        let payloadLength = payload.count
        let totalLength = payloadLength + 7
        var result = Data(capacity: totalLength + 2)
        result.append(0xAA)
        result.append(UInt8(truncatingIfNeeded: totalLength))
        result.append(contentsOf: [0x00, 0x00])
        result.append(UInt8(truncatingIfNeeded: command))
        result.append(UInt8(truncatingIfNeeded: command >> 8))
        result.append(sequence)
        result.append(UInt8(truncatingIfNeeded: payloadLength))
        result.append(UInt8(truncatingIfNeeded: payloadLength >> 8))
        result.append(payload)
        return result
    }
}

public final class OppoPacketBuilder: @unchecked Sendable {
    private let lock = NSLock()
    private var sequence: UInt8 = 1

    public init() {}

    public func make(_ command: Int, payload: [UInt8] = []) -> Data {
        lock.lock()
        let current = sequence
        sequence = sequence >= 0xFE ? 1 : sequence + 1
        lock.unlock()
        return OppoFrame(command: command, sequence: current, payload: Data(payload)).data
    }

    public func make(_ command: Int, fixedSequence: UInt8, payload: [UInt8] = []) -> Data {
        OppoFrame(command: command, sequence: fixedSequence, payload: Data(payload)).data
    }
}
