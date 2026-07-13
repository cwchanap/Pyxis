import Testing
@testable import Pyxis

struct SoldierAnimationManifestTests {
    @Test func currentApprovedActionsMatchInstalledArcherTrio() {
        #expect(SoldierAnimationAction.allCases.allSatisfy {
            SoldierAnimationManifest.isAuthored($0, for: .archer)
        })
        #expect(SoldierAnimationManifest.usesFullCanvas(for: .archer))

        for type in SoldierType.allCases where type != .archer {
            #expect(!SoldierAnimationManifest.usesFullCanvas(for: type))
            for action in SoldierAnimationAction.allCases {
                #expect(!SoldierAnimationManifest.isAuthored(action, for: type))
            }
        }
    }
}
