//
//  Country1CityCatalogTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

@MainActor
struct Country1CityCatalogTests {
    @MainActor
    private struct ExpectedDefinition {
        let cityNumber: Int
        let name: String
        let flavorText: String
        let conquestTitle: String
        let defenseTrait: CityDefenseTrait
        let fortifiedLane: BattleLane
        let exposedLane: BattleLane
        let visualFamily: CityVisualFamily
        let siegeLayout: CitySiegeLayout?

        init(
            _ cityNumber: Int,
            name: String,
            flavorText: String,
            conquestTitle: String,
            _ defenseTrait: CityDefenseTrait,
            _ fortifiedLane: BattleLane,
            _ exposedLane: BattleLane,
            _ visualFamily: CityVisualFamily,
            siegeLayout: CitySiegeLayout? = nil
        ) {
            self.cityNumber = cityNumber
            self.name = name
            self.flavorText = flavorText
            self.conquestTitle = conquestTitle
            self.defenseTrait = defenseTrait
            self.fortifiedLane = fortifiedLane
            self.exposedLane = exposedLane
            self.visualFamily = visualFamily
            self.siegeLayout = siegeLayout
        }

        var definition: CityDefinition {
            CityDefinition(
                cityNumber: cityNumber,
                name: name,
                flavorText: flavorText,
                conquestTitle: conquestTitle,
                defenseTrait: defenseTrait,
                laneDefenseProfile: LaneDefenseProfile(
                    fortifiedLane: fortifiedLane,
                    exposedLane: exposedLane
                ),
                visualFamily: visualFamily,
                siegeLayout: siegeLayout
            )
        }
    }

    /// The authored Willowford tactical siege layout (HPA-477), shared by the
    /// fixture entry. City 1 has no Barracks and no Captain.
    private static let willowfordSiegeLayout = CitySiegeLayout(
        objectives: [
            .init(id: "willowford.keep", kind: .keep, durabilityWeight: 3, visualLane: .center, visualProgress: 1.0),
            .init(id: "willowford.gate", kind: .gate, durabilityWeight: 1, visualLane: .center, visualProgress: 0.76)
        ],
        routes: [
            .left: ["willowford.gate", "willowford.keep"],
            .center: ["willowford.gate", "willowford.keep"],
            .right: ["willowford.keep"]
        ],
        defaultLane: .center,
        defensiveFire: .init(sourceObjectiveID: "willowford.keep", coveredLanes: [.right])
    )

    /// The authored Falconridge tactical siege layout, shared by the
    /// fixture entry and the dedicated pin test.
    private static let falconridgeSiegeLayout = CitySiegeLayout(
        objectives: [
            .init(id: "falconridge.keep", kind: .keep, durabilityWeight: 3, visualLane: .center, visualProgress: 1.0),
            .init(
                id: "falconridge.arrow-tower",
                kind: .arrowTower,
                durabilityWeight: 4,
                visualLane: .left,
                visualProgress: 0.68
            ),
            .init(
                id: "falconridge.ridge-gate",
                kind: .gate,
                durabilityWeight: 1,
                visualLane: .center,
                visualProgress: 0.58
            )
        ],
        routes: [
            .left: ["falconridge.arrow-tower", "falconridge.keep"],
            .center: ["falconridge.ridge-gate", "falconridge.keep"],
            .right: ["falconridge.ridge-gate", "falconridge.keep"]
        ],
        defaultLane: .center,
        defensiveFire: .init(sourceObjectiveID: "falconridge.arrow-tower", coveredLanes: BattleLane.allCases)
    )

    /// The authored Highcrest tactical siege layout (HPA-469 Guard pilot),
    /// shared by the fixture entry and the dedicated pin test.
    private static let highcrestSiegeLayout = CitySiegeLayout(
        objectives: [
            .init(id: "highcrest.keep", kind: .keep, durabilityWeight: 20, visualLane: .center, visualProgress: 1.0),
            .init(id: "highcrest.barracks", kind: .barracks, durabilityWeight: 1, visualLane: .left, visualProgress: 0.72)
        ],
        routes: [
            .left: ["highcrest.barracks", "highcrest.keep"],
            .center: ["highcrest.keep"],
            .right: ["highcrest.keep"]
        ],
        defaultLane: .right,
        defensiveFire: .init(sourceObjectiveID: "highcrest.keep", coveredLanes: BattleLane.allCases)
    )

