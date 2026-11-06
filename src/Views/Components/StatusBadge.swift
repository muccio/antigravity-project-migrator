import SwiftUI

public struct StatusBadge: View {
    public let status: ProjectStorageStatus

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(status.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .local:
            return .blue
        case .symlinkedExternal(_, let isOnline):
            return isOnline ? .purple : .orange
        case .symlinkedLocal:
            return .teal
        case .brokenSymlink:
            return .red
        }
    }
}

public struct ChatBadge: View {
    public let count: Int

    public var body: some View {
        if count > 0 {
            HStack(spacing: 3) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 10))
                Text("\(count) chat")
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.15))
            .foregroundColor(.green)
            .clipShape(Capsule())
        }
    }
}

public struct CacheWarningBadge: View {
    public let formattedCacheSize: String

    public var body: some View {
        if !formattedCacheSize.isEmpty {
            HStack(spacing: 3) {
                Image(systemName: "trash.circle")
                    .font(.system(size: 11))
                Text("Cache: \(formattedCacheSize)")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
