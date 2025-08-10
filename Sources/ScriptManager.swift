import Foundation
import Darwin

struct ScriptError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class ScriptManager {
    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let scriptsDirectory = "scriptsDirectoryPath"
        static let interpreterPath = "pythonInterpreterPath"
        static let additionalScripts = "additionalScriptsPaths"
        static let customStatusIconPath = "customStatusIconPath"
        static let customStatusIconSymbolName = "customStatusIconSymbolName"
        static let showStatusBadge = "showStatusBadge"
    }

    static let processListDidChange = Notification.Name("ScriptManagerProcessListDidChange")

    // Synchronisation und Prozesse
    private let syncQueue = DispatchQueue(label: "com.menupy.scriptmanager.sync")
    private var runningProcessesByPath: [String: Process] = [:]

    private func canonicalPath(for url: URL) -> String {
        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func postProcessListChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: ScriptManager.processListDidChange, object: self)
        }
    }

    private func postCustomIconChanged() {
        NotificationCenter.default.post(name: .init("CustomStatusIconDidChange"), object: nil)
    }

    private func postBadgePreferenceChanged() {
        NotificationCenter.default.post(name: .init("StatusBadgePreferenceDidChange"), object: nil)
    }

    // MARK: - Persistenz

    func saveScriptsDirectory(_ url: URL) {
        userDefaults.set(url.path, forKey: Keys.scriptsDirectory)
    }

    func clearScriptsDirectory() {
        userDefaults.removeObject(forKey: Keys.scriptsDirectory)
    }

    func savePythonInterpreter(_ url: URL) {
        userDefaults.set(url.path, forKey: Keys.interpreterPath)
    }

    func savePythonInterpreterPath(_ path: String) {
        userDefaults.set(path, forKey: Keys.interpreterPath)
    }

    func addAdditionalScripts(_ urls: [URL]) {
        var existing = userDefaults.stringArray(forKey: Keys.additionalScripts) ?? []
        let newPaths = urls.map { $0.path }
        for p in newPaths where !existing.contains(p) {
            existing.append(p)
        }
        userDefaults.set(existing, forKey: Keys.additionalScripts)
    }

    func removeAdditionalScript(_ url: URL) {
        let path = url.path
        var existing = userDefaults.stringArray(forKey: Keys.additionalScripts) ?? []
        existing.removeAll { $0 == path }
        userDefaults.set(existing, forKey: Keys.additionalScripts)
    }

    func clearMissingAdditionalScripts() {
        let fm = FileManager.default
        let existing = (userDefaults.stringArray(forKey: Keys.additionalScripts) ?? [])
            .filter { fm.fileExists(atPath: $0) }
        userDefaults.set(existing, forKey: Keys.additionalScripts)
    }

    // Custom Status Icon (Datei)
    func saveCustomStatusIcon(_ url: URL) {
        userDefaults.set(url.path, forKey: Keys.customStatusIconPath)
        postCustomIconChanged()
    }

    func clearCustomStatusIcon() {
        userDefaults.removeObject(forKey: Keys.customStatusIconPath)
        postCustomIconChanged()
    }

    func customStatusIconURL() -> URL? {
        guard let path = userDefaults.string(forKey: Keys.customStatusIconPath), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    // Custom Status Icon (SF-Symbol)
    func saveCustomStatusIconSymbolName(_ name: String) {
        userDefaults.set(name, forKey: Keys.customStatusIconSymbolName)
        postCustomIconChanged()
    }

    func clearCustomStatusIconSymbolName() {
        userDefaults.removeObject(forKey: Keys.customStatusIconSymbolName)
        postCustomIconChanged()
    }

    func customStatusIconSymbolName() -> String? {
        let name = userDefaults.string(forKey: Keys.customStatusIconSymbolName)
        return (name?.isEmpty == false) ? name : nil
    }

    // Badge-Präferenz
    func setStatusBadgeEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.showStatusBadge)
        postBadgePreferenceChanged()
    }

    func isStatusBadgeEnabled() -> Bool {
        if userDefaults.object(forKey: Keys.showStatusBadge) == nil {
            return true // Standard: Badge an
        }
        return userDefaults.bool(forKey: Keys.showStatusBadge)
    }

    // MARK: - Zugriff

    func scriptsDirectoryURL() -> URL? {
        if let path = userDefaults.string(forKey: Keys.scriptsDirectory) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    func pythonInterpreterPath() -> String {
        if let path = userDefaults.string(forKey: Keys.interpreterPath), !path.isEmpty {
            return path
        }
        // Fallback-Suche nach typischen Installationsorten
        for path in discoverPythonInterpreters() {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "/usr/bin/env python3"
    }

    func additionalScripts() -> [URL] {
        let fm = FileManager.default
        let paths = userDefaults.stringArray(forKey: Keys.additionalScripts) ?? []
        return paths.compactMap { p in
            fm.fileExists(atPath: p) ? URL(fileURLWithPath: p) : nil
        }
    }

    func availableScripts() -> [URL]? {
        let fm = FileManager.default
        var result: [URL] = []

        if let dir = scriptsDirectoryURL() {
            if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                result.append(contentsOf: contents.filter { $0.pathExtension.lowercased() == "py" })
            }
        }

        result.append(contentsOf: additionalScripts())

        // Deduplizieren nach Pfad und sortieren
        var seen: Set<String> = []
        let unique = result.filter { url in
            let p = canonicalPath(for: url)
            if seen.contains(p) { return false }
            seen.insert(p)
            return true
        }
        return unique.sorted { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
    }

    // MARK: - Interpreter-Erkennung

    func discoverPythonInterpreters() -> [String] {
        var candidates: [String] = []
        let fm = FileManager.default

        // Homebrew-Standardpfade (inkl. spezifischer Versionen)
        let brewPrefixes = ["/opt/homebrew", "/usr/local"]
        let brewVersions = ["3.12", "3.11", "3.10"]
        for prefix in brewPrefixes {
            let generic = "\(prefix)/bin/python3"
            candidates.append(generic)
            for v in brewVersions {
                candidates.append("\(prefix)/opt/python@\(v)/bin/python\(v)")
                candidates.append("\(prefix)/bin/python\(v)")
            }
        }

        // Systempfade
        candidates.append("/usr/bin/python3")

        // pyenv: alle Versionen unter ~/.pyenv/versions/*/bin/python3
        let home = fm.homeDirectoryForCurrentUser.path
        let pyenvVersionsDir = "\(home)/.pyenv/versions"
        if let subdirs = try? fm.contentsOfDirectory(atPath: pyenvVersionsDir) {
            for sub in subdirs {
                let path = "\(pyenvVersionsDir)/\(sub)/bin/python3"
                candidates.append(path)
            }
        }
        // pyenv shim
        candidates.append("\(home)/.pyenv/shims/python3")

        // Dedup und Filter: existierend + executable
        var seen: Set<String> = []
        var filtered: [String] = []
        for c in candidates {
            if seen.contains(c) { continue }
            seen.insert(c)
            if fm.isExecutableFile(atPath: c) {
                filtered.append(c)
            }
        }
        // Falls nichts gefunden wurde, env-Fallback
        if filtered.isEmpty { filtered = ["/usr/bin/env python3"] }
        return filtered
    }

    // MARK: - Laufende Prozesse

    func isRunning(script url: URL) -> Bool {
        let key = canonicalPath(for: url)
        return syncQueue.sync { runningProcessesByPath[key] != nil }
    }

    func runningScriptURLs() -> [URL] {
        let keys = syncQueue.sync { Array(runningProcessesByPath.keys) }
        return keys.map { URL(fileURLWithPath: $0) }
    }

    func cancelScript(at url: URL) {
        let key = canonicalPath(for: url)
        let process: Process? = syncQueue.sync { runningProcessesByPath[key] }
        guard let p = process else { return }
        p.interrupt()
        postProcessListChanged()
        // Fallback, falls nicht beendet
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let stillRunning: Process? = self.syncQueue.sync { self.runningProcessesByPath[key] }
            if let sp = stillRunning, sp.isRunning {
                sp.terminate()
                self.postProcessListChanged()
            }
            // Letzter Ausweg: SIGKILL
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let again: Process? = self.syncQueue.sync { self.runningProcessesByPath[key] }
                if let ap = again, ap.isRunning {
                    kill(ap.processIdentifier, SIGKILL)
                }
            }
        }
    }

    func cancelAll() {
        let processes: [Process] = syncQueue.sync { Array(runningProcessesByPath.values) }
        for p in processes { p.interrupt() }
        postProcessListChanged()
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let still: [Process] = self.syncQueue.sync { Array(self.runningProcessesByPath.values) }
            for p in still where p.isRunning { p.terminate() }
            self.postProcessListChanged()
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let yet: [Process] = self.syncQueue.sync { Array(self.runningProcessesByPath.values) }
                for p in yet where p.isRunning { kill(p.processIdentifier, SIGKILL) }
            }
        }
    }

    // MARK: - Ausführung

    func runScript(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.standardOutput = stdout
        process.standardError = stderr
        process.currentDirectoryURL = url.deletingLastPathComponent()

        let interpreter = pythonInterpreterPath()
        if interpreter.hasPrefix("/usr/bin/env") {
            process.launchPath = "/usr/bin/env"
            process.arguments = ["python3", url.path]
        } else {
            process.launchPath = interpreter
            process.arguments = [url.path]
        }

        let key = canonicalPath(for: url)
        syncQueue.sync { runningProcessesByPath[key] = process }
        postProcessListChanged()

        process.terminationHandler = { [weak self] _ in
            guard let self = self else { return }
            self.syncQueue.sync { self.runningProcessesByPath[key] = nil }
            self.postProcessListChanged()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
            } catch {
                self.syncQueue.sync { self.runningProcessesByPath[key] = nil }
                self.postProcessListChanged()
                completion(.failure(ScriptError(message: "Konnte Prozess nicht starten: \(error.localizedDescription)")))
                return
            }

            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                completion(.success(output.trimmingCharacters(in: .whitespacesAndNewlines)))
            } else {
                var message = "Skript beendete sich mit Status \(process.terminationStatus)."
                if !errorOutput.isEmpty { message += "\n\nFehler:\n" + errorOutput }
                if !output.isEmpty { message += "\n\nAusgabe:\n" + output }
                completion(.failure(ScriptError(message: message)))
            }
        }
    }
}
