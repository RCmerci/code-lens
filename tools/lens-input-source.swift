// Code Lens guard/metadata frontend for the pinned official macism core.
// Uses public Carbon/AppKit APIs; never types keys or reads user text.
import Cocoa
import Carbon
import Foundation

@main
struct CodeLensInputSource {
    static func emit(_ value: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }
    static func frontmostPID() -> Int {
        Int(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)
    }
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args == ["--version"] {
            print("Code Lens input source: macism 3.1.1 @ 8d3077bc09e7887c9c0993a1b75b4c7e6b65b6d0")
            return
        }
        InputSourceManager.initialize()
        if args == ["--inspect"] {
            emit([
                "current": InputSourceManager.getCurrentSource().id,
                "frontmost_pid": frontmostPID(),
                "sources": InputSourceManager.inputSources.filter {
                    $0.tisInputSource.category == (kTISCategoryKeyboardInputSource as String)
                }.map {
                    ["id": $0.id, "languages": $0.tisInputSource.sourceLanguages] as [String: Any]
                }
            ])
            return
        }
        guard args.count == 4, args[0] == "--select", args[2] == "--owner-pid",
              let owner = Int(args[3]), owner > 0, let source = InputSourceManager.getInputSource(name: args[1]),
              source.tisInputSource.category == (kTISCategoryKeyboardInputSource as String) else {
            emit(["error": "expected enabled source and owner PID"])
            exit(2)
        }
        // Check at the point of mutation as well as in Emacs: stale focus events cannot select.
        guard frontmostPID() == owner else {
            emit(["error": "owner is not foreground"])
            exit(3)
        }
        // Official macism's CJK workaround uses its 3x3 window for 150 ms.
        // No CGEvent/Accessibility keyboard injection is compiled into this helper.
        source.select()
        emit(["current": InputSourceManager.getCurrentSource().id])
    }
}
