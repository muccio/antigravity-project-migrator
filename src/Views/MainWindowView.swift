import AppKit
import SwiftUI

public enum ProjectFilter: String, CaseIterable, Identifiable {
    case all = "Tutti"
    case local = "Sul Mac"
    case external = "Su Disco Esterno"
    case withChats = "Con Chat Antigravity"

    public var id: String { rawValue }
}

public enum ProjectSort: String, CaseIterable, Identifiable {
    case sizeDesc = "Dimensione (Maggiore)"
    case sizeAsc = "Dimensione (Minore)"
    case nameAsc = "Nome (A-Z)"
    case chatsDesc = "Chat Antigravity"

    public var id: String { rawValue }
}

public struct MainWindowView: View {
    @StateObject private var scanner = FolderScanner.shared
    @State private var selectedProject: ProjectItem? = nil
    @State private var searchText: String = ""
    @State private var selectedFilter: ProjectFilter = .all
    @State private var selectedSort: ProjectSort = .sizeDesc

    @State private var projectToMigrate: ProjectItem? = nil
    @State private var projectToRestore: ProjectItem? = nil
    @State private var projectToCleanCache: ProjectItem? = nil
    @State private var showBackupsModal: Bool = false

    public var body: some View {
        HSplitView {
            // Left Column: List and Filters
            VStack(spacing: 0) {
                projectFolderBar
                Divider()
                topSearchBar
                Divider()
                summaryHeader
                Divider()
                projectList
            }
            .frame(minWidth: 440, idealWidth: 490)

            // Right Column: Detail Inspector
            Group {
                if let project = selectedProject {
                    ProjectDetailView(
                        project: project,
                        onMigrate: {
                            MigrationService.shared.reset()
                            projectToMigrate = project
                        },
                        onRestore: {
                            MigrationService.shared.reset()
                            projectToRestore = project
                        },
                        onCleanCache: { projectToCleanCache = project },
                        onRecalculate: { scanner.refreshProject(atPath: project.path) }
                    )
                } else {
                    emptySelectionView
                }
            }
            .frame(minWidth: 360, idealWidth: 420)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: selectCustomFolder) {
                    Label("Scegli Cartella", systemImage: "folder.badge.gearshape")
                }
                .help("Seleziona la cartella dei progetti da scansionare (Cmd+O)")

                Menu {
                    folderQuickOptions
                } label: {
                    Label("Percorsi Rapidi", systemImage: "clock.arrow.circlepath")
                }

                Button(action: { scanner.scan(directory: scanner.currentFolder) }) {
                    Label("Ricarica", systemImage: "arrow.clockwise")
                }
                .help("Riscansiona la cartella corrente (Cmd+R)")

                Button(action: { showBackupsModal = true }) {
                    Label("Backup Chat", systemImage: "shield.checkerboard")
                }
                .help("Visualizza e crea backup delle chat Antigravity")
            }
        }
        .sheet(item: $projectToMigrate) { project in
            MigrationModalView(project: project) {
                MigrationService.shared.reset()
                projectToMigrate = nil
                updateSelectedProject()
            }
        }
        .sheet(item: $projectToRestore) { project in
            RestoreModalView(project: project) {
                MigrationService.shared.reset()
                projectToRestore = nil
                updateSelectedProject()
            }
        }
        .sheet(item: $projectToCleanCache) { project in
            CleanCacheModalView(project: project) {
                projectToCleanCache = nil
                updateSelectedProject()
            }
        }
        .sheet(isPresented: $showBackupsModal) {
            BackupsModalView {
                showBackupsModal = false
            }
        }
        .onAppear {
            if scanner.projects.isEmpty {
                let initial = scanner.resolveInitialDirectory()
                scanner.scan(directory: initial)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectProjectsFolder)) { _ in
            selectCustomFolder()
        }
        .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleDrop)
    }

    // MARK: - Project Folder Selector Bar
    private var projectFolderBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill.badge.gearshape")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("CARTELLA PROGETTI")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                Text(scanner.currentFolder.isEmpty ? "Nessuna cartella selezionata" : scanner.currentFolder)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(scanner.currentFolder)
            }

            Spacer(minLength: 8)

            Button(action: selectCustomFolder) {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                    Text("Sfoglia...")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Seleziona una cartella diversa di progetti")

            Menu {
                folderQuickOptions
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
            .help("Opzioni cartella e percorsi recenti")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
    }

    @ViewBuilder
    private var folderQuickOptions: some View {
        Button("Scegli un'altra cartella...") {
            selectCustomFolder()
        }

        if !scanner.currentFolder.isEmpty && FileManager.default.fileExists(atPath: scanner.currentFolder) {
            Button("Mostra nel Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: scanner.currentFolder)])
            }

            Button("Copia percorso negli appunti") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(scanner.currentFolder, forType: .string)
            }
        }

        if !scanner.recentFolders.isEmpty {
            Divider()
            Text("Cartelle Recenti:")

            ForEach(scanner.recentFolders, id: \.self) { folder in
                Button(action: { scanner.scan(directory: folder) }) {
                    HStack {
                        if folder == scanner.currentFolder {
                            Image(systemName: "checkmark")
                        }
                        Text((folder as NSString).lastPathComponent)
                    }
                }
            }
        }

        Divider()
        Text("Percorsi Standard:")

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let webdevPath = (home as NSString).appendingPathComponent("Documents/Development/WEBDEV")
        if FileManager.default.fileExists(atPath: webdevPath) {
            Button("WEBDEV (~/Documents/Development/WEBDEV)") {
                scanner.scan(directory: webdevPath)
            }
        }

        let devPath = (home as NSString).appendingPathComponent("Documents/Development")
        if FileManager.default.fileExists(atPath: devPath) {
            Button("Development (~/Documents/Development)") {
                scanner.scan(directory: devPath)
            }
        }

        Button("Home Utente (~)") {
            scanner.scan(directory: home)
        }
    }

    // MARK: - Search & Filters
    private var topSearchBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Cerca progetti...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Menu {
                    Picker("Ordina per", selection: $selectedSort) {
                        ForEach(ProjectSort.allCases) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Picker("Filtro", selection: $selectedFilter) {
                ForEach(ProjectFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(10)
    }

    // MARK: - Summary Header
    private var summaryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text("\(filteredProjects.count) progetti trovati")
                        .font(.system(size: 11, weight: .bold))

                    let totalBytes = filteredProjects.compactMap { $0.sizeBytes }.reduce(0, +)
                    Text("•  Totale: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    let externalCount = filteredProjects.filter { $0.isSymlink }.count
                    if externalCount > 0 {
                        Text("•  \(externalCount) su disco esterno")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                }
            }

            Spacer()

            if scanner.calculationProgress > 0 && scanner.calculationProgress < 1.0 {
                ProgressView(value: scanner.calculationProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Projects List
    private var projectList: some View {
        Group {
            if scanner.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scansione cartella in corso...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredProjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary)
                    Text("Nessun progetto trovato")
                        .font(.system(size: 15, weight: .bold))
                    Text("La cartella corrente non contiene progetti oppure i filtri applicati hanno escluso tutti gli elementi.\n\n\(scanner.currentFolder)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)

                    HStack(spacing: 10) {
                        Button(action: selectCustomFolder) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Scegli Cartella Progetti...")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Button(action: { scanner.scan(directory: scanner.currentFolder) }) {
                            Image(systemName: "arrow.clockwise")
                            Text("Ricarica")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            } else {
                List(selection: $selectedProject) {
                    ForEach(filteredProjects) { project in
                        ProjectRowView(project: project, isSelected: selectedProject?.id == project.id)
                            .tag(project)
                            .onTapGesture {
                                selectedProject = project
                            }
                            .contextMenu {
                                if project.isSymlink {
                                    Button("Ripristina sul Mac") {
                                        MigrationService.shared.reset()
                                        projectToRestore = project
                                    }
                                } else {
                                    Button("Sposta su Disco Esterno...") {
                                        MigrationService.shared.reset()
                                        projectToMigrate = project
                                    }
                                }

                                if !project.cacheItems.isEmpty {
                                    Button("Pulisci Cache...") {
                                        projectToCleanCache = project
                                    }
                                }

                                Divider()

                                Button("Rivela nel Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
                                }

                                Button("Apri in Antigravity") {
                                    NSWorkspace.shared.open([URL(fileURLWithPath: project.path)], withApplicationAt: URL(fileURLWithPath: "/Applications/Antigravity.app"), configuration: NSWorkspace.OpenConfiguration())
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Empty Selection View
    private var emptySelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Seleziona un progetto")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondary)
            Text("Visualizza le dimensioni, le cartelle di cache ricreabili (node_modules, build) e spostalo in modo sicuro su un'unità esterna senza perdere le chat di Antigravity.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filter and Sort Logic
    private var filteredProjects: [ProjectItem] {
        var list = scanner.projects

        // Filter
        switch selectedFilter {
        case .all:
            break
        case .local:
            list = list.filter { !$0.isSymlink }
        case .external:
            list = list.filter { $0.isSymlink }
        case .withChats:
            list = list.filter { $0.antigravityChatCount > 0 }
        }

        // Search text
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText) ||
                ($0.symlinkTarget?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Sort
        switch selectedSort {
        case .sizeDesc:
            list.sort { ($0.sizeBytes ?? 0) > ($1.sizeBytes ?? 0) }
        case .sizeAsc:
            list.sort { ($0.sizeBytes ?? 0) < ($1.sizeBytes ?? 0) }
        case .nameAsc:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .chatsDesc:
            list.sort { $0.antigravityChatCount > $1.antigravityChatCount }
        }

        return list
    }

    private func updateSelectedProject() {
        if let current = selectedProject, let updated = scanner.projects.first(where: { $0.path == current.path }) {
            selectedProject = updated
        }
    }

    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Seleziona Cartella"
        panel.message = "Seleziona la cartella radice che contiene i tuoi progetti"
        if !scanner.currentFolder.isEmpty && FileManager.default.fileExists(atPath: scanner.currentFolder) {
            panel.directoryURL = URL(fileURLWithPath: scanner.currentFolder)
        }

        if panel.runModal() == .OK, let url = panel.url {
            scanner.scan(directory: url.path)
            selectedProject = nil
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let folderURL = url {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue {
                    DispatchQueue.main.async {
                        self.scanner.scan(directory: folderURL.path)
                        self.selectedProject = nil
                    }
                }
            }
        }
        return true
    }
}
