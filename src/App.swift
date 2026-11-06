import SwiftUI

@main
struct AntigravityMigratorApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .frame(minWidth: 920, minHeight: 580)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Aggiorna Progetti") {
                    FolderScanner.shared.scan(directory: FolderScanner.shared.currentFolder)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
