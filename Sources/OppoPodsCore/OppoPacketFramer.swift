import Foundation

public struct OppoPacketFramer: Sendable {
    private var pending = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [Data] {
        guard !data.isEmpty else { return [] }
        pending.append(data)
        var frames: [Data] = []

        while !pending.isEmpty {
            guard let header = pending.firstIndex(of: 0xAA) else {
                pending.removeAll(keepingCapacity: true)
                break
            }
            if header > pending.startIndex {
                pending.removeSubrange(pending.startIndex..<header)
            }
            guard pending.count >= 2 else { break }

            let totalLength = Int(pending[pending.index(after: pending.startIndex)])
            let frameLength = totalLength + 2
            guard totalLength >= 7, frameLength <= 512 else {
                pending.removeFirst()
                continue
            }
            guard pending.count >= frameLength else { break }
            frames.append(Data(pending.prefix(frameLength)))
            pending.removeFirst(frameLength)
        }
        return frames
    }
}
