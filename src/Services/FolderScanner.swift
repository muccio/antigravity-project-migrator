import Foundation

public final class FolderScanner: ObservableObject {
    public static let shared = FolderScanner()

    @Published public var projects: [ProjectItem] = []
    @Published public var isScanning: Bool = false
    @Published public var currentFolder: String = ""
    @Published public var recentFolders: [String] = []
    @Published public var calculationProgress: Double = 0.0

    private let fileManager = FileManager.default
    private var calculationQueue = DispatchQueue(label: "com.antigravity.migrator.calc", qos: .userInitiated)

    private let savedFolderKey = "AntigravitySavedProjectsFolder"
    private let recentFoldersKey = "AntigravityRecentProjectsFolders"

    private init() {
        loadRecentFolders()
        if let saved = UserDefaults.standard.string(forKey: savedFolderKey),
           fileManager.fileExists(atPath: saved) {
            currentFolder = (saved as NSString).standardizingPath
        }
    }

    private func loadRecentFolders() {
        if let recents = UserDefaults.standard.stringArray(forKey: recentFoldersKey) {
            self.recentFolders = recents.filter { fileManager.fileExists(atPath: $0) }
        }
    }

    public func saveRecentFolder(_ folder: String) {
        let std = (folder as NSString).standardizingPath
        var recents = self.recentFolders.filter { $0 != std && self.fileManager.fileExists(atPath: $0) }
        recents.insert(std, at: 0)
        if recents.count > 6 {
            recents = Array(recents.prefix(6))
        }
        self.recentFolders = recents
        UserDefaults.standard.set(recents, forKey: recentFoldersKey)
    }

    /// Determines the best initial directory to scan
    public func resolveInitialDirectory() -> String {
        // 1. Saved folder in UserDefaults
        if let saved = UserDefaults.standard.string(forKey: savedFolderKey),
           !saved.isEmpty,
           fileManager.fileExists(atPath: saved) {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: saved, isDirectory: &isDir), isDir.boolValue {
                return (saved as NSString).standardizingPath
            }
        }

        // 2. Proximity: If running inside or near a projects directory
        let bundleURL = Bundle.main.bundleURL.standardized
        let parentURL = bundleURL.deletingLastPathComponent()
        let parentPath = parentURL.path

        if parentPath != "/" && parentPath != "/Applications" && !parentPath.hasPrefix("/private") {
            if containsCandidateProjects(path: parentPath, excluding: bundleURL.lastPathComponent) {
                return parentPath
            }
            let grandParentURL = parentURL.deletingLastPathComponent()
            let grandParentPath = grandParentURL.path
            if grandParentPath != "/" && grandParentPath != "/Applications" && !grandParentPath.hasPrefix("/private") {
                if containsCandidateProjects(path: grandParentPath, excluding: parentURL.lastPathComponent) {
                    return grandParentPath
                }
            }
        }

        // 3. Common developer locations
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidatePaths = [
            (home as NSString).appendingPathComponent("Documents/Development/WEBDEV"),
            (home as NSString).appendingPathComponent("Documents/Development"),
            (home as NSString).appendingPathComponent("Development"),
            (home as NSString).appendingPathComponent("Developer"),
            (home as NSString).appendingPathComponent("Projects"),
            (home as NSString).appendingPathComponent("Documents/Projects"),
            (home as NSString).appendingPathComponent("Documents")
        ]

