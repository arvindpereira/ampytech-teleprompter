import Foundation
import SwiftData

@Model
final class Script {
    var title: String = ""
    var body: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(title: String = "", body: String = "") {
        self.title = title
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return firstLine.map { String($0.prefix(60)) } ?? String(localized: "Untitled Script")
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wordCount: Int { Self.wordCount(of: body) }

    /// Rough read time at a typical speaking pace of ~150 words per minute.
    var estimatedReadingTime: String { Self.readingTime(forWords: wordCount) }

    static func wordCount(of text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    static func readingTime(forWords words: Int, wordsPerMinute: Double = 150) -> String {
        let minutes = Double(words) / wordsPerMinute
        if minutes < 1 { return String(localized: "<1 min") }
        return String(localized: "~\(Int(minutes.rounded())) min")
    }
}

extension Script {
    static let sampleBody = """
    Welcome to Teleprompter.

    This is a sample script. Tap the play button and you'll get a 3-2-1 countdown before the text starts scrolling.

    Tap anywhere on the text to show or hide the controls. Drag the text with your finger to jump ahead or go back — scrolling picks up from wherever you let go.

    Use the speed slider to match your speaking pace, and the text-size buttons to make the words bigger or smaller.

    If you're using a beam-splitter glass rig, turn on mirroring so the text reads correctly in the reflection.

    Paired a Bluetooth keyboard or remote? Space starts and pauses, the up and down arrows change the speed, and the left and right arrows jump back and forward.

    When you're ready, delete this script and write your own. Good luck!
    """
}
