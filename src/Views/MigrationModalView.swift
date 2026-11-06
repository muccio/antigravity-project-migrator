import AppKit
import SwiftUI

public struct MigrationModalView: View {
    public let project: ProjectItem
    public let onDismiss: () -> Void

    @StateObject private var migration = MigrationService.shared
    @State private var volumes: [ExternalVolume] = []
    @State private var selectedVolume: ExternalVolume? = nil
    @State private var targetSubfolder: String = "AntigravityProjects"
    @State private var customParentPath: String = ""
    @State private var createBackup: Bool = true
    @State private var pruneCaches: Bool = true
    @State private var cachesToPrune: [CacheFolderItem] = []
    @State private var isAntigravityRunning: Bool = false
    @State private var ignoreAntigravityWarning: Bool = false
    @State private var isCheckingProcesses: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Migrazione Progetto su Disco Esterno")
                        .font(.system(size: 16, weight: .bold))
                    Text(project.name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !migration.isRunning {
                    Button("Chiudi") {
                        migration.reset()
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
                VStack(alignment: .leading, spacing: 20) {
                    if migration.isRunning || migration.isSuccess || migration.errorDescription != nil {
                        progressViewSection
                    } else {
                        configurationSection
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
                        .lineLimit(1)
                    Spacer()
                    Button("Annulla") {
                        migration.cancel()
                    }
                } else if migration.isSuccess {
                    Spacer()
                    Button("Fatto") {
                        migration.reset()
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else if migration.errorDescription != nil {
                    Button("Chiudi") {
                        migration.reset()
                        onDismiss()
                    }
                    Spacer()
                    Button("Riprova") {
                        migration.reset()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Annulla") {
                        migration.reset()
                        onDismiss()
                    }

                    Spacer()

                    Button(action: startMigration) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Avvia Spostamento Sicuro")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(selectedVolume == nil || (isAntigravityRunning && !ignoreAntigravityWarning))
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 650, height: 600)
        .onAppear {
            migration.reset()
            loadInitialData()
        }
        .onDisappear {
            migration.reset()
        }
    }

    // MARK: - Configuration Section
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Step 1: Destination Volume
            VStack(alignment: .leading, spacing: 8) {
                Text("1. SELEZIONA DISCO ESTERNO DI DESTINAZIONE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                if volumes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "externaldrive.badge.xmark")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Nessuna unità esterna rilevata")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Collega un disco rigido esterno, un SSD o una scheda SD per procedere.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Button("Aggiorna Dischi") {
                            loadVolumes()
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(volumes) { vol in
                            VolumeCard(volume: vol, isSelected: selectedVolume?.id == vol.id) {
                                selectedVolume = vol
                            }
                        }
                    }
                }

                if let vol = selectedVolume {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sottocartella archivio sul disco:")
                            .font(.system(size: 11, weight: .medium))
                        HStack {
                            Text(vol.url.path + "/")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                            TextField("Nome cartella", text: $targetSubfolder)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.top, 6)
                }
            }

            // Step 2: Safety Pre-flight Checks
            VStack(alignment: .leading, spacing: 8) {
                Text("2. CONTROLLI DI SICUREZZA PRE-VOLO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    // Antigravity running check
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: isAntigravityRunning ? "exclamationmark.octagon.fill" : "checkmark.circle.fill")
                                .foregroundColor(isAntigravityRunning ? .red : .green)
                                .font(.system(size: 16))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isAntigravityRunning ? "Antigravity è aperto!" : "Antigravity non è in esecuzione")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isAntigravityRunning ? .red : .primary)
                                Text(isAntigravityRunning ? "Per non corrompere l'indice chat o bloccare i file aperti, devi chiudere l'app." : "Stato ideale per lo spostamento dei file.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isAntigravityRunning {
                                HStack(spacing: 8) {
                                    Button("Chiudi Antigravity") {
                                        closeAntigravity()
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)

                                    Button(action: checkProcessStatus) {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.plain)
                                    .help("Ricarica stato processi")
                                }
                            } else {
                                Button(action: checkProcessStatus) {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(.plain)
                                .help("Ricarica stato processi")
                            }
                        }

                        if isAntigravityRunning {
                            Toggle("Procedi comunque (ignora controllo Antigravity)", isOn: $ignoreAntigravityWarning)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(10)
                    .background(isAntigravityRunning ? Color.red.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)

                    // Target Filesystem Check
                    if let vol = selectedVolume {
                        HStack {
                            Image(systemName: vol.isAPFS ? "checkmark.circle.fill" : (vol.isExFAT ? "exclamationmark.triangle.fill" : "info.circle.fill"))
                                .foregroundColor(vol.isAPFS ? .green : (vol.isExFAT ? .yellow : .blue))
                                .font(.system(size: 16))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Formato Filesystem: \(vol.fileSystemFormat)")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(vol.isAPFS ? "Formato APFS nativo: massimo supporto per link simbolici e metadati Git." : (vol.isExFAT ? "Attenzione: ExFAT non gestisce i permessi POSIX e symlink di build complessi." : "Compatibile con macOS."))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }

            // Step 3: Options (Backup & Pruning)
            VStack(alignment: .leading, spacing: 8) {
                Text("3. OPZIONI DI OTTIMIZZAZIONE E BACKUP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $createBackup) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Esegui backup di sicurezza delle chat prima di procedere")
                                .font(.system(size: 12, weight: .medium))
                            Text("Salva una copia istantanea di conversation_summaries.db e state.vscdb in ~/.gemini/antigravity_backups")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !cachesToPrune.isEmpty {
                        Divider()

                        Toggle(isOn: $pruneCaches) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Elimina cache ricreabili prima del trasferimento (Consigliato)")
                                    .font(.system(size: 12, weight: .medium))
                                Text("node_modules e cartelle build contengono centinaia di migliaia di micro-file. Eliminarli riduce il tempo di copia da ore a pochi secondi.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if pruneCaches {
                            VStack(spacing: 4) {
                                ForEach($cachesToPrune) { $cache in
                                    HStack {
                                        Toggle("", isOn: $cache.isSelectedForCleaning)
                                            .labelsHidden()
                                        Image(systemName: "folder")
                                            .font(.system(size: 11))
                                            .foregroundColor(.orange)
                                        Text(cache.name)
                                            .font(.system(size: 11))
                                        Spacer()
                                        Text(cache.formattedSize)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(NSColor.windowBackgroundColor))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Progress / Log Section
    private var progressViewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Status Banner
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusBannerColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: statusBannerIcon)
                        .font(.system(size: 22))
                        .foregroundColor(statusBannerColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(migration.phase.rawValue)
                        .font(.system(size: 15, weight: .bold))
                    Text(migration.progressMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(statusBannerColor.opacity(0.1))
            .cornerRadius(10)

            // GLOBAL PROJECT PROGRESS CARD
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("AVANZAMENTO GLOBALE MIGRAZIONE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    let percent = Int(migration.progressFraction * 100)
                    Text("\(percent)%")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(statusBannerColor)
                }

                // Global Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: migration.isSuccess ? [.green, .mint] : [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(migration.progressFraction))), height: 12)
                            .animation(.linear(duration: 0.3), value: migration.progressFraction)
                    }
                }
                .frame(height: 12)

                // Transferred Bytes vs Total
                HStack {
                    Text("\(ByteCountFormatter.string(fromByteCount: migration.bytesCopied, countStyle: .file)) di \(ByteCountFormatter.string(fromByteCount: migration.totalBytesToCopy, countStyle: .file))")
                        .font(.system(size: 12, weight: .semibold))

                    Spacer()

                    if !migration.estimatedTimeRemaining.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "hourglass")
                                .font(.system(size: 11))
                            Text(migration.estimatedTimeRemaining)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .padding(.vertical, 2)

                // Metric Pills: Speed, Remaining, Files
                HStack(spacing: 8) {
                    // Speed
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Text(migration.currentTransferSpeed.isEmpty ? "-- MB/s" : migration.currentTransferSpeed)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(6)

                    // Files count
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text("\(migration.filesCopied) / \(migration.totalFilesCount > 0 ? "\(migration.totalFilesCount)" : "...") file")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(6)

                    Spacer()
                }

                // Current file being processed
                if !migration.currentFileName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Copia: \(migration.currentFileName)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )

            // Log Console
            VStack(alignment: .leading, spacing: 6) {
                Text("LOG OPERAZIONI")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(migration.logOutput.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(line.contains("❌") ? .red : (line.contains("✅") ? .green : .secondary))
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .frame(height: 160)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(8)
                    .onChange(of: migration.logOutput.count) { _ in
                        if let last = migration.logOutput.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var statusBannerColor: Color {
        if migration.isSuccess { return .green }
        if migration.errorDescription != nil { return .red }
        return .accentColor
    }

    private var statusBannerIcon: String {
        if migration.isSuccess { return "checkmark.circle.fill" }
        if migration.errorDescription != nil { return "xmark.circle.fill" }
        return "arrow.triangle.2.circlepath"
    }

    // MARK: - Actions
    private func loadInitialData() {
        loadVolumes()
        checkProcessStatus()
        cachesToPrune = project.cacheItems
    }

    private func loadVolumes() {
        volumes = VolumeService.shared.getMountedVolumes()
        if selectedVolume == nil {
            selectedVolume = volumes.first
        }
    }

    private func checkProcessStatus() {
        isAntigravityRunning = ProcessService.shared.isAntigravityRunning()
    }

    private func closeAntigravity() {
        _ = ProcessService.shared.terminateAntigravity()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkProcessStatus()
        }
    }

    private func startMigration() {
        guard let vol = selectedVolume else { return }
        let destParent = (vol.url.path as NSString).appendingPathComponent(targetSubfolder)
        try? FileManager.default.createDirectory(atPath: destParent, withIntermediateDirectories: true)

        migration.migrateProject(
            project: project,
            destinationParentFolder: destParent,
            pruneCaches: pruneCaches,
            cachesToPrune: cachesToPrune,
            createBackup: createBackup,
            ignoreAntigravityRunning: ignoreAntigravityWarning
        ) { success, _ in
            if success {
                FolderScanner.shared.refreshProject(atPath: project.path)
            }
        }
    }
}
