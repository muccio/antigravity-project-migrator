import SwiftUI

public struct RestoreModalView: View {
    public let project: ProjectItem
    public let onDismiss: () -> Void

    @StateObject private var migration = MigrationService.shared
    @State private var isAntigravityRunning: Bool = false
    @State private var ignoreAntigravityWarning: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ripristina Progetto sul Mac")
                        .font(.system(size: 16, weight: .bold))
                    Text(project.name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !migration.isRunning {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if migration.isRunning || migration.isSuccess || migration.errorDescription != nil {
                        progressViewSection
                    } else {
                        confirmationSection
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                if migration.isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(migration.progressMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                } else if migration.isSuccess {
                    Spacer()
                    Button("Fatto") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button("Annulla") {
                        onDismiss()
                    }

                    Spacer()

                    Button(action: startRestore) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                            Text("Ripristina su Disco Interno")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isAntigravityRunning && !ignoreAntigravityWarning)
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 480)
        .onAppear {
            isAntigravityRunning = ProcessService.shared.isAntigravityRunning()
        }
    }

    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Questa operazione copierà tutti i file fisici dal disco esterno alla memoria interna del Mac, sostituendo il collegamento simbolico con la cartella originale.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Origine (Esterna):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(project.symlinkTarget ?? "Sconosciuto")
                        .font(.system(size: 11, design: .monospaced))
                }

                HStack {
                    Text("Destinazione (Mac):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(project.path)
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Antigravity running check
            HStack {
                Image(systemName: isAntigravityRunning ? "exclamationmark.octagon.fill" : "checkmark.circle.fill")
                    .foregroundColor(isAntigravityRunning ? .red : .green)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isAntigravityRunning ? "Antigravity è aperto!" : "Antigravity è chiuso")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isAntigravityRunning ? .red : .primary)
                    Text(isAntigravityRunning ? "Chiudi l'IDE prima di sostituire il symlink." : "Pronto per il ripristino.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isAntigravityRunning {
                    HStack(spacing: 8) {
                        Button("Chiudi Antigravity") {
                            _ = ProcessService.shared.terminateAntigravity()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.isAntigravityRunning = ProcessService.shared.isAntigravityRunning()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Button(action: { self.isAntigravityRunning = ProcessService.shared.isAntigravityRunning() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: { self.isAntigravityRunning = ProcessService.shared.isAntigravityRunning() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(isAntigravityRunning ? Color.red.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            if isAntigravityRunning {
                Toggle("Procedi comunque (ignora controllo Antigravity)", isOn: $ignoreAntigravityWarning)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var progressViewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(migration.logOutput.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(line.contains("❌") ? .red : (line.contains("✅") ? .green : .secondary))
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .frame(height: 220)
                .background(Color.black.opacity(0.85))
                .cornerRadius(8)
            }
        }
    }

    private func startRestore() {
        migration.restoreToMac(project: project, ignoreAntigravityRunning: ignoreAntigravityWarning) { success, _ in
            if success {
                FolderScanner.shared.refreshProject(atPath: project.path)
            }
        }
    }
}
