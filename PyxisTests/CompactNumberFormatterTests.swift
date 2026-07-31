import Testing
@testable import Pyxis

struct CompactNumberFormatterTests {
    @Test(arguments: [
        (0, "0"),
        (42, "42"),
        (999, "999"),
        (1_000, "1K"),
        (1_100, "1.1K"),
        (1_500, "1.5K"),
        (10_000, "10K"),
        (12_000, "12K"),
        (150_000, "150K"),
        (500_000, "500K"),
        (999_000, "999K"),
        (999_400, "999K"),
        (994_999, "995K"),
        (999_950, "1M"),
        (1_000_000, "1M"),
        (1_500_000, "1.5M"),
        (2_500_000, "2.5M"),
        (15_000_000, "15M"),
        (999_500_000, "1B"),
        (1_000_000_000, "1B"),
        (3_200_000_000, "3.2B"),
        (999_500_000_000, "1T"),
        (1_000_000_000_000, "1T"),
        (-1_500, "-1.5K"),
        (-1_000_000, "-1M")
    ])
    func formatsExistingBattleContract(value: Int, expected: String) {
        #expect(CompactNumberFormatter.string(from: value) == expected)
    }
}
