import SwiftUI

public struct CleanCacheModalView: View {
    public let project: ProjectItem
    public let onDismiss: () -> Void

    @State private var cacheItems: [CacheFolderItem] = []
    @State private var isCleaning: Bool = false
    @State private var statusMessage: String = ""
    @State private var isDone: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pulizia Cache Progetto")
                        .font(.system(size: 16, weight: .bold))
                    Text(project.name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !isCleaning {
                    Button("Chiudi") {
                        onDismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text("Le cartelle di cache (come node_modules, build o dist) possono essere facilmente rigenerate dai package manager (npm install, cargo build, etc.). Eliminarle libera immediatamente spazio su disco.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if isDone {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("Cache rimosse con successo!")
                            .font(.system(size: 14, weight: .bold))
                        Text(statusMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach($cacheItems) { $item in
                            HStack {
                                Toggle("", isOn: $item.isSelectedForCleaning)
                                    .labelsHidden()

                                Image(systemName: "folder.badge.gearshape")
                                    .foregroundColor(.orange)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(item.path)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Text(item.formattedSize)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .padding(20)

            Divider()

            // Footer
            HStack {
                if !isDone {
                    let totalToClean = cacheItems.filter { $0.isSelectedForCleaning }.reduce(Int64(0)) { $0 + $1.sizeBytes }
                    Text("Spazio da liberare: \(ByteCountFormatter.string(fromByteCount: totalToClean, countStyle: .file))")
                        .font(.system(size: 12, weight: .semibold))
                }

                Spacer()

                if isDone {
                    Button("Chiudi") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Annulla") {
                        onDismiss()
                    }

                    Button(action: executeClean) {
                        if isCleaning {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Text("Elimina Selezionati")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isCleaning || !cacheItems.contains { $0.isSelectedForCleaning })
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 520, height: 420)
        .onAppear {
            cacheItems = project.cacheItems
        }
    }

    private func executeClean() {
        isCleaning = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FolderSizeService.shared.pruneCacheFolders(items: cacheItems)
                FolderScanner.shared.refreshProject(atPath: project.path)
                DispatchQueue.main.async {
                    self.isCleaning = false
                    self.isDone = true
                    self.statusMessage = "Lo spazio è stato liberato e il progetto è stato aggiornato."
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCleaning = false
                    self.statusMessage = "Errore: \(error.localizedDescription)"
                }
            }
        }
    }
}
