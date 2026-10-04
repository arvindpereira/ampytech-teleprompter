import SwiftUI
import SwiftData

struct ScriptListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Script.updatedAt, order: .reverse) private var scripts: [Script]

    @AppStorage("didSeedSampleScript") private var didSeedSampleScript = false
    @State private var path: [Script] = []
    @State private var searchText = ""
    @State private var prompting: Script?
    @State private var showImporter = false
    @State private var showSettings = false
    @State private var importError: String?

    private var filteredScripts: [Script] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return scripts }
        return scripts.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(filteredScripts) { script in
                    NavigationLink(value: script) {
                        ScriptRow(script: script)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            prompting = script
                        } label: {
                            Label("Prompt", systemImage: "play.fill")
                        }
                        .tint(.accentColor)
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if scripts.isEmpty {
                    ContentUnavailableView {
                        Label("No Scripts", systemImage: "text.alignleft")
                    } description: {
                        Text("Write a new script or import a text file to get started.")
                    } actions: {
                        Button("New Script", action: newScript)
                            .buttonStyle(.borderedProminent)
                    }
                } else if filteredScripts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search scripts")
            .navigationTitle("Scripts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: newScript) {
                            Label("New Script", systemImage: "square.and.pencil")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import from Files…", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Label("Add Script", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: Script.self) { script in
                ScriptEditorView(script: script)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: ScriptImporter.supportedTypes,
            allowsMultipleSelection: true,
            onCompletion: importFiles
        )
        .fullScreenCover(item: $prompting) { script in
            PrompterView(script: script)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .alert(
            "Import Failed",
            isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .task {
            seedSampleScriptIfNeeded()
        }
    }

    private func newScript() {
        let script = Script()
        modelContext.insert(script)
        path.append(script)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredScripts[index])
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var failures: [String] = []
            for url in urls {
                do {
                    let imported = try ScriptImporter.importScript(from: url)
                    modelContext.insert(Script(title: imported.title, body: imported.body))
                } catch {
                    failures.append(error.localizedDescription)
                }
            }
            if !failures.isEmpty { importError = failures.joined(separator: "\n") }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func seedSampleScriptIfNeeded() {
        guard !didSeedSampleScript else { return }
        didSeedSampleScript = true
        if scripts.isEmpty {
            modelContext.insert(Script(title: String(localized: "Getting Started"), body: Script.sampleBody))
        }
    }
}

private struct ScriptRow: View {
    let script: Script

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(script.displayTitle)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text("\(script.wordCount) words")
                Text("·")
                Text(script.estimatedReadingTime)
                Spacer()
                Text(script.updatedAt, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let store = SettingsStore()
    ScriptListView()
        .environment(store)
        .environment(RemoteControlService(settingsStore: store, activateSession: false))
        .modelContainer(for: Script.self, inMemory: true)
}
