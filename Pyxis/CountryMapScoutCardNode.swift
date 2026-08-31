import SpriteKit
import UIKit

final class CountryMapScoutCardNode: SKNode {
    enum ApplyResult: Equatable {
        case presented
        case requiredContentDoesNotFit
    }

    typealias ImageLoader = (String) -> UIImage?

    private struct Metrics {
        let titleSize: CGFloat
        let badgeSize: CGFloat
        let rewardSize: CGFloat
        let fallbackRewardSize: CGFloat
        let traitSize: CGFloat
        let footerSize: CGFloat
        let attackSize: CGFloat
        let feedbackSize: CGFloat
        let feedbackHorizontalInset: CGFloat
        let iconSize: CGFloat
        let prefixGap: CGFloat
        let iconLabelGap: CGFloat
        let itemGap: CGFloat
        let fixedPadLabelWidth: CGFloat?
    }

    private struct PreparedFooterItem {
        let type: SoldierType?
        let label: String
        let multiplierText: String?
        let requestedImageName: String?
        let image: UIImage?
    }

    private struct RenderedFooterItem {
        let type: SoldierType?
        let multiplierText: String?
        let requestedImageName: String?
        let labelNode: SKLabelNode
        let iconNode: SKSpriteNode?
        let targetFrame: CGRect
    }

    private struct PreparedScout {
        let scout: CountryMapScoutCardContent.Scout
        let metrics: Metrics
        let titleFontSize: CGFloat
        let traitLines: [String]
        let favorableItems: [PreparedFooterItem]
        let disadvantagedItems: [PreparedFooterItem]
        let laneText: String
        let cityImage: UIImage?
        let cityAssetName: String?
        let goldImage: UIImage?
        let rewardText: String
        let rewardFontSize: CGFloat
        let rewardFrame: CGRect
    }

    private enum PreparedPresentation {
        case scout(PreparedScout)
        case countryComplete(text: String, fontSize: CGFloat)
    }

