import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Teleprompter

struct ScriptImporterTests {
    @Test func plainTextNormalizesLineEndingsAndTrims() {
        let data = Data("  Line one\r\nLine two\rLine three\n\n".utf8)
        #expect(ScriptImporter.text(from: data, type: .plainText) == "Line one\nLine two\nLine three")
    }

    @Test func utf16TextIsDecoded() {
        let data = "Héllo wörld".data(using: .utf16)!
        #expect(ScriptImporter.text(from: data, type: .plainText) == "Héllo wörld")
    }

    @Test func rtfIsConvertedToPlainText() {
        let rtf = #"{\rtf1\ansi{\fonttbl\f0\fswiss Helvetica;}\f0\pard Hello {\b World}\par}"#
        #expect(ScriptImporter.text(from: Data(rtf.utf8), type: .rtf) == "Hello World")
    }

    @Test func importUsesFileNameAsTitle() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("My Speech.txt")
        try "Four score and seven years ago".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try ScriptImporter.importScript(from: url)
        #expect(result.title == "My Speech")
        #expect(result.body == "Four score and seven years ago")
    }
}
