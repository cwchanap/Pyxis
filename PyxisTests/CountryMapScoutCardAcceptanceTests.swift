import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct CountryMapScoutCardAcceptanceTests {
    @Test
    func harnessCleanupRemovesItsPersistentDomainAfterUse() throws {
        let fixture = try #require(CountryMapLayoutTestFixtures.supported.first)
        var retainedDefaults: UserDefaults?
        var suiteName: String?

        try withHarness(
            state: KingdomGameState(),
            fixture: fixture
        ) { harness in
            retainedDefaults = harness.defaults
            suiteName = harness.suiteName
            let persistedDomain = harness.defaults.persistentDomain(
                forName: harness.suiteName
            )
            #expect(persistedDomain?["state"] != nil)
        }

        let savedDefaults = try #require(retainedDefaults)
        let savedSuiteName = try #require(suiteName)
        #expect(
            savedDefaults.persistentDomain(forName: savedSuiteName) == nil
        )
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func everySupportedFixtureCoversTheCompleteScoutFlow(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        try withHarness(
            state: KingdomGameState(),
            fixture: fixture
        ) { fresh in
            let freshLayout = try #require(
                fresh.scene.countryMapLayoutForTesting
            )
            let freshScout = try projectedScout(from: fresh.scene)
            let freshBase = try #require(
                fresh.scene.scoutCardBaseContentForTesting
            )
            let cardFrame = try #require(
                fresh.scene.scoutCardHitFrameForTesting
            )
            let attackFrame = try #require(
                fresh.scene.scoutCardAttackHitFrameForTesting
            )

            #expect(freshScout.cityNumber == 1)
            assertRequiredScoutContent(
                freshBase,
                scout: freshScout,
                layoutClass: fixture.layoutClass,
                usesGoldFallback: false
            )
            #expect(freshLayout.informationRegionFrame.contains(cardFrame))
            #expect(freshLayout.informationRegionFrame.contains(attackFrame))
            for cityNumber in Country1CityCatalog.cityRange {
                let cityFrame = try #require(
                    fresh.scene.cityHitFrameForTesting(cityNumber)
                )
                #expect(!cardFrame.intersects(cityFrame))
            }
            #expect(
                fresh.scene.visibleScoutCardTextsForTesting
                    == expectedVisibleLabelTexts(from: freshBase)
            )

            let projectedBeforeRelayout =
                fresh.scene.projectedScoutCardContentForTesting
            let baseBeforeRelayout =
                fresh.scene.scoutCardBaseContentForTesting
            let labelsBeforeRelayout =
                fresh.scene.visibleScoutCardTextsForTesting
            fresh.scene.didChangeSize(fresh.scene.size)
            #expect(
                fresh.scene.projectedScoutCardContentForTesting
                    == projectedBeforeRelayout
            )
            #expect(
                fresh.scene.scoutCardBaseContentForTesting
                    == baseBeforeRelayout
            )
            #expect(
                fresh.scene.visibleScoutCardTextsForTesting
                    == labelsBeforeRelayout
            )
            #expect(fresh.scene.scoutCardAttackHitFrameForTesting != nil)
            #expect(!fresh.scene.isRoutingToBattleForTesting)
        }

        let pendingState = KingdomGameState(
            cityLevel: 4,
            cityRemainingPower: 0,
            cityNumberInCountry: 4,
            completedCityCount: 4,
            stageStatus: .cityConqueredPendingMap
        )
        try withHarness(state: pendingState, fixture: fixture) { pending in
            let pendingScout = try projectedScout(from: pending.scene)
            let pendingBase = try #require(
                pending.scene.scoutCardBaseContentForTesting
            )
            #expect(pendingScout.cityNumber == 5)
            assertRequiredScoutContent(
                pendingBase,
                scout: pendingScout,
                layoutClass: fixture.layoutClass,
                usesGoldFallback: false
            )
            #expect(
                pending.scene.visibleScoutCardTextsForTesting
                    == expectedVisibleLabelTexts(from: pendingBase)
            )
        }

        let entryState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        try withHarness(state: entryState, fixture: fixture) { attackEntry in
            let attackTarget = try #require(
                attackEntry.scene.scoutCardAttackHitFrameForTesting
            )
            attackEntry.scene.touchesEnded(
                [MockTouch(location: attackTarget.center)],
                with: nil
            )
            #expect(attackEntry.store.load().cityNumberInCountry == 2)
            #expect(attackEntry.router.battleRequestCount == 1)
        }

        try withHarness(state: entryState, fixture: fixture) { nodeEntry in
            let unlockedCityPoint = try #require(
                nodeEntry.scene.cityNodePositionForTesting(2)
            )
            nodeEntry.scene.touchesEnded(
                [MockTouch(location: unlockedCityPoint)],
                with: nil
            )
            #expect(nodeEntry.store.load().cityNumberInCountry == 2)
            #expect(nodeEntry.router.battleRequestCount == 1)
        }

        let feedbackState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        )
        try withHarness(state: feedbackState, fixture: fixture) { feedback in
            let feedbackBase = try #require(
                feedback.scene.scoutCardBaseContentForTesting
            )
            let lockedPoint = try #require(
                feedback.scene.cityNodePositionForTesting(4)
            )
            feedback.scene.touchesEnded(
                [MockTouch(location: lockedPoint)],
                with: nil
            )
            #expect(
                feedback.scene.visibleFeedbackTextForTesting
                    == "Bramblegate is locked"
            )
            assertSameRequiredStrings(
                feedback.scene.scoutCardBaseContentForTesting,
                feedbackBase
            )

            feedback.scene.advanceFeedbackForTesting(by: 1.5)
            let completedPoint = try #require(
                feedback.scene.cityNodePositionForTesting(2)
            )
            feedback.scene.touchesEnded(
                [MockTouch(location: completedPoint)],
                with: nil
            )
            #expect(
                feedback.scene.visibleFeedbackTextForTesting
                    == "Pinewatch complete"
            )
            assertSameRequiredStrings(
                feedback.scene.scoutCardBaseContentForTesting,
                feedbackBase
            )
        }

        let completeState = KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )
        try withHarness(state: completeState, fixture: fixture) { complete in
            let completeBase = try #require(
                complete.scene.scoutCardBaseContentForTesting
            )
            #expect(completeBase.title == "Country 1 conquered · Crownspire Keep")
            #expect(completeBase.attack == nil)
            #expect(complete.scene.scoutCardAttackHitFrameForTesting == nil)
            #expect(
                complete.scene.visibleScoutCardTextsForTesting
                    == ["Country 1 conquered · Crownspire Keep"]
            )
        }
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func everyCatalogDefinitionRendersItsActualDenseContent(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        var exposedLanes = Set<BattleLane>()

        for definition in Country1CityCatalog.definitions {
            let state = KingdomGameState(
                cityLevel: definition.cityNumber,
                cityRemainingPower: KingdomGameState.cityMaxPower(
                    for: definition.cityNumber
                ),
                cityNumberInCountry: definition.cityNumber,
                completedCityCount: definition.cityNumber - 1,
                stageStatus: .battleActive
            )
            try withHarness(state: state, fixture: fixture) { harness in
                let scout = try projectedScout(from: harness.scene)
                let base = try #require(
                    harness.scene.scoutCardBaseContentForTesting
                )

                #expect(scout.cityNumber == definition.cityNumber)
                #expect(scout.defenseTrait == definition.defenseTrait)
                #expect(
                    scout.defenseTrait.favorableSoldierTypes
                        == definition.defenseTrait.favorableSoldierTypes
                )
                #expect(
                    scout.defenseTrait.disadvantagedSoldierTypes
                        == definition.defenseTrait.disadvantagedSoldierTypes
                )
                #expect(
                    scout.exposedLane
                        == definition.laneDefenseProfile.exposedLane
                )
                exposedLanes.insert(scout.exposedLane)
                assertRequiredScoutContent(
                    base,
                    scout: scout,
                    layoutClass: fixture.layoutClass,
                    usesGoldFallback: false
                )
                #expect(
                    harness.scene.visibleScoutCardTextsForTesting
                        == expectedVisibleLabelTexts(from: base)
                )
            }
        }

        #expect(exposedLanes == Set(BattleLane.allCases))
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func missingAssetMatrixRetainsEveryRequiredString(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let image = testImage()
        let soldierNames = Set(SoldierType.allCases.map {
            "\($0.rawValue)-walk-01"
        })
        let completeImages = Dictionary(
            uniqueKeysWithValues:
                [("country-map-backdrop", image), ("gold-burst", image)]
                + soldierNames.map { ($0, image) }
        )
        let scenarios = [
            AssetScenario(missingNames: []),
            AssetScenario(missingNames: ["gold-burst"]),
            AssetScenario(missingNames: ["\(SoldierType.archer.rawValue)-walk-01"]),
            AssetScenario(missingNames: soldierNames)
        ]
        let definition = Country1CityCatalog.definition(for: 7)
        let state = KingdomGameState(
            cityLevel: definition.cityNumber,
            cityRemainingPower: KingdomGameState.cityMaxPower(
                for: definition.cityNumber
            ),
            cityNumberInCountry: definition.cityNumber,
            completedCityCount: definition.cityNumber - 1,
            stageStatus: .battleActive
        )

        for scenario in scenarios {
            try withHarness(
                state: state,
                fixture: fixture,
                imageLoader: { name in
                    scenario.missingNames.contains(name)
                        ? nil
                        : completeImages[name]
                },
                body: { harness in
                    let scout = try projectedScout(from: harness.scene)
                    let base = try #require(
                        harness.scene.scoutCardBaseContentForTesting
                    )

                    #expect(!harness.scene.isMapUnavailableForTesting)
                    assertRequiredScoutContent(
                        base,
                        scout: scout,
                        layoutClass: fixture.layoutClass,
                        usesGoldFallback:
                            scenario.missingNames.contains("gold-burst")
                    )
                    #expect(
                        harness.scene.visibleScoutCardTextsForTesting
                            == expectedVisibleLabelTexts(from: base)
                    )
                }
            )
        }
    }

    private final class SceneHarness {
        let scene: CountryMapScene
        let store: KingdomGameStore
        let router: RouteSpy
        let defaults: UserDefaults
        let suiteName: String

        init(
            scene: CountryMapScene,
            store: KingdomGameStore,
            router: RouteSpy,
            defaults: UserDefaults,
            suiteName: String
        ) {
            self.scene = scene
            self.store = store
            self.router = router
            self.defaults = defaults
            self.suiteName = suiteName
        }

        func tearDown() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private struct AssetScenario {
        let missingNames: Set<String>
    }

    private final class RouteSpy: CountryMapSceneRouting {
        private(set) var battleRequestCount = 0

        func countryMapSceneDidRequestBattle(
            _ scene: CountryMapScene
        ) -> Bool {
            battleRequestCount += 1
            return true
        }

        func countryMapScene(
            _ scene: CountryMapScene,
            didRequestLayoutGate reason: AppLayoutGateReason
        ) {}
    }

    private final class MockTouch: UITouch {
        private let point: CGPoint

        init(location: CGPoint) {
            self.point = location
            super.init()
        }

        override func location(in view: UIView?) -> CGPoint {
            point
        }
    }

    private func makeHarness(
        state: KingdomGameState,
        fixture: CountryMapLayoutTestFixture,
        imageLoader: ((String) -> UIImage?)? = nil
    ) throws -> SceneHarness {
        let suiteName = "PyxisTests.Acceptance.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(state)
        let router = RouteSpy()
        let scene = CountryMapScene(
            size: fixture.size,
            store: store,
            router: router,
            layoutEnvironmentOverride: .init(
                safeAreaInsets: fixture.insets,
                layoutClass: fixture.layoutClass
            ),
            imageLoaderOverride: imageLoader
        )
        let view = SKView(
            frame: CGRect(origin: .zero, size: fixture.size)
        )
        scene.didMove(to: view)
        return SceneHarness(
            scene: scene,
            store: store,
            router: router,
            defaults: defaults,
            suiteName: suiteName
        )
    }

    private func withHarness<Result>(
        state: KingdomGameState,
        fixture: CountryMapLayoutTestFixture,
        imageLoader: ((String) -> UIImage?)? = nil,
        body: (SceneHarness) throws -> Result
    ) throws -> Result {
        let harness = try makeHarness(
            state: state,
            fixture: fixture,
            imageLoader: imageLoader
        )
        defer { harness.tearDown() }
        return try body(harness)
    }

    private func projectedScout(
        from scene: CountryMapScene
    ) throws -> CountryMapScoutCardContent.Scout {
        guard case .scout(let scout) =
                scene.projectedScoutCardContentForTesting else {
            Issue.record("Expected projected Scout content")
            throw AcceptanceError.missingScout
        }
        return scout
    }

    private func assertRequiredScoutContent(
        _ base: CountryMapScoutCardNode.BaseContentReadback,
        scout: CountryMapScoutCardContent.Scout,
        layoutClass: CountryMapLayoutClass,
        usesGoldFallback: Bool
    ) {
        let traitText =
            "\(scout.defenseTrait.displayName) · "
            + scout.defenseTrait.shortDescription
        let favorable = expectedFooterText(
            prefix: "+",
            types: scout.defenseTrait.favorableSoldierTypes,
            layoutClass: layoutClass
        )
        let disadvantaged = expectedFooterText(
            prefix: "-",
            types: scout.defenseTrait.disadvantagedSoldierTypes,
            layoutClass: layoutClass
        )
        let reward = usesGoldFallback
            ? "Gold \(scout.goldReward)"
            : "\(scout.goldReward)"

        #expect(base.badge == "\(scout.cityNumber)")
        #expect(base.title == scout.displayTitle)
        #expect(base.traitLines.joined(separator: " ") == traitText)
        #expect(base.favorable == favorable)
        #expect(base.disadvantaged == disadvantaged)
        #expect(base.lane == "Open: \(scout.exposedLane.displayName)")
        #expect(base.reward == reward)
        #expect(base.attack == "Attack")

        let requiredStrings =
            [base.badge, base.title, base.favorable, base.disadvantaged,
             base.lane, base.reward, base.attack]
            .compactMap { $0 }
            + base.traitLines
        #expect(!requiredStrings.isEmpty)
        #expect(requiredStrings.allSatisfy { !$0.isEmpty })
    }

    private func assertSameRequiredStrings(
        _ current: CountryMapScoutCardNode.BaseContentReadback?,
        _ expected: CountryMapScoutCardNode.BaseContentReadback
    ) {
        #expect(current?.badge == expected.badge)
        #expect(current?.title == expected.title)
        #expect(current?.traitLines == expected.traitLines)
        #expect(current?.favorable == expected.favorable)
        #expect(current?.disadvantaged == expected.disadvantaged)
        #expect(current?.lane == expected.lane)
        #expect(current?.reward == expected.reward)
        #expect(current?.attack == expected.attack)
    }

    private func expectedFooterText(
        prefix: String,
        types: [SoldierType],
        layoutClass: CountryMapLayoutClass
    ) -> String {
        let names = types.isEmpty
            ? ["None"]
            : types.map {
                layoutClass == .phone
                    ? compactName(for: $0)
                    : $0.displayName
            }
        return ([prefix] + names).joined(separator: " ")
    }

    private func compactName(for type: SoldierType) -> String {
        switch type {
        case .infantry: return "Inf"
        case .archer: return "Arc"
        case .cavalry: return "Cav"
        case .mage: return "Mag"
        case .siege: return "Sie"
        }
    }

    private func expectedVisibleLabelTexts(
        from base: CountryMapScoutCardNode.BaseContentReadback
    ) -> [String] {
        var values = [base.badge, base.title]
            .compactMap { $0 }
        values += base.traitLines
        values += base.favorable?.split(separator: " ").map(String.init) ?? []
        values += base.disadvantaged?.split(separator: " ").map(String.init) ?? []
        values += [base.lane, base.reward, base.attack].compactMap { $0 }
        return values.sorted()
    }

    private func testImage() -> UIImage {
        UIGraphicsImageRenderer(
            size: CGSize(width: 128, height: 128)
        ).image { context in
            UIColor.white.setFill()
            context.fill(
                CGRect(x: 0, y: 0, width: 128, height: 128)
            )
        }
    }

    private enum AcceptanceError: Error {
        case missingScout
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
