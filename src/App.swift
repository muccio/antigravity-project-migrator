import SwiftUI

extension Notification.Name {
    static let selectProjectsFolder = Notification.Name("selectProjectsFolder")
}

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
                Button("Scegli Cartella Progetti...") {
                    NotificationCenter.default.post(name: .selectProjectsFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Ricarica Progetti") {
                    FolderScanner.shared.scan(directory: FolderScanner.shared.currentFolder)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
