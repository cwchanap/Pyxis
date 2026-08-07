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
        for soundID in GameplaySoundID.allCases {
            #expect(GameplaySoundCatalog.all[soundID] != nil)
        }
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

            #expect(resource.maximumDuration != nil)
            let budget = try #require(resource.maximumDuration)
            #expect(duration <= budget)
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

        let manifestRows = manifest.split(separator: "\n").filter { line in
            line.hasPrefix("| `")
        }
        #expect(manifestRows.count == GameplaySoundID.allCases.count)
        #expect(Set(expectedManifestEntries.keys) == Set(GameplaySoundID.allCases))

        for resource in GameplaySoundCatalog.all.values {
            let expectedEntry = try #require(expectedManifestEntries[resource.id])
            let rowPrefix = "| `\(resource.resourceName).\(resource.fileExtension)` |"
            let row = try #require(manifestRows.first { line in
                line.hasPrefix(rowPrefix)
            })
            let cells = row
                .split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            #expect(cells.count == 11)
            #expect(cells[0] == "`\(resource.resourceName).\(resource.fileExtension)`")
            #expect(cells[1] == expectedEntry.semanticUse)
            #expect(cells[2] == "`\(expectedEntry.originalSourceFile)`")
            #expect(cells[3] == sourcePack)
            #expect(cells[4] == creator)
            #expect(cells[5] == sourceReference)
            #expect(cells[6] == spdxIdentifier)
            #expect(cells[7] == localLicensePath)
            #expect(cells[8] == redistributionConfirmation)
            #expect(cells[9] == processingDescription)

            let durationParts = cells[10].split(separator: " ")
            #expect(durationParts.count == 2)
            #expect(durationParts[1] == "s")
            let manifestDuration = try #require(durationParts.first.flatMap { Double($0) })
            let resourceURL = try #require(
                Bundle.main.url(
                    forResource: resource.resourceName,
                    withExtension: resource.fileExtension
                )
            )
            let file = try AVAudioFile(forReading: resourceURL)
            let onDiskDuration = Double(file.length) / file.processingFormat.sampleRate

            #expect(manifestDuration >= 0)
            #expect(abs(manifestDuration - onDiskDuration) <= 0.000_001)
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
        )
    ]

    private struct ManifestEntry {
        let semanticUse: String
        let originalSourceFile: String
    }

    private let expectedManifestEntries: [GameplaySoundID: ManifestEntry] = [
        .deployment: ManifestEntry(
            semanticUse: "Manual soldier deployment",
            originalSourceFile: "drawKnife3.ogg"
        ),
        .attackMelee: ManifestEntry(
            semanticUse: "Automatic melee attack",
            originalSourceFile: "knifeSlice.ogg"
        ),
        .attackRanged: ManifestEntry(
            semanticUse: "Automatic ranged or magic attack",
            originalSourceFile: "drawKnife2.ogg"
        ),
        .attackSiege: ManifestEntry(
            semanticUse: "Automatic siege attack",
            originalSourceFile: "chop.ogg"
        ),
        .towerFire: ManifestEntry(
            semanticUse: "Automatic enemy-tower shot",
            originalSourceFile: "metalClick.ogg"
        ),
        .soldierHit: ManifestEntry(
            semanticUse: "Automatic soldier-damage hit",
            originalSourceFile: "cloth2.ogg"
        ),
        .soldierDeath: ManifestEntry(
            semanticUse: "Automatic soldier-damage death",
            originalSourceFile: "dropLeather.ogg"
        ),
        .construction: ManifestEntry(
            semanticUse: "Building constructed or upgraded",
            originalSourceFile: "metalPot3.ogg"
        ),
        .blocked: ManifestEntry(
            semanticUse: "Invalid or unaffordable action",
            originalSourceFile: "metalLatch.ogg"
        ),
        .goldReward: ManifestEntry(
            semanticUse: "Gold reward",
            originalSourceFile: "handleCoins.ogg"
        ),
        .cityConquest: ManifestEntry(
            semanticUse: "City-conquest outcome",
            originalSourceFile: "doorOpen_1.ogg"
        ),
        .countryCompletion: ManifestEntry(
            semanticUse: "Country-completion outcome",
            originalSourceFile: "doorOpen_2.ogg"
        )
    ]

    private let sourcePack = "Kenney RPG Audio v1.0"
    private let creator = "Kenney"
    private let sourceReference = "[Official archive](https://www.kenney.nl/media/pages/assets/" +
        "rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip)"
    private let spdxIdentifier = "CC0-1.0"
    private let localLicensePath = "`docs/licenses/audio/CC0-1.0.txt`"
    private let redistributionConfirmation = "Yes — CC0 permits modification and binary-app redistribution."
    private let processingDescription = "Decoded OGG; 48 kHz stereo to 44.1 kHz mono LEI16 CAF; no trim."
}