    private let imageLoader: ImageLoader
    private let cardPanel = PanelNode(size: .zero)
    private let contentLayer = SKNode()
    private let overlayLayer = SKNode()
    private let cityArt = SKSpriteNode()
    private let badgePanel = PanelNode(size: .zero)
    private let badgeLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let goldIcon = SKSpriteNode()
    private let rewardLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let traitLabels = [
        SKLabelNode(fontNamed: GameUITheme.Font.medium),
        SKLabelNode(fontNamed: GameUITheme.Font.medium)
    ]
    private let favorableContainer = SKNode()
    private let disadvantagedContainer = SKNode()
    private let laneLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let attackContainer = SKNode()
    private let attackPanel = PanelNode(size: .zero)
    private let attackLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let feedbackPanel = PanelNode(size: .zero)
    private let feedbackLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)

    private var currentLayout: CountryMapScoutCardLayout?
    private var currentMetrics: Metrics?
    private var currentPresentationIsScout = false
    private var currentEntryIsEnabled = false
    private var feedbackIsVisible = false
    private var currentGoldIconTargetFrame: CGRect?
    private var currentRewardTargetFrame: CGRect?
    private var currentCountryCompleteTitleFrame: CGRect?
    private var currentCityArtTargetFrame: CGRect?
    private var currentCityArtAssetName: String?

    #if DEBUG
    struct FooterItemReadback: Equatable {
        let type: SoldierType?
        let label: String
        let multiplierText: String?
        let requestedImageName: String?
        let textureRect: CGRect?
        let iconSize: CGSize
        let targetFrame: CGRect
        let labelIsInstalled: Bool
        let iconIsInstalled: Bool
        let labelFontName: String?
        let labelFontSize: CGFloat
    }

    struct BaseContentReadback: Equatable {
        let badge: String?
        let title: String?
        let traitLines: [String]
        let favorable: String?
        let disadvantaged: String?
        let lane: String?
        let reward: String?
        let attack: String?
        let attackAlpha: CGFloat
    }

    struct LocalZPositionsReadback: Equatable {
        let base: CGFloat
        let content: CGFloat
        let overlay: CGFloat
    }

    struct FontsReadback: Equatable {
        let boldName: String
        let mediumName: String
        let title: CGFloat
        let badge: CGFloat
        let reward: CGFloat
        let trait: CGFloat
        let footer: CGFloat
        let attack: CGFloat
        let titleIsInstalled: Bool
        let badgeIsInstalled: Bool
        let rewardIsInstalled: Bool
        let traitIsInstalled: Bool
        let footerIsInstalled: Bool
        let attackIsInstalled: Bool
    }

    private var favorableRenderedItems = [RenderedFooterItem]()
    private var disadvantagedRenderedItems = [RenderedFooterItem]()
    private weak var favorablePrefixLabel: SKLabelNode?
    private weak var disadvantagedPrefixLabel: SKLabelNode?
    #endif

    private(set) var cardHitFrame: CGRect?
    private(set) var attackHitFrame: CGRect?
    private(set) var overlayHitFrame: CGRect?

    init(imageLoader: @escaping ImageLoader = { UIImage(named: $0) }) {
        self.imageLoader = imageLoader
        super.init()
        buildNodeTree()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        content: CountryMapScoutCardContent,
        layout: CountryMapScoutCardLayout,
        isEntryEnabled: Bool
    ) -> ApplyResult {
        guard let prepared = prepare(content: content, layout: layout) else {
            currentLayout = nil
            currentPresentationIsScout = false
            currentEntryIsEnabled = false
            clearHitFrames()
            return .requiredContentDoesNotFit
        }

        render(prepared, layout: layout, isEntryEnabled: isEntryEnabled)
        return .presented
    }

    func applyFeedback(text: String?, alpha: CGFloat, blocksAttack: Bool) {
        guard let text,
              !text.isEmpty,
              let layout = currentLayout,
              let metrics = currentMetrics,
              let fontSize = fittedFontSize(
                  text,
                  startingAt: metrics.feedbackSize,
                  frameWidth: (blocksAttack ? layout.overlayFrame : layout.nonBlockingOverlayFrame)
                      .insetBy(dx: metrics.feedbackHorizontalInset, dy: 0)
                      .width
              )
        else {
            feedbackIsVisible = false
            feedbackLabel.text = nil
            overlayLayer.isHidden = true
            overlayHitFrame = nil
            restoreAttackHitFrame()
            return
        }

        let frame = blocksAttack ? layout.overlayFrame : layout.nonBlockingOverlayFrame
        feedbackIsVisible = true
        feedbackLabel.text = text
        overlayLayer.alpha = alpha
        overlayLayer.isHidden = false
        feedbackPanel.update(size: frame.size)
        feedbackPanel.position = CGPoint(x: frame.midX, y: frame.midY)
        feedbackLabel.fontSize = fontSize
        feedbackLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        overlayHitFrame = frame
        if blocksAttack {
            // Blocking feedback (locked/completed/status/recoverableError)
            // covers the whole card and disables the Attack target.
            attackHitFrame = nil
        }
        // When blocksAttack == false (flavor), the overlay is confined to
        // `nonBlockingOverlayFrame`, which excludes `attackFrame`, so the
        // existing Attack target is preserved untouched and stays tappable.
    }

    func clearLayout() {
        currentLayout = nil
        currentPresentationIsScout = false
        currentEntryIsEnabled = false
        currentCityArtTargetFrame = nil
        currentCityArtAssetName = nil
        feedbackIsVisible = false
        cardPanel.isHidden = true
        contentLayer.isHidden = true
        overlayLayer.isHidden = true
        clearHitFrames()
    }

    private func buildNodeTree() {
        zPosition = GameUITheme.Z.hud
        cardPanel.zPosition = 0
        contentLayer.zPosition = 1
        overlayLayer.zPosition = 2

        addChild(cardPanel)
        addChild(contentLayer)
        addChild(overlayLayer)

        contentLayer.addChild(badgePanel)
        cityArt.name = "countryMapScoutCityArt"
        cityArt.zPosition = -1
        contentLayer.addChild(cityArt)
        contentLayer.addChild(badgeLabel)
        contentLayer.addChild(titleLabel)
        contentLayer.addChild(goldIcon)
        contentLayer.addChild(rewardLabel)
        traitLabels.forEach(contentLayer.addChild)
        contentLayer.addChild(favorableContainer)
        contentLayer.addChild(disadvantagedContainer)
        contentLayer.addChild(laneLabel)
        contentLayer.addChild(attackContainer)
        attackContainer.addChild(attackPanel)
        attackContainer.addChild(attackLabel)

        overlayLayer.addChild(feedbackPanel)
        overlayLayer.addChild(feedbackLabel)

        configureLabel(badgeLabel, horizontal: .center)
        configureLabel(titleLabel, horizontal: .left)
        configureLabel(rewardLabel, horizontal: .right)
        traitLabels.forEach { configureLabel($0, horizontal: .left) }
        configureLabel(laneLabel, horizontal: .right)
        configureLabel(attackLabel, horizontal: .center)
        configureLabel(feedbackLabel, horizontal: .center)

        badgeLabel.fontColor = GameUITheme.Color.textPrimary
        titleLabel.fontColor = GameUITheme.Color.textPrimary
        rewardLabel.fontColor = GameUITheme.Color.gold
        traitLabels.forEach { $0.fontColor = GameUITheme.Color.textSecondary }
        laneLabel.fontColor = GameUITheme.Color.textSecondary
        attackLabel.fontColor = GameUITheme.Color.textPrimary
        feedbackLabel.fontColor = GameUITheme.Color.textPrimary
        overlayLayer.isHidden = true
    }

    private func configureLabel(
        _ label: SKLabelNode,
        horizontal: SKLabelHorizontalAlignmentMode
    ) {
        label.horizontalAlignmentMode = horizontal
        label.verticalAlignmentMode = .center
        label.numberOfLines = 1
    }

    private func prepare(
        content: CountryMapScoutCardContent,
        layout: CountryMapScoutCardLayout
    ) -> PreparedPresentation? {
        let metrics = metrics(for: layout.layoutClass)
        switch content {
        case .countryComplete(let countryNumber, let finalCityName):
            let text = "Country \(countryNumber) conquered · \(finalCityName)"
            guard let fontSize = fittedFontSize(
                text,
                startingAt: metrics.titleSize,
                frameWidth: layout.cardFrame.width
            ) else {
                return nil
            }
            return .countryComplete(text: text, fontSize: fontSize)

        case .scout(let scout):
            return prepareScout(scout, layout: layout, metrics: metrics).map {
                .scout($0)
            }
        }
    }

    private func prepareScout(
        _ scout: CountryMapScoutCardContent.Scout,
        layout: CountryMapScoutCardLayout,
        metrics: Metrics
    ) -> PreparedScout? {
        if layout.isCompact {
            guard let titleFontSize = fittedFontSize(
                scout.displayTitle,
                startingAt: metrics.titleSize,
                frameWidth: layout.titleFrame.width
            ) else {
                return nil
            }
            return PreparedScout(
                scout: scout,
                metrics: metrics,
                titleFontSize: titleFontSize,
                traitLines: [],
                favorableItems: [],
                disadvantagedItems: [],
                laneText: "",
                cityImage: nil,
                cityAssetName: nil,
                goldImage: nil,
                rewardText: "",
                rewardFontSize: metrics.rewardSize,
                rewardFrame: layout.rewardFrame
            )
        }

        guard let traitWidth = layout.traitLineFrames.map(\.width).min(),
              let traitMeasure = measure(fontName: GameUITheme.Font.medium, size: metrics.traitSize),
              let footerMeasure = measure(fontName: GameUITheme.Font.medium, size: metrics.footerSize),
              let rewardMeasure = measure(fontName: GameUITheme.Font.bold, size: metrics.rewardSize),
              let fallbackMeasure = measure(
                  fontName: GameUITheme.Font.bold,
                  size: metrics.fallbackRewardSize
              ),
              let titleFontSize = fittedFontSize(
                  scout.displayTitle,
                  startingAt: metrics.titleSize,
                  frameWidth: layout.titleFrame.width
              )
        else {
            return nil
        }

        let traitText =
            "\(scout.defenseTrait.displayName) · \(scout.defenseTrait.shortDescription)"
        guard let traitLines = CountryMapScoutCardTextLayout.wrapIntoTwoLines(
            traitText,
            maximumWidth: traitWidth,
            measure: traitMeasure
        ), traitLines.count <= layout.traitLineFrames.count else {
            return nil
        }

        let favorableItems = preparedFooterItems(
            for: scout.defenseTrait.favorableSoldierTypes,
            trait: scout.defenseTrait,
            layoutClass: layout.layoutClass
        )
        let disadvantagedItems = preparedFooterItems(
            for: scout.defenseTrait.disadvantagedSoldierTypes,
            trait: scout.defenseTrait,
            layoutClass: layout.layoutClass
        )
        guard footerRequiredWidth(
            items: favorableItems,
            prefix: "+",
            metrics: metrics,
            measure: footerMeasure
        ) <= layout.favorableFrame.width,
        footerRequiredWidth(
            items: disadvantagedItems,
            prefix: "-",
            metrics: metrics,
            measure: footerMeasure
        ) <= layout.disadvantagedFrame.width
        else {
            return nil
        }

        let laneText = "Open: \(scout.exposedLane.displayName)"
        guard footerMeasure(laneText) <= layout.exposedLaneFrame.width else {
            return nil
        }

        let cityAssetName = "enemy-city"
        let cityImage = imageLoader(cityAssetName)
        let goldImage = imageLoader("gold-burst")
        let numericReward = "\(scout.goldReward)"
        let fallbackReward = "Gold \(scout.goldReward)"
        let rewardFrame: CGRect
        let rewardText: String
        let rewardFontSize: CGFloat
        if goldImage != nil {
            guard rewardMeasure(numericReward) <= layout.rewardFrame.width else {
                return nil
            }
            rewardFrame = layout.rewardFrame
            rewardText = numericReward
            rewardFontSize = metrics.rewardSize
        } else {
            let unionFrame = rewardUnionFrame(layout)
            guard fallbackMeasure(fallbackReward) <= unionFrame.width else {
                return nil
            }
            rewardFrame = unionFrame
            rewardText = fallbackReward
            rewardFontSize = metrics.fallbackRewardSize
        }

        return PreparedScout(
            scout: scout,
            metrics: metrics,
            titleFontSize: titleFontSize,
            traitLines: traitLines,
            favorableItems: favorableItems,
            disadvantagedItems: disadvantagedItems,
            laneText: laneText,
            cityImage: cityImage,
            cityAssetName: cityImage == nil ? nil : cityAssetName,
            goldImage: goldImage,
            rewardText: rewardText,
            rewardFontSize: rewardFontSize,
            rewardFrame: rewardFrame
        )
    }

    private func preparedFooterItems(
        for types: [SoldierType],
        trait: CityDefenseTrait,
        layoutClass: CountryMapLayoutClass
    ) -> [PreparedFooterItem] {
        guard !types.isEmpty else {
            return [
                PreparedFooterItem(
                    type: nil,
                    label: "None",
                    multiplierText: nil,
                    requestedImageName: nil,
                    image: nil
                )
            ]
        }

        let multiplierText = footerMultiplierText(
            trait.damageMultiplier(for: types[0])
        )
        return types.map { type in
            let frameName = "\(type.rawValue)-walk-01"
            return PreparedFooterItem(
                type: type,
                label: layoutClass == .phone ? compactName(for: type) : type.displayName,
                multiplierText: multiplierText,
                requestedImageName: frameName,
                image: imageLoader(frameName)
            )
        }
    }

    private func footerMultiplierText(_ multiplier: Double) -> String? {
        if multiplier == 1.25 { return "×1.25" }
        if multiplier == 0.80 { return "×0.80" }
        return nil
    }

    private func footerRequiredWidth(
        items: [PreparedFooterItem],
        prefix: String,
        metrics: Metrics,
        measure: (String) -> CGFloat
    ) -> CGFloat {
        CountryMapScoutCardTextLayout.footerGroupRequiredWidth(
            prefix: prefix,
            items: items.map {
                .init(label: $0.label, showsIcon: $0.image != nil)
            },
            spacing: .init(
                iconWidth: metrics.iconSize,
                prefixGap: metrics.prefixGap,
                iconLabelGap: metrics.iconLabelGap,
                itemGap: metrics.itemGap
            ),
            labelWidth: { label in
                if let fixedWidth = metrics.fixedPadLabelWidth, label != "None" {
                    return fixedWidth
                }
                return measure(label)
            }
        )
    }

    private func render(
        _ presentation: PreparedPresentation,
        layout: CountryMapScoutCardLayout,
        isEntryEnabled: Bool
    ) {
        resetVisibleContent()
        currentLayout = layout
        currentEntryIsEnabled = isEntryEnabled
        currentGoldIconTargetFrame = nil
        currentRewardTargetFrame = nil
        currentCountryCompleteTitleFrame = nil
        currentCityArtTargetFrame = nil
        currentCityArtAssetName = nil
        feedbackIsVisible = false
        overlayLayer.isHidden = true
        overlayLayer.alpha = 1
        overlayHitFrame = nil

        cardPanel.apply(size: layout.cardFrame.size, style: .normal, showsRivets: true)
        cardPanel.position = CGPoint(x: layout.cardFrame.midX, y: layout.cardFrame.midY)
        cardPanel.isHidden = false
        contentLayer.isHidden = false
        cardHitFrame = layout.cardFrame

        switch presentation {
        case .countryComplete(let text, let fontSize):
            currentPresentationIsScout = false
            currentMetrics = metrics(for: layout.layoutClass)
            titleLabel.text = text
            titleLabel.fontSize = fontSize
            titleLabel.horizontalAlignmentMode = .center
            titleLabel.position = CGPoint(x: layout.cardFrame.midX, y: layout.cardFrame.midY)
            currentCountryCompleteTitleFrame = layout.cardFrame
            attackHitFrame = nil

        case .scout(let prepared):
            currentPresentationIsScout = true
            currentMetrics = prepared.metrics
            currentEntryIsEnabled = isEntryEnabled && prepared.scout.actionTitle != nil
            renderScout(prepared, layout: layout, isEntryEnabled: isEntryEnabled)
        }
    }

    private func renderScout(
        _ prepared: PreparedScout,
        layout: CountryMapScoutCardLayout,
        isEntryEnabled: Bool
    ) {
        badgePanel.update(size: layout.badgeFrame.size)
        badgePanel.position = CGPoint(x: layout.badgeFrame.midX, y: layout.badgeFrame.midY)
        badgePanel.isHidden = false
        badgeLabel.text = "\(prepared.scout.cityNumber)"
        badgeLabel.fontSize = prepared.metrics.badgeSize
        badgeLabel.position = CGPoint(x: layout.badgeFrame.midX, y: layout.badgeFrame.midY)
        renderCityArt(prepared, layout: layout)

        titleLabel.horizontalAlignmentMode = .left
        titleLabel.text = prepared.scout.displayTitle
        titleLabel.fontSize = prepared.titleFontSize
        titleLabel.position = CGPoint(x: layout.titleFrame.minX, y: layout.titleFrame.midY)

        if layout.isCompact {
            goldIcon.isHidden = true
            rewardLabel.text = nil
            traitLabels.forEach { $0.text = nil }
            favorableContainer.removeAllChildren()
            disadvantagedContainer.removeAllChildren()
            laneLabel.text = nil
            renderAction(
                title: prepared.scout.actionTitle,
                frame: layout.attackFrame,
                fontSize: prepared.metrics.attackSize,
                isEnabled: isEntryEnabled
            )
            return
        }

        renderReward(prepared, layout: layout)
        renderTraitLines(
            prepared.traitLines,
            frames: layout.traitLineFrames,
            metrics: prepared.metrics
        )

        let favorableRendered = renderFooter(
            items: prepared.favorableItems,
            prefix: "+",
            frame: layout.favorableFrame,
            metrics: prepared.metrics,
            container: favorableContainer
        )
        let disadvantagedRendered = renderFooter(
            items: prepared.disadvantagedItems,
            prefix: "-",
            frame: layout.disadvantagedFrame,
            metrics: prepared.metrics,
            container: disadvantagedContainer
        )
        #if DEBUG
        favorableRenderedItems = favorableRendered
        favorablePrefixLabel = favorableContainer.children.first as? SKLabelNode
        disadvantagedRenderedItems = disadvantagedRendered
        disadvantagedPrefixLabel = disadvantagedContainer.children.first as? SKLabelNode
        #else
        _ = favorableRendered
        _ = disadvantagedRendered
        #endif

        laneLabel.text = prepared.laneText
        laneLabel.fontSize = prepared.metrics.footerSize
        laneLabel.position = CGPoint(x: layout.exposedLaneFrame.maxX, y: layout.exposedLaneFrame.midY)

        renderAction(
            title: prepared.scout.actionTitle,
            frame: layout.attackFrame,
            fontSize: prepared.metrics.attackSize,
            isEnabled: isEntryEnabled
        )
    }

    private func renderAction(
        title: String?,
        frame: CGRect,
        fontSize: CGFloat,
        isEnabled: Bool
    ) {
        guard let title else {
            attackContainer.isHidden = true
            attackLabel.text = nil
            attackHitFrame = nil
            return
        }

        attackPanel.apply(
            size: frame.size,
            style: isEnabled ? .primaryAction : .disabled,
            showsRivets: true
        )
        attackPanel.position = .zero
        attackLabel.text = title
        attackLabel.fontSize = fontSize
        attackLabel.position = .zero
        attackContainer.position = CGPoint(x: frame.midX, y: frame.midY)
        attackContainer.isHidden = false
        attackContainer.alpha = isEnabled ? 1 : GameUITheme.Alpha.lockedIcon
        attackHitFrame = isEnabled ? frame : nil
    }

    private func renderCityArt(
        _ prepared: PreparedScout,
        layout: CountryMapScoutCardLayout
    ) {
        guard !layout.isCompact,
              let image = prepared.cityImage,
              let assetName = prepared.cityAssetName else {
            cityArt.isHidden = true
            cityArt.texture = nil
            cityArt.size = .zero
            return
        }

        let targetFrame = CGRect(
            x: layout.cardFrame.minX + 8,
            y: layout.cardFrame.midY - min(44, layout.cardFrame.height / 2 - 10),
            width: min(80, layout.cardFrame.width * 0.24),
            height: min(88, layout.cardFrame.height - 20)
        )
        let texture = SKTexture(image: image)
        cityArt.texture = texture
        cityArt.size = aspectFit(texture.size(), in: targetFrame.size)
        cityArt.position = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        cityArt.alpha = 0.78
        cityArt.isHidden = false
        currentCityArtTargetFrame = targetFrame
        currentCityArtAssetName = assetName
    }

    private func renderReward(
        _ prepared: PreparedScout,
        layout: CountryMapScoutCardLayout
    ) {
        if let image = prepared.goldImage {
            let texture = SKTexture(image: image)
            goldIcon.texture = texture
            goldIcon.size = aspectFit(texture.size(), in: layout.goldIconFrame.size)
            goldIcon.position = CGPoint(x: layout.goldIconFrame.midX, y: layout.goldIconFrame.midY)
            goldIcon.isHidden = false
            currentGoldIconTargetFrame = layout.goldIconFrame
        } else {
            goldIcon.texture = nil
            goldIcon.size = .zero
            goldIcon.isHidden = true
        }

        rewardLabel.text = prepared.rewardText
        rewardLabel.fontSize = prepared.rewardFontSize
        rewardLabel.position = CGPoint(
            x: prepared.rewardFrame.maxX,
            y: prepared.rewardFrame.midY
        )
        currentRewardTargetFrame = prepared.rewardFrame
    }

    private func renderTraitLines(
        _ lines: [String],
        frames: [CGRect],
        metrics: Metrics
    ) {
        for (index, label) in traitLabels.enumerated() {
            guard index < lines.count else {
                label.text = nil
                continue
            }
            let frame = frames[index]
            label.text = lines[index]
            label.fontSize = metrics.traitSize
            label.position = CGPoint(x: frame.minX, y: frame.midY)
        }
    }

    @discardableResult
    private func renderFooter(
        items: [PreparedFooterItem],
        prefix: String,
        frame: CGRect,
        metrics: Metrics,
        container: SKNode
    ) -> [RenderedFooterItem] {
        container.removeAllChildren()
        let prefixLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
        configureLabel(prefixLabel, horizontal: .left)
        prefixLabel.fontColor = GameUITheme.Color.textSecondary
        prefixLabel.fontSize = metrics.footerSize
        prefixLabel.text = prefix
        prefixLabel.position = CGPoint(x: frame.minX, y: frame.midY)
        container.addChild(prefixLabel)

        guard let measure = measure(fontName: GameUITheme.Font.medium, size: metrics.footerSize) else {
            return []
        }
        var cursorX = frame.minX + measure(prefix) + metrics.prefixGap
        var renderedItems = [RenderedFooterItem]()
        for (index, item) in items.enumerated() {
            if index > 0 {
                cursorX += metrics.itemGap
            }

            var targetFrame = CGRect.zero
            var iconNode: SKSpriteNode?
            if let type = item.type, let image = item.image {
                targetFrame = CGRect(
                    x: cursorX,
                    y: frame.midY - metrics.iconSize / 2,
                    width: metrics.iconSize,
                    height: metrics.iconSize
                )
                let source = SKTexture(image: image)
                let body = SKTexture(
                    rect: SoldierAnimationGeometry(type: type).bodyRegion,
                    in: source
                )
                let icon = SKSpriteNode(texture: body)
                icon.size = aspectFit(body.size(), in: targetFrame.size)
                icon.position = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
                container.addChild(icon)
                iconNode = icon
                cursorX = targetFrame.maxX + metrics.iconLabelGap
            }

            let label = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            configureLabel(label, horizontal: .left)
            label.fontColor = GameUITheme.Color.textSecondary
            label.fontSize = metrics.footerSize
            label.text = item.label
            label.position = CGPoint(x: cursorX, y: frame.midY)
            container.addChild(label)

            let labelWidth = metrics.fixedPadLabelWidth.flatMap { item.type == nil ? nil : $0 }
                ?? measure(item.label)
            cursorX += labelWidth
            renderedItems.append(RenderedFooterItem(
                type: item.type,
                multiplierText: item.multiplierText,
                requestedImageName: item.requestedImageName,
                labelNode: label,
                iconNode: iconNode,
                targetFrame: targetFrame
            ))
        }
        if let multiplierText = items.first?.multiplierText {
            let multiplierLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            multiplierLabel.name = "footerMultiplier"
            configureLabel(multiplierLabel, horizontal: .right)
            multiplierLabel.fontColor = GameUITheme.Color.textSecondary
            multiplierLabel.fontSize = max(7, metrics.footerSize - 1)
            multiplierLabel.text = multiplierText
            multiplierLabel.position = CGPoint(x: frame.maxX, y: frame.midY)
            container.addChild(multiplierLabel)
        }
        return renderedItems
    }

    #if DEBUG
    private func footerReadbacks(
        from renderedItems: [RenderedFooterItem],
        container: SKNode
    ) -> [FooterItemReadback] {
        renderedItems.map {
            FooterItemReadback(
                type: $0.type,
                label: $0.labelNode.text ?? "",
                multiplierText: $0.multiplierText,
                requestedImageName: $0.requestedImageName,
                textureRect: $0.iconNode?.texture?.textureRect(),
                iconSize: $0.iconNode?.size ?? .zero,
                targetFrame: $0.targetFrame,
                labelIsInstalled: $0.labelNode.parent === container,
                iconIsInstalled: $0.iconNode?.parent === container,
                labelFontName: $0.labelNode.fontName,
                labelFontSize: $0.labelNode.fontSize
            )
        }
    }
    #endif

    private func resetVisibleContent() {
        badgePanel.isHidden = true
        cityArt.isHidden = true
        cityArt.texture = nil
        cityArt.size = .zero
        badgeLabel.text = nil
        titleLabel.text = nil
        goldIcon.isHidden = true
        goldIcon.texture = nil
        goldIcon.size = .zero
        rewardLabel.text = nil
        traitLabels.forEach { $0.text = nil }
        favorableContainer.removeAllChildren()
        disadvantagedContainer.removeAllChildren()
        laneLabel.text = nil
        attackContainer.isHidden = true
        attackLabel.text = nil
        feedbackLabel.text = nil
        #if DEBUG
        favorableRenderedItems = []
        disadvantagedRenderedItems = []
        favorablePrefixLabel = nil
        disadvantagedPrefixLabel = nil
        #endif
    }

    private func restoreAttackHitFrame() {
        guard currentPresentationIsScout,
              currentEntryIsEnabled,
              !feedbackIsVisible,
              let layout = currentLayout
        else {
            attackHitFrame = nil
            return
        }
        attackHitFrame = layout.attackFrame
    }

    private func clearHitFrames() {
        cardHitFrame = nil
        attackHitFrame = nil
        overlayHitFrame = nil
    }

    private func measure(
        fontName: String,
        size: CGFloat
    ) -> ((String) -> CGFloat)? {
        guard let font = UIFont(name: fontName, size: size) else {
            return nil
        }
        return { text in
            ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }
    }

    private func fittedFontSize(
        _ text: String,
        startingAt size: CGFloat,
        frameWidth: CGFloat
    ) -> CGFloat? {
        CountryMapScoutCardTextLayout.fittedFontSize(
            text,
            startingAt: size,
            minimum: 8,
            maximumWidth: frameWidth,
            measure: { [weak self] text, size in
                self?.measure(fontName: GameUITheme.Font.bold, size: size)?(text)
                    ?? .greatestFiniteMagnitude
            }
        )
    }

    private func rewardUnionFrame(_ layout: CountryMapScoutCardLayout) -> CGRect {
        CGRect(
            x: layout.goldIconFrame.minX,
            y: min(layout.goldIconFrame.minY, layout.rewardFrame.minY),
            width: layout.rewardFrame.maxX - layout.goldIconFrame.minX,
            height: max(layout.goldIconFrame.maxY, layout.rewardFrame.maxY)
                - min(layout.goldIconFrame.minY, layout.rewardFrame.minY)
        )
    }

    private func aspectFit(_ sourceSize: CGSize, in targetSize: CGSize) -> CGSize {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              targetSize.width > 0,
              targetSize.height > 0
        else {
            return .zero
        }
        let scale = min(
            targetSize.width / sourceSize.width,
            targetSize.height / sourceSize.height
        )
        return CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    }

    private func compactName(for type: SoldierType) -> String {
        switch type {
        case .infantry: return "Inf"
        case .archer: return "Arc"
        case .cavalry: return "Cav"
        case .mage: return "Mag"
        case .siege: return "Sie"
        }
    }

    private func metrics(for layoutClass: CountryMapLayoutClass) -> Metrics {
        switch layoutClass {
        case .phone:
            return Metrics(
                titleSize: 11,
                badgeSize: 11,
                rewardSize: 10,
                fallbackRewardSize: 9,
                traitSize: 9,
                footerSize: 9,
                attackSize: 13,
                feedbackSize: 13,
                feedbackHorizontalInset: 6,
                iconSize: 10,
                prefixGap: 2,
                iconLabelGap: 2,
                itemGap: 4,
                fixedPadLabelWidth: nil
            )
        case .pad:
            return Metrics(
                titleSize: 16,
                badgeSize: 16,
                rewardSize: 14,
                fallbackRewardSize: 13,
                traitSize: 12,
                footerSize: 11,
                attackSize: 16,
                feedbackSize: 16,
                feedbackHorizontalInset: 12,
                iconSize: 14,
                prefixGap: 4,
                iconLabelGap: 4,
                itemGap: 8,
                fixedPadLabelWidth: 52
            )
        }
    }
}

