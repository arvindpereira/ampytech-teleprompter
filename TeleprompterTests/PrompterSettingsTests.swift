import Foundation
import Testing
@testable import Teleprompter

struct PrompterSettingsTests {
    @Test func roundTripsThroughJSON() throws {
        var settings = PrompterSettings()
        settings.font = .georgia
        settings.fontSize = 72
        settings.mirrorHorizontal = true
        settings.countdownSeconds = 5

        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(PrompterSettings.self, from: data) == settings)
    }

    @Test func missingAndUnknownValuesFallBackToDefaults() throws {
        let json = #"{"fontSize": 90, "font": "comicSans", "mirrorHorizontal": true}"#
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(json.utf8))

        #expect(settings.fontSize == 90)
        #expect(settings.mirrorHorizontal)
        #expect(settings.font == PrompterSettings().font)
        #expect(settings.scrollSpeed == PrompterSettings().scrollSpeed)
    }

    @Test func adjustmentsAreClamped() {
        var settings = PrompterSettings()
        settings.fontSize = PrompterSettings.fontSizeRange.upperBound
        settings.adjustFontSize(by: 10)
        #expect(settings.fontSize == PrompterSettings.fontSizeRange.upperBound)

        settings.scrollSpeed = PrompterSettings.speedRange.lowerBound
        settings.adjustSpeed(by: -50)
        #expect(settings.scrollSpeed == PrompterSettings.speedRange.lowerBound)
    }

    @Test func storePersistsChanges() {
        let defaults = UserDefaults(suiteName: "PrompterSettingsTests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.settings.fontSize = 100
        store.settings.theme = .yellowOnBlack

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.settings.fontSize == 100)
        #expect(reloaded.settings.theme == .yellowOnBlack)
    }

    @Test func everyFontResolves() {
        for font in PrompterFont.allCases {
            #expect(font.uiFont(size: 40, bold: true).pointSize == 40)
        }
    }
}
