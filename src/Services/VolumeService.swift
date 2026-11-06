import Foundation

public final class VolumeService {
    public static let shared = VolumeService()

    private let fileManager = FileManager.default

    private init() {}

    /// Discovers all mounted volumes (removable drives, external hard drives, USB, SD cards)
    public func getMountedVolumes() -> [ExternalVolume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey,
            .volumeLocalizedFormatDescriptionKey
        ]

        let urls = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        var volumes: [ExternalVolume] = []

        for url in urls {
            let vals = try? url.resourceValues(forKeys: Set(keys))
            let name = vals?.volumeName ?? url.lastPathComponent
            let isRemovable = vals?.volumeIsRemovable ?? false
            let isInternal = vals?.volumeIsInternal ?? true
            let avail = Int64(vals?.volumeAvailableCapacity ?? 0)
            let total = Int64(vals?.volumeTotalCapacity ?? 0)
            var format = vals?.volumeLocalizedFormatDescription ?? "Unknown"

            // Enrich format using diskutil if unknown or generic
            let (detailedFormat, isAPFS, isExFAT) = inspectFileSystem(path: url.path, fallback: format)
            if detailedFormat != "Unknown" {
                format = detailedFormat
            }

            // Exclude root and system partitions from "External" list unless user wants all
            // But keep all volumes that are in /Volumes/
            if url.path == "/" {
                continue
            }

            volumes.append(ExternalVolume(
                url: url,
                name: name,
                isRemovable: isRemovable,
                isInternal: isInternal,
                availableCapacity: avail,
                totalCapacity: total,
                fileSystemFormat: format,
                isAPFS: isAPFS,
                isExFAT: isExFAT
            ))
        }

        return volumes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Runs diskutil info to check filesystem details (APFS, ExFAT, etc.)
    public func inspectFileSystem(path: String, fallback: String = "") -> (format: String, isAPFS: Bool, isExFAT: Bool) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", path]
        process.standardOutput = pipe
        process.standardError = Pipe()

        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            let lower = fallback.lowercased()
            return (fallback, lower.contains("apfs"), lower.contains("exfat"))
        }

        var format = fallback
        var isAPFS = false
        var isExFAT = false

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Type (Bundle):") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let b = parts[1].trimmingCharacters(in: .whitespaces).lowercased()
                    if b.contains("apfs") { isAPFS = true; format = "APFS" }
                    if b.contains("exfat") { isExFAT = true; format = "ExFAT" }
                }
            } else if trimmed.contains("File System Personality:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    let pers = parts[1].trimmingCharacters(in: .whitespaces)
                    if pers.lowercased().contains("apfs") { isAPFS = true; format = "APFS" }
                    if pers.lowercased().contains("exfat") { isExFAT = true; format = "ExFAT" }
                }
            }
        }

        return (format, isAPFS, isExFAT)
    }

    /// Verifies if a given path on an external volume is reachable and mounted
    public func isVolumeMounted(forPath path: String) -> Bool {
        if path.hasPrefix("/Volumes/") {
            let components = path.components(separatedBy: "/")
            if components.count >= 3 {
                let volumePath = "/Volumes/\(components[2])"
                return fileManager.fileExists(atPath: volumePath)
            }
        }
        return fileManager.fileExists(atPath: path)
    }
}
