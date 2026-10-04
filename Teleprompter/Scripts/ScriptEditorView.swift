import SwiftUI
import SwiftData

struct ScriptEditorView: View {
    @Bindable var script: Script

    @Environment(\.modelContext) private var modelContext
    @State private var isPrompting = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, body }

    private var canPrompt: Bool {
        !script.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $script.title)
                .font(.title2.bold())
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .body }
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

            TextEditor(text: $script.body)
                .font(.body)
                .focused($focusedField, equals: .body)
                .scrollDismissesKeyboard(.interactively)
                .padding(.horizontal, 12)
                .overlay(alignment: .topLeading) {
                    if script.body.isEmpty {
                        Text("Type or paste your script here…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
        .navigationTitle(script.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    focusedField = nil
                    isPrompting = true
                } label: {
                    Label("Start Prompter", systemImage: "play.fill")
                }
                .disabled(!canPrompt)
            }
            ToolbarItem(placement: .status) {
                Text("\(script.wordCount) words · \(script.estimatedReadingTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .toolbar(.visible, for: .bottomBar)
        .onChange(of: script.title) { script.updatedAt = .now }
        .onChange(of: script.body) { script.updatedAt = .now }
        .onAppear {
            if script.isEmpty { focusedField = .title }
        }
        .onDisappear {
            // Don't leave blank drafts lying around when the user backs out of "New Script".
            if script.isEmpty && !isPrompting {
                modelContext.delete(script)
            }
        }
        .fullScreenCover(isPresented: $isPrompting) {
            PrompterView(script: script)
        }
    }
}
