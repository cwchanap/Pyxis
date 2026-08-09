import CoreGraphics
import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct CountryMapScoutCardNodeTests {
    @Test func phoneScoutRendersEveryRequiredPieceOfModelInformation() throws {
        let spy = ScoutCardImageLoaderSpy(images: completeImageSet())
        let node = CountryMapScoutCardNode(imageLoader: spy.load)
        let layout = try scoutCardLayout(named: "small phone")
        let scout = CountryMapScoutCardContent.Scout(
            cityNumber: 3,
            displayTitle: "City 3 · Falconridge",
            defenseTrait: .arrowTower,
            exposedLane: .center,
            goldReward: 27,
            flavorText: "Arrow towers command the high ridge road."
        )

        #expect(node.apply(content: .scout(scout), layout: layout, isEntryEnabled: true) == .presented)
        #expect(node.badgeTextForTesting == "3")
        #expect(node.titleTextForTesting == "City 3 · Falconridge")
        #expect(node.traitLineTextsForTesting.joined(separator: " ")
            == "Arrow Tower · Durable and fast melee troops perform better.")
        #expect(node.favorableTextForTesting == "+ Inf Cav")
        #expect(node.disadvantagedTextForTesting == "- Arc Mag")
        #expect(node.laneTextForTesting == "Open: Center")
        #expect(node.rewardTextForTesting == "27")
        #expect(node.attackTextForTesting == "Attack")
        #expect(node.cardHitFrame == layout.cardFrame)
        #expect(node.attackHitFrame == layout.attackFrame)
        #expect(node.overlayHitFrame == nil)
    }

    @Test func countryCompleteCentersExactCopyAndHasNoAttackTarget() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")

        #expect(node.apply(
            content: .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep"),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.titleTextForTesting == "Country 1 conquered · Crownspire Keep")
        #expect(node.countryCompleteTitleFrameForTesting == layout.cardFrame)
        #expect(node.cardHitFrame == layout.cardFrame)
        #expect(node.attackHitFrame == nil)
        #expect(node.attackTextForTesting == nil)
    }

    @Test func phoneUsesFixedCompactSoldierNamesAndPadUsesFullNames() throws {
        let phoneNode = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let padNode = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let phoneLayout = try scoutCardLayout(named: "small phone")
        let padLayout = try scoutCardLayout(named: "narrow iPad")
        var phoneNames = [SoldierType: String]()
        var padNames = [SoldierType: String]()

        for trait in CityDefenseTrait.allCases {
            let scout = testScout(trait: trait)
            #expect(phoneNode.apply(
                content: .scout(scout),
                layout: phoneLayout,
                isEntryEnabled: true
            ) == .presented)
            #expect(padNode.apply(
                content: .scout(scout),
                layout: padLayout,
                isEntryEnabled: true
            ) == .presented)

            for item in phoneNode.favorableItemsForTesting + phoneNode.disadvantagedItemsForTesting {
                if let type = item.type {
                    phoneNames[type] = item.label
                }
            }
            for item in padNode.favorableItemsForTesting + padNode.disadvantagedItemsForTesting {
                if let type = item.type {
                    padNames[type] = item.label
                }
            }
        }

        #expect(phoneNames == [
            .infantry: "Inf",
            .archer: "Arc",
            .cavalry: "Cav",
            .mage: "Mag",
            .siege: "Sie"
        ])
        #expect(padNames == Dictionary(uniqueKeysWithValues: SoldierType.allCases.map {
            ($0, $0.displayName)
        }))
    }

    @Test func emptyMatchupsRenderLiteralNoneWithoutRequestingSoldierIcons() throws {
        let spy = ScoutCardImageLoaderSpy(images: ["gold-burst": testImage()])
        let node = CountryMapScoutCardNode(imageLoader: spy.load)
        let layout = try scoutCardLayout(named: "small phone")

        #expect(node.apply(
            content: .scout(testScout(trait: .standardWatch)),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.favorableTextForTesting == "+ None")
        #expect(node.disadvantagedTextForTesting == "- None")
        let favorableNone = try #require(node.favorableItemsForTesting.first)
        let disadvantagedNone = try #require(node.disadvantagedItemsForTesting.first)
        #expect(node.favorableItemsForTesting.count == 1)
        #expect(node.disadvantagedItemsForTesting.count == 1)
        #expect(favorableNone.label == "None")
        #expect(disadvantagedNone.label == "None")
        #expect(favorableNone.labelIsInstalled)
        #expect(disadvantagedNone.labelIsInstalled)
        #expect(!favorableNone.iconIsInstalled)
        #expect(!disadvantagedNone.iconIsInstalled)
        #expect(favorableNone.textureRect == nil)
        #expect(disadvantagedNone.textureRect == nil)
        #expect(node.favorablePrefixTextForTesting == "+")
        #expect(node.disadvantagedPrefixTextForTesting == "-")
        #expect(node.favorablePrefixIsInstalledForTesting)
        #expect(node.disadvantagedPrefixIsInstalledForTesting)
        #expect(spy.requestedNames == ["gold-burst"])
    }

    @Test func installedGoldUsesSeparateIconAndNumericRewardFrames() throws {
        let spy = ScoutCardImageLoaderSpy(images: ["gold-burst": testImage(width: 40, height: 20)])
        let node = CountryMapScoutCardNode(imageLoader: spy.load)
        let layout = try scoutCardLayout(named: "small phone")

        #expect(node.apply(
            content: .scout(testScout(goldReward: 81)),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.goldIconIsVisibleForTesting)
        #expect(node.goldIconTargetFrameForTesting == layout.goldIconFrame)
        #expect(node.rewardTargetFrameForTesting == layout.rewardFrame)
        #expect(node.rewardTextForTesting == "81")
        #expect(node.rewardFontSizeForTesting == 10)
        #expect(node.goldIconSizeForTesting == CGSize(width: 12, height: 6))

        let padLayout = try scoutCardLayout(named: "narrow iPad")
        #expect(node.apply(
            content: .scout(testScout(goldReward: 81)),
            layout: padLayout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.rewardTextForTesting == "81")
        #expect(node.rewardFontSizeForTesting == 14)
        #expect(node.fontsForTesting?.reward == 14)
    }

    @Test func missingGoldUsesExactFallbackCopyInUnionFrame() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let phoneLayout = try scoutCardLayout(named: "small phone")
        let padLayout = try scoutCardLayout(named: "narrow iPad")

        #expect(node.apply(
            content: .scout(testScout(goldReward: 81)),
            layout: phoneLayout,
            isEntryEnabled: true
        ) == .presented)
        #expect(!node.goldIconIsVisibleForTesting)
        #expect(node.rewardTextForTesting == "Gold 81")
        #expect(node.rewardTargetFrameForTesting
            == phoneLayout.goldIconFrame.union(phoneLayout.rewardFrame))
        #expect(node.rewardFontSizeForTesting == 9)

        #expect(node.apply(
            content: .scout(testScout(goldReward: 81)),
            layout: padLayout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.rewardTextForTesting == "Gold 81")
        #expect(node.rewardFontSizeForTesting == 13)
    }

    @Test func soldierIconsUseExactWalkFramesBodyCropsAndAspectFit() throws {
        let image = testImage(width: 128, height: 128)
        let images = Dictionary(uniqueKeysWithValues: SoldierType.allCases.map {
            ("\($0.rawValue)-walk-01", image)
        }).merging(["gold-burst": image]) { left, _ in left }
        let spy = ScoutCardImageLoaderSpy(images: images)
        let node = CountryMapScoutCardNode(imageLoader: spy.load)
        let layout = try scoutCardLayout(named: "narrow iPad")
        var readbacks = [SoldierType: CountryMapScoutCardNode.FooterItemReadback]()

        for trait in CityDefenseTrait.allCases {
            #expect(node.apply(
                content: .scout(testScout(trait: trait)),
                layout: layout,
                isEntryEnabled: true
            ) == .presented)
            for item in node.favorableItemsForTesting + node.disadvantagedItemsForTesting {
                if let type = item.type {
                    readbacks[type] = item
                }
            }
        }

        for type in SoldierType.allCases {
            let item = try #require(readbacks[type])
            let expectedName = "\(type.rawValue)-walk-01"
            let expectedRect = SoldierAnimationGeometry(type: type).bodyRegion
            let bodySize = CGSize(width: 128 * expectedRect.width, height: 128 * expectedRect.height)
            let scale = min(14 / bodySize.width, 14 / bodySize.height)

            #expect(item.requestedImageName == expectedName)
            #expect(item.textureRect == expectedRect)
            #expect(abs(item.iconSize.width - bodySize.width * scale) < 0.001)
            #expect(abs(item.iconSize.height - bodySize.height * scale) < 0.001)
            #expect(item.targetFrame.size == CGSize(width: 14, height: 14))
            #expect(item.labelIsInstalled)
            #expect(item.iconIsInstalled)
            #expect(item.labelFontName == GameUITheme.Font.medium)
            #expect(item.labelFontSize == 11)
            #expect(spy.requestedNames.contains(expectedName))
        }
        let allowedNames = Set(["gold-burst"] + SoldierType.allCases.map {
            "\($0.rawValue)-walk-01"
        })
        #expect(Set(spy.requestedNames).isSubset(of: allowedNames))
    }

    @Test func missingSoldierImageKeepsTextAndRecomputesWidthWithoutIcon() throws {
        let spy = ScoutCardImageLoaderSpy(images: ["gold-burst": testImage()])
        let node = CountryMapScoutCardNode(imageLoader: spy.load)
        let layout = try scoutCardLayout(named: "small phone")

        #expect(node.apply(
            content: .scout(testScout(trait: .arrowTower)),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.favorableTextForTesting == "+ Inf Cav")
        #expect(node.disadvantagedTextForTesting == "- Arc Mag")
        #expect(node.favorableItemsForTesting.allSatisfy { $0.textureRect == nil && $0.iconSize == .zero })
        #expect(node.disadvantagedItemsForTesting.allSatisfy { $0.textureRect == nil && $0.iconSize == .zero })
        #expect(node.favorableItemsForTesting.allSatisfy { $0.labelIsInstalled && !$0.iconIsInstalled })
        #expect(node.disadvantagedItemsForTesting.allSatisfy { $0.labelIsInstalled && !$0.iconIsInstalled })
    }

    @Test func missingIconsReduceFooterWidthAtTheBoundaryWithoutHidingText() throws {
        let layout = try scoutCardLayout(named: "small phone")
        let boundaryLayout = replacing(
            layout,
            favorableFrame: CGRect(
                x: layout.favorableFrame.minX,
                y: layout.favorableFrame.minY,
                width: 50,
                height: layout.favorableFrame.height
            )
        )
        let installedNode = CountryMapScoutCardNode(imageLoader: {
            completeImageSet()[$0]
        })
        let missingNode = CountryMapScoutCardNode(imageLoader: { name in
            name == "gold-burst" ? testImage() : nil
        })

        #expect(installedNode.apply(
            content: .scout(testScout(trait: .arrowTower)),
            layout: boundaryLayout,
            isEntryEnabled: true
        ) == .requiredContentDoesNotFit)
        #expect(missingNode.apply(
            content: .scout(testScout(trait: .arrowTower)),
            layout: boundaryLayout,
            isEntryEnabled: true
        ) == .presented)
        #expect(missingNode.favorableTextForTesting == "+ Inf Cav")
        #expect(missingNode.favorableItemsForTesting.allSatisfy {
            $0.labelIsInstalled && !$0.iconIsInstalled
        })
    }

    @Test func disabledEntryPreservesCardConsumptionAndDimsOnlyAttack() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")

        #expect(node.apply(
            content: .scout(testScout()),
            layout: layout,
            isEntryEnabled: false
        ) == .presented)
        #expect(node.cardHitFrame == layout.cardFrame)
        #expect(node.attackHitFrame == nil)
        #expect(abs(node.attackAlphaForTesting - GameUITheme.Alpha.lockedIcon) < 0.001)
        #expect(node.baseContentAlphaForTesting == 1)
    }

    @Test func feedbackOverlaysUnchangedBaseContentAndRestoresEnabledAttack() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")
        #expect(node.apply(
            content: .scout(testScout()),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        let base = node.baseContentReadbackForTesting

        node.applyFeedback(text: "Falconridge is locked", alpha: 0.72, blocksAttack: true)

        #expect(node.baseContentReadbackForTesting == base)
        #expect(node.feedbackTextForTesting == "Falconridge is locked")
        #expect(abs(node.feedbackAlphaForTesting - 0.72) < 0.001)
        #expect(node.localZPositionsForTesting == .init(base: 0, content: 1, overlay: 2))
        #expect(node.zPosition == GameUITheme.Z.hud)
        #expect(node.overlayHitFrame == layout.overlayFrame)
        #expect(node.attackHitFrame == nil)

        node.applyFeedback(text: nil, alpha: 0, blocksAttack: true)

        #expect(node.feedbackTextForTesting == nil)
        #expect(node.overlayHitFrame == nil)
        #expect(node.attackHitFrame == layout.attackFrame)
        #expect(node.baseContentReadbackForTesting == base)
    }

    @Test func nonBlockingFlavorUsesNonBlockingOverlayAndPreservesAttackTarget() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")
        #expect(node.apply(
            content: .scout(testScout()),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        let base = node.baseContentReadbackForTesting

        node.applyFeedback(
            text: "Arrow towers command the high ridge road.",
            alpha: 1,
            blocksAttack: false
        )

        // Flavor overlays the informational area only and leaves Attack tappable.
        #expect(node.feedbackTextForTesting == "Arrow towers command the high ridge road.")
        #expect(abs(node.feedbackAlphaForTesting - 1) < 0.001)
        #expect(node.overlayHitFrame == layout.nonBlockingOverlayFrame)
        #expect(!layout.nonBlockingOverlayFrame.intersects(layout.attackFrame))
        #expect(node.attackHitFrame == layout.attackFrame)
        #expect(node.baseContentReadbackForTesting == base)

        // Clearing flavor restores the scout overlay to nil and keeps Attack live.
        node.applyFeedback(text: nil, alpha: 0, blocksAttack: false)
        #expect(node.feedbackTextForTesting == nil)
        #expect(node.overlayHitFrame == nil)
        #expect(node.attackHitFrame == layout.attackFrame)
    }

    @Test func nonBlockingFlavorOnPadAlsoPreservesAttackAcrossTheWiderGap() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "narrow iPad")
        #expect(node.apply(
            content: .scout(testScout()),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)

        node.applyFeedback(text: "Pad flavor copy.", alpha: 1, blocksAttack: false)

        #expect(node.overlayHitFrame == layout.nonBlockingOverlayFrame)
        #expect(!layout.nonBlockingOverlayFrame.intersects(layout.attackFrame))
        #expect(node.attackHitFrame == layout.attackFrame)
    }

    @Test func nonBlockingFlavorKeepsAttackNilWhenEntryIsDisabled() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")
        #expect(node.apply(
            content: .scout(testScout()),
            layout: layout,
            isEntryEnabled: false
        ) == .presented)

        node.applyFeedback(text: "Flavor while disabled.", alpha: 1, blocksAttack: false)

        #expect(node.overlayHitFrame == layout.nonBlockingOverlayFrame)
        #expect(node.attackHitFrame == nil)
    }

    @Test func everyFeedbackCopyFamilyFitsTheActualLabelOnMinimumPhoneAndPad() throws {
        let messages = [
            "Crownspire Keep is locked",
            "Crownspire Keep complete",
            "Country 1 conquered · Crownspire Keep",
            "Next: Crownspire Keep",
            "Buildings dealt 999999 idle damage.",
            "No building damage while away.",
            "Cannot enter city yet.",
            "The final keep rises above the capital."
        ]
        let fixtures = [
            (name: "small phone", startingSize: CGFloat(13)),
            (name: "narrow iPad", startingSize: CGFloat(16))
        ]

        for fixture in fixtures {
            let layout = try scoutCardLayout(named: fixture.name)
            let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
            #expect(node.apply(
                content: .scout(testScout()),
                layout: layout,
                isEntryEnabled: true
            ) == .presented)

            for message in messages {
                node.applyFeedback(text: message, alpha: 1, blocksAttack: true)
                let labelFrame = try #require(node.feedbackLabelFrameForTesting)

                #expect(node.feedbackTextForTesting == message)
                #expect(layout.overlayFrame.contains(labelFrame), "\(fixture.name): \(message)")
                #expect(node.feedbackLabelIsInstalledForTesting)
                #expect(node.feedbackLabelNumberOfLinesForTesting == 1)
                #expect(node.feedbackFontNameForTesting == GameUITheme.Font.bold)
                #expect(node.feedbackFontSizeForTesting >= 8)
                #expect(node.feedbackFontSizeForTesting <= fixture.startingSize)
            }
        }
    }

    @Test func failedApplyInvalidatesStaleAttackEligibilityBeforeFeedbackClears() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")
        #expect(node.apply(
            content: .scout(testScout()),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        let visibleBase = node.baseContentReadbackForTesting
        let invalidTitleLayout = replacing(
            layout,
            titleFrame: CGRect(
                x: layout.titleFrame.minX,
                y: layout.titleFrame.minY,
                width: 1,
                height: layout.titleFrame.height
            )
        )

        #expect(node.apply(
            content: .scout(testScout(displayTitle: "Replacement City")),
            layout: invalidTitleLayout,
            isEntryEnabled: true
        ) == .requiredContentDoesNotFit)
        node.applyFeedback(text: nil, alpha: 0, blocksAttack: true)

        #expect(node.baseContentReadbackForTesting == visibleBase)
        #expect(node.cardHitFrame == nil)
        #expect(node.attackHitFrame == nil)
        #expect(node.overlayHitFrame == nil)
    }

    @Test func feedbackClearNeverCreatesAttackForDisabledOrCountryCompleteContent() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")

        #expect(node.apply(
            content: .scout(testScout()),
            layout: layout,
            isEntryEnabled: false
        ) == .presented)
        node.applyFeedback(text: "Cannot enter city yet.", alpha: 1, blocksAttack: true)
        node.applyFeedback(text: nil, alpha: 0, blocksAttack: true)
        #expect(node.attackHitFrame == nil)

        #expect(node.apply(
            content: .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep"),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        node.applyFeedback(text: "Willowford complete", alpha: 1, blocksAttack: true)
        node.applyFeedback(text: nil, alpha: 0, blocksAttack: true)
        #expect(node.attackHitFrame == nil)
    }

    @Test func clearLayoutClearsAllConsumptionFrames() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")
        #expect(node.apply(
            content: .scout(testScout()),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        node.applyFeedback(text: "Transient", alpha: 1, blocksAttack: true)

        node.clearLayout()

        #expect(node.cardHitFrame == nil)
        #expect(node.attackHitFrame == nil)
        #expect(node.overlayHitFrame == nil)
    }

    @Test func phoneAndPadUseApprovedProductionFontsAndSizes() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let phoneLayout = try scoutCardLayout(named: "small phone")
        let padLayout = try scoutCardLayout(named: "narrow iPad")

        #expect(node.apply(
            content: .scout(testScout()),
            layout: phoneLayout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.fontsForTesting == .init(
            boldName: GameUITheme.Font.bold,
            mediumName: GameUITheme.Font.medium,
            title: 11,
            badge: 11,
            reward: 9,
            trait: 9,
            footer: 9,
            attack: 13,
            titleIsInstalled: true,
            badgeIsInstalled: true,
            rewardIsInstalled: true,
            traitIsInstalled: true,
            footerIsInstalled: true,
            attackIsInstalled: true
        ))

        #expect(node.apply(
            content: .scout(testScout()),
            layout: padLayout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.fontsForTesting == .init(
            boldName: GameUITheme.Font.bold,
            mediumName: GameUITheme.Font.medium,
            title: 16,
            badge: 16,
            reward: 13,
            trait: 12,
            footer: 11,
            attack: 16,
            titleIsInstalled: true,
            badgeIsInstalled: true,
            rewardIsInstalled: true,
            traitIsInstalled: true,
            footerIsInstalled: true,
            attackIsInstalled: true
        ))
    }

    @Test func wrappedTraitLinesUseIndependentTopThenBottomFixedSlots() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")

        #expect(node.apply(
            content: .scout(testScout(trait: .arcaneWard)),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.traitLineTextsForTesting.count == 2)
        #expect(node.traitLinePositionsForTesting
            == layout.traitLineFrames.map { CGPoint(x: $0.minX, y: $0.midY) })

        #expect(node.apply(
            content: .scout(testScout(trait: .arrowTower)),
            layout: layout,
            isEntryEnabled: true
        ) == .presented)
        #expect(node.traitLineTextsForTesting.count == 1)
        #expect(node.traitLinePositionsForTesting == [
            CGPoint(
                x: layout.traitLineFrames[0].minX,
                y: layout.traitLineFrames[0].midY
            )
        ])
    }

    @Test func invalidTraitTitleFooterAndRewardFitsFailWithoutPartialReplacement() throws {
        let goodLayout = try scoutCardLayout(named: "small phone")
        let image = testImage()
        let allImages = completeImageSet(image: image)
        let node = CountryMapScoutCardNode(imageLoader: { allImages[$0] })
        #expect(node.apply(
            content: .scout(testScout()),
            layout: goodLayout,
            isEntryEnabled: true
        ) == .presented)
        let original = node.baseContentReadbackForTesting

        var invalidLayouts = [CountryMapScoutCardLayout]()
        invalidLayouts.append(replacing(goodLayout, traitLineFrames: [
            CGRect(x: goodLayout.traitLineFrames[0].minX,
                   y: goodLayout.traitLineFrames[0].minY, width: 1, height: 24)
        ]))
        invalidLayouts.append(replacing(goodLayout, titleFrame: CGRect(
            x: goodLayout.titleFrame.minX, y: goodLayout.titleFrame.minY,
            width: 1, height: goodLayout.titleFrame.height
        )))
        invalidLayouts.append(replacing(goodLayout, favorableFrame: CGRect(
            x: goodLayout.favorableFrame.minX, y: goodLayout.favorableFrame.minY,
            width: 1, height: goodLayout.favorableFrame.height
        )))
        invalidLayouts.append(replacing(goodLayout, exposedLaneFrame: CGRect(
            x: goodLayout.exposedLaneFrame.minX, y: goodLayout.exposedLaneFrame.minY,
            width: 1, height: goodLayout.exposedLaneFrame.height
        )))
        invalidLayouts.append(replacing(goodLayout, rewardFrame: CGRect(
            x: goodLayout.rewardFrame.minX, y: goodLayout.rewardFrame.minY,
            width: 1, height: goodLayout.rewardFrame.height
        )))

        for invalidLayout in invalidLayouts {
            #expect(node.apply(
                content: .scout(testScout(displayTitle: "Replacement City", trait: .burningOil, goldReward: 999)),
                layout: invalidLayout,
                isEntryEnabled: true
            ) == .requiredContentDoesNotFit)
            #expect(node.baseContentReadbackForTesting == original)
            #expect(node.cardHitFrame == nil)
            #expect(node.attackHitFrame == nil)
            #expect(node.overlayHitFrame == nil)
        }
    }

    @Test func missingGoldFallbackRewardOverflowFailsValidation() throws {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        let layout = try scoutCardLayout(named: "small phone")
        let tinyGold = CGRect(
            x: layout.goldIconFrame.minX,
            y: layout.goldIconFrame.minY,
            width: 1,
            height: layout.goldIconFrame.height
        )
        let tinyReward = CGRect(
            x: tinyGold.maxX,
            y: layout.rewardFrame.minY,
            width: 1,
            height: layout.rewardFrame.height
        )

        #expect(node.apply(
            content: .scout(testScout(goldReward: 999)),
            layout: replacing(layout, goldIconFrame: tinyGold, rewardFrame: tinyReward),
            isEntryEnabled: true
        ) == .requiredContentDoesNotFit)
    }

    @Test func allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome() throws {
        let image = testImage()
        let presentImages = completeImageSet(image: image)
        var presentationCount = 0
        var seenTraits = Set<CityDefenseTrait>()
        var seenLanes = Set<BattleLane>()
        var seenRewards = Set<Int>()
        var seenFixtures = Set<String>()
        var seenImageOutcomes = Set<Bool>()

        for fixture in CountryMapLayoutTestFixtures.supported {
            let layout = try scoutCardLayout(for: fixture)
            seenFixtures.insert(fixture.name)
            for hasImages in [true, false] {
                let node = CountryMapScoutCardNode(imageLoader: { name in
                    hasImages ? presentImages[name] : nil
                })
                seenImageOutcomes.insert(hasImages)
                for trait in CityDefenseTrait.allCases {
                    seenTraits.insert(trait)
                    for lane in BattleLane.allCases {
                        seenLanes.insert(lane)
                        for cityNumber in Country1CityCatalog.cityRange {
                            let reward = KingdomGameState.goldReward(for: cityNumber)
                            seenRewards.insert(reward)
                            let scout = CountryMapScoutCardContent.Scout(
                                cityNumber: cityNumber,
                                displayTitle: Country1CityCatalog.definition(for: cityNumber).displayTitle,
                                defenseTrait: trait,
                                exposedLane: lane,
                                goldReward: reward,
                                flavorText: Country1CityCatalog.definition(for: cityNumber).flavorText
                            )
                            #expect(node.apply(
                                content: .scout(scout),
                                layout: layout,
                                isEntryEnabled: true
                            ) == .presented,
                            "\(fixture.name), \(trait), \(lane), city \(cityNumber), images \(hasImages)")
                            presentationCount += 1
                        }
                    }
                }
            }
        }

        #expect(seenTraits == Set(CityDefenseTrait.allCases))
        #expect(seenLanes == Set(BattleLane.allCases))
        #expect(seenRewards == Set(Country1CityCatalog.cityRange.map(KingdomGameState.goldReward(for:))))
        #expect(seenFixtures == Set(CountryMapLayoutTestFixtures.supported.map(\.name)))
        #expect(seenImageOutcomes == [true, false])
        #expect(presentationCount == 10 * 7 * 3 * 15 * 2)
    }
}

