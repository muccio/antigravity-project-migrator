import AppKit
import Foundation

public final class ProcessService {
    public static let shared = ProcessService()

    private init() {}

    /// Checks if the main Antigravity IDE application is currently running
    public func isAntigravityRunning() -> Bool {
        // 1. Check exact bundle identifier: "com.google.antigravity"
        // Note: Helpers have "com.google.antigravity.helper", which is excluded.
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.antigravity")
        for app in running {
            if app.bundleIdentifier == "com.google.antigravity",
               !app.isTerminated,
               app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                return true
            }
        }

        // 2. Exact executable name check via pgrep (matches only exact "Antigravity", not "Antigravity Migrator" or "Antigravity Helper")
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "Antigravity"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return true
        }

        // 3. Exact full binary path check
        let pipe2 = Pipe()
        let process2 = Process()
        process2.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process2.arguments = ["-f", "/Applications/Antigravity.app/Contents/MacOS/Antigravity"]
        process2.standardOutput = pipe2
        process2.standardError = Pipe()

        try? process2.run()
        process2.waitUntilExit()

        return process2.terminationStatus == 0
    }

    /// Attempts to close Antigravity gracefully, or forcibly if requested
    public func terminateAntigravity(force: Bool = false) -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.antigravity")
        var success = true

        for app in apps where app.bundleIdentifier == "com.google.antigravity" {
            if force {
                let killed = app.forceTerminate()
                if !killed { success = false }
            } else {
                let terminated = app.terminate()
                if !terminated { success = false }
            }
        }

        // Exact kill of main Antigravity process if force requested
        if force {
            let pkill = Process()
            pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            pkill.arguments = ["-9", "-x", "Antigravity"]
            try? pkill.run()
            pkill.waitUntilExit()
        }

        return success
    }
}
