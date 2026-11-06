import SwiftUI

public struct VolumeCard: View {
    public let volume: ExternalVolume
    public let isSelected: Bool
    public let onSelect: () -> Void

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: volume.isRemovable ? "externaldrive.fill" : "internaldrive.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : .accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(volume.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isSelected ? .white : .primary)

                        Text(volume.url.path)
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    // Filesystem tag
                    HStack(spacing: 4) {
                        if volume.isExFAT {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                        Text(volume.fileSystemFormat)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(volume.isAPFS ? Color.green.opacity(0.2) : (volume.isExFAT ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2)))
                    .foregroundColor(volume.isAPFS ? .green : (volume.isExFAT ? .yellow : .secondary))
                    .clipShape(Capsule())
                }

                // Progress gauge
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? Color.white : (volume.percentUsed > 0.9 ? Color.red : Color.accentColor))
                            .frame(width: max(0, geo.size.width * CGFloat(volume.percentUsed)), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Disponibili: \(volume.formattedAvailable)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)

                    Spacer()

                    Text("Totale: \(volume.formattedTotal)")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                }

                if volume.isExFAT {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                        Text("Avviso ExFAT: permessi Git e symlink interni potrebbero avere limitazioni. Consigliato APFS.")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .orange)
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
