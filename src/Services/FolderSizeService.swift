import Foundation

public final class FolderSizeService {
    public static let shared = FolderSizeService()

    private let fileManager = FileManager.default
    private let cacheFolderNames = [
        "node_modules",
        "build",
        "Builds",
        "cmake-build-debug",
        "cmake-build-release",
        "dist",
        ".next",
        ".nuxt",
        "out",
        "target",
        "Pods",
        "DerivedData",
        ".turbo"
    ]

    private init() {}

    /// Calculates total size of a directory in bytes using du -sk
    public func calculateSize(atPath path: String) -> Int64 {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if let output = String(data: data, encoding: .utf8),
               let firstPart = output.split(separator: "\t").first,
               let kb = Int64(firstPart.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return kb * 1024
            }
        } catch {
            return 0
        }
        return 0
    }

    /// Finds and sizes common cache folders inside a project
    public func inspectCacheFolders(projectPath: String) -> (totalCacheBytes: Int64, items: [CacheFolderItem]) {
        var items: [CacheFolderItem] = []
        var totalCache: Int64 = 0

        for name in cacheFolderNames {
            let cachePath = (projectPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: cachePath, isDirectory: &isDir), isDir.boolValue {
                let size = calculateSize(atPath: cachePath)
                if size > 0 {
                    totalCache += size
                    items.append(CacheFolderItem(name: name, path: cachePath, sizeBytes: size, isSelectedForCleaning: true))
                }
            }
        }

        return (totalCache, items.sorted { $0.sizeBytes > $1.sizeBytes })
    }

    /// Deletes specific cache folders (e.g., node_modules, build) to lighten project before migration
    public func pruneCacheFolders(items: [CacheFolderItem], progressLog: ((String) -> Void)? = nil) throws {
        for item in items where item.isSelectedForCleaning {
            if fileManager.fileExists(atPath: item.path) {
                progressLog?("Eliminazione cache: \(item.name)...")
                try fileManager.removeItem(atPath: item.path)
            }
        }
    }
}
