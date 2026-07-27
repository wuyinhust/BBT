# Performance Audit - 2026-07-07

## 范围

本次只做不改功能语义的卡顿排查与低风险优化。重点检查 SwiftUI 重复渲染、定时器、滚动偏移状态、图片解码、照片/贴纸处理、列表与滚动视图、阴影/模糊/材质等可能导致掉帧的位置。

## 已改动

### BabyBuddy/BBB/Models.swift

- `BabyAvatarContentView` 不再无条件包一层 `TimelineView`。只有 `motionEnabled == true` 时才进入 24fps 动画时间线；静态头像走普通视图，避免列表、卡片、导航栏里所有头像持续刷新。
- 照片头像不再在 `body` 内直接执行 `UIImage(data:)`。新增 `DecodedAvatarPhotoView`，把 Data 解码放到 `.task(id:)` 里，并用 utility priority 后台任务完成，减少 SwiftUI body 重算时的主线程解码压力。

### BabyBuddy/BBB/RecordHomeView.swift

- `StatisticsAnalysisView` 的节奏行改为每个日期先生成 `RhythmAnalysisDaySummary`。同一天的喂养、照护、睡眠数据只查一次，时间轴和摘要共用同一份结果。
- 统计页日期格式化器改为静态缓存，避免列表中每一行重复创建 `DateFormatter`。
- 移除了统计页中未使用的 `rhythmKinds` 辅助函数，减少无效代码干扰。

### BabyBuddy/BBB/OtherPages.swift

- `MilestoneLearningPathContentView` 不再把每一次滚动偏移都写入 `@State`。当前日期可见性只在结果变化时更新，悬浮按钮收起状态按 24pt 滚动桶更新。
- 滚动停止后的展开任务只在向下滚动时创建，并在后续滚动桶变化时取消旧任务，减少快速滚动期间的动画和任务抖动。

## 可改动但本次未改

- `FeedingSheet` 内的一秒定时器在 sheet 存在期间持续运行。可以进一步按录制状态或可见区域降频，但它关联草稿时间、自动保存与进行中状态，本次不改变行为。
- `ContentView` 内存在全局一秒定时器。当前逻辑主要在有 active draft 时更新，可继续观察；若运行时 Instruments 证明它触发大范围刷新，再集中到 draft store 层处理。
- `FeedingSheet`、`RecordHomeView`、`OtherPages` 有较多 `.blur`、多层 `.shadow`、`.ultraThinMaterial` 与渐变叠加。它们可能触发离屏渲染；本次不削弱视觉，因为会改变产品观感。
- 成就相册扫描和相机/相册导入仍有 `UIImage(data:)`、大图裁切和 Vision/CI 处理。多数已在用户动作或后台任务里执行；进一步优化可增加缩略图预热、请求取消、分批并发限制和更严格的 degraded image 过滤。
- 统计页的 period summary 目前仍在视图层按当前 store 生成。后续可以在 store 层增加 revision token 和缓存，但这会扩大状态模型改动范围。
- 多处 `DateFormatter()` 仍分散在非滚动热点或低频交互路径。可以后续统一为 formatter cache，但本次只处理统计列表热点。

## 未改动与原因

- 没有重构现有导航、记录、贴纸、相册、睡眠等功能流程，避免把性能优化变成功能变更。
- 没有删除大面积视觉效果或重画组件，因为缺少 Instruments 帧时间证据时，这类调整容易变成主观设计改动。
- 没有把所有滚动视图改成 `List` 或虚拟化容器。当前主要长列表已使用 `LazyVStack`/`LazyVGrid`；本次优先处理状态更新和重复计算。

## 验证记录

- `xcrun swiftc -parse BabyBuddy/BBB/*.swift BabyBuddy/BaByBuddyWidget/*.swift`：通过。
- `git diff --check`：通过。
- `plutil -lint BabyBuddy/BBB/Info.plist BabyBuddy/BBB/BBB.entitlements BabyBuddy/BaByBuddyWidget/Info.plist BabyBuddy/BaByBuddyWidgetExtension.entitlements`：通过。
- `xcodebuild -list -project BabyBuddy/BBB.xcodeproj`：能读取项目、target 与 scheme；命令同时输出当前机器的 CoreSimulator/provisioning profile 噪声。
- `xcodebuild -project BabyBuddy/BBB.xcodeproj -scheme BBB -configuration Debug -destination generic/platform=iOS -derivedDataPath ... CODE_SIGNING_ALLOWED=NO build`：未完成，失败点是 `actool` 报 `No available simulator runtimes for platform iphonesimulator`，属于当前 CoreSimulator/asset catalog 环境问题，不是 Swift 编译诊断。
- app 源文件 `swiftc -typecheck`：未完成，失败点是唯一的 `#Preview` 宏需要外部 `swift-plugin-server`，沙盒中返回 malformed response；排除该文件后又会因为其他视图依赖其中的 `SafetyStatusBar`/`SafetyTipFooter` 类型而产生非等价误报。
