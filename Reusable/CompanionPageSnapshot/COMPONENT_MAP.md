# Component Map

```text
CompanionLiveView / CompanionSquareView
  -> CompanionScenePage
      -> RootPageTitleBar
          -> tasksPageButton
          -> bbBucksPill
      -> CompanionSceneBackground
      -> CompanionSceneBreathingFigure
      -> CompanionSceneShelfPanel
          -> visitor/gift carousel
          -> Buddy catalog
          -> catalog share image
      -> CompanionDailyTasksPage
      -> CompanionDetailOverlay
      -> BBBriefPage
```

## State boundaries

| Boundary | Current owner | Reuse replacement |
| --- | --- | --- |
| Current Buddy | `CompanionStore` | Character-selection store |
| Unlock and friendship | `CompanionRecruitmentStore` | Progress/unlock store |
| Currency | `CompanionRecruitmentStore.bbBucks` | Destination economy store |
| Visitor reports | `BBBriefStore` | Activity/report store |
| Achievements | `AchievementStickerStore` | Milestone/event store |
| Scene availability | `SceneEntitlementStore` and `PlusMembershipStore` | Theme/entitlement store |
| Visual tokens | `DesignToken` and `BBBFont` | Destination design system |
| Localization | `AppLocalization` and `Localizable.xcstrings` | Destination localization system |

## Preservation boundary

`OriginalSources` contains every top-level Swift file from the BBBuddy app target so the archived implementation retains its original type context. The primary page implementation remains in `OtherPages.swift`; unrelated source copied alongside it is supporting context, not a recommendation to reproduce BBBuddy's full architecture in another app.
