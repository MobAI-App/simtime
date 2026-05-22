import ArgumentParser
import Foundation
import SimtimeCore

/// `simtime inject` - sets DYLD_INSERT_LIBRARIES on the sim and launches the
/// target app with simtime's runtime dylib hooked. The dylib reads the same
/// /private/tmp/simtime-<udid>-<bundle>.json the CLI writes.
///
/// We use `xcrun simctl launch` with `--terminate-running-process` because:
///  - `SIMCTL_CHILD_*` env vars are the only documented way to pass arbitrary
///    env into a sim-launched app.
///  - The app has to be relaunched for DYLD_INSERT_LIBRARIES to take effect.
struct Inject: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Launch (or relaunch) the target app with the simtime runtime hooked."
    )

    @OptionGroup var target: TargetOptions

    @Option(name: .long, help: "Path to libsimtime.dylib. Defaults to ./Runtime/libsimtime.dylib relative to PWD, then $SIMTIME_DYLIB.")
    var dylib: String?

    func run() throws {
        let path = try resolveDylibPath()
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("dylib not found at \(path) - pass --dylib or set SIMTIME_DYLIB")
        }

        // The sim needs the dylib at a path *it* can see. /private/tmp is
        // shared between host and guest, so copying there sidesteps any
        // sandbox / dev-dir visibility issues.
        let inSimPath = "/private/tmp/libsimtime-\(target.udid).dylib"
        try copyDylib(from: path, to: inSimPath)

        // Terminate any running instance - DYLD_INSERT_LIBRARIES only takes
        // effect at process start.
        _ = runProc("xcrun", ["simctl", "terminate", target.udid, target.bundle])

        // Launch with the runtime injected + identification env vars.
        let env = [
            "SIMCTL_CHILD_DYLD_INSERT_LIBRARIES": inSimPath,
            "SIMCTL_CHILD_SIMTIME_UDID": target.udid,
            "SIMCTL_CHILD_SIMTIME_BUNDLE": target.bundle,
        ]
        let result = runProc("xcrun", ["simctl", "launch", target.udid, target.bundle], env: env)
        if result.code != 0 {
            throw ValidationError("simctl launch failed: \(result.stderr.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))")
        }
        print(result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        print("→ runtime injected; control with: simtime freeze/travel/scale/reset --udid \(target.udid) --bundle \(target.bundle)")
    }

    private func resolveDylibPath() throws -> String {
        if let p = dylib { return p }
        if let env = ProcessInfo.processInfo.environment["SIMTIME_DYLIB"] { return env }
        // Best effort: look next to the binary, then in PWD/Runtime, then in
        // a sibling .build/runtime folder set up by `make install`.
        let candidates = [
            "Runtime/libsimtime.dylib",
            ".build/runtime/libsimtime.dylib",
            "/usr/local/lib/libsimtime.dylib",
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) { return c }
        }
        return candidates[0]
    }

    private func copyDylib(from src: String, to dst: String) throws {
        // Always overwrite - keeps the in-sim copy fresh during dev iteration.
        try? FileManager.default.removeItem(atPath: dst)
        try FileManager.default.copyItem(atPath: src, toPath: dst)
    }
}

struct CmdResult {
    let code: Int32
    let stdout: String
    let stderr: String
}

func runProc(_ tool: String, _ args: [String], env: [String: String]? = nil) -> CmdResult {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = [tool] + args
    if let env = env {
        var merged = ProcessInfo.processInfo.environment
        for (k, v) in env { merged[k] = v }
        p.environment = merged
    }
    let outPipe = Pipe(), errPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = errPipe
    do {
        try p.run()
    } catch {
        return CmdResult(code: -1, stdout: "", stderr: "\(error)")
    }
    p.waitUntilExit()
    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return CmdResult(code: p.terminationStatus, stdout: out, stderr: err)
}