#if DEBUG
extension CountryMapScoutCardNode {
    var badgeTextForTesting: String? {
        badgeLabel.text
    }

    var titleTextForTesting: String? {
        titleLabel.text
    }

    var traitLineTextsForTesting: [String] {
        traitLabels.compactMap(\.text)
    }

    var traitLinePositionsForTesting: [CGPoint] {
        traitLabels.compactMap { label in
            label.text == nil ? nil : label.position
        }
    }

    var favorableItemsForTesting: [FooterItemReadback] {
        footerReadbacks(from: favorableRenderedItems, container: favorableContainer)
    }

    var disadvantagedItemsForTesting: [FooterItemReadback] {
        footerReadbacks(from: disadvantagedRenderedItems, container: disadvantagedContainer)
    }

    var favorableTextForTesting: String? {
        visibleFooterText(prefix: "+", items: favorableItemsForTesting)
    }

    var disadvantagedTextForTesting: String? {
        visibleFooterText(prefix: "-", items: disadvantagedItemsForTesting)
    }

    var favorablePrefixTextForTesting: String? {
        favorablePrefixLabel?.text
    }

    var disadvantagedPrefixTextForTesting: String? {
        disadvantagedPrefixLabel?.text
    }

    var favorablePrefixIsInstalledForTesting: Bool {
        favorablePrefixLabel?.parent === favorableContainer
    }

