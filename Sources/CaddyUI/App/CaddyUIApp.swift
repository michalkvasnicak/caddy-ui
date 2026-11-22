import AppKit
import Darwin
import SwiftUI

@main
enum EntryPoint {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments.first {
        case "--mcp":
            MCPBridge.run(directory: AppDelegate.dataDirectory)
        case "serve", "help", "--help", "-h":
            ServeCommand.run(arguments, directory: AppDelegate.dataDirectory)
        default:
            CaddyUIApp.main()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var dataDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CaddyUI", isDirectory: true)
    }

    let model = AppModel(directory: AppDelegate.dataDirectory)
    private lazy var targetsWindow = TargetsWindow(model: model)
    private var listener: MCPListener?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            try prepareDirectory()
            listener = try MCPListener(directory: model.directory) { [model] request in
                await MCPServer.handle(request, model: model)
            }
            try model.load()
        } catch {
            model.notice = error.localizedDescription
        }
    }

    func showTargets() {
        targetsWindow.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutDown()
    }

    private func prepareDirectory() throws {
        let manager = FileManager.default
        let path = model.directory.path
        if !manager.fileExists(atPath: path) {
            try manager.createDirectory(
                at: model.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
        }

        let attributes = try manager.attributesOfItem(atPath: path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              attributes[.ownerAccountID] as? UInt32 == getuid(),
              attributes[.posixPermissions] as? Int == 0o700 else {
            throw AppError("Caddy UI needs a private directory (mode 700) owned by you: \(path)")
        }
    }
}

@MainActor
struct CaddyUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Caddy UI", systemImage: "server.rack") {
            MenuContent(model: delegate.model, showTargets: delegate.showTargets)
        }
    }
}
