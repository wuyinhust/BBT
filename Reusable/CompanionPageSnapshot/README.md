# BBBuddy Companion Page Snapshot

This directory preserves the complete source context for the BBBuddy companion page as it existed in the local working tree on 2026-08-27.

## Why this snapshot exists

The current companion page is being redesigned. This snapshot keeps the existing implementation available for reuse in other apps without committing the BBBuddy working tree's unrelated in-progress changes.

The snapshot is intentionally source-faithful rather than presented as a standalone Swift Package. The page is coupled to BBBuddy's stores, reporting flow, design tokens, localization, and asset catalog. All top-level Swift source files from the app target are included so that a future extraction does not silently omit a required type.

## Primary entry points

- `OriginalSources/OtherPages.swift`
  - `CompanionLiveView`
  - `CompanionSquareView`
  - `CompanionScenePage`
  - scene picker and scene background
  - daily-task page
  - visitor/gift carousel and catalog panel
  - catalog sharing
- `OriginalSources/CompanionPickerView.swift`
  - Buddy detail overlay
  - Buddy figure rendering
- `OriginalSources/ContentView.swift`
  - root title bar and companion-tab routing
- `OriginalSources/Models.swift`
  - Buddy catalog, recruitment, friendship, BB Bucks, scene entitlements, design tokens, feedback primitives
- `OriginalSources/BBBrief.swift`
  - visitor report detail flow used by the companion page
- `OriginalSources/AchievementStickerStore.swift`
  - milestone/achievement data used by companion-related surfaces
- `OriginalSources/BBBApp.swift`
  - environment-store ownership and injection

## Assets

- `Assets.xcassets/buddy/` contains the Buddy artwork used by the page.
- `Assets.xcassets/scenes/` contains the current companion-scene backgrounds.
- `Assets.xcassets/common/bbbucks_coin.imageset/` contains the BB Bucks coin.

## Reuse guidance

For another app, begin with `CompanionScenePage` and replace these BBBuddy-specific boundaries:

1. `CompanionStore` and `CompanionRecruitmentStore` with the destination app's character and unlock stores.
2. `BBBriefStore` and `BBBriefPage` with the destination app's report/detail route.
3. `AchievementStickerStore` with the destination app's event or milestone source.
4. `DesignToken`, `BBBFont`, and localized strings with the destination app's theme and copy.
5. `RootPageTitleBar` and the custom bottom dock with the destination app's shell.

Do not copy the entire `OriginalSources` directory into another target. It is a preservation snapshot. Extract only the primary components and replace the boundaries above.

## Provenance

- Source repository: `wuyinhust/BBT`
- Base commit: `13c9ae343420c807c2473aea0fa599e86e60380b`
- Snapshot date: `2026-08-27`
- Source state: local working-tree snapshot, including the current uncommitted companion-page implementation

No build products, DerivedData, credentials, user data, or local configuration files are included.
