import Foundation

public enum MigrationPhase: String {
    case idle = "In attesa"
    case preflight = "Verifica requisiti e sicurezza"
    case backup = "Backup database Antigravity"
    case pruning = "Pulizia cache selezionate"
    case copying = "Copia file su disco esterno (rsync)"
    case verifyingCopy = "Verifica integrità file copiati"
    case creatingSymlink = "Creazione collegamento simbolico (ln -s)"
    case completed = "Migrazione completata con successo"
    case failed = "Errore durante la migrazione"
}

public final class MigrationService: ObservableObject {
    public static let shared = MigrationService()

    @Published public var phase: MigrationPhase = .idle
    @Published public var progressMessage: String = ""
    @Published public var logOutput: [String] = []
    @Published public var isRunning: Bool = false
    @Published public var errorDescription: String? = nil
    @Published public var isSuccess: Bool = false

    private let fileManager = FileManager.default
    private var currentProcess: Process?

    private init() {}

    private func appendLog(_ message: String) {
        DispatchQueue.main.async {
            self.logOutput.append(message)
            self.progressMessage = message
        }
    }

    /// Executes the safe migration pipeline
    public func migrateProject(
        project: ProjectItem,
        destinationParentFolder: String,
        pruneCaches: Bool,
        cachesToPrune: [CacheFolderItem],
        createBackup: Bool,
        ignoreAntigravityRunning: Bool = false,
        completion: @escaping (Bool, String?) -> Void
    ) {
        isRunning = true
        isSuccess = false
        errorDescription = nil
        logOutput.removeAll()
        phase = .preflight

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1. Preflight check: Antigravity running
                self.appendLog("🔍 Controllo processi attivi...")
                if !ignoreAntigravityRunning && ProcessService.shared.isAntigravityRunning() {
                    throw NSError(domain: "Migration", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Antigravity è attualmente in esecuzione. Chiudi l'IDE (Cmd+Q) prima di spostare il progetto, oppure attiva 'Ignora controllo'."
                    ])
                }