private final class ScoutCardImageLoaderSpy {
    let images: [String: UIImage]
    private(set) var requestedNames = [String]()

    init(images: [String: UIImage]) {
        self.images = images
    }

    func load(_ name: String) -> UIImage? {
        requestedNames.append(name)
        return images[name]
    }
}

private func testScout(
    cityNumber: Int = 3,
    displayTitle: String = "City 3 · Falconridge",
    trait: CityDefenseTrait = .arrowTower,
    lane: BattleLane = .left,
    goldReward: Int = 27
) -> CountryMapScoutCardContent.Scout {
    .init(
        cityNumber: cityNumber,
        displayTitle: displayTitle,
        defenseTrait: trait,
        exposedLane: lane,
        goldReward: goldReward,
        flavorText: Country1CityCatalog.definition(for: cityNumber).flavorText
    )
}

private func completeImageSet(image: UIImage = testImage()) -> [String: UIImage] {
    Dictionary(uniqueKeysWithValues:
        [("gold-burst", image)]
        + SoldierType.allCases.map { ("\($0.rawValue)-walk-01", image) }
    )
}

private func testImage(width: CGFloat = 128, height: CGFloat = 128) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private func scoutCardLayout(named fixtureName: String) throws -> CountryMapScoutCardLayout {
    let fixture = try #require(CountryMapLayoutTestFixtures.supported.first {
        $0.name == fixtureName
    })
    return try scoutCardLayout(for: fixture)
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
        throw CountryMapScoutCardNodeTestError.unsupportedFixture
    }
    return CountryMapScoutCardLayout.compute(
        in: outerLayout.informationRegionFrame,
        layoutClass: fixture.layoutClass
    )
}

