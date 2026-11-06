import AppKit
import SwiftUI

public struct BackupsModalView: View {
    public let onDismiss: () -> Void

    @State private var backups: [AntigravityBackupInfo] = []
    @State private var isCreatingBackup: Bool = false
    @State private var statusMessage: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Backup di Sicurezza Antigravity")
                        .font(.system(size: 16, weight: .bold))
                    Text("Copie di sicurezza di conversation_summaries.db e state.vscdb")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Chiudi") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("I backup conservano l'indice storico delle chat, i metadati e i file state.vscdb. Vengono creati automaticamente prima di ogni migrazione su disco esterno.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: createBackupNow) {
                        HStack(spacing: 4) {
                            if isCreatingBackup {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text("Nuovo Backup")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(isCreatingBackup)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }

                if backups.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Nessun backup trovato")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Clicca su 'Nuovo Backup' per creare una copia preventiva dello stato attuale delle chat.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(backups) { backup in
                            HStack {
                                Image(systemName: "shield.checkerboard")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(backup.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(backup.formattedDate)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(backup.formattedSize)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: backup.path)])
                                }) {
                                    Image(systemName: "folder")
                                }
                                .buttonStyle(.plain)
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
                Button("Apri Cartella Backup") {
                    let dir = AntigravityService.shared.backupsDirectory
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
                }

                Spacer()

                Button("Chiudi") {
                    onDismiss()
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 440)
        .onAppear {
            loadBackups()
        }
    }

    private func loadBackups() {
        backups = AntigravityService.shared.listExistingBackups()
    }

    private func createBackupNow() {
        isCreatingBackup = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try AntigravityService.shared.createSafetyBackup()
                DispatchQueue.main.async {
                    self.isCreatingBackup = false
                    self.statusMessage = "Backup salvato con successo!"
                    self.loadBackups()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCreatingBackup = false
                    self.statusMessage = "Errore: \(error.localizedDescription)"
                }
            }
        }
    }
}
