import XCTest
@testable import OppoPodsCore

final class OppoProtocolTests: XCTestCase {
    func testPacketRoundTrip() throws {
        let data = OppoFrame(command: OppoCommand.setANC, sequence: 0xF0, payload: Data([1, 1, 2])).data
        let frame = try XCTUnwrap(OppoFrame(data: data))
        XCTAssertEqual(frame.command, OppoCommand.setANC)
        XCTAssertEqual(frame.sequence, 0xF0)
        XCTAssertEqual(frame.payload, Data([1, 1, 2]))
    }

    func testFramerHandlesSplitAndCombinedPackets() {
        let first = OppoFrame(command: OppoCommand.queryBattery, sequence: 1).data
        let second = OppoFrame(command: OppoCommand.queryANC, sequence: 2, payload: Data([1, 1])).data
        var framer = OppoPacketFramer()

        XCTAssertTrue(framer.append(first.prefix(4)).isEmpty)
        let frames = framer.append(first.dropFirst(4) + second)
        XCTAssertEqual(frames, [first, second])
    }

    func testBatteryParser() throws {
        let frame = OppoFrame(
            command: OppoCommand.batteryResponse,
            sequence: 1,
            payload: Data([1, 86, 2, UInt8(0x80 | 74), 3, 55])
        )
        let battery = try XCTUnwrap(OppoParsers.battery(from: frame))
        XCTAssertEqual(battery.left, BatteryLevel(level: 86, isCharging: false))
        XCTAssertEqual(battery.right, BatteryLevel(level: 74, isCharging: true))
        XCTAssertEqual(battery.chargingCase, BatteryLevel(level: 55, isCharging: false))
    }

    func testKnownSpatialPacket() {
        let data = OppoCommands().setSpatialAudio(.headTracking)
        XCTAssertEqual(data, Data([0xAA, 0x08, 0, 0, 0x22, 0x04, 0xF0, 1, 0, 2]))
    }

    func testGameModeFeatureVariants() throws {
        let frame = OppoFrame(
            command: OppoCommand.statusResponse,
            sequence: 1,
            payload: Data([0, 2, 0x06, 1, 0x28, 0])
        )
        let status = try XCTUnwrap(OppoParsers.featureStatus(from: frame))
        XCTAssertEqual(status.lowLatencyMode, true)
        XCTAssertEqual(status.gameMode, false)
    }

    func testModelSpecificANCPayload() {
        let data = OppoCommands().setNoiseControl(protocolIndex: 11)
        XCTAssertEqual(data, Data([0xAA, 0x0B, 0, 0, 0x04, 0x04, 0xF0, 4, 0, 1, 1, 0, 0x08]))
    }

    func testQueryAllEqualizersPacket() throws {
        let frame = try XCTUnwrap(OppoFrame(data: OppoCommands().queryAllEQ()))
        XCTAssertEqual(frame.command, OppoCommand.queryAllEQ)
        XCTAssertEqual(frame.payload, Data([0x01, 0x05]))
    }

    func testCustomEqualizerParser() throws {
        let name = Array("自定义".utf8)
        let payload = Data(
            [0, 1, 1, 0xFA, 0x06, 7, UInt8(name.count)]
                + name
                + [2, 62, 0, 3, 0xE8, 3, 0xFE]
        )
        let frame = OppoFrame(command: OppoCommand.allEQResponse, sequence: 1, payload: payload)
        let presets = try XCTUnwrap(OppoParsers.allEqualizers(from: frame))
        XCTAssertEqual(presets, [DeviceEqualizerPreset(
            id: 7,
            name: "自定义",
            isSelected: true,
            minimumGain: -6,
            maximumGain: 6,
            frequencies: [62, 1_000],
            gains: [3, -2]
        )])
    }