private func replacing(
    _ layout: CountryMapScoutCardLayout,
    titleFrame: CGRect? = nil,
    goldIconFrame: CGRect? = nil,
    rewardFrame: CGRect? = nil,
    traitLineFrames: [CGRect]? = nil,
    favorableFrame: CGRect? = nil,
    exposedLaneFrame: CGRect? = nil
) -> CountryMapScoutCardLayout {
    .init(
        layoutClass: layout.layoutClass,
        cardFrame: layout.cardFrame,
        badgeFrame: layout.badgeFrame,
        titleFrame: titleFrame ?? layout.titleFrame,
        goldIconFrame: goldIconFrame ?? layout.goldIconFrame,
        rewardFrame: rewardFrame ?? layout.rewardFrame,
        traitLineFrames: traitLineFrames ?? layout.traitLineFrames,
        favorableFrame: favorableFrame ?? layout.favorableFrame,
        disadvantagedFrame: layout.disadvantagedFrame,
        exposedLaneFrame: exposedLaneFrame ?? layout.exposedLaneFrame,
        attackFrame: layout.attackFrame,
        overlayFrame: layout.overlayFrame,
        nonBlockingOverlayFrame: layout.nonBlockingOverlayFrame
    )
}

private enum CountryMapScoutCardNodeTestError: Error {
    case unsupportedFixture
}