                // Verify destination parent folder
                let destParent = (destinationParentFolder as NSString).standardizingPath
                var isDir: ObjCBool = false
                guard self.fileManager.fileExists(atPath: destParent, isDirectory: &isDir), isDir.boolValue else {
                    throw NSError(domain: "Migration", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "La cartella di destinazione non esiste o non è accessibile: \(destParent)"
                    ])
                }

                let targetProjectPath = (destParent as NSString).appendingPathComponent(project.name)
                if self.fileManager.fileExists(atPath: targetProjectPath) {
                    throw NSError(domain: "Migration", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "Attenzione: Esiste già una cartella con lo stesso nome sulla destinazione:\n\(targetProjectPath)\nScegli un'altra cartella o rinominala."
                    ])
                }

                // Check free space on target volume
                let targetURL = URL(fileURLWithPath: destParent)
                let freeSpace = Int64((try? targetURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]))?.volumeAvailableCapacity ?? 0)
                let projectSize = project.sizeBytes ?? 0
                if freeSpace > 0 && freeSpace < (projectSize + 500 * 1024 * 1024) {
                    throw NSError(domain: "Migration", code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "Spazio insufficiente sul disco di destinazione. Disponibili: \(ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)), Richiesti: \(ByteCountFormatter.string(fromByteCount: projectSize, countStyle: .file))"
                    ])
                }

                // 2. Safety Backup
                if createBackup {
                    DispatchQueue.main.async { self.phase = .backup }
                    self.appendLog("💾 Creazione backup di sicurezza delle chat Antigravity...")
                    let backupPath = try AntigravityService.shared.createSafetyBackup()
                    self.appendLog("✅ Backup completato in: \(backupPath)")
                }

                // 3. Optional Cache Pruning
                if pruneCaches && !cachesToPrune.isEmpty {
                    DispatchQueue.main.async { self.phase = .pruning }
                    self.appendLog("🧹 Sfoltimento cartelle di cache prima del trasferimento...")
                    try FolderSizeService.shared.pruneCacheFolders(items: cachesToPrune) { log in
                        self.appendLog("   \(log)")
                    }
                    self.appendLog("✅ Cache rimosse con successo.")
                }

                // 4. Rsync to external drive
                DispatchQueue.main.async { self.phase = .copying }
                self.appendLog("📦 Avvio trasferimento rsync...")
                self.appendLog("   Sorgente: \(project.path)")
                self.appendLog("   Destinazione: \(destParent)/")

                try self.runRsync(source: project.path, destinationParent: destParent)
                self.appendLog("✅ Copia rsync terminata con successo.")

                // 5. Verification of copied files
                DispatchQueue.main.async { self.phase = .verifyingCopy }
                self.appendLog("🔍 Verifica integrità della cartella su disco esterno...")
                guard self.fileManager.fileExists(atPath: targetProjectPath) else {
                    throw NSError(domain: "Migration", code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "La cartella di destinazione non è stata trovata dopo il trasferimento: \(targetProjectPath)"
                    ])
                }

                // Quick item count check
                let targetContents = (try? self.fileManager.contentsOfDirectory(atPath: targetProjectPath)) ?? []
                if targetContents.isEmpty {
                    throw NSError(domain: "Migration", code: 6, userInfo: [
                        NSLocalizedDescriptionKey: "La cartella copiata su disco esterno risulta vuota. Operazione interrotta per sicurezza."
                    ])
                }
                self.appendLog("✅ Verifica superata: \(targetContents.count) elementi principali presenti.")

                // 6. Atomic swap: Rename original to backup, create symlink, then delete backup
                DispatchQueue.main.async { self.phase = .creatingSymlink }
                self.appendLog("🔗 Creazione collegamento simbolico...")

                let backupOriginalPath = project.path + ".__migrating_backup__"

                // Move original to temp backup name
                try self.fileManager.moveItem(atPath: project.path, toPath: backupOriginalPath)
                self.appendLog("   Cartella originale spostata temporaneamente in backup di sicurezza.")

                do {
                    // Create symbolic link: ln -s targetProjectPath project.path
                    try self.fileManager.createSymbolicLink(atPath: project.path, withDestinationPath: targetProjectPath)
                    self.appendLog("   Collegamento simbolico creato:")
                    self.appendLog("   \(project.path) -> \(targetProjectPath)")

                    // Verify symlink
                    let dest = try self.fileManager.destinationOfSymbolicLink(atPath: project.path)
                    guard dest == targetProjectPath else {
                        throw NSError(domain: "Migration", code: 7, userInfo: [
                            NSLocalizedDescriptionKey: "Il symlink creato non punta alla destinazione corretta: \(dest)"
                        ])
                    }

                    // Test reading contents through symlink
                    let symlinkContents = try self.fileManager.contentsOfDirectory(atPath: project.path)
                    guard !symlinkContents.isEmpty else {
                        throw NSError(domain: "Migration", code: 8, userInfo: [
                            NSLocalizedDescriptionKey: "Impossibile leggere i contenuti attraverso il symlink."
                        ])
                    }

                    self.appendLog("✅ Symlink verificato e trasparente per Antigravity!")

                    // Safe deletion of temp backup
                    self.appendLog("🗑️ Rimozione copia temporanea dal disco interno...")
                    try self.fileManager.removeItem(atPath: backupOriginalPath)
                    self.appendLog("✅ Spazio liberato sul disco Mac.")

                } catch {
                    // ROLLBACK: Restore original folder if symlink fails
                    self.appendLog("⚠️ Errore nella creazione del symlink. Ripristino cartella originale...")
                    try? self.fileManager.removeItem(atPath: project.path)
                    try? self.fileManager.moveItem(atPath: backupOriginalPath, toPath: project.path)
                    throw error
                }

                // Refresh scanner
                FolderScanner.shared.refreshProject(atPath: project.path)

                DispatchQueue.main.async {
                    self.phase = .completed
                    self.isRunning = false
                    self.isSuccess = true
                    self.appendLog("🎉 Operazione completata! Il progetto risiede ora sul disco esterno con symlink trasparente.")
                    completion(true, nil)
                }

            } catch {
                DispatchQueue.main.async {
                    self.phase = .failed
                    self.isRunning = false
                    self.isSuccess = false
                    self.errorDescription = error.localizedDescription
                    self.appendLog("❌ ERRORE: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    /// Restores a symlinked project back to the local Mac drive
    public func restoreToMac(
        project: ProjectItem,
        ignoreAntigravityRunning: Bool = false,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard project.isSymlink, let target = project.symlinkTarget else {
            completion(false, "Il progetto non è un collegamento simbolico.")
            return
        }

        isRunning = true
        isSuccess = false
        errorDescription = nil
        logOutput.removeAll()
        phase = .copying

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if !ignoreAntigravityRunning && ProcessService.shared.isAntigravityRunning() {
                    throw NSError(domain: "Restore", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Antigravity è attualmente aperto. Chiudi l'IDE prima di procedere, oppure attiva 'Ignora controllo'."
                    ])
                }

                self.appendLog("🔄 Ripristino del progetto sul disco interno del Mac...")
                self.appendLog("   Origine (Disco Esterno): \(target)")
                self.appendLog("   Destinazione (Mac): \(project.path)")

                let restoringTemp = project.path + ".__restoring_tmp__"
                if self.fileManager.fileExists(atPath: restoringTemp) {
                    try? self.fileManager.removeItem(atPath: restoringTemp)
                }

                // Copy from external to temp folder
                try self.runRsync(source: target, destinationParent: (restoringTemp as NSString).deletingLastPathComponent, customTargetName: (restoringTemp as NSString).lastPathComponent)

                // Remove the symlink
                self.appendLog("🔗 Rimozione del collegamento simbolico...")
                try self.fileManager.removeItem(atPath: project.path)

                // Rename temp folder to original name
                self.appendLog("📁 Spostamento cartella fisica al percorso originale...")
                try self.fileManager.moveItem(atPath: restoringTemp, toPath: project.path)

                FolderScanner.shared.refreshProject(atPath: project.path)

                DispatchQueue.main.async {
                    self.phase = .completed
                    self.isRunning = false
                    self.isSuccess = true
                    self.appendLog("🎉 Progetto ripristinato con successo sul disco interno del Mac!")
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.phase = .failed
                    self.isRunning = false
                    self.isSuccess = false
                    self.errorDescription = error.localizedDescription
                    self.appendLog("❌ ERRORE RIPRISTINO: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    /// Helper to execute /usr/bin/rsync
    private func runRsync(source: String, destinationParent: String, customTargetName: String? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")

        var dest = destinationParent
        if !dest.hasSuffix("/") { dest += "/" }

        if let customName = customTargetName {
            dest = (destinationParent as NSString).appendingPathComponent(customName) + "/"
            try? fileManager.createDirectory(atPath: dest, withIntermediateDirectories: true)
            var src = source
            if !src.hasSuffix("/") { src += "/" }
            process.arguments = ["-avP", "--protect-args", src, dest]
        } else {
            // Source without trailing slash copies the directory itself into destinationParent/
            process.arguments = ["-avP", "--protect-args", source, dest]
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        currentProcess = process

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                let lines = str.components(separatedBy: "\r")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        // Filter frequent rsync lines or capture progress
                        if trimmed.contains("%") || trimmed.contains("to-check=") || trimmed.hasPrefix("sending") {
                            DispatchQueue.main.async {
                                self.progressMessage = trimmed
                            }
                        } else {
                            self.appendLog("   \(trimmed)")
                        }
                    }
                }
            }
        }

        try process.run()
        process.waitUntilExit()

        pipe.fileHandleForReading.readabilityHandler = nil
        currentProcess = nil

        if process.terminationStatus != 0 {
            throw NSError(domain: "Rsync", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "rsync è terminato con codice di errore \(process.terminationStatus)"
            ])
        }
    }

    public func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
        isRunning = false
        phase = .failed
        appendLog("⚠️ Operazione annullata dall'utente.")
    }
}
