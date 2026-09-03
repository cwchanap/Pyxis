import CoreGraphics
import Testing
@testable import Pyxis

private struct FeedbackSettingsFixture: Sendable {
    let name: String
    let sceneSize: CGSize
    let safeAreaInsets: FeedbackSettingsSafeAreaInsets
}

private let feedbackSettingsFixtures = [
    FeedbackSettingsFixture(
        name: "compact phone",
        sceneSize: .init(width: 375, height: 499),
        safeAreaInsets: .zero
    ),
    FeedbackSettingsFixture(
        name: "regular phone",
        sceneSize: .init(width: 375, height: 667),
        safeAreaInsets: .zero
    ),
    FeedbackSettingsFixture(
        name: "tall phone",
        sceneSize: .init(width: 393, height: 852),
        safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
    ),
    FeedbackSettingsFixture(
        name: "iPad with side insets",
        sceneSize: .init(width: 834, height: 1194),
        safeAreaInsets: .init(top: 24, left: 50, bottom: 20, right: 50)
    )
]

private func feedbackSettingsLayout(_ fixture: FeedbackSettingsFixture) -> FeedbackSettingsLayout? {
    FeedbackSettingsLayout.compute(
        sceneSize: fixture.sceneSize,
        safeAreaInsets: fixture.safeAreaInsets
    )
}

private func feedbackSettingsSafeFrame(for fixture: FeedbackSettingsFixture) -> CGRect {
    CGRect(
        x: fixture.safeAreaInsets.left,
        y: fixture.safeAreaInsets.bottom,
        width: fixture.sceneSize.width - fixture.safeAreaInsets.left - fixture.safeAreaInsets.right,
        height: fixture.sceneSize.height - fixture.safeAreaInsets.top - fixture.safeAreaInsets.bottom
    )
}

struct FeedbackSettingsLayoutTests {
    @Test(arguments: feedbackSettingsFixtures)
    private func supportedFixturesContainTheBottomSheetStack(
        fixture: FeedbackSettingsFixture
    ) throws {
        let layout = try #require(feedbackSettingsLayout(fixture))
        let safeFrame = feedbackSettingsSafeFrame(for: fixture)
        let controls = [layout.soundRowFrame, layout.hapticsRowFrame, layout.closeFrame]

        #expect(layout.scrimFrame == CGRect(origin: .zero, size: fixture.sceneSize))
        #expect(layout.panelFrame.minX == 0)
        #expect(layout.panelFrame.maxX == fixture.sceneSize.width)
        #expect(layout.panelFrame.minY == 0)
        #expect(layout.panelFrame.maxY <= fixture.sceneSize.height)
        #expect(layout.panelFrame.maxY <= safeFrame.maxY)
        #expect(layout.panelFrame.contains(layout.handleFrame))
        #expect(controls.allSatisfy { layout.panelFrame.contains($0) })
        #expect(layout.handleFrame.width == 44)
        #expect(layout.handleFrame.height == 4)
        #expect(controls.allSatisfy { $0.width >= 44 && $0.height >= 52 })

        #expect(layout.soundRowFrame.minY == layout.hapticsRowFrame.maxY + 1)
        #expect(layout.hapticsRowFrame.minY == layout.closeFrame.maxY + 14)
        #expect(layout.handleFrame.minY == layout.soundRowFrame.maxY + 16)
        #expect(layout.handleFrame.maxY + 12 == layout.panelFrame.maxY)
        #expect(layout.closeFrame.minY >= max(20, fixture.safeAreaInsets.bottom))
    }

    @Test func compactPhoneUsesTheExactBottomSheetFrames() throws {
        let fixture = feedbackSettingsFixtures[0]
        let layout = try #require(feedbackSettingsLayout(fixture))

        #expect(layout.panelFrame == CGRect(x: 0, y: 0, width: 375, height: 239))
        #expect(layout.handleFrame == CGRect(x: 165.5, y: 223, width: 44, height: 4))
        #expect(layout.soundRowFrame == CGRect(x: 20, y: 147, width: 335, height: 60))
        #expect(layout.hapticsRowFrame == CGRect(x: 20, y: 86, width: 335, height: 60))
        #expect(layout.closeFrame == CGRect(x: 20, y: 20, width: 335, height: 52))
    }

    @Test func tallPhoneUsesTheSafeAreaBottomAsSheetPadding() throws {
        let layout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        ))

        #expect(layout.panelFrame == CGRect(x: 0, y: 0, width: 393, height: 253))
        #expect(layout.handleFrame == CGRect(x: 174.5, y: 237, width: 44, height: 4))
        #expect(layout.soundRowFrame == CGRect(x: 20, y: 161, width: 353, height: 60))
        #expect(layout.hapticsRowFrame == CGRect(x: 20, y: 100, width: 353, height: 60))
        #expect(layout.closeFrame == CGRect(x: 20, y: 34, width: 353, height: 52))
    }

    @Test func narrowSafeMarginsRemainContainedAtTheBoundary() throws {
        let layout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 84, height: 239),
            safeAreaInsets: .zero
        ))

        #expect(layout.panelFrame == CGRect(x: 0, y: 0, width: 84, height: 239))
        #expect(layout.soundRowFrame == CGRect(x: 20, y: 147, width: 44, height: 60))
        #expect(layout.panelFrame.contains(layout.soundRowFrame))
    }

    @Test func nonfiniteAndInsufficientSafeGeometryReturnsNil() {
        #expect(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: CGFloat.nan, height: 499),
            safeAreaInsets: .zero
        ) == nil)
        #expect(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 375, height: CGFloat.infinity),
            safeAreaInsets: .zero
        ) == nil)
        #expect(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 375, height: 499),
            safeAreaInsets: .init(top: 0, left: -1, bottom: 0, right: 0)
        ) == nil)
        #expect(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 83, height: 239),
            safeAreaInsets: .zero
        ) == nil)
        #expect(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 375, height: 238),
            safeAreaInsets: .zero
        ) == nil)
        // A short scene with a nonzero top safe-area inset fails closed even
        // though the raw scene height alone would fit the bottom sheet.
        #expect(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 375, height: 260),
            safeAreaInsets: .init(top: 30, left: 0, bottom: 0, right: 0)
        ) == nil)
    }
}
