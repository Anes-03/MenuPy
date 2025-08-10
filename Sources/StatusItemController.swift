import AppKit
import UniformTypeIdentifiers

final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let scriptManager = ScriptManager()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(processListChanged), name: ScriptManager.processListDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(customIconChanged), name: .init("CustomStatusIconDidChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(badgePreferenceChanged), name: .init("StatusBadgePreferenceDidChange"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setupStatusItem() {
        applyStatusIcon()
        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        }
        updateStatusBadge()
        rebuildMenu()
    }

    private func applyStatusIcon() {
        if let customURL = scriptManager.customStatusIconURL(), let image = NSImage(contentsOf: customURL) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            statusItem.button?.image = image
            return
        }
        if #available(macOS 11.0, *), let symbolName = scriptManager.customStatusIconSymbolName(), let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MenuPy") {
            symbolImage.isTemplate = true
            statusItem.button?.image = symbolImage
            return
        }
        if #available(macOS 11.0, *) {
            statusItem.button?.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "MenuPy")
        } else {
            statusItem.button?.title = "MenuPy"
        }
    }

    @objc private func customIconChanged() {
        applyStatusIcon()
    }

    @objc private func badgePreferenceChanged() {
        updateStatusBadge()
    }

    private func updateStatusBadge() {
        guard let button = statusItem.button else { return }
        let runningCount = scriptManager.runningScriptURLs().count
        if scriptManager.isStatusBadgeEnabled() && runningCount > 0 {
            button.title = " \(runningCount)"
            button.toolTip = "\(runningCount) Skript(e) laufen"
        } else {
            button.title = ""
            button.toolTip = "MenuPy"
        }
    }

    @objc private func processListChanged() {
        updateStatusBadge()
        rebuildMenu()
    }

    @objc private func selectScriptsFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Skripte-Ordner wählen"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            scriptManager.saveScriptsDirectory(url)
            rebuildMenu()
        }
    }

    @objc private func clearScriptsFolder(_ sender: Any?) {
        scriptManager.clearScriptsDirectory()
        rebuildMenu()
    }

    @objc private func addScriptFiles(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Python-Skripte hinzufügen"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if let pyType = UTType(filenameExtension: "py") {
            panel.allowedContentTypes = [pyType]
        }
        if panel.runModal() == .OK {
            scriptManager.addAdditionalScripts(panel.urls)
            rebuildMenu()
        }
    }

    @objc private func removeScript(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        scriptManager.removeAdditionalScript(url)
        rebuildMenu()
    }

    @objc private func selectPythonInterpreter(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Python-Interpreter wählen"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            scriptManager.savePythonInterpreter(url)
            rebuildMenu()
        }
    }

    @objc private func pickKnownInterpreter(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        scriptManager.savePythonInterpreterPath(path)
        rebuildMenu()
    }

    @objc private func refreshScripts(_ sender: Any?) {
        scriptManager.clearMissingAdditionalScripts()
        rebuildMenu()
    }

    @objc private func stopAllRunning(_ sender: Any?) {
        scriptManager.cancelAll()
    }

    @objc private func stopThisScript(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        scriptManager.cancelScript(at: url)
    }

    @objc private func openSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    @objc private func showAbout(_ sender: Any?) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let alert = NSAlert()
        alert.messageText = "MenuPy"
        alert.informativeText = "Version \(version) (\(build))\n\nMenuPy ist eine kleine macOS-Menüleisten-App zum schnellen Ausführen von Python-Skripten (z. B. Tools, Automatisierungen), ohne das Terminal zu öffnen.\n\nEntwickler: Anes-03"
        if let icon = NSImage(named: "AboutIcon") ?? loadAboutIconFromBundle() {
            icon.isTemplate = false
            alert.icon = icon
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub öffnen")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn, let url = URL(string: "https://github.com/Anes-03/MenuPy") {
            NSWorkspace.shared.open(url)
        }
    }

    private func loadAboutIconFromBundle() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AboutIcon", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: "AboutIcon", withExtension: nil) {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    @objc private func runScript(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        run(script: url)
    }

    private func run(script: URL) {
        scriptManager.runScript(at: script) { _ in }
    }

    private func symbol(_ name: String) -> NSImage? {
        if #available(macOS 11.0, *) {
            let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            img?.isTemplate = true
            return img
        }
        return nil
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Dynamische Skripte
        if let scripts = scriptManager.availableScripts() {
            for script in scripts {
                let title = script.deletingPathExtension().lastPathComponent
                let item = NSMenuItem(title: title, action: #selector(runScript(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = script
                item.image = symbol("play.fill")
                if scriptManager.isRunning(script: script) {
                    let stopItem = NSMenuItem(title: "Stop \(title)", action: #selector(stopThisScript(_:)), keyEquivalent: "")
                    stopItem.target = self
                    stopItem.representedObject = script
                    stopItem.image = symbol("stop.fill")
                    menu.addItem(stopItem)
                }
                menu.addItem(item)
            }
            if !scripts.isEmpty { menu.addItem(.separator()) }
        }

        // Verwaltung
        let selectFolderItem = NSMenuItem(title: "Skripte-Ordner…", action: #selector(selectScriptsFolder(_:)), keyEquivalent: "")
        selectFolderItem.target = self
        selectFolderItem.image = symbol("folder")
        menu.addItem(selectFolderItem)

        let clearFolderItem = NSMenuItem(title: "Skripte-Ordner entfernen", action: #selector(clearScriptsFolder(_:)), keyEquivalent: "")
        clearFolderItem.target = self
        clearFolderItem.image = symbol("folder.badge.minus")
        menu.addItem(clearFolderItem)

        let addFilesItem = NSMenuItem(title: "Skripte hinzufügen (.py)…", action: #selector(addScriptFiles(_:)), keyEquivalent: "")
        addFilesItem.target = self
        addFilesItem.image = symbol("plus.square.on.square")
        menu.addItem(addFilesItem)

        // Entfernen einzelner hinzugefügter Skripte
        let added = scriptManager.additionalScripts()
        if !added.isEmpty {
            let manageMenu = NSMenu()
            for url in added.sorted(by: { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }) {
                let item = NSMenuItem(title: url.lastPathComponent, action: #selector(removeScript(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                item.image = symbol("trash")
                manageMenu.addItem(item)
            }
            let manageRoot = NSMenuItem(title: "Hinzugefügte Skripte entfernen", action: nil, keyEquivalent: "")
            manageRoot.submenu = manageMenu
            manageRoot.image = symbol("trash")
            menu.addItem(manageRoot)
        }

        // Interpreter-Untermenü
        let interpreterMenu = NSMenu()
        let known = scriptManager.discoverPythonInterpreters()
        let active = scriptManager.pythonInterpreterPath()
        for path in known {
            let title = (path as NSString).lastPathComponent + " — " + path
            let item = NSMenuItem(title: title, action: #selector(pickKnownInterpreter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = path
            item.state = (path == active) ? .on : .off
            interpreterMenu.addItem(item)
        }
        if known.isEmpty {
            interpreterMenu.addItem(NSMenuItem(title: "Keine Interpreter gefunden", action: nil, keyEquivalent: ""))
        }
        interpreterMenu.addItem(.separator())
        let customItem = NSMenuItem(title: "Eigenen Interpreter wählen…", action: #selector(selectPythonInterpreter(_:)), keyEquivalent: "")
        customItem.target = self
        interpreterMenu.addItem(customItem)

        let interpreterRoot = NSMenuItem(title: "Python-Interpreter", action: nil, keyEquivalent: "")
        interpreterRoot.submenu = interpreterMenu
        interpreterRoot.image = symbol("gearshape")
        menu.addItem(interpreterRoot)

        // Laufende Prozesse
        let running = scriptManager.runningScriptURLs()
        let runningRoot = NSMenuItem(title: "Laufende Skripte", action: nil, keyEquivalent: "")
        runningRoot.image = symbol("waveform")
        let runningMenu = NSMenu()
        if running.isEmpty {
            runningMenu.addItem(NSMenuItem(title: "Keine laufenden Skripte", action: nil, keyEquivalent: ""))
        } else {
            for url in running {
                let item = NSMenuItem(title: url.lastPathComponent, action: #selector(stopThisScript(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                item.image = symbol("stop.fill")
                runningMenu.addItem(item)
            }
            runningMenu.addItem(.separator())
            let stopAll = NSMenuItem(title: "Alle stoppen", action: #selector(stopAllRunning(_:)), keyEquivalent: "")
            stopAll.target = self
            stopAll.image = symbol("stop.circle")
            runningMenu.addItem(stopAll)
        }
        runningRoot.submenu = runningMenu
        menu.addItem(runningRoot)

        let refreshItem = NSMenuItem(title: "Aktualisieren", action: #selector(refreshScripts(_:)), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = symbol("arrow.clockwise")
        menu.addItem(refreshItem)

        // Unterer Bereich: Einstellungen, About, Beenden
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Einstellungen…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = symbol("gear")
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "Über MenuPy", action: #selector(showAbout(_:)), keyEquivalent: "i")
        aboutItem.keyEquivalentModifierMask = [.command]
        aboutItem.target = self
        aboutItem.image = symbol("info.circle")
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        quitItem.image = symbol("power")
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateStatusBadge()
    }
}
