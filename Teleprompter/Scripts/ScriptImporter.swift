import Foundation
import UniformTypeIdentifiers

enum ScriptImporter {
    static let supportedTypes: [UTType] = [.plainText, .rtf]

    enum ImportError: LocalizedError {
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name):
                String(localized: "\"\(name)\" couldn't be read as text.")
            }
        }
    }

    /// Reads a script from a file picked via the document picker.
    static func importScript(from url: URL) throws -> (title: String, body: String) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let title = url.deletingPathExtension().lastPathComponent
        let type = UTType(filenameExtension: url.pathExtension)
        guard let body = text(from: data, type: type) else {
            throw ImportError.unreadable(url.lastPathComponent)
        }
        return (title, body)
    }

    static func text(from data: Data, type: UTType?) -> String? {
        let raw: String?
        if let type, type.conforms(to: .rtf) {
            raw = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ).string
        } else {
            raw = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .windowsCP1252)
        }
        return raw.map(normalize)
    }

    static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