    func testSaveCustomEqualizerPacket() throws {
        let data = OppoCommands().saveCustomEQ(
            id: 7,
            name: "EQ",
            frequencies: [62, 1_000],
            gains: [3, -2]
        )
        let frame = try XCTUnwrap(OppoFrame(data: data))
        XCTAssertEqual(frame.command, OppoCommand.setEQDetail)
        XCTAssertEqual(
            frame.payload,
            Data([2, 0xFA, 0x06, 7, 2, 0x45, 0x51, 2, 62, 0, 3, 0xE8, 3, 0xFE])
        )
    }

    // MARK: - 噪声两级选择（深度档位 / 强化人声）

    func testNoiseIndexBitmapExtraction() {
        // 0x01 0x01 前缀后跟两位位图：低字节 bit4 = protocolIndex 4（深度降噪）
        let frame = OppoFrame(
            command: OppoCommand.ancResponse,
            sequence: 1,
            payload: Data([0x01, 0x01, 0x10, 0x00])
        )
        XCTAssertEqual(OppoParsers.noiseIndexBitmap(from: frame), 0x10)

        // 高字节 bit0 = protocolIndex 8（通透默认档）
        let highFrame = OppoFrame(
            command: OppoCommand.ancResponse,
            sequence: 1,
            payload: Data([0x01, 0x01, 0x00, 0x01])
        )
        XCTAssertEqual(OppoParsers.noiseIndexBitmap(from: highFrame), 0x100)
    }

    func testNoiseSelectionPrefersLeveledEntry() {
        let indexToSelection: [Int: NoiseSelection] = [
            1: NoiseSelection(main: .noiseCancellation),
            4: NoiseSelection(main: .noiseCancellation, levelIndex: 4),
            7: NoiseSelection(main: .noiseCancellation, levelIndex: 7),
            8: NoiseSelection(main: .transparency, levelIndex: 8),
        ]
        // 位图命中 protocolIndex 4
        let frame = OppoFrame(
            command: OppoCommand.ancResponse,
            sequence: 1,
            payload: Data([0x01, 0x01, 0x10, 0x00])
        )
        let selection = OppoParsers.noiseSelection(from: frame, indexToSelection: indexToSelection)
        XCTAssertEqual(selection, NoiseSelection(main: .noiseCancellation, levelIndex: 4))
    }

    func testNoiseSelectionFallsBackToGroupEntry() {
        let indexToSelection: [Int: NoiseSelection] = [
            1: NoiseSelection(main: .noiseCancellation),
            4: NoiseSelection(main: .noiseCancellation, levelIndex: 4),
        ]
        // 位图只命中顶层组 protocolIndex 1
        let frame = OppoFrame(
            command: OppoCommand.ancResponse,
            sequence: 1,
            payload: Data([0x01, 0x01, 0x02, 0x00])
        )
        let selection = OppoParsers.noiseSelection(from: frame, indexToSelection: indexToSelection)
        XCTAssertEqual(selection, NoiseSelection(main: .noiseCancellation))
    }

    // MARK: - 双联（多点连接）

    private func multiConnectElement(
        macReversed: [UInt8],
        state: UInt8,
        flag: UInt8,
        name: String
    ) -> [UInt8] {
        let nameBytes = Array(name.utf8)
        let recordLength = 3 + nameBytes.count
        return macReversed + [UInt8(recordLength), state, flag, UInt8(nameBytes.count)] + nameBytes
    }

    func testMultiConnectDevicesFromResponseWithStatus() throws {
        // 真实响应格式：[status, count, elements…]（官方轮询响应约定，数据从 offset 1 开始）
        let element = multiConnectElement(
            macReversed: [0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA],
            state: 2,
            flag: 0x01 | (3 << 3),
            name: "MacBook"
        )
        let payload = Data([0x00, 0x01] + element)
        let frame = OppoFrame(command: OppoCommand.multiConnectResponse, sequence: 1, payload: payload)
        let devices = try XCTUnwrap(OppoParsers.multiConnectDevices(from: frame))
        XCTAssertEqual(devices.count, 1)
        let device = try XCTUnwrap(devices.first)
        XCTAssertEqual(device.address, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(device.name, "MacBook")
        XCTAssertEqual(device.connectionState, .connected)
        XCTAssertTrue(device.isCurrentDevice)
        XCTAssertFalse(device.isMainAudioDevice)
        XCTAssertFalse(device.isAudioActive)
        XCTAssertEqual(device.deviceType, 3)
    }

    func testMultiConnectDevicesFromResponseWithoutStatus() throws {
        // 兼容固件省略 status 字节的变体：[count, elements…]
        let element = multiConnectElement(
            macReversed: [0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA],
            state: 2,
            flag: 0x01,
            name: "MacBook"
        )
        let payload = Data([0x01] + element)
        let frame = OppoFrame(command: OppoCommand.multiConnectResponse, sequence: 1, payload: payload)
        let devices = try XCTUnwrap(OppoParsers.multiConnectDevices(from: frame))
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.address, "AA:BB:CC:DD:EE:FF")
    }

