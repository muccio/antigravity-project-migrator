import Foundation

public struct ExternalVolume: Identifiable, Hashable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let isRemovable: Bool
    public let isInternal: Bool
    public let availableCapacity: Int64
    public let totalCapacity: Int64
    public let fileSystemFormat: String
    public let isAPFS: Bool
    public let isExFAT: Bool

    public var formattedAvailable: String {
        ByteCountFormatter.string(fromByteCount: availableCapacity, countStyle: .file)
    }

    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
    }

    public var percentUsed: Double {
        guard totalCapacity > 0 else { return 0 }
        let used = Double(totalCapacity - availableCapacity)
        return min(max(used / Double(totalCapacity), 0), 1.0)
    }

    public init(
        url: URL,
        name: String,
        isRemovable: Bool,
        isInternal: Bool,
        availableCapacity: Int64,
        totalCapacity: Int64,
        fileSystemFormat: String,
        isAPFS: Bool,
        isExFAT: Bool
    ) {
        self.url = url
        self.name = name
        self.isRemovable = isRemovable
        self.isInternal = isInternal
        self.availableCapacity = availableCapacity
        self.totalCapacity = totalCapacity
        self.fileSystemFormat = fileSystemFormat
        self.isAPFS = isAPFS
        self.isExFAT = isExFAT
    }
}
