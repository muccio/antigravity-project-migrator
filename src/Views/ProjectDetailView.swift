import AppKit
import SwiftUI

public struct ProjectDetailView: View {
    public let project: ProjectItem
    public let onMigrate: () -> Void
    public let onRestore: () -> Void
    public let onCleanCache: () -> Void
    public let onRecalculate: () -> Void

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(project.isSymlink ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                            .frame(width: 54, height: 54)

                        Image(systemName: project.isSymlink ? "externaldrive.fill.badge.checkmark" : "folder.fill")
                            .font(.system(size: 26))
                            .foregroundColor(project.isSymlink ? .purple : .blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.system(size: 20, weight: .bold))

                        Text(project.path)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)

                        HStack(spacing: 8) {
                            StatusBadge(status: project.status)
                            if project.antigravityChatCount > 0 {
                                ChatBadge(count: project.antigravityChatCount)
                            }
                        }
                        .padding(.top, 4)
                    }

                    Spacer()
                }

                Divider()

                // Storage Status Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("STATO MEMORIZZAZIONE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    if project.isSymlink {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "link.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.purple)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Collegamento Simbolico Attivo")
                                        .font(.system(size: 13, weight: .semibold))

                                    Text("I file fisici risiedono su disco esterno, mentre un symlink trasparente risiede nel percorso originale del Mac. Antigravity continua a funzionare con tutte le chat e il contesto storico intatti!")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)

                                    if let target = project.symlinkTarget {
                                        HStack {
                                            Text("Destinazione reale:")
                                                .font(.system(size: 11, weight: .bold))
                                            Text(target)
                                                .font(.system(size: 11))
                                                .foregroundColor(.purple)
                                                .textSelection(.enabled)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(10)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "internaldrive.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Archiviato sul Disco Interno del Mac")
                                        .font(.system(size: 13, weight: .semibold))

                                    Text("Il progetto occupa spazio sul disco del tuo Mac. Puoi spostarlo su un'unità esterna mantenendo un symlink locale per liberare giga senza alcun impatto sulle chat di Antigravity.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(10)
                    }
                }

                // Size and Cache Breakdown
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ANALISI DIMENSIONI")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: onRecalculate) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Ricalcola")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }

                    HStack(spacing: 12) {
                        // Total
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dimensione Totale")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(project.formattedSize)
                                .font(.system(size: 18, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                        // Net (code only)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Codice ed Asset")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(project.formattedNetSize)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)

                        // Cache
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cache / Build Ricreabili")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(project.cacheSizeBytes ?? 0 > 0 ? project.formattedCacheSize : "0 B")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(project.cacheSizeBytes ?? 0 > 0 ? .orange : .secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    // Cache folders breakdown list
                    if !project.cacheItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Dettaglio cartelle di cache:")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Button(action: onCleanCache) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("Pulisci Cache...")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 4)

                            ForEach(project.cacheItems) { item in
                                HStack {
                                    Image(systemName: "folder.badge.gearshape")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 12))
                                    Text(item.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text(item.formattedSize)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                    }
                }

                // Antigravity integration details
                VStack(alignment: .leading, spacing: 8) {
                    Text("INTEGRAZIONE ANTIGRAVITY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text("Database Chat Antigravity:")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(project.antigravityChatCount > 0 ? "\(project.antigravityChatCount) conversazioni registrate" : "Nessuna sessione trovata nel DB")
                                .font(.system(size: 12))
                                .foregroundColor(project.antigravityChatCount > 0 ? .primary : .secondary)
                        }

                        if !project.markers.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "tag")
                                    .foregroundColor(.blue)
                                Text("Marker progetto:")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(project.markers.joined(separator: ", "))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                Divider()

                // Action Buttons
                VStack(spacing: 12) {
                    if project.isSymlink {
                        Button(action: onRestore) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 15))
                                Text("Ripristina sul Disco Interno del Mac")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    } else {
                        Button(action: onMigrate) {
                            HStack {
                                Image(systemName: "externaldrive.badge.plus")
                                    .font(.system(size: 15))
                                Text("Sposta su Disco Esterno (Conserva Chat)...")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }

                    HStack(spacing: 12) {
                        Button(action: revealInFinder) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Rivela nel Finder")
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Button(action: openInAntigravity) {
                            HStack {
                                Image(systemName: "arrow.up.forward.app")
                                Text("Apri in Antigravity")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func revealInFinder() {
        let url = URL(fileURLWithPath: project.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openInAntigravity() {
        let url = URL(fileURLWithPath: project.path)
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: URL(fileURLWithPath: "/Applications/Antigravity.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
