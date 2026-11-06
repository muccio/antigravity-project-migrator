import SwiftUI

public struct ProjectRowView: View {
    public let project: ProjectItem
    public let isSelected: Bool

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackgroundColor)
                    .frame(width: 38, height: 38)

                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(iconForegroundColor)
            }

            // Title and Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    if project.antigravityChatCount > 0 {
                        ChatBadge(count: project.antigravityChatCount)
                    }

                    if project.isSymlink {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                            .foregroundColor(.purple)
                    }
                }

                HStack(spacing: 8) {
                    StatusBadge(status: project.status)

                    if let target = project.symlinkTarget {
                        Text("➔ \(target)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else if !project.markers.isEmpty {
                        Text(project.markers.prefix(3).joined(separator: " • "))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Size and Cache info
            VStack(alignment: .trailing, spacing: 3) {
                if project.isCalculatingSize {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text("Calcolo...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(project.formattedSize)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(project.sizeBytes ?? 0 > 1024 * 1024 * 1024 ? .primary : .secondary)

                    if let cache = project.cacheSizeBytes, cache > 0 {
                        CacheWarningBadge(formattedCacheSize: project.formattedCacheSize)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(8)
    }

    private var iconName: String {
        if project.isSymlink {
            return "externaldrive.fill.badge.checkmark"
        }
        if project.antigravityChatCount > 0 {
            return "sparkles.rectangle.stack.fill"
        }
        return "folder.fill"
    }

    private var iconBackgroundColor: Color {
        if project.isSymlink {
            return Color.purple.opacity(0.15)
        }
        if project.antigravityChatCount > 0 {
            return Color.blue.opacity(0.15)
        }
        return Color.gray.opacity(0.15)
    }

    private var iconForegroundColor: Color {
        if project.isSymlink {
            return .purple
        }
        if project.antigravityChatCount > 0 {
            return .blue
        }
        return .secondary
    }
}
