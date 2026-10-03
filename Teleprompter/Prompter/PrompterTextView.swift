import SwiftUI
import UIKit

/// The scrolling script text. Backed by a TextKit 1 UITextView so long scripts lay out exactly
/// (TextKit 2 estimates heights lazily, which makes auto-scroll and progress jumpy).
struct PrompterTextView: UIViewRepresentable {
    let text: String
    let settings: PrompterSettings
    let controller: PrompterController
    var onTap: () -> Void

    func makeUIView(context: Context) -> PrompterContainerView {
        let view = PrompterContainerView()
        view.textView.delegate = context.coordinator
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        )
        view.onScrollGeometryChange = { [weak controller] in controller?.syncFromScrollView() }
        controller.scrollView = view.textView
        return view
    }

    func updateUIView(_ view: PrompterContainerView, context: Context) {
        context.coordinator.parent = self
        view.apply(text: text, settings: settings)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PrompterTextView

        init(parent: PrompterTextView) {
            self.parent = parent
        }

        @objc func handleTap() {
            parent.onTap()
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.controller.userInteractionBegan()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { parent.controller.userInteractionEnded() }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            parent.controller.userInteractionEnded()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if parent.controller.isUserInteracting {
                parent.controller.syncFromScrollView()
            }
        }
    }
}

/// Hosts the text view and applies mirroring as a UIKit transform so touch handling stays correct.
final class PrompterContainerView: UIView {
    let textView = UITextView(usingTextLayoutManager: false)
    var onScrollGeometryChange: (() -> Void)?

    private struct TextStyle: Equatable {
        var text: String
        var font: PrompterFont
        var fontSize: Double
        var isBold: Bool
        var lineSpacing: Double
        var alignment: PrompterAlignment
        var theme: PrompterTheme
    }

    private struct Geometry: Equatable {
        var mirrorHorizontal = false
        var mirrorVertical = false
        var readingPosition: CGFloat = 0.3
        var horizontalMargin: CGFloat = 0.06
    }

    private var style: TextStyle?
    private var geometry = Geometry()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true

        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.contentInsetAdjustmentBehavior = .never
        textView.alwaysBounceVertical = true
        textView.scrollsToTop = false
        textView.textContainer.lineFragmentPadding = 0
        textView.layoutManager.allowsNonContiguousLayout = false
        addSubview(textView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(text: String, settings: PrompterSettings) {
        let newStyle = TextStyle(
            text: text,
            font: settings.font,
            fontSize: settings.fontSize,
            isBold: settings.isBold,
            lineSpacing: settings.lineSpacing,
            alignment: settings.alignment,
            theme: settings.theme
        )
        let newGeometry = Geometry(
            mirrorHorizontal: settings.mirrorHorizontal,
            mirrorVertical: settings.mirrorVertical,
            readingPosition: settings.readingGuidePosition,
            horizontalMargin: settings.horizontalMargin
        )
        guard newStyle != style || newGeometry != geometry else { return }

        backgroundColor = settings.theme.backgroundColor
        preservingScrollPosition {
            if newStyle != style {
                textView.attributedText = Self.attributedText(text, settings: settings)
                style = newStyle
            }
            geometry = newGeometry
            layoutTextView()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if textView.bounds.size != bounds.size {
            preservingScrollPosition { layoutTextView() }
        }
    }

    private func layoutTextView() {
        // Don't touch bounds.origin: for a scroll view that *is* the content offset.
        textView.bounds = CGRect(origin: textView.bounds.origin, size: bounds.size)
        textView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        textView.transform = CGAffineTransform(
            scaleX: geometry.mirrorHorizontal ? -1 : 1,
            y: geometry.mirrorVertical ? -1 : 1
        )

        // Top inset puts the first line at the reading line; bottom inset lets the last line reach it.
        let top = (bounds.height * geometry.readingPosition).rounded()
        let insets = UIEdgeInsets(top: top, left: 0, bottom: max(0, bounds.height - top), right: 0)
        if textView.contentInset != insets { textView.contentInset = insets }

        let side = (bounds.width * geometry.horizontalMargin).rounded()
        let containerInsets = UIEdgeInsets(top: 0, left: side, bottom: 0, right: side)
        if textView.textContainerInset != containerInsets { textView.textContainerInset = containerInsets }
    }

    /// Keeps the reader at the same relative spot in the script across re-layouts
    /// (font size changes, rotation, margin tweaks).
    private func preservingScrollPosition(_ changes: () -> Void) {
        let fraction = textView.prompterScrollFraction
        changes()
        guard bounds.width > 0, bounds.height > 0 else { return }
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        textView.layoutIfNeeded()
        let minY = textView.prompterMinOffset
        let maxY = textView.prompterMaxOffset
        textView.contentOffset = CGPoint(x: 0, y: minY + fraction * (maxY - minY))
        onScrollGeometryChange?()
    }

    static func attributedText(_ text: String, settings: PrompterSettings) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = settings.lineSpacing
        paragraph.alignment = settings.alignment.textAlignment
        paragraph.paragraphSpacing = settings.fontSize * 0.25
        return NSAttributedString(string: text, attributes: [
            .font: settings.uiFont,
            .foregroundColor: settings.theme.textColor,
            .paragraphStyle: paragraph,
        ])
    }
}
