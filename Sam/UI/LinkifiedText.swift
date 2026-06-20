import SwiftUI

enum LinkifiedTextHelper {
    static func attributedString(from text: String, baseColor: Color, linkColor: Color) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = baseColor

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }

        let fullRange = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, options: [], range: fullRange) {
            guard let range = Range(match.range, in: text),
                  let url = match.url,
                  let attrRange = Range(range, in: attributed) else { continue }
            attributed[attrRange].link = url
            attributed[attrRange].foregroundColor = linkColor
            attributed[attrRange].underlineStyle = .single
        }

        return attributed
    }
}

/// Plain-Text mit automatisch erkannten, klickbaren URLs.
struct LinkifiedText: View {
    let text: String
    var baseColor: Color = .primary
    var linkColor: Color = SamDesign.accent
    var font: Font = .system(size: 14)

    var body: some View {
        Text(LinkifiedTextHelper.attributedString(from: text, baseColor: baseColor, linkColor: linkColor))
            .font(font)
            .lineSpacing(2)
            .textSelection(.enabled)
    }
}
