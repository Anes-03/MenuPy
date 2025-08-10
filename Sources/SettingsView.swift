import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var availableSymbols: [String] = [
        "terminal", "play.fill", "gearshape", "folder", "bolt.fill", "hammer.fill",
        "chevron.right", "pencil", "doc.text", "paperplane.fill", "wand.and.stars"
    ]
    @State private var selectedSymbol: String = ""
    @State private var customSymbolName: String = ""
    @State private var customIconPreview: NSImage? = nil
    @State private var showBadge: Bool = true

    private let scriptManager = ScriptManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Menüleisten-Icon").font(.headline)

            HStack(spacing: 16) {
                // Vorschau
                ZStack {
                    Color(NSColor.windowBackgroundColor)
                    IconPreviewView(symbolName: effectiveSymbolName, image: customIconPreview)
                }
                .frame(width: 64, height: 64)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Bilddatei wählen…") { chooseFileIcon() }
                        Button("SF‑Symbol setzen") { saveSymbolSelection() }
                        Button("Standard") { resetIcon() }
                    }
                    Picker("Empfohlene SF‑Symbole", selection: $selectedSymbol) {
                        ForEach(availableSymbols, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    HStack {
                        Text("SF‑Symbolname")
                        TextField("terminal", text: $customSymbolName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                        Button("Übernehmen") { applyCustomSymbolName() }
                    }
                }
            }

            Toggle("Badge mit Anzahl laufender Skripte anzeigen", isOn: $showBadge)
                .onChange(of: showBadge) { newValue in
                    scriptManager.setStatusBadgeEnabled(newValue)
                }

            Spacer()
        }
        .padding(20)
        .onAppear {
            selectedSymbol = scriptManager.customStatusIconSymbolName() ?? "terminal"
            customSymbolName = selectedSymbol
            showBadge = scriptManager.isStatusBadgeEnabled()
            if let url = scriptManager.customStatusIconURL(), let img = NSImage(contentsOf: url) {
                customIconPreview = img
            }
        }
    }

    private var effectiveSymbolName: String {
        // Vorschau nutzt Bild, falls gesetzt, sonst das im UI selektierte Symbol
        if customIconPreview != nil { return "" }
        return customSymbolName.isEmpty ? selectedSymbol : customSymbolName
    }

    private func chooseFileIcon() {
        let panel = NSOpenPanel()
        panel.title = "Menüleisten-Icon wählen"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .pdf]
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            customIconPreview = img
            scriptManager.saveCustomStatusIcon(url)
        }
    }

    private func saveSymbolSelection() {
        scriptManager.saveCustomStatusIconSymbolName(selectedSymbol)
        customSymbolName = selectedSymbol
        customIconPreview = nil // Symbolmodus, keine Bildvorschau
    }

    private func applyCustomSymbolName() {
        let name = customSymbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        scriptManager.saveCustomStatusIconSymbolName(name)
        customIconPreview = nil
    }

    private func resetIcon() {
        scriptManager.clearCustomStatusIcon()
        scriptManager.clearCustomStatusIconSymbolName()
        customIconPreview = nil
        selectedSymbol = "terminal"
        customSymbolName = "terminal"
    }
}

private struct IconPreviewView: NSViewRepresentable {
    let symbolName: String
    let image: NSImage?

    func makeNSView(context: Context) -> NSImageView {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.contentTintColor = .labelColor
        return iv
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if let image = image {
            nsView.image = image
            nsView.contentTintColor = nil
        } else if #available(macOS 11.0, *), !symbolName.isEmpty, let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            nsView.image = symbol
            nsView.contentTintColor = .labelColor
        } else {
            nsView.image = nil
        }
    }
}