        for path in candidatePaths {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return path
            }
        }

        return home
    }

    private func containsCandidateProjects(path: String, excluding: String) -> Bool {
        guard let items = try? fileManager.contentsOfDirectory(atPath: path) else { return false }
        let subfolders = items.filter { item in
            if item.hasPrefix(".") || item == excluding { return false }
            var isDir: ObjCBool = false
            let full = (path as NSString).appendingPathComponent(item)
            return fileManager.fileExists(atPath: full, isDirectory: &isDir) && isDir.boolValue
        }
        return subfolders.count >= 2
    }

    /// Scans a directory and lists all project candidates
    public func scan(directory: String) {
        let stdDir = (directory as NSString).standardizingPath
        currentFolder = stdDir
        UserDefaults.standard.set(stdDir, forKey: savedFolderKey)
        saveRecentFolder(stdDir)
        isScanning = true
        calculationProgress = 0.0

        let conversationCounts = AntigravityService.shared.getConversationCounts()

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: stdDir, isDirectory: &isDir), isDir.boolValue,
              let contents = try? fileManager.contentsOfDirectory(atPath: stdDir) else {
            DispatchQueue.main.async {
                self.projects = []
                self.isScanning = false
            }
            return
        }

        var detectedItems: [ProjectItem] = []

        for item in contents {
            if item.hasPrefix(".") {
                // Skip hidden directories at top level like .git or .gemini
                continue
            }

            let fullPath = (stdDir as NSString).appendingPathComponent(item)
            let itemURL = URL(fileURLWithPath: fullPath)

            var isSymlink = false
            var symlinkTarget: String? = nil

            // Check if it is a symbolic link
            var statInfo = stat()
            if lstat(fullPath, &statInfo) == 0 {
                if (statInfo.st_mode & S_IFMT) == S_IFLNK {
                    isSymlink = true
                    if let target = try? fileManager.destinationOfSymbolicLink(atPath: fullPath) {
                        symlinkTarget = target
                    }
                }
            }

            var isDirectory: ObjCBool = false
            _ = fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)

            // If it's not a directory and not a symlink, ignore (e.g. .zip files or readme)
            if !isDirectory.boolValue && !isSymlink {
                continue
            }

            let isExternalSymlink = symlinkTarget?.hasPrefix("/Volumes/") ?? false
            var isTargetVolumeMounted = true
            if let target = symlinkTarget {
                isTargetVolumeMounted = VolumeService.shared.isVolumeMounted(forPath: target)
            }

            // Antigravity chat count
            let chatCount = conversationCounts[fullPath] ?? 0

            // Project markers
            var markers: [String] = []
            let checkMarkers = [
                (".agents", "Antigravity Agents"),
                (".agent", "Antigravity Agent"),
                (".gemini", "Gemini Config"),
                (".planning", "GSD Planning"),
                (".git", "Git"),
                ("package.json", "Node.js"),
                ("CMakeLists.txt", "C++ / CMake"),
                ("Cargo.toml", "Rust"),
                ("go.mod", "Go"),
                ("requirements.txt", "Python"),
                ("pyproject.toml", "Python"),
                ("pubspec.yaml", "Flutter / Dart"),
                ("Assets", "Unity")
            ]

            let targetPathToCheck = symlinkTarget ?? fullPath
            for (marker, label) in checkMarkers {
                let markerPath = (targetPathToCheck as NSString).appendingPathComponent(marker)
                if fileManager.fileExists(atPath: markerPath) {
                    markers.append(label)
                }
            }

            let isKnownAntigravity = chatCount > 0 || markers.contains(where: { $0.contains("Antigravity") || $0.contains("Gemini") || $0.contains("GSD") })

            let project = ProjectItem(
                name: item,
                path: fullPath,
                url: itemURL,
                isSymlink: isSymlink,
                symlinkTarget: symlinkTarget,
                isExternalSymlink: isExternalSymlink,
                isTargetVolumeMounted: isTargetVolumeMounted,
                antigravityChatCount: chatCount,
                isKnownAntigravity: isKnownAntigravity,
                markers: markers,
                sizeBytes: nil,
                isCalculatingSize: true,
                cacheSizeBytes: nil,
                cacheItems: [],
                lastModified: (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            )

            detectedItems.append(project)
        }

        // Sort: projects with Antigravity chats first, then alphabetically
        detectedItems.sort { (a, b) -> Bool in
            if a.antigravityChatCount != b.antigravityChatCount {
                return a.antigravityChatCount > b.antigravityChatCount
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        DispatchQueue.main.async {
            self.projects = detectedItems
            self.isScanning = false
            self.startCalculatingSizes()
        }
    }

    /// Background queue to compute sizes and cache folders one by one
    private func startCalculatingSizes() {
        let currentProjects = self.projects
        let totalCount = currentProjects.count
        guard totalCount > 0 else { return }

        calculationQueue.async {
            for (index, project) in currentProjects.enumerated() {
                let pathToMeasure = project.symlinkTarget ?? project.path

                // Only measure if reachable
                var size: Int64 = 0
                var cacheTotal: Int64 = 0
                var cacheItems: [CacheFolderItem] = []

                if self.fileManager.fileExists(atPath: pathToMeasure) {
                    size = FolderSizeService.shared.calculateSize(atPath: pathToMeasure)
                    let cacheResult = FolderSizeService.shared.inspectCacheFolders(projectPath: pathToMeasure)
                    cacheTotal = cacheResult.totalCacheBytes
                    cacheItems = cacheResult.items
                }

                DispatchQueue.main.async {
                    if let idx = self.projects.firstIndex(where: { $0.path == project.path }) {
                        self.projects[idx].sizeBytes = size
                        self.projects[idx].cacheSizeBytes = cacheTotal
                        self.projects[idx].cacheItems = cacheItems
                        self.projects[idx].isCalculatingSize = false
                    }
                    self.calculationProgress = Double(index + 1) / Double(totalCount)
                }
            }
        }
    }

    /// Refresh a single project after migration or cache cleanup
    public func refreshProject(atPath path: String) {
        calculationQueue.async {
            var statInfo = stat()
            var isSymlink = false
            var symlinkTarget: String? = nil

            if lstat(path, &statInfo) == 0 {
                if (statInfo.st_mode & S_IFMT) == S_IFLNK {
                    isSymlink = true
                    symlinkTarget = try? self.fileManager.destinationOfSymbolicLink(atPath: path)
                }
            }

            let pathToMeasure = symlinkTarget ?? path
            let size = FolderSizeService.shared.calculateSize(atPath: pathToMeasure)
            let cacheResult = FolderSizeService.shared.inspectCacheFolders(projectPath: pathToMeasure)

            DispatchQueue.main.async {
                if let idx = self.projects.firstIndex(where: { $0.path == path }) {
                    self.projects[idx].isSymlink = isSymlink
                    self.projects[idx].symlinkTarget = symlinkTarget
                    self.projects[idx].isExternalSymlink = symlinkTarget?.hasPrefix("/Volumes/") ?? false
                    self.projects[idx].isTargetVolumeMounted = symlinkTarget != nil ? VolumeService.shared.isVolumeMounted(forPath: symlinkTarget!) : true
                    self.projects[idx].sizeBytes = size
                    self.projects[idx].cacheSizeBytes = cacheResult.totalCacheBytes
                    self.projects[idx].cacheItems = cacheResult.items
                    self.projects[idx].isCalculatingSize = false
                }
            }
        }
    }
}