    var disadvantagedPrefixIsInstalledForTesting: Bool {
        disadvantagedPrefixLabel?.parent === disadvantagedContainer
    }

    var laneTextForTesting: String? {
        laneLabel.text
    }

    var rewardTextForTesting: String? {
        rewardLabel.text
    }

    var attackTextForTesting: String? {
        attackContainer.isHidden ? nil : attackLabel.text
    }

    var feedbackTextForTesting: String? {
        feedbackIsVisible ? feedbackLabel.text : nil
    }

    var attackAlphaForTesting: CGFloat {
        attackContainer.alpha
    }

    var baseContentAlphaForTesting: CGFloat {
        contentLayer.alpha
    }

    var feedbackAlphaForTesting: CGFloat {
        overlayLayer.alpha
    }

    var feedbackLabelFrameForTesting: CGRect? {
        feedbackIsVisible ? feedbackLabel.frame : nil
    }

    var feedbackLabelIsInstalledForTesting: Bool {
        feedbackLabel.parent === overlayLayer
    }

    var feedbackLabelNumberOfLinesForTesting: Int {
        feedbackLabel.numberOfLines
    }

    var feedbackFontNameForTesting: String? {
        feedbackLabel.fontName
    }

    var feedbackFontSizeForTesting: CGFloat {
        feedbackLabel.fontSize
    }

