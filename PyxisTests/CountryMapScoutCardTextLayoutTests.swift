import CoreGraphics
import Testing
import UIKit
@testable import Pyxis

struct CountryMapScoutCardTextLayoutTests {
    @Test func wrapperKeepsTextOnOneLineWhenEveryWordFits() {
        let result = CountryMapScoutCardTextLayout.wrapIntoTwoLines(
            "Scout card",
            maximumWidth: 10,
            measure: measuredCharacterCount
        )

        #expect(result == ["Scout card"])
    }

    @Test func wrapperMovesTheFirstNonFittingWordToTheSecondLine() {
        let result = CountryMapScoutCardTextLayout.wrapIntoTwoLines(
            "one two three",
            maximumWidth: 7,
            measure: measuredCharacterCount
        )

        #expect(result == ["one two", "three"])
    }

    @Test func wrapperRejectsAWordWiderThanTheAvailableSlot() {
        let result = CountryMapScoutCardTextLayout.wrapIntoTwoLines(
            "wide small",
            maximumWidth: 3,
            measure: measuredCharacterCount
        )

        #expect(result == nil)
    }

    @Test func wrapperRejectsCopyThatNeedsThreeLines() {
        let result = CountryMapScoutCardTextLayout.wrapIntoTwoLines(
            "one two three",
            maximumWidth: 3,
            measure: measuredCharacterCount
        )

        #expect(result == nil)
    }

    @Test func wrapperNeverSplitsAWordAtCharacterBoundaries() {
        let result = CountryMapScoutCardTextLayout.wrapIntoTwoLines(
            "Scout cards",
            maximumWidth: 5,
            measure: measuredCharacterCount
        )

        #expect(result == ["Scout", "cards"])
    }

