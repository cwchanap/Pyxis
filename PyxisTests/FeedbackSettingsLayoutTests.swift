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
    private func supportedFixturesContainTheFixedSettingsStack(
        fixture: FeedbackSettingsFixture
    ) throws {
        let layout = try #require(feedbackSettingsLayout(fixture))
        let safeFrame = feedbackSettingsSafeFrame(for: fixture)
        let controls = [layout.soundRowFrame, layout.hapticsRowFrame, layout.closeFrame]

        #expect(layout.scrimFrame == CGRect(origin: .zero, size: fixture.sceneSize))
        #expect(layout.panelFrame.width == 320)
        #expect(layout.panelFrame.height == 222)
        #expect(layout.panelFrame.midX == safeFrame.midX)
        #expect(layout.panelFrame.midY == safeFrame.midY)
        #expect(safeFrame.contains(layout.panelFrame))
        #expect(controls.allSatisfy { layout.panelFrame.contains($0) })
        #expect(controls.allSatisfy { $0.width >= 44 && $0.height >= 44 })

        #expect(layout.soundRowFrame.maxY + 20 == layout.panelFrame.maxY)
        #expect(layout.hapticsRowFrame.maxY + 12 == layout.soundRowFrame.minY)
        #expect(layout.closeFrame.maxY + 18 == layout.hapticsRowFrame.minY)
        #expect(layout.closeFrame.minY == layout.panelFrame.minY + 20)
    }

    @Test func compactPhoneUsesTheExactSpecifiedFrames() throws {
        let fixture = feedbackSettingsFixtures[0]
        let layout = try #require(feedbackSettingsLayout(fixture))

        #expect(layout.panelFrame == CGRect(x: 27.5, y: 138.5, width: 320, height: 222))
        #expect(layout.soundRowFrame == CGRect(x: 47.5, y: 288.5, width: 280, height: 52))
        #expect(layout.hapticsRowFrame == CGRect(x: 47.5, y: 224.5, width: 280, height: 52))
        #expect(layout.closeFrame == CGRect(x: 47.5, y: 158.5, width: 280, height: 48))
    }

    @Test func sixteenPointSafeMarginsAndMaximumPanelWidthMeetAtTheBoundary() throws {
        let layout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 352, height: 222),
            safeAreaInsets: .zero
        ))

        #expect(layout.panelFrame == CGRect(x: 16, y: 0, width: 320, height: 222))
        #expect(layout.panelFrame.minX == 16)
        #expect(layout.scrimFrame.maxX - layout.panelFrame.maxX == 16)
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
            sceneSize: .init(width: 115, height: 222),
            safeAreaInsets: .zero
        ) == nil)
        #expect(FeedbackSettingsLayout.compute(
            sceneSize: .init(width: 375, height: 221),
            safeAreaInsets: .zero
        ) == nil)
    }
}
