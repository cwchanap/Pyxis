import CoreGraphics

enum CountryMapScoutCardTextLayout {
    struct FooterItem: Equatable {
        let label: String
        let showsIcon: Bool
    }

    static func wrapIntoTwoLines(
        _ text: String,
        maximumWidth: CGFloat,
        measure: (String) -> CGFloat
    ) -> [String]? {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        guard words.allSatisfy({ measure($0) <= maximumWidth }) else { return nil }

        var lines = [String]()
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if measure(candidate) <= maximumWidth {
                current = candidate
            } else {
                lines.append(current)
                current = word
            }
        }
        lines.append(current)
        return lines.count <= 2 ? lines : nil
    }

    static func fittedFontSize(
        _ text: String,
        startingAt start: CGFloat,
        minimum: CGFloat,
        maximumWidth: CGFloat,
        measure: (String, CGFloat) -> CGFloat
    ) -> CGFloat? {
        var size = floor(start)
        while size >= minimum {
            if measure(text, size) <= maximumWidth {
                return size
            }
            size -= 1
        }
        return nil
    }

    static func footerGroupRequiredWidth(
        prefix: String,
        items: [FooterItem],
        iconWidth: CGFloat,
        prefixGap: CGFloat,
        iconLabelGap: CGFloat,
        itemGap: CGFloat,
        labelWidth: (String) -> CGFloat
    ) -> CGFloat {
        guard !items.isEmpty else { return labelWidth(prefix) }

        let itemsWidth = items.enumerated().reduce(CGFloat.zero) { total, item in
            let itemWidth = labelWidth(item.element.label)
                + (item.element.showsIcon ? iconWidth + iconLabelGap : 0)
            return total + itemWidth + (item.offset == 0 ? 0 : itemGap)
        }
        return labelWidth(prefix) + prefixGap + itemsWidth
    }
}
