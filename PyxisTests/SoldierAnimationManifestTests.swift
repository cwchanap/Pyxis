import Testing
@testable import Pyxis

struct SoldierAnimationManifestTests {
    @Test func currentApprovedActionsMatchInstalledArcherPilot() {
        #expect(SoldierAnimationManifest.isAuthored(.attack, for: .archer))
        #expect(SoldierAnimationManifest.isAuthored(.hit, for: .archer))
        #expect(!SoldierAnimationManifest.isAuthored(.walk, for: .archer))
        #expect(SoldierAnimationManifest.usesFullCanvas(for: .archer))

        for type in SoldierType.allCases where type != .archer {
            #expect(!SoldierAnimationManifest.usesFullCanvas(for: type))
            for action in SoldierAnimationAction.allCases {
                #expect(!SoldierAnimationManifest.isAuthored(action, for: type))
            }
        }
    }
}
