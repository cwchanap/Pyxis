//
//  CountryMapLayoutUIKitAdapterTests.swift
//  PyxisTests
//

import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct CountryMapLayoutUIKitAdapterTests {
    @Test func phoneIdiomMapsToPhoneLayoutClassAndPreservesInsets() throws {
        let environment = try #require(CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: UIEdgeInsets(top: 59, left: 3, bottom: 34, right: 5),
            idiom: .phone
        ))

        #expect(environment.layoutClass == .phone)
        #expect(environment.safeAreaInsets == CountryMapSafeAreaInsets(top: 59, left: 3, bottom: 34, right: 5))
    }

    @Test func padIdiomMapsToPadLayoutClassAndPreservesInsets() throws {
        let environment = try #require(CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: UIEdgeInsets(top: 24, left: 11, bottom: 20, right: 7),
            idiom: .pad
        ))

        #expect(environment.layoutClass == .pad)
        #expect(environment.safeAreaInsets == CountryMapSafeAreaInsets(top: 24, left: 11, bottom: 20, right: 7))
    }

    @Test func zeroInsetsRoundTripAsZero() throws {
        let environment = try #require(CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: .zero,
            idiom: .phone
        ))

        #expect(environment.safeAreaInsets == .zero)
    }

    @Test(arguments: [
        UIUserInterfaceIdiom.unspecified,
        UIUserInterfaceIdiom.tv,
        UIUserInterfaceIdiom.carPlay
    ])
    private func unsupportedIdiomsProduceNoEnvironment(idiom: UIUserInterfaceIdiom) {
        #expect(CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: .zero,
            idiom: idiom
        ) == nil)
    }

    @Test func environmentForViewDelegatesToSafeAreaAndIdiomOverload() {
        // Avoid asserting a specific idiom/insets here: a bare SKView with no
        // window may report `.unspecified` in a headless test host. Instead,
        // verify the convenience overload forwards exactly what the primary
        // overload would compute from the same view's live properties.
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

        let viaConvenience = CountryMapLayoutUIKitAdapter.environment(for: view)
        let viaDirectOverload = CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: view.safeAreaInsets,
            idiom: view.traitCollection.userInterfaceIdiom
        )

        #expect(viaConvenience == viaDirectOverload)
    }

    @Test func resultingEnvironmentIsAcceptedByLayoutComputation() throws {
        let environment = try #require(CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
            idiom: .phone
        ))

        let result = CountryMapLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            environment: environment,
            definition: .country1
        ))

        guard case .supported = result else {
            Issue.record("Adapter-produced environment should satisfy a supported phone layout")
            return
        }
    }
}