    @Test func wrapperRejectsEmptyAndWhitespaceOnlyCopy() {
        #expect(CountryMapScoutCardTextLayout.wrapIntoTwoLines(
            "",
            maximumWidth: 10,
            measure: measuredCharacterCount
        ) == nil)
        #expect(CountryMapScoutCardTextLayout.wrapIntoTwoLines(
            " \n\t ",
            maximumWidth: 10,
            measure: measuredCharacterCount
        ) == nil)
    }

    @Test func fittedFontSizeKeepsTheStartingWholePointWhenItFits() {
        #expect(CountryMapScoutCardTextLayout.fittedFontSize(
            "Title",
            startingAt: 12,
            minimum: 8,
            maximumWidth: 60,
            measure: { _, size in size * 5 }
        ) == 12)
    }

    @Test func fittedFontSizeDecrementsOnlyInWholePoints() {
        var measuredSizes = [CGFloat]()

        let result = CountryMapScoutCardTextLayout.fittedFontSize(
            "Title",
            startingAt: 12.8,
            minimum: 8,
            maximumWidth: 50,
            measure: { _, size in
                measuredSizes.append(size)
                return size * 5
            }
        )

        #expect(result == 10)
        #expect(measuredSizes == [12, 11, 10])
    }

    @Test func fittedFontSizeReturnsEightWhenItIsTheFirstFittingSize() {
        #expect(CountryMapScoutCardTextLayout.fittedFontSize(
            "Title",
            startingAt: 12,
            minimum: 8,
            maximumWidth: 80,
            measure: { _, size in size * 10 }
        ) == 8)
    }

    @Test func fittedFontSizeRejectsTextThatStillOverflowsAtEight() {
        #expect(CountryMapScoutCardTextLayout.fittedFontSize(
            "Title",
            startingAt: 12,
            minimum: 8,
            maximumWidth: 79,
            measure: { _, size in size * 10 }
        ) == nil)
    }

    @Test func footerWidthIncludesEveryVisiblePartAndGap() {
        let items: [CountryMapScoutCardTextLayout.FooterItem] = [
            .init(label: "Inf", showsIcon: true),
            .init(label: "Arc", showsIcon: true)
        ]
        let width = CountryMapScoutCardTextLayout.footerGroupRequiredWidth(
            prefix: "+",
            items: items,
            iconWidth: 10,
            prefixGap: 2,
            iconLabelGap: 2,
            itemGap: 4,
            labelWidth: { label in
                switch label {
                case "+": 4
                case "Inf": 12
                default: 10
                }
            }
        )

        #expect(width == 56)
    }

    @Test func footerWidthTreatsIconFreeNoneAsAnOrdinaryLabel() {
        let items: [CountryMapScoutCardTextLayout.FooterItem] = [
            .init(label: "None", showsIcon: false)
        ]
        let width = CountryMapScoutCardTextLayout.footerGroupRequiredWidth(
            prefix: "-",
            items: items,
            iconWidth: 10,
            prefixGap: 2,
            iconLabelGap: 2,
            itemGap: 4,
            labelWidth: { label in label == "-" ? 4 : 11 }
        )

        #expect(width == 17)
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func everyTraitStringWrapsCompletelyInEverySupportedLayout(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let cardLayout = try scoutCardLayout(for: fixture)
        let traitWidth = cardLayout.traitLineFrames[0].width
        let fontSize: CGFloat = isPhoneLayout(fixture) ? 9 : 12
        let measure = try productionMeasure(fontName: GameUITheme.Font.medium, size: fontSize)

        for trait in CityDefenseTrait.allCases {
            let source = "\(trait.displayName) · \(trait.shortDescription)"
            let lines = CountryMapScoutCardTextLayout.wrapIntoTwoLines(
                source,
                maximumWidth: traitWidth,
                measure: measure
            )

            guard let wrapped = lines else {
                Issue.record("\(fixture.name): \(trait.displayName) must wrap")
                continue
            }
            #expect((1...2).contains(wrapped.count))
            #expect(wrapped.joined(separator: " ") == source)
            for line in wrapped {
                #expect(measure(line) <= traitWidth, "\(fixture.name): \(line) overflows")
            }
        }
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func everyMatchupAndLaneFitsInEverySupportedLayout(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let cardLayout = try scoutCardLayout(for: fixture)
        let isPhone = isPhoneLayout(fixture)
        let footerSize: CGFloat = isPhone ? 9 : 11
        let measure = try productionMeasure(fontName: GameUITheme.Font.medium, size: footerSize)

        for trait in CityDefenseTrait.allCases {
            let favorableWidth = footerRequiredWidth(
                for: trait.favorableSoldierTypes,
                prefix: "+",
                isPhone: isPhone,
                measure: measure
            )
            let disadvantagedWidth = footerRequiredWidth(
                for: trait.disadvantagedSoldierTypes,
                prefix: "-",
                isPhone: isPhone,
                measure: measure
            )

            #expect(favorableWidth <= cardLayout.favorableFrame.width, "\(fixture.name): \(trait.displayName) favorable overflow")
            #expect(disadvantagedWidth <= cardLayout.disadvantagedFrame.width, "\(fixture.name): \(trait.displayName) disadvantaged overflow")
        }

        for lane in BattleLane.allCases {
            #expect(measure("Open: \(lane.displayName)") <= cardLayout.exposedLaneFrame.width)
        }
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let cardLayout = try scoutCardLayout(for: fixture)
        let isPhone = isPhoneLayout(fixture)
        let titleSize: CGFloat = isPhone ? 11 : 16
        let rewardSize: CGFloat = isPhone ? 10 : 14
        let fallbackSize: CGFloat = isPhone ? 9 : 13
        let rewardMeasure = try productionMeasure(fontName: GameUITheme.Font.bold, size: rewardSize)
        let fallbackMeasure = try productionMeasure(fontName: GameUITheme.Font.bold, size: fallbackSize)
        let fallbackWidth = cardLayout.rewardFrame.maxX - cardLayout.goldIconFrame.minX

        for cityNumber in Country1CityCatalog.cityRange {
            let title = KingdomGameState().displayCityTitle(for: cityNumber)
            let reward = KingdomGameState.goldReward(for: cityNumber)

            #expect(CountryMapScoutCardTextLayout.fittedFontSize(
                title,
                startingAt: titleSize,
                minimum: 8,
                maximumWidth: cardLayout.titleFrame.width,
                measure: { text, size in
                    (try? width(text, fontName: GameUITheme.Font.bold, size: size))
                        ?? .greatestFiniteMagnitude
                }
            ) == titleSize)
            #expect(rewardMeasure("\(reward)") <= cardLayout.rewardFrame.width)
            #expect(fallbackMeasure("Gold \(reward)") <= fallbackWidth)
            #expect(try width(title, fontName: GameUITheme.Font.bold, size: titleSize)
                <= cardLayout.titleFrame.width)
        }
    }

    @Test func syntheticFooterTitleAndRewardOverflowFailValidation() throws {
        let fixture = try #require(CountryMapLayoutTestFixtures.supported.first { $0.name == "small phone" })
        let cardLayout = try scoutCardLayout(for: fixture)
        let footerMeasure = try productionMeasure(fontName: GameUITheme.Font.medium, size: 9)
        let rewardMeasure = try productionMeasure(fontName: GameUITheme.Font.bold, size: 10)
        let overflowItems: [CountryMapScoutCardTextLayout.FooterItem] = [
            .init(label: "UnreasonablyLongSoldierName", showsIcon: true)
        ]
        let footerWidth = CountryMapScoutCardTextLayout.footerGroupRequiredWidth(
            prefix: "+",
            items: overflowItems,
            iconWidth: 10,
            prefixGap: 2,
            iconLabelGap: 2,
            itemGap: 4,
            labelWidth: footerMeasure
        )

        #expect(footerWidth > cardLayout.favorableFrame.width)
        #expect(CountryMapScoutCardTextLayout.fittedFontSize(
            "An exceptionally long future city title that cannot fit",
            startingAt: 11,
            minimum: 8,
            maximumWidth: cardLayout.titleFrame.width,
            measure: { text, size in
                (try? width(text, fontName: GameUITheme.Font.bold, size: size))
                    ?? .greatestFiniteMagnitude
            }
        ) == nil)
        #expect(rewardMeasure("123456789") > cardLayout.rewardFrame.width)
    }
}

