import Foundation

public struct CacheFolderItem: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public var sizeBytes: Int64
    public var isSelectedForCleaning: Bool = true

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    public init(name: String, path: String, sizeBytes: Int64, isSelectedForCleaning: Bool = true) {
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.isSelectedForCleaning = isSelectedForCleaning
    }
}
