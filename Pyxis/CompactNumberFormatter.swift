import Foundation

enum CompactNumberFormatter {
    static func string(from value: Int) -> String {
        let magnitude = value.magnitude
        let sign = value < 0 ? "-" : ""
        let units: [(threshold: UInt, suffix: String)] = [
            (1_000_000_000_000, "T"),
            (1_000_000_000, "B"),
            (1_000_000, "M"),
            (1_000, "K")
        ]
        guard let index = units.firstIndex(where: { magnitude >= $0.threshold }) else {
            return String(value)
        }
        let unit = units[index]
        let scaled = Double(magnitude) / Double(unit.threshold)
        let roundedTenths = (scaled * 10).rounded() / 10
        if roundedTenths.rounded() >= 1_000, index > 0 {
            let promoted = units[index - 1]
            return formatted(
                Double(magnitude) / Double(promoted.threshold),
                sign: sign,
                suffix: promoted.suffix
            )
        }
        return formatted(roundedTenths, sign: sign, suffix: unit.suffix, alreadyRounded: true)
    }

    private static func formatted(
        _ value: Double,
        sign: String,
        suffix: String,
        alreadyRounded: Bool = false
    ) -> String {
        let rounded = alreadyRounded ? value : (value * 10).rounded() / 10
        let body = rounded >= 10 || rounded.rounded() == rounded
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
        return "\(sign)\(body)\(suffix)"
    }
}
