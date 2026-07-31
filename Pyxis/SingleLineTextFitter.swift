import CoreGraphics

enum SingleLineTextFitter {
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
}