    var goldIconIsVisibleForTesting: Bool {
        !goldIcon.isHidden
    }

    var goldIconSizeForTesting: CGSize {
        goldIcon.size
    }

    var goldIconTargetFrameForTesting: CGRect? {
        currentGoldIconTargetFrame
    }

    var rewardTargetFrameForTesting: CGRect? {
        currentRewardTargetFrame
    }

    var countryCompleteTitleFrameForTesting: CGRect? {
        currentCountryCompleteTitleFrame
    }

    var cityArtAssetNameForTesting: String? {
        currentCityArtAssetName
    }

    var cityArtIsVisibleForTesting: Bool {
        !cityArt.isHidden && cityArt.texture != nil
    }

    var cityArtTargetFrameForTesting: CGRect? {
        currentCityArtTargetFrame
    }

    var rewardFontSizeForTesting: CGFloat {
        rewardLabel.fontSize
    }

    var localZPositionsForTesting: LocalZPositionsReadback {
        .init(base: cardPanel.zPosition, content: contentLayer.zPosition, overlay: overlayLayer.zPosition)
    }

    var fontsForTesting: FontsReadback? {
        guard currentMetrics != nil,
              let traitLabel = traitLabels.first,
              let footerLabel = favorableRenderedItems.first?.labelNode
        else {
            return nil
        }
        return .init(
            boldName: titleLabel.fontName ?? "",
            mediumName: traitLabel.fontName ?? "",
            title: titleLabel.fontSize,
            badge: badgeLabel.fontSize,
            reward: rewardLabel.fontSize,
            trait: traitLabel.fontSize,
            footer: footerLabel.fontSize,
            attack: attackLabel.fontSize,
            titleIsInstalled: titleLabel.parent === contentLayer,
            badgeIsInstalled: badgeLabel.parent === contentLayer,
            rewardIsInstalled: rewardLabel.parent === contentLayer,
            traitIsInstalled: traitLabel.parent === contentLayer,
            footerIsInstalled: footerLabel.parent === favorableContainer,
            attackIsInstalled: attackLabel.parent === attackContainer
        )
    }

    var baseContentReadbackForTesting: BaseContentReadback {
        .init(
            badge: badgeLabel.text,
            title: titleLabel.text,
            traitLines: traitLineTextsForTesting,
            favorable: favorableTextForTesting,
            disadvantaged: disadvantagedTextForTesting,
            lane: laneLabel.text,
            reward: rewardLabel.text,
            attack: attackTextForTesting,
            attackAlpha: attackContainer.alpha
        )
    }

    private func visibleFooterText(
        prefix: String,
        items: [FooterItemReadback]
    ) -> String? {
        guard !items.isEmpty else {
            return nil
        }
        let multiplier = items.compactMap(\.multiplierText).first
        return ([prefix] + items.map(\.label) + [multiplier].compactMap { $0 })
            .joined(separator: " ")
    }
}
#endif