    private static let expectedDefinitions: [ExpectedDefinition] = [
        .init(
            1,
            name: "Willowford",
            flavorText: "A quiet crossing where the campaign begins.",
            conquestTitle: "Willowford Secured",
            .standardWatch,
            .left,
            .right,
            .frontier,
            siegeLayout: willowfordSiegeLayout
        ),
        .init(2, name: "Pinewatch", flavorText: "A hill watchtown guarding the old trade road.", conquestTitle: "Pinewatch Secured", .standardWatch, .center, .left, .frontier),
        .init(
            3,
            name: "Falconridge",
            flavorText: "Arrow towers command the high ridge road.",
            conquestTitle: "Falconridge Silenced",
            .arrowTower,
            .right,
            .left,
            .frontier,
            siegeLayout: falconridgeSiegeLayout
        ),
        .init(4, name: "Bramblegate", flavorText: "Iron spikes guard a narrow frontier gate.", conquestTitle: "Bramblegate Broken", .spikedGate, .left, .right, .frontier),
        .init(
            5,
            name: "Highcrest",
            flavorText: "A proud hill fortress crowns the frontier.",
            conquestTitle: "Highcrest Falls",
            .arrowTower,
            .center,
            .right,
            .frontier,
            siegeLayout: highcrestSiegeLayout
        ),
        .init(6, name: "Granite Pass", flavorText: "Stone walls seal the mountain road ahead.", conquestTitle: "Granite Pass Open", .stoneWall, .right, .center, .frontier),
        .init(7, name: "Emberford", flavorText: "Burning oil guards the bridge inland.", conquestTitle: "Emberford Secured", .burningOil, .left, .right, .ember),
        .init(8, name: "Greywall", flavorText: "Layered stone walls protect a busy town.", conquestTitle: "Greywall Falls", .stoneWall, .center, .left, .frontier),
        .init(9, name: "Runewatch", flavorText: "Arcane wards shimmer over the night road.", conquestTitle: "Runewatch Unbound", .arcaneWard, .right, .center, .arcane),
        .init(10, name: "Ironthorn Gate", flavorText: "A hardened gate blocks the inner road.", conquestTitle: "Ironthorn Gate Broken", .spikedGate, .left, .right, .frontier),
        .init(11, name: "Kingshield Keep", flavorText: "A reinforced fortress guards the royal road.", conquestTitle: "Kingshield Keep Falls", .reinforcedKeep, .center, .left, .frontier),
        .init(12, name: "Ashbridge", flavorText: "Fire cauldrons guard the last crossing.", conquestTitle: "Ashbridge Secured", .burningOil, .right, .center, .ember),
        .init(13, name: "Starveil Citadel", flavorText: "Arcane wards protect the capital heights.", conquestTitle: "Starveil Citadel Falls", .arcaneWard, .left, .right, .arcane),
        .init(14, name: "Stonecrown", flavorText: "Massive stone walls ring the royal seat.", conquestTitle: "Stonecrown Breached", .stoneWall, .center, .left, .frontier),
        .init(15, name: "Crownspire Keep", flavorText: "The final keep rises above the capital.", conquestTitle: "Crownspire Keep Falls", .reinforcedKeep, .right, .center, .royal)
    ]

    @Test func catalogIsCompleteUniqueOrderedAndMatchesAuthoredCombatMetadata() {
        let expectedNumbers = Self.expectedDefinitions.map(\.cityNumber)
        let actualDefinitions = Country1CityCatalog.definitions
        let actualNumbers = actualDefinitions.map(\.cityNumber)

        #expect(expectedNumbers == Array(Country1CityCatalog.cityRange))
        #expect(actualDefinitions.count == Country1CityCatalog.cityRange.count)
        #expect(actualNumbers == expectedNumbers)
        #expect(Set(actualNumbers).count == actualNumbers.count)
        #expect(actualDefinitions == Self.expectedDefinitions.map(\.definition))
    }

