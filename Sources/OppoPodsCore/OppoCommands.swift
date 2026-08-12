import Foundation

public struct OppoCommands: Sendable {
    private let builder: OppoPacketBuilder

    public init(builder: OppoPacketBuilder = OppoPacketBuilder()) {
        self.builder = builder
    }

    public func handshake() -> Data { builder.make(OppoCommand.handshake) }
    public func queryProductID() -> Data { builder.make(OppoCommand.queryProductID) }
    public func queryBattery() -> Data { builder.make(OppoCommand.queryBattery, fixedSequence: 0xF0) }
    public func queryANC() -> Data { builder.make(OppoCommand.queryANC, payload: [0x01, 0x01]) }
    public func queryEQ() -> Data { builder.make(OppoCommand.queryEQ) }
    public func queryBroadcastCodes() -> Data { builder.make(OppoCommand.queryBroadcastCodes) }

    public func queryStatus() -> Data {
        builder.make(
            OppoCommand.queryStatus,
            fixedSequence: 0,
            payload: [0x0B, 0x05, 0x04, 0x0B, 0x11, 0x13, 0x18, 0x06, 0x1B, 0x1C, 0x27, 0x28]
        )
    }

    public func subscribe(to codes: [UInt8]) -> Data {
        builder.make(OppoCommand.subscribeBroadcast, payload: [UInt8(clamping: codes.count)] + codes)
    }

    public func setNoiseControl(_ mode: NoiseControlMode) -> Data {
        let payload: [UInt8]
        switch mode {
        case .off: payload = [0x01, 0x01, 0x08]
        case .noiseCancellation: payload = [0x01, 0x01, 0x10]
        case .transparency: payload = [0x01, 0x01, 0x00, 0x01]
        case .adaptive: payload = [0x01, 0x01, 0x00, 0x08]
        }
        return builder.make(OppoCommand.setANC, fixedSequence: 0xF0, payload: payload)
    }

    public func setNoiseControl(protocolIndex: Int) -> Data {
        let byteCount = protocolIndex / 8 + 1
        var payload = [UInt8](repeating: 0, count: 2 + byteCount)
        payload[0] = 0x01
        payload[1] = 0x01
        payload[2 + protocolIndex / 8] = UInt8(1 << (protocolIndex % 8))
        return builder.make(OppoCommand.setANC, fixedSequence: 0xF0, payload: payload)
    }

    public func setFeature(_ feature: UInt8, enabled: Bool) -> Data {
        builder.make(OppoCommand.setFeature, fixedSequence: 0xF0, payload: [feature, enabled ? 1 : 0])
    }

    public func setSpatialAudio(_ mode: SpatialAudioMode) -> Data {
        builder.make(OppoCommand.setSpatialAudio, fixedSequence: 0xF0, payload: [UInt8(mode.rawValue)])
    }

    public func setEQ(_ presetID: Int) -> Data {
        builder.make(OppoCommand.setEQ, payload: [UInt8(clamping: presetID)])
    }
}
