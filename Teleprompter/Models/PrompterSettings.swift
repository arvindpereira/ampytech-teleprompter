import UIKit

enum PrompterFont: String, Codable, CaseIterable, Identifiable {
    case system
    case rounded
    case serif
    case monospaced
    case helveticaNeue
    case avenirNext
    case georgia
    case timesNewRoman
    case verdana
    case courierNew

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "San Francisco"
        case .rounded: "SF Rounded"
        case .serif: "New York"
        case .monospaced: "SF Mono"
        case .helveticaNeue: "Helvetica Neue"
        case .avenirNext: "Avenir Next"
        case .georgia: "Georgia"
        case .timesNewRoman: "Times New Roman"
        case .verdana: "Verdana"
        case .courierNew: "Courier New"
        }
    }

    private var familyName: String? {
        switch self {
        case .system, .rounded, .serif, .monospaced: nil
        case .helveticaNeue: "Helvetica Neue"
        case .avenirNext: "Avenir Next"
        case .georgia: "Georgia"
        case .timesNewRoman: "Times New Roman"
        case .verdana: "Verdana"
        case .courierNew: "Courier New"
        }
    }

    func uiFont(size: CGFloat, bold: Bool) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        let descriptor: UIFontDescriptor?
        switch self {
        case .system:
            return base
        case .rounded:
            descriptor = base.fontDescriptor.withDesign(.rounded)
        case .serif:
            descriptor = base.fontDescriptor.withDesign(.serif)
        case .monospaced:
            descriptor = base.fontDescriptor.withDesign(.monospaced)
        default:
            let family = UIFontDescriptor(fontAttributes: [.family: familyName ?? ""])
            descriptor = bold ? (family.withSymbolicTraits(.traitBold) ?? family) : family
        }
        guard let descriptor else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

enum PrompterTheme: String, Codable, CaseIterable, Identifiable {
    case whiteOnBlack
    case yellowOnBlack
    case greenOnBlack
    case blackOnWhite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whiteOnBlack: String(localized: "White on Black")
        case .yellowOnBlack: String(localized: "Yellow on Black")
        case .greenOnBlack: String(localized: "Green on Black")
        case .blackOnWhite: String(localized: "Black on White")
        }
    }

    var textColor: UIColor {
        switch self {
        case .whiteOnBlack: .white
        case .yellowOnBlack: UIColor(red: 1, green: 0.86, blue: 0.2, alpha: 1)
        case .greenOnBlack: UIColor(red: 0.35, green: 1, blue: 0.45, alpha: 1)
        case .blackOnWhite: .black
        }
    }

    var backgroundColor: UIColor {
        self == .blackOnWhite ? .white : .black
    }
}

enum PrompterAlignment: String, Codable, CaseIterable, Identifiable {
    case leading
    case center

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leading: String(localized: "Left")
        case .center: String(localized: "Center")
        }
    }

    var textAlignment: NSTextAlignment {
        switch self {
        case .leading: .natural
        case .center: .center
        }
    }
}

struct PrompterSettings: Codable, Equatable {
    var font: PrompterFont = .system
    var fontSize: Double = 48
    var isBold = true
    /// Line height as a multiple of the font's natural line height.
    var lineSpacing: Double = 1.3
    var alignment: PrompterAlignment = .leading
    /// Left/right margin as a fraction of the screen width.
    var horizontalMargin: Double = 0.06
    var theme: PrompterTheme = .whiteOnBlack
    /// Scroll speed in points per second.
    var scrollSpeed: Double = 60
    var countdownSeconds: Int = 3
    var mirrorHorizontal = false
    var mirrorVertical = false
    var showReadingGuide = true
    /// Vertical position of the reading line as a fraction of screen height.
    var readingGuidePosition: Double = 0.3

    static let fontSizeRange: ClosedRange<Double> = 20...160
    static let fontSizeStep: Double = 4
    static let speedRange: ClosedRange<Double> = 10...400
    static let speedStep: Double = 10
    static let lineSpacingRange: ClosedRange<Double> = 1.0...2.5
    static let marginRange: ClosedRange<Double> = 0...0.25
    static let readingGuideRange: ClosedRange<Double> = 0.1...0.7
    static let countdownOptions = [0, 3, 5, 10]

    init() {}

    // Decode field-by-field so settings saved by an older app version (missing keys,
    // or a since-removed enum case) fall back to defaults instead of being discarded.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PrompterSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        font = value(.font, d.font)
        fontSize = value(.fontSize, d.fontSize)
        isBold = value(.isBold, d.isBold)
        lineSpacing = value(.lineSpacing, d.lineSpacing)
        alignment = value(.alignment, d.alignment)
        horizontalMargin = value(.horizontalMargin, d.horizontalMargin)
        theme = value(.theme, d.theme)
        scrollSpeed = value(.scrollSpeed, d.scrollSpeed)
        countdownSeconds = value(.countdownSeconds, d.countdownSeconds)
        mirrorHorizontal = value(.mirrorHorizontal, d.mirrorHorizontal)
        mirrorVertical = value(.mirrorVertical, d.mirrorVertical)
        showReadingGuide = value(.showReadingGuide, d.showReadingGuide)
        readingGuidePosition = value(.readingGuidePosition, d.readingGuidePosition)
    }

    var uiFont: UIFont { font.uiFont(size: fontSize, bold: isBold) }

    mutating func adjustFontSize(by delta: Double) {
        fontSize = (fontSize + delta).clamped(to: Self.fontSizeRange)
    }

    mutating func adjustSpeed(by delta: Double) {
        scrollSpeed = (scrollSpeed + delta).clamped(to: Self.speedRange)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
