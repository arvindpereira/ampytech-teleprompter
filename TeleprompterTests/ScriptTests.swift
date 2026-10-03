import Testing
@testable import Teleprompter

struct ScriptTests {
    @Test func displayTitleFallsBackToFirstLine() {
        #expect(Script(title: "  ", body: "\n  Opening line\nSecond").displayTitle == "Opening line")
        #expect(Script(title: "Keynote", body: "Hello").displayTitle == "Keynote")
    }

    @Test func wordCountAndReadingTime() {
        #expect(Script.wordCount(of: "one two\nthree\t four") == 4)
        #expect(Script.readingTime(forWords: 10) == "<1 min")
        #expect(Script.readingTime(forWords: 450) == "~3 min")
    }
}
