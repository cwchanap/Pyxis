struct SoldierAnimationManifest {
    private static let authoredActions: [SoldierType: Set<SoldierAnimationAction>] = [
        .archer: Set(SoldierAnimationAction.allCases)
    ]
    private static let fullCanvasTypes: Set<SoldierType> = [.archer]

    static func isAuthored(_ action: SoldierAnimationAction, for type: SoldierType) -> Bool {
        authoredActions[type]?.contains(action) == true
    }

    static func usesFullCanvas(for type: SoldierType) -> Bool {
        fullCanvasTypes.contains(type)
    }
}