    func testMultiConnectEmptyResponse() {
        // [status, count=0]：合法的空列表
        let frame = OppoFrame(command: OppoCommand.multiConnectResponse, sequence: 1, payload: Data([0x00, 0x00]))
        XCTAssertEqual(OppoParsers.multiConnectDevices(from: frame), [])
    }

    func testMultiConnectDevicesSkipZeroAddress() {
        let zero = multiConnectElement(
            macReversed: [UInt8](repeating: 0, count: 6),
            state: 2,
            flag: 0,
            name: "X"
        )
        let payload = Data([0x00, 0x01] + zero)
        let frame = OppoFrame(command: OppoCommand.multiConnectResponse, sequence: 1, payload: payload)
        XCTAssertEqual(OppoParsers.multiConnectDevices(from: frame), [])
    }

    func testMultiConnectDevicesFromActiveEvent() throws {
        let element = multiConnectElement(
            macReversed: [0x44, 0x33, 0x22, 0x11, 0x00, 0x99],
            state: 1,
            flag: 0x06,
            name: "iPhone"
        )
        // 0x0204 事件：type=0x06 + count + elements
        let payload = Data([0x06, 0x01] + element)
        let frame = OppoFrame(command: OppoCommand.activeReport, sequence: 0xFF, payload: payload)
        let devices = try XCTUnwrap(OppoParsers.multiConnectDevices(from: frame))
        XCTAssertEqual(devices.count, 1)
        let device = try XCTUnwrap(devices.first)
        XCTAssertEqual(device.address, "99:00:11:22:33:44")
        XCTAssertEqual(device.name, "iPhone")
        XCTAssertEqual(device.connectionState, .connecting)
        XCTAssertTrue(device.isMainAudioDevice)
        XCTAssertTrue(device.isAudioActive)
        XCTAssertFalse(device.isCurrentDevice)
    }

    func testQueryMultiConnectPacket() throws {
        let frame = try XCTUnwrap(OppoFrame(data: OppoCommands().queryMultiConnect()))
        XCTAssertEqual(frame.command, OppoCommand.queryMultiConnect)
        XCTAssertEqual(frame.payload, Data())
    }

    func testOperateMultiConnectHandheldPackets() throws {
        let mac = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])

        let connect = try XCTUnwrap(OppoFrame(data: OppoCommands().operateMultiConnectHandheld(
            operationType: 1, address: mac
        )))
        XCTAssertEqual(connect.command, OppoCommand.operateMultiConnectHandheld)
        XCTAssertEqual(connect.payload, Data([0x01, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]))

        let disconnect = try XCTUnwrap(OppoFrame(data: OppoCommands().operateMultiConnectHandheld(
            operationType: 2, address: mac
        )))
        XCTAssertEqual(disconnect.payload.first, 0x02)

        let raise = try XCTUnwrap(OppoFrame(data: OppoCommands().operateMultiConnectHandheld(
            operationType: 4, raisePriority: true
        )))
        XCTAssertEqual(raise.payload, Data([0x04, 0x00]))

        let lower = try XCTUnwrap(OppoFrame(data: OppoCommands().operateMultiConnectHandheld(
            operationType: 4, address: mac, raisePriority: false
        )))
        XCTAssertEqual(lower.payload, Data([0x04, 0x01, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]))
    }
}
