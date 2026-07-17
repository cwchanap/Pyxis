import Testing
@testable import Pyxis

struct SoldierAnimationManifestTests {
    @Test func currentApprovedActionsMatchInstalledArcherTrio() {
        #expect(SoldierAnimationAction.allCases.allSatisfy {
            SoldierAnimationManifest.isAuthored($0, for: .archer)
        })
        #expect(SoldierAnimationManifest.usesFullCanvas(for: .archer))
    }

    @Test func infantryTrioIsApprovedForFullCanvasPlayback() {
        for action in SoldierAnimationAction.allCases {
            #expect(SoldierAnimationManifest.isAuthored(action, for: .infantry))
        }
        #expect(SoldierAnimationManifest.usesFullCanvas(for: .infantry))
    }

    @Test func remainingSoldierTriosAreApprovedForFullCanvasPlayback() {
        for type in [SoldierType.cavalry, .mage, .siege] {
            #expect(SoldierAnimationManifest.usesFullCanvas(for: type))
            for action in SoldierAnimationAction.allCases {
                #expect(SoldierAnimationManifest.isAuthored(action, for: type))
            }
        }
    }
}