    @Test func definitionLookupClampsToCountryOneBounds() {
        let cityOne = Self.expectedDefinitions[0].definition
        let cityFifteen = Self.expectedDefinitions[14].definition

        #expect(Country1CityCatalog.definition(for: -4) == cityOne)
        #expect(Country1CityCatalog.definition(for: 0) == cityOne)
        #expect(Country1CityCatalog.definition(for: 1) == cityOne)
        #expect(Country1CityCatalog.definition(for: 15) == cityFifteen)
        #expect(Country1CityCatalog.definition(for: 16) == cityFifteen)
        #expect(Country1CityCatalog.definition(for: 18) == cityFifteen)
    }

    @Test func everyAuthoredProfileHasExactlyOneLaneOfEachRole() {
        for definition in Country1CityCatalog.definitions {
            let roles = BattleLane.allCases.map {
                definition.laneDefenseProfile.role(for: $0)
            }

            #expect(roles.filter { $0 == .fortified }.count == 1)
            #expect(roles.filter { $0 == .exposed }.count == 1)
            #expect(roles.filter { $0 == .standard }.count == 1)
        }
    }

    @Test func kingdomGameStateCompatibilityAccessorsProjectAuthoredDefinitions() {
        for expected in Self.expectedDefinitions {
            let state = KingdomGameState(
                cityNumberInCountry: expected.cityNumber,
                completedCityCount: expected.cityNumber - 1
            )

            #expect(
                KingdomGameState.defenseTrait(forCityNumber: expected.cityNumber)
                    == expected.defenseTrait
            )
            #expect(state.currentCityDefinition == expected.definition)
            #expect(state.currentCityDefenseTrait == expected.defenseTrait)
            #expect(
                state.currentCityLaneDefenseProfile
                    == expected.definition.laneDefenseProfile
            )
        }

        #expect(KingdomGameState.defenseTrait(forCityNumber: -4) == .standardWatch)
        #expect(KingdomGameState.defenseTrait(forCityNumber: 18) == .reinforcedKeep)
    }

    @Test func authoredIdentityFieldsAreNonEmptyAndWithinCoarseLengthBounds() {
        for expected in Self.expectedDefinitions {
            #expect(!expected.name.isEmpty, "City \(expected.cityNumber) name must be non-empty")
            #expect(!expected.flavorText.isEmpty, "City \(expected.cityNumber) flavorText must be non-empty")
            #expect(!expected.conquestTitle.isEmpty, "City \(expected.cityNumber) conquestTitle must be non-empty")

            #expect(expected.name.count <= 18, "City \(expected.cityNumber) name exceeds 18 chars: \(expected.name)")
            #expect(expected.flavorText.count <= 48, "City \(expected.cityNumber) flavorText exceeds 48 chars: \(expected.flavorText)")
            #expect(expected.conquestTitle.count <= 24, "City \(expected.cityNumber) conquestTitle exceeds 24 chars: \(expected.conquestTitle)")
        }

        let actualDefinitions = Country1CityCatalog.definitions
        #expect(actualDefinitions == Self.expectedDefinitions.map(\.definition))
    }

    @Test func authoredCityNamesAreUniqueCaseInsensitively() {
        let loweredNames = Self.expectedDefinitions.map { $0.name.lowercased() }
        #expect(Set(loweredNames).count == loweredNames.count)
    }

    @Test func displayTitleCombinesCityNumberAndAuthoredName() {
        for expected in Self.expectedDefinitions {
            #expect(expected.definition.displayTitle == "City \(expected.cityNumber) · \(expected.name)")
        }

        let actualDefinitions = Country1CityCatalog.definitions
        for definition in actualDefinitions {
            #expect(definition.displayTitle == "City \(definition.cityNumber) · \(definition.name)")
        }
    }

    @Test func falconridgeAuthorsTheTacticalSiegeLayout() {
        #expect(Country1CityCatalog.definition(for: 3).siegeLayout == Self.falconridgeSiegeLayout)
    }

    @Test func highcrestAuthorsKeepAndBarracksPilot() {
        let definition = Country1CityCatalog.definition(for: 5)
        let layout = definition.siegeLayout
        let maxPower = layout.maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 5))

        #expect(layout.defaultLane == .right)
        #expect(layout.routes[.left] == ["highcrest.barracks", "highcrest.keep"])
        #expect(layout.routes[.center] == ["highcrest.keep"])
        #expect(layout.routes[.right] == ["highcrest.keep"])
        #expect(layout.barracksObjective?.id == "highcrest.barracks")
        #expect(maxPower["highcrest.keep"] == 407)
        #expect(maxPower["highcrest.barracks"] == 20)
    }

    /// Pins the shared Guard constants to the City 5 (Highcrest) pilot baseline.
    /// Every Barracks city uses these values, so changing one changes the pilot.
    @Test func guardRulesMatchTheCityFivePilotBaseline() {
        #expect(Country1GuardRules.maxHP == 12)
        #expect(Country1GuardRules.attackPower == 3)
        #expect(Country1GuardRules.waveIntervalSeconds == 30)
        #expect(Country1GuardRules.totalReserve == 12)
        #expect(Country1GuardRules.guardsPerWave == 2)
        #expect(Country1GuardRules.attackSpeed == 1.0)
        #expect(Country1GuardRules.attackRange == 0.28)
        #expect(Country1GuardRules.movementSpeed == 0.30)
    }

    /// Shelter invariant (Highcrest route-balance pass): every soldier type
    /// that stalls at the Barracks must stand inside the Keep's defensive
    /// fire, so Barracks chewers can never chew for free. Geometry:
    /// `barracksProgress − soldierRange ≥ keepProgress − towerAttackRange`.
    /// Ranges are recomputed from the live combat configuration (base 0.12;
    /// archer ×2.2 = 0.264 is the largest).
    @Test func highcrestBarracksStallPositionStaysInsideKeepTowerRangeForEverySoldierType() throws {
        let layout = Country1CityCatalog.definition(for: 5).siegeLayout
        let barracksProgress = try #require(layout.barracksObjective?.visualProgress)
        let keepProgress = layout.keepObjective.visualProgress
        let configuration = BattleCombatState.Configuration.live(cityLevel: 5)
        var combat = BattleCombatState(configuration: configuration)

        for type in SoldierType.allCases {
            let id = combat.spawnSoldier(
                type: type,
                source: .manual,
                level: 1,
                attackPower: 1,
                lane: .left
            )
            let soldierRange = try #require(combat.soldier(id: id)).attackRange
            let stallPosition = barracksProgress - soldierRange
            let towerReach = keepProgress - configuration.towerAttackRange

            #expect(
                stallPosition >= towerReach,
                "\(type) stalls at \(stallPosition), outside Keep tower reach \(towerReach)"
            )
        }
    }

    @Test func highcrestDefensiveFireStaysSourcedFromTheKeepAcrossAllLanes() {
        let fire = Country1CityCatalog.definition(for: 5).siegeLayout.defensiveFire

        #expect(fire.sourceObjectiveID == "highcrest.keep")
        #expect(Set(fire.coveredLanes) == Set(BattleLane.allCases))
    }

    @Test func nonPilotCitiesUseSingleKeepDefaultedToTheirStandardLane() {
        // City 1 (Willowford) authors a gate layout (HPA-477). Its features are
        // asserted directly, not against a duplicated CityDefinition.
        let layout = Country1CityCatalog.definition(for: 1).siegeLayout
        #expect(layout.objectives.map(\.id) == ["willowford.keep", "willowford.gate"])
        #expect(layout.keepObjective.id == "willowford.keep")
        #expect(layout.objective(id: "willowford.gate")?.kind == .gate)
        #expect(layout.objective(id: "willowford.gate")?.visualProgress == 0.76)
        #expect(layout.routes[.left] == ["willowford.gate", "willowford.keep"])
        #expect(layout.routes[.center] == ["willowford.gate", "willowford.keep"])
        #expect(layout.routes[.right] == ["willowford.keep"])
        #expect(layout.defensiveFire.sourceObjectiveID == "willowford.keep")
        #expect(layout.defensiveFire.coveredLanes == [.right])
        #expect(layout.barracksObjective == nil)
        #expect(layout.defaultLane == .center)
        // The Keep holds most of the city HP and stays the conquest authority.
        let maxPower = layout.maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 1))
        #expect(maxPower["willowford.gate", default: 0] > 0)
        #expect(maxPower["willowford.keep", default: 0] > maxPower["willowford.gate", default: 0])

        // Cities 3 (Falconridge), 5 (Highcrest) and 1 (Willowford) author tactical layouts.
        // The rest stay single-Keep on their standard lane until later tasks author them.
        for definition in Country1CityCatalog.definitions where ![1, 3, 5].contains(definition.cityNumber) {
            #expect(
                definition.siegeLayout == .singleKeep(defaultLane: definition.laneDefenseProfile.standardLane),
                "City \(definition.cityNumber) must use the single-keep siege layout on its standard lane"
            )
        }
    }

    @Test func definitionIfPresentReturnsNilOutsideCityRangeAndTheAuthoredDefinitionInside() {
        #expect(Country1CityCatalog.definitionIfPresent(for: -4) == nil)
        #expect(Country1CityCatalog.definitionIfPresent(for: 0) == nil)
        #expect(Country1CityCatalog.definitionIfPresent(for: 16) == nil)
        #expect(Country1CityCatalog.definitionIfPresent(for: 18) == nil)

        for expected in Self.expectedDefinitions {
            #expect(Country1CityCatalog.definitionIfPresent(for: expected.cityNumber) == expected.definition)
        }
    }

    // MARK: Behavioral geometry (HPA-477)

    private struct SyntheticGeometryCase {
        let label: String
        let layout: CitySiegeLayout
        let cityNumber: Int
        let expectedFragment: String
    }

    private static func geometryObjective(
        _ id: String,
        _ kind: CitySiegeLayout.ObjectiveKind,
        weight: Int,
        progress: Double
    ) -> CitySiegeLayout.Objective {
        CitySiegeLayout.Objective(
            id: id,
            kind: kind,
            durabilityWeight: weight,
            visualLane: .center,
            visualProgress: progress
        )
    }

    /// Behavioral geometry rules for one authored siege layout (HPA-477).
    /// Structural rules (objective counts, gate and tower caps, route
    /// reachability, tower as fire source) belong to `CitySiegeLayout.init`
    /// and are not rechecked here. Returns one readable line per violation;
    /// empty means the layout passes.
    private static func geometryViolations(of layout: CitySiegeLayout, cityNumber: Int) throws -> [String] {
        let configuration = BattleCombatState.Configuration.live(cityLevel: cityNumber)
        let ranges = try liveSoldierAttackRanges(configuration)
        var violations = allocationViolations(of: layout, cityNumber: cityNumber)
        violations += identicalRouteViolations(of: layout)
        violations += towerCoverageViolations(of: layout)
        violations += try barracksShelterViolations(
            of: layout,
            ranges: ranges,
            towerAttackRange: configuration.towerAttackRange
        )
        violations += guardReachViolations(of: layout, ranges: ranges)
        return violations
    }

    /// Per-type soldier attack ranges read from real spawns, so the rules track
    /// `BattleCombatState` (archer is 2.2x the base range, not a hard-coded 0.264).
    private static func liveSoldierAttackRanges(
        _ configuration: BattleCombatState.Configuration
    ) throws -> [(soldier: SoldierType, range: Double)] {
        var combat = BattleCombatState(configuration: configuration)
        var ranges: [(soldier: SoldierType, range: Double)] = []
        for type in SoldierType.allCases {
            let id = combat.spawnSoldier(type: type, source: .manual, level: 1, attackPower: 1, lane: .left)
            let range = try #require(combat.soldier(id: id)).attackRange
            ranges.append((soldier: type, range: range))
        }
        return ranges
    }

    /// Every objective holds positive max HP, and the allocation spends the
    /// city's whole budget.
    private static func allocationViolations(of layout: CitySiegeLayout, cityNumber: Int) -> [String] {
        let budget = KingdomGameState.cityMaxPower(for: cityNumber)
        let maxPowers = layout.maxPowerAllocation(totalBudget: budget)
        var violations = layout.objectives
            .filter { maxPowers[$0.id, default: 0] <= 0 }
            .map { "\($0.id) allocates no max HP at budget \(budget)" }
        let allocated = maxPowers.values.reduce(0, +)
        if allocated != budget {
            violations.append("allocated max HP sums to \(allocated), not cityMaxPower \(budget)")
        }
        return violations
    }

    /// Lanes with identical ordered routes must agree on binary fire coverage,
    /// or one gets equivalent obstacles with strictly less source fire.
    private static func identicalRouteViolations(of layout: CitySiegeLayout) -> [String] {
        let covered = Set(layout.defensiveFire.coveredLanes)
        var violations: [String] = []
        for lane in BattleLane.allCases {
            for other in BattleLane.allCases where other.rawValue > lane.rawValue {
                guard layout.routes[lane] == layout.routes[other],
                      covered.contains(lane) != covered.contains(other) else { continue }
                let route = layout.routes[lane] ?? []
                violations.append("\(lane) and \(other) share route \(route) but fire covers only one of them")
            }
        }
        return violations
    }

    /// Every lane whose route holds the Tower must be covered, so killing an
    /// undefended Tower cannot disable fire for the other lanes for free.
    private static func towerCoverageViolations(of layout: CitySiegeLayout) -> [String] {
        guard let tower = layout.objectives.first(where: { $0.kind == .arrowTower }) else { return [] }
        let covered = Set(layout.defensiveFire.coveredLanes)
        return BattleLane.allCases.compactMap { lane -> String? in
            guard layout.routes[lane]?.contains(tower.id) == true, !covered.contains(lane) else { return nil }
            return "\(lane) route contains tower \(tower.id) but fire does not cover that lane"
        }
    }

    /// Barracks shelter: every lane through the Barracks is covered by fire, and
    /// soldiers stalled at the Barracks stay inside the fire source's reach
    /// (`barracks - attackRange >= source - towerAttackRange`) for every type.
    private static func barracksShelterViolations(
        of layout: CitySiegeLayout,
        ranges: [(soldier: SoldierType, range: Double)],
        towerAttackRange: Double
    ) throws -> [String] {
        guard let barracks = layout.barracksObjective else { return [] }
        let source = try #require(layout.objective(id: layout.defensiveFire.sourceObjectiveID))
        let covered = Set(layout.defensiveFire.coveredLanes)
        let reachLimit = source.visualProgress - towerAttackRange
        var violations: [String] = []
        for lane in BattleLane.allCases where layout.routes[lane]?.contains(barracks.id) == true {
            if !covered.contains(lane) {
                violations.append("\(lane) route contains barracks \(barracks.id) but fire does not cover that lane")
            }
            for entry in ranges {
                let stall = barracks.visualProgress - entry.range
                if stall < reachLimit {
                    violations.append(
                        "\(lane) barracks stall for \(entry.soldier) at \(stall) "
                            + "is outside \(source.id) fire reach \(reachLimit)"
                    )
                }
            }
        }
        return violations
    }

    /// Guard reach: Guards deploy from the Barracks floor, so every support
    /// objective must keep soldiers it stalls within Guard reach of that floor
    /// (`support - attackRange + guardRange >= barracks`).
    private static func guardReachViolations(
        of layout: CitySiegeLayout,
        ranges: [(soldier: SoldierType, range: Double)]
    ) -> [String] {
        guard let barracks = layout.barracksObjective else { return [] }
        var violations: [String] = []
        for support in layout.objectives where support.kind != .keep {
            guard layout.routes.values.contains(where: { $0.contains(support.id) }) else { continue }
            for entry in ranges {
                let reach = support.visualProgress - entry.range + Country1GuardRules.attackRange
                if reach < barracks.visualProgress {
                    violations.append(
                        "Guards at \(barracks.id) cannot reach \(entry.soldier) stalled at \(support.id)"
                    )
                }
            }
        }
        return violations
    }

    @Test func everyAuthoredCityPassesTheBehavioralGeometryRules() throws {
        for definition in Country1CityCatalog.definitions {
            let violations = try Self.geometryViolations(
                of: definition.siegeLayout,
                cityNumber: definition.cityNumber
            )
            #expect(
                violations.isEmpty,
                "City \(definition.cityNumber) breaks the geometry rules: \(violations.joined(separator: "; "))"
            )
        }
    }

    @Test func syntheticLayoutsBreakingOneBehavioralRuleEachAreReported() throws {
        // Each layout passes every `CitySiegeLayout.init` precondition, so it
        // constructs without trapping, yet breaks exactly one behavioral rule.
        let identicalRoutes = CitySiegeLayout(
            objectives: [
                Self.geometryObjective("bad.keep", .keep, weight: 1, progress: 1.0),
                Self.geometryObjective("bad.gate", .gate, weight: 1, progress: 0.5)
            ],
            routes: [
                .left: ["bad.gate", "bad.keep"],
                .center: ["bad.gate", "bad.keep"],
                .right: ["bad.keep"]
            ],
            defaultLane: .left,
            defensiveFire: .init(sourceObjectiveID: "bad.keep", coveredLanes: [.left])
        )
        let uncoveredBarracksLane = CitySiegeLayout(
            objectives: [
                Self.geometryObjective("bad.keep", .keep, weight: 20, progress: 1.0),
                Self.geometryObjective("bad.barracks", .barracks, weight: 1, progress: 0.72)
            ],
            routes: [
                .left: ["bad.barracks", "bad.keep"],
                .center: ["bad.keep"],
                .right: ["bad.keep"]
            ],
            defaultLane: .right,
            defensiveFire: .init(sourceObjectiveID: "bad.keep", coveredLanes: [.center, .right])
        )
        let unreachableSupport = CitySiegeLayout(
            objectives: [
                Self.geometryObjective("bad.keep", .keep, weight: 20, progress: 1.0),
                Self.geometryObjective("bad.barracks", .barracks, weight: 1, progress: 0.72),
                Self.geometryObjective("bad.gate", .gate, weight: 1, progress: 0.30)
            ],
            routes: [
                .left: ["bad.gate", "bad.barracks", "bad.keep"],
                .center: ["bad.barracks", "bad.keep"],
                .right: ["bad.keep"]
            ],
            defaultLane: .right,
            defensiveFire: .init(sourceObjectiveID: "bad.keep", coveredLanes: BattleLane.allCases)
        )
        let barracksOutsideFire = CitySiegeLayout(
            objectives: [
                Self.geometryObjective("bad.keep", .keep, weight: 20, progress: 1.0),
                Self.geometryObjective("bad.barracks", .barracks, weight: 1, progress: 0.30)
            ],
            routes: [
                .left: ["bad.barracks", "bad.keep"],
                .center: ["bad.keep"],
                .right: ["bad.keep"]
            ],
            defaultLane: .right,
            defensiveFire: .init(sourceObjectiveID: "bad.keep", coveredLanes: BattleLane.allCases)
        )
        let uncoveredTowerLane = CitySiegeLayout(
            objectives: [
                Self.geometryObjective("bad.keep", .keep, weight: 1, progress: 1.0),
                Self.geometryObjective("bad.tower", .arrowTower, weight: 1, progress: 0.68)
            ],
            routes: [
                .left: ["bad.tower", "bad.keep"],
                .center: ["bad.keep"],
                .right: ["bad.keep"]
            ],
            defaultLane: .center,
            defensiveFire: .init(sourceObjectiveID: "bad.tower", coveredLanes: [.center, .right])
        )
        let starvedObjective = CitySiegeLayout(
            objectives: [
                Self.geometryObjective("bad.keep", .keep, weight: 100, progress: 1.0),
                Self.geometryObjective("bad.gate", .gate, weight: 1, progress: 0.5)
            ],
            routes: [
                .left: ["bad.gate", "bad.keep"],
                .center: ["bad.gate", "bad.keep"],
                .right: ["bad.keep"]
            ],
            defaultLane: .center,
            defensiveFire: .init(sourceObjectiveID: "bad.keep", coveredLanes: BattleLane.allCases)
        )

        let cases: [SyntheticGeometryCase] = [
            SyntheticGeometryCase(
                label: "identical routes with unequal fire",
                layout: identicalRoutes,
                cityNumber: 1,
                expectedFragment: "share route"
            ),
            SyntheticGeometryCase(
                label: "barracks lane outside fire",
                layout: uncoveredBarracksLane,
                cityNumber: 5,
                expectedFragment: "contains barracks"
            ),
            SyntheticGeometryCase(
                label: "support Guards cannot reach",
                layout: unreachableSupport,
                cityNumber: 5,
                expectedFragment: "cannot reach"
            ),
            SyntheticGeometryCase(
                label: "barracks stall outside fire reach",
                layout: barracksOutsideFire,
                cityNumber: 5,
                expectedFragment: "is outside"
            ),
            SyntheticGeometryCase(
                label: "tower lane outside its own fire",
                layout: uncoveredTowerLane,
                cityNumber: 1,
                expectedFragment: "contains tower"
            ),
            SyntheticGeometryCase(
                label: "objective allocated no max HP",
                layout: starvedObjective,
                cityNumber: 1,
                expectedFragment: "allocates no max HP"
            )
        ]

        for testCase in cases {
            let violations = try Self.geometryViolations(of: testCase.layout, cityNumber: testCase.cityNumber)
            #expect(
                violations.contains { $0.contains(testCase.expectedFragment) },
                "\(testCase.label) should report \"\(testCase.expectedFragment)\"; got \(violations)"
            )
        }
    }

    // MARK: Vanguard Captain rules (HPA-475)

    @Test func vanguardCaptainRulesMatchAuthoredTuning() {
        #expect(VanguardCaptainRules.unlockCity == 3)
        #expect(VanguardCaptainRules.recoverySeconds == 12.0)
        #expect(VanguardCaptainRules.rallyDurationSeconds == 5.0)
        #expect(VanguardCaptainRules.rallyDamageMultiplier == 0.70)

        #expect(!VanguardCaptainRules.isAvailable(cityNumber: 1))
        #expect(!VanguardCaptainRules.isAvailable(cityNumber: 2))
        #expect(VanguardCaptainRules.isAvailable(cityNumber: 3))
        #expect(VanguardCaptainRules.isAvailable(cityNumber: 15))

        // One attack point above the ordinary soldier curve.
        #expect(VanguardCaptainRules.attackPower(for: 1) == KingdomGameState.normalSoldierAttackPower(for: 1) + 1)
        #expect(VanguardCaptainRules.attackPower(for: 1) == 2)
        #expect(VanguardCaptainRules.attackPower(for: 2) == 3)
        #expect(VanguardCaptainRules.attackPower(for: 4) == 4)

        #expect(VanguardCaptainRules.maxHP(for: 1) == 20)
        #expect(VanguardCaptainRules.maxHP(for: 2) == 25)
        #expect(VanguardCaptainRules.maxHP(for: 3) == 31)
        #expect(VanguardCaptainRules.maxHP(for: 0) == VanguardCaptainRules.maxHP(for: 1))
    }

    @Test func captainNormalizationPreservesIdentityAndClampsValues() {
        // Keeps lane and Rally consumption; clamps HP >= 0 and recovery
        // into 0...12.
        let normalized = VanguardCaptainProgress(
            lane: .left,
            remainingHP: -3,
            recoveryRemainingSeconds: 30,
            rallyConsumed: true
        ).normalizedForCaptain()
        #expect(normalized.lane == .left)
        #expect(normalized.remainingHP == 0)
        #expect(normalized.recoveryRemainingSeconds == 12.0)
        #expect(normalized.rallyConsumed == true)

        // An alive captain never carries recovery time.
        let alive = VanguardCaptainProgress(
            lane: .right,
            remainingHP: 7,
            recoveryRemainingSeconds: 6,
            rallyConsumed: false
        ).normalizedForCaptain()
        #expect(alive.remainingHP == 7)
        #expect(alive.recoveryRemainingSeconds == 0)
        #expect(alive.lane == .right)

        // Negative recovery clamps to zero.
        let rested = VanguardCaptainProgress(
            lane: .center,
            remainingHP: 0,
            recoveryRemainingSeconds: -2,
            rallyConsumed: false
        ).normalizedForCaptain()
        #expect(rested.recoveryRemainingSeconds == 0)
        #expect(rested.remainingHP == 0)
    }
}