private func measuredCharacterCount(_ text: String) -> CGFloat {
    CGFloat(text.count)
}

private func scoutCardLayout(
    for fixture: CountryMapLayoutTestFixture
) throws -> CountryMapScoutCardLayout {
    let result = CountryMapLayout.compute(.init(
        sceneSize: fixture.size,
        environment: .init(safeAreaInsets: fixture.insets, layoutClass: fixture.layoutClass),
        definition: .country1
    ))
    guard case .supported(let outerLayout) = result else {
        Issue.record("Expected supported outer layout for \(fixture.name)")
        throw CountryMapScoutCardTextLayoutTestError.unsupportedFixture
    }
    return CountryMapScoutCardLayout.compute(
        in: outerLayout.informationRegionFrame,
        layoutClass: fixture.layoutClass
    )
}

private func footerRequiredWidth(
    for soldierTypes: [SoldierType],
    prefix: String,
    isPhone: Bool,
    measure: (String) -> CGFloat
) -> CGFloat {
    let items: [CountryMapScoutCardTextLayout.FooterItem] = soldierTypes.isEmpty
        ? [.init(label: "None", showsIcon: false)]
        : soldierTypes.map {
            .init(label: isPhone ? abbreviation(for: $0) : $0.displayName, showsIcon: true)
        }
    return CountryMapScoutCardTextLayout.footerGroupRequiredWidth(
        prefix: prefix,
        items: items,
        iconWidth: isPhone ? 10 : 14,
        prefixGap: isPhone ? 2 : 4,
        iconLabelGap: isPhone ? 2 : 4,
        itemGap: isPhone ? 4 : 8,
        labelWidth: { label in
            isPhone || label == "None" ? measure(label) : 52
        }
    )
}

private func abbreviation(for soldierType: SoldierType) -> String {
    switch soldierType {
    case .infantry: return "Inf"
    case .archer: return "Arc"
    case .cavalry: return "Cav"
    case .mage: return "Mag"
    case .siege: return "Sie"
    }
}

private func isPhoneLayout(_ fixture: CountryMapLayoutTestFixture) -> Bool {
    if case .phone = fixture.layoutClass {
        return true
    }
    return false
}

private func productionMeasure(
    fontName: String,
    size: CGFloat
) throws -> (String) -> CGFloat {
    let font = try #require(UIFont(name: fontName, size: size))
    return { text in
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

private func width(_ text: String, fontName: String, size: CGFloat) throws -> CGFloat {
    let font = try #require(UIFont(name: fontName, size: size))
    return ceil((text as NSString).size(withAttributes: [.font: font]).width)
}

private enum CountryMapScoutCardTextLayoutTestError: Error {
    case unsupportedFixture
}
