import SwiftUI

struct CorrectionEditorView: View {
    let title: String
    let originalText: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var correctedText: String

    init(
        title: String,
        originalText: String,
        correctedText: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.originalText = originalText
        self.onCancel = onCancel
        self.onSave = onSave
        _correctedText = State(initialValue: correctedText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Original")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(originalText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                }
                .frame(minHeight: 110)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Corrected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $correctedText)
                    .font(.body)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }

                Button("Save & Learn") {
                    onSave(correctedText)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
    }

    private var canSave: Bool {
        let corrected = correctedText.trimmedForLearning
        return !corrected.isEmpty && corrected != originalText.trimmedForLearning
    }
}
