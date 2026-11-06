import Foundation

public enum ProjectStorageStatus: Equatable {
    case local
    case symlinkedExternal(targetPath: String, isOnline: Bool)
    case symlinkedLocal(targetPath: String)
    case brokenSymlink(targetPath: String)

    public var title: String {
        switch self {
        case .local:
            return "Sul Mac (Locale)"
        case .symlinkedExternal(_, let isOnline):
            return isOnline ? "Su Disco Esterno" : "Disco Scollegato"
        case .symlinkedLocal:
            return "Symlink Locale"
        case .brokenSymlink:
            return "Symlink Non Valido"
        }
    }
}

public struct ProjectItem: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let url: URL
    public var isSymlink: Bool
    public var symlinkTarget: String?
    public var isExternalSymlink: Bool
    public var isTargetVolumeMounted: Bool

    public var antigravityChatCount: Int
    public var isKnownAntigravity: Bool
    public var markers: [String]

    public var sizeBytes: Int64?
    public var isCalculatingSize: Bool
    public var cacheSizeBytes: Int64?
    public var cacheItems: [CacheFolderItem]
    public var lastModified: Date?

    public var status: ProjectStorageStatus {
        if isSymlink {
            guard let target = symlinkTarget else {
                return .brokenSymlink(targetPath: "Sconosciuto")
            }
            if target.hasPrefix("/Volumes/") {
                return .symlinkedExternal(targetPath: target, isOnline: isTargetVolumeMounted)
            } else {
                return .symlinkedLocal(targetPath: target)
            }
        }
        return .local
    }

    public var formattedSize: String {
        if isCalculatingSize {
            return "Calcolo in corso..."
        }
        guard let size = sizeBytes else {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var formattedCacheSize: String {
        guard let size = cacheSizeBytes, size > 0 else {
            return ""
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var netSizeBytes: Int64? {
        guard let size = sizeBytes else { return nil }
        let cache = cacheSizeBytes ?? 0
        return max(0, size - cache)
    }

    public var formattedNetSize: String {
        guard let net = netSizeBytes else { return "--" }
        return ByteCountFormatter.string(fromByteCount: net, countStyle: .file)
    }

    public init(
        name: String,
        path: String,
        url: URL,
        isSymlink: Bool = false,
        symlinkTarget: String? = nil,
        isExternalSymlink: Bool = false,
        isTargetVolumeMounted: Bool = true,
        antigravityChatCount: Int = 0,
        isKnownAntigravity: Bool = false,
        markers: [String] = [],
        sizeBytes: Int64? = nil,
        isCalculatingSize: Bool = false,
        cacheSizeBytes: Int64? = nil,
        cacheItems: [CacheFolderItem] = [],
        lastModified: Date? = nil
    ) {
        self.name = name
        self.path = path
        self.url = url
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.isExternalSymlink = isExternalSymlink
        self.isTargetVolumeMounted = isTargetVolumeMounted
        self.antigravityChatCount = antigravityChatCount
        self.isKnownAntigravity = isKnownAntigravity
        self.markers = markers
        self.sizeBytes = sizeBytes
        self.isCalculatingSize = isCalculatingSize
        self.cacheSizeBytes = cacheSizeBytes
        self.cacheItems = cacheItems
        self.lastModified = lastModified
    }
}
