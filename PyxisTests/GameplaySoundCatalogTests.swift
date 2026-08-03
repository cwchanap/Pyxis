//
//  GameplaySoundCatalogTests.swift
//  PyxisTests
//

import AVFoundation
import Foundation
import Testing
@testable import Pyxis

@MainActor
struct GameplaySoundCatalogTests {
    @Test func catalogHasOneExpectedResourceForEverySoundID() {
        #expect(GameplaySoundCatalog.all == expectedResources)
    }

    @Test func everyCatalogResourceIsBundledInTheMainAppBundle() {
        for resource in GameplaySoundCatalog.all.values {
            #expect(
                Bundle.main.url(
                    forResource: resource.resourceName,
                    withExtension: resource.fileExtension
                ) != nil
            )
        }
    }

    @Test func automaticCombatResourcesMeetTheirMeasuredDurationBudget() throws {
        for resource in GameplaySoundCatalog.all.values where resource.soundClass == .automaticCombat {
            let url = try #require(
                Bundle.main.url(
                    forResource: resource.resourceName,
                    withExtension: resource.fileExtension
                )
            )
            let file = try AVAudioFile(forReading: url)
            let duration = Double(file.length) / file.processingFormat.sampleRate

            #expect(resource.maximumDuration == 0.750)
            #expect(duration <= 0.750)
        }
    }

    @Test func manifestDocumentsEveryCatalogResourceAndItsOfflineLicenseEvidence() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifestURL = repositoryRoot.appendingPathComponent("docs/audio-assets.md")
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)

        for requiredField in [
            "Bundled resource",
            "Semantic use",
            "Original source file",
            "Source pack",
            "Creator",
            "Source reference",
            "SPDX",
            "Local license",
            "Redistribution",
            "Processing",
            "Measured duration"
        ] {
            #expect(manifest.contains(requiredField))
        }

        for resource in expectedResources.values {
            let rowPrefix = "| `\(resource.resourceName).\(resource.fileExtension)` |"
            let row = try #require(manifest.split(separator: "\n").first { line in
                line.hasPrefix(rowPrefix)
            })
            let cells = row
                .split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            #expect(cells.count == 11)
            #expect(cells[0] == "`\(resource.resourceName).\(resource.fileExtension)`")
            #expect(cells[3].contains("Kenney"))
            #expect(cells[4] == "Kenney")
            #expect(cells[6] == "CC0-1.0")
            #expect(cells[7] == "`docs/licenses/audio/CC0-1.0.txt`")
            #expect(cells[8].contains("Yes"))
            #expect(cells[10].hasSuffix("s"))
        }

        let licenseURL = repositoryRoot.appendingPathComponent("docs/licenses/audio/CC0-1.0.txt")
        #expect(FileManager.default.fileExists(atPath: licenseURL.path))
    }

    private let expectedResources: [GameplaySoundID: GameplaySoundResource] = [
        .deployment: GameplaySoundResource(
            id: .deployment,
            resourceName: "deployment",
            fileExtension: "caf",
            soundClass: .nonAutomatic,
            maximumDuration: nil
        ),
        .attackMelee: GameplaySoundResource(
            id: .attackMelee,
            resourceName: "attack-melee",
            fileExtension: "caf",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .attackRanged: GameplaySoundResource(
            id: .attackRanged,
            resourceName: "attack-ranged",
            fileExtension: "caf",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .attackSiege: GameplaySoundResource(
            id: .attackSiege,
            resourceName: "attack-siege",
            fileExtension: "caf",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .towerFire: GameplaySoundResource(
            id: .towerFire,
            resourceName: "tower-fire",
            fileExtension: "caf",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .soldierHit: GameplaySoundResource(
            id: .soldierHit,
            resourceName: "soldier-hit",
            fileExtension: "caf",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .soldierDeath: GameplaySoundResource(
            id: .soldierDeath,
            resourceName: "soldier-death",
            fileExtension: "caf",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .construction: GameplaySoundResource(
            id: .construction,
            resourceName: "construction",
            fileExtension: "caf",
            soundClass: .nonAutomatic,
            maximumDuration: nil
        ),
        .blocked: GameplaySoundResource(
            id: .blocked,
            resourceName: "blocked",
            fileExtension: "caf",
            soundClass: .nonAutomatic,
            maximumDuration: nil
        ),
        .goldReward: GameplaySoundResource(
            id: .goldReward,
            resourceName: "gold-reward",
            fileExtension: "caf",
            soundClass: .nonAutomatic,
            maximumDuration: nil
        ),
        .cityConquest: GameplaySoundResource(
            id: .cityConquest,
            resourceName: "city-conquest",
            fileExtension: "caf",
            soundClass: .nonAutomatic,
            maximumDuration: nil
        ),
        .countryCompletion: GameplaySoundResource(
            id: .countryCompletion,
            resourceName: "country-completion",
            fileExtension: "caf",
            soundClass: .nonAutomatic,
            maximumDuration: nil
        ),
        .fortifiedWarning: GameplaySoundResource(
            id: .fortifiedWarning,
            resourceName: "fortified-warning",
            fileExtension: "caf",
            soundClass: .nonAutomatic,
            maximumDuration: nil
        )
    ]
}
