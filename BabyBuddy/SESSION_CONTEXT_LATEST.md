# BBBuddy Session Context Latest

更新时间：2026-06-17 19:20（Asia/Shanghai）

> 本文件创建于项目迁移后的新路径：`/Volumes/PSSD/Projects/codex/BBB`。
> 旧工作区曾在 `/Users/vuyin/Desktop/桌面 - vuyin的MacBook Pro - 1/codex/BBB`。
> 创建前已确认新路径下 `BBT/BabyBuddy/SESSION_CONTEXT_LATEST.md` 不存在，因此没有覆盖他人上下文。

## 当前主要工作线

正在迭代 BBBuddy iOS App 的记录页玻璃风 UI，重点是把各记录页外层统一到“记录喂养 - 瓶喂”页当前风格。

当前标准页：
- `记录喂养 - 瓶喂`
- 淡紫玻璃背景
- 顶部小圆形玻璃按钮
- 四项统计：数值在上、标签在下
- 中央素材舞台
- 左右舞台按钮
- 底部玻璃 dock
- 保存按钮使用首页日历高亮 / 底部 tab `+` 的同一套紫色渐变

## 已完成/近期变更摘要

### 喂养页

- 瓶喂页已作为视觉标准。
- 亲喂页已按瓶喂外层壳统一：
  - 中间可使用 `record_nursing_hero`。
  - 左右两侧有弧形刻度，左右分别设置，范围 5 到 30 分钟。
  - 左右计时器保留原功能。
  - 底部快捷项从 `60/90/120 ml` 改为类似 `左5右5 / 左10右10 / 左15右15`。
  - 当已有计时记录时，快捷项或手动输入覆盖前需要提醒。
- 辅食页已开始统一外层样式，素材占位为 `record_solids_bowl_hero`。
- 瓶喂左侧舞台按钮曾多次修复，目标行为是打开奶源选择（母乳/奶粉），不要打开更多信息。
- 右上角 `...` 更多信息中应只保留备注和添加图片。

### 尿布页

- 尿布页默认选中已改为“尿了”。
- 用户希望尿布页同时显示图片和“尿布从上往下掉”的动画。
- 最近实现方向：
  - 如果存在 `record_diaper_hero`，它作为中间主图片。
  - 仍叠加尿布 token 掉落动画层。
  - 不再因为有图片就跳过掉落动画。
- 注意：不要改尿布页底部保存按钮区域，用户要求后续一步步改。

### 体重/身高页

- 用户希望体重页、身高页顶部按钮、左右按钮、底部 tab/save 区域后续统一为瓶喂页样式。
- 但用户明确要求先不要一次性改底部保存区域，后续逐步修改。
- 中间图片用户说已准备好或希望先占位：
  - `record_weight_scale_hero`
  - `record_height_meter_hero`

### Assets

预留/已使用资产名：
- `record_bottle_hero`
- `record_nursing_hero`
- `record_solids_bowl_hero`
- `record_diaper_hero`
- `record_weight_scale_hero`
- `record_height_meter_hero`
- `record_icon_feeding`
- `record_icon_diaper`
- `record_icon_sleep`
- `record_icon_weight`
- `record_icon_height`

用户后续会替换真实图片，当前可以用空图集或占位，不应阻塞实现。

## 重要设计约束

- 不要改业务逻辑、保存逻辑、数据结构、导航逻辑，除非用户明确要求。
- 用户现在偏好一步步调，不要一次性大改多个页。
- 当前不要再用纯 `VStack + Spacer` 撑记录页关键布局；记录器应保持接近瓶喂页的比例坐标/分区布局。
- 记录页切换时不要短暂露出首页；最终需要同一个壳，避免 fullScreenCover 闪烁。
- iOS 版本不用考虑 iOS 26 以下兼容。
- 使用 SwiftUI Liquid Glass 可以，但不要为了系统玻璃牺牲当前视觉比例；用户曾反馈系统玻璃按钮太大且不好看。

## 视觉细节偏好

- 记录页字体应更接近首页：整体不要过粗、过大。
- 顶部统计：
  - 数值在上，标签在下。
  - 标签更小、更细、更弱。
  - 当前时间前不需要 clock icon。
- 保存按钮紫色应统一为首页日历高亮 / 底部 tab `+` 的紫色渐变。
- 未选中玻璃按钮不要看起来像纯白实心块；要有透明感。
- 选中态需要比未选中态更明确。
- 背景去掉明显粉色光，整体更偏淡紫、协调、柔和。

## 已知风险/注意事项

- `BBT/BabyBuddy/BBB/OtherPages.swift` 很大，很多记录页组件和共享玻璃组件都在这里，改动前要先定位清楚。
- `FeedingSheet.swift` 也包含大量喂养页交互逻辑，改 UI 时必须避免误改草稿、计时、保存。
- 之前 Xcode/DerivedData 曾出现 AppIcon 写入失败；如果再遇到，可能需要清理 DerivedData 或替换符合要求的 AppIcon，而不是误判 Swift 代码问题。
- 当前工作区迁移后，优先在 `/Volumes/PSSD/Projects/codex/BBB` 下运行命令，不要再改旧路径。

## 建议下一步

1. 先检查新路径下当前 `OtherPages.swift` 和 `FeedingSheet.swift` 是否包含旧路径最近的修改。
2. 按用户最新要求继续尿布页：
   - 确认 `record_diaper_hero` 图片和掉落动画是否同屏显示。
   - 若动画位置与图片不匹配，只调 token overlay 的 frame/offset，不改保存逻辑。
3. 再逐页统一体重、身高、尿布的顶部/左右按钮/底部保存区。
4. 每次小改后至少跑：
   - `xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios26.0-simulator -parse BBT/BabyBuddy/BBB/OtherPages.swift`
   - 如改喂养页，再 parse `BBT/BabyBuddy/BBB/FeedingSheet.swift`

---

# 补充上下文：项目迁移与 Buddy 资料库

更新时间：2026-06-17（Asia/Shanghai）
记录者：Codex 当前线程

## 迁移说明

- 项目已从旧本地路径迁移到移动硬盘路径：`/Volumes/PSSD/Projects/codex/BBB`。
- 旧路径曾是：`/Users/vuyin/Desktop/桌面 - vuyin的MacBook Pro - 1/codex/BBB`。
- 后续新线程应优先使用：`/Volumes/PSSD/Projects/codex/BBB/BBT/BabyBuddy`。
- 如果旧线程出现“当前工作目录缺失”，原因是线程仍绑定旧目录；新任务应在新路径新开线程。

## Buddy 资料库主文件

- 主资料库：`BBT/BabyBuddy/docs/伙伴资料库.md`。
- 接手 Buddy 工作时先读该文件，不要只依赖聊天历史。
- 该资料库是 Buddy 设定、气质、稀有度、现实分布、立绘提示词和资产占位的主源。

## Buddy 体系规则

- C01-C10：onboarding 气质测评伙伴，必须继续对应 onboarding 的气质结果。
- 非 onboarding 伙伴也必须有明确气质类型。
- 气质类型仅使用：`easy`、`intermediate`、`slow_to_warm_up`、`high_sensitivity`。
- 稀有程度仅使用：`普通`、`少见`、`稀有`、`珍稀`。
- 立绘提示词只描述动作和姿态，不写画风、镜头、材质，不出现任何外部道具、文字、icon、特效、树木、自行车等。

## 已知 Buddy 状态

- C11 尤卡 / Yuca / `piggy`：已从“补充设定”明确为 `easy`。
- C12 雪溜 / Ferry / `ferry`：已从“补充设定”明确为 `intermediate`。
- C13-C20：已按推荐 8 个动物补全资料：绵塔、洛奇、泡露、栗栗、皮诺、米卡、咻咻、糖飞。
- C21 以后由 mimo 扩充过第二轮网络热门候选。
- 最新新路径资料库当前总览显示：C01-C12 当前已接入；C13-C20 首批扩充候选；C21-C37 第二轮扩充候选；另有 3 个候补变体不占正式编号。

## mimo 第二轮候选的复查重点

此前初版 C21-C40 存在这些问题，已要求 mimo 返工：

- 顶部总览过期。
- C36/C39/C40 原本是同物种变体或重复方案，不应占正式 C 编号。
- `dun2`、`sasa2`、`rin2` 这类临时 ID 不适合进入稳定资料库。
- C39 现实分布曾写错。
- C28 的“小竹子”、C36 的“雪花”、泡温泉场景等违反无外部元素规则。
- C24 沙丘猫保护状态曾写成近危，需要按当前可靠资料复核。
- 网络热门选题需要补“网络热度依据”，不能只列 Wikipedia/IUCN。

当前资料库看起来已被 mimo 返工到 C37 正式候选，但仍建议接手者再次检查：

- C21-C37 是否都有完整详细条目。
- C21-C37 总表与详细条目是否一致。
- 是否新增了“网络热度依据”字段；如果没有，还需要补。
- 所有立绘提示词是否严格无道具、无特效、无场景元素。
- 现实分布、保护状态、稀有程度是否准确。

## 接手建议

1. 先读本文件已有记录页 UI 上下文，再读本补充段落。
2. Buddy 相关任务先打开 `docs/伙伴资料库.md`。
3. 不要直接把所有候选写入 `BabyCompanion.all`；必须先让用户确认最终入选动物。
4. 如果要修改资料库，保留已有上下文，不要覆盖整个文件。

## 补充上下文：陪伴页 / BBBuddy 档案页

更新时间：2026-06-17

以下是旧工作区最后一轮陪伴页相关工作记录。迁移后继续开发前，先在新路径核对这些改动是否已经完整带过来。

### 陪伴页重构状态

- 审核版 `CompanionSquareView` 已按“当前 Buddy 档案页”方向重构；完整开发版 `CompanionLiveView` 应保持不动。
- 当前 Buddy 档案卡包含：立绘、C 编号、中文名、英文名、物种、稀有度、气质标签、App 内一句介绍、好感度、现实世界分布。
- 气质标签已移动到档案卡顶部编号/稀有度同一行右侧。
- 现实世界分布已改为一行展示，用 `🌍` 代替“分布”文字。
- 新增“每日来访”入口卡，展示最新来访 Buddy，点击打开来访卡。
- 来访卡弹层标题从 `yesterday's` 改为“来访卡”，顺序为：昨日喂养数据 -> 当日节奏 -> 分析 -> 来访伙伴与 BBBucks 喂养。
- “BBBuddy们”是独立分区标题。
- 全部 Buddy 容器改为收藏册样式，含顶部装订夹/标签页装饰、已解锁数、Plus 预留位、三列 Buddy、locked mask、三颗心好感度和底部邀请文案。

### Buddy 数据和资源

- `BabyCompanion.all` 从 12 个扩展到 20 个。
- 新增 C13-C20：
  - C13 `alpaca_minta`：绵塔 / Minta / 羊驼宝宝
  - C14 `raccoon_rocky`：洛奇 / Rocky / 浣熊宝宝
  - C15 `seal_poro`：泡露 / Poro / 小海豹宝宝
  - C16 `hedgehog_lili`：栗栗 / Lili / 小刺猬宝宝
  - C17 `penguin_pino`：皮诺 / Pino / 小企鹅宝宝
  - C18 `lemur_mika`：米卡 / Mika / 小狐猴宝宝
  - C19 `hamster_shushu`：咻咻 / Shushu / 小仓鼠宝宝
  - C20 `sugar_glider_taffy`：糖飞 / Taffy / 小蜜袋鼯宝宝
- 资源命名规则：
  - 彩色立绘：`companion_<englishName.lowercased()>_portrait`
  - 未解锁灰图：`companion_<englishName.lowercased()>_locked_mask`
- 旧路径中已补齐 20 个 portrait imageset 和 20 个 locked mask imageset。迁移后如图片缺失，优先检查 `BBB/Assets.xcassets/buddy/` 下这些标准 asset 名。

### 用词和文档口径

- App 和文档中应统一用“宝宝”，避免“幼崽”等类似词。
- Buddy 物种名称应保持全局一致；例如欧缇统一为“亚洲小爪水獭宝宝”。
- Buddy 立绘设定要求：
  - 都是 BBBuddy app 的 Buddy。
  - 6 到 12 个月宝宝比例，整体圆润可爱。
  - 拟人化，但保留耳朵、尾巴、翅膀、花纹等动物核心特征。
  - 只允许站姿或坐姿，不允许四脚着地、趴着、倒挂。
  - 立绘描述不出现道具、文字、icon、特效、树木、自行车等外部元素。
- locked mask 图要求：
  - 单体居中，完整露出头、身体、四肢、耳朵、尾巴。
  - 可以是剪影或半剪影，但不能变成纯黑图标。
  - 保留可识别动物特征，透明背景优先。
  - 不使用道具、文字、icon、特效、复杂背景。

### 最近修复的问题

- 芬灵作为当前选择但显示未解锁：
  - 根因：`previewLockedIDs = ["fenny"]` 是全局生效，不只是测试环境。
  - 修复：`previewLockedIDs` 改为空集合，当前选择和默认解锁逻辑恢复一致。
- 未解锁灰图变深：
  - 根因：`CompanionAnimalFigure` 对 locked mask 做了 `.renderingMode(.template)`、统一染色和透明度处理。
  - 修复：locked mask 改为 `.renderingMode(.original)`，不再额外染色/降透明度，显示用户提供的原图。
- 来访卡点击“喂 1 份”崩溃：
  - 根因：`CompanionRecruitmentStore.deterministicSeed(for:)` 中普通整数乘加在 Debug 下溢出。
  - 修复：改为 wrapping arithmetic，并用 `raw & 0x7fffffff` 得到稳定正数 seed。
- `OtherPages.swift` 两处 `some View` 推断失败：
  - `metricControls`
  - `diaperHero`
  - 修复：补显式 `return`。

### 最近验证记录

旧路径最后一次 Swift 语法检查通过：

```bash
xcrun swiftc -parse BBB/Models.swift BBB/OtherPages.swift BBB/CompanionPickerView.swift BBB/RecordHomeView.swift
```

完整 `xcodebuild` 曾使用 `/tmp/BBBDerivedData` 尝试构建，但因本机 CoreSimulator/ibtool 无可用 simulator runtime，在 widget asset catalog 阶段失败；不是 Swift 语法错误。
---

## 2026-06-17 补充上下文：首页、统计、每日来访、导出、iOS 26 清理

> 本段为迁移后追加记录，保留上方既有上下文不动。

### 首页视觉与今日节奏

- 首页背景从浅紫改为灰色基底，顶部保留更明显的紫/蓝/暖色玻璃渐变，下方仍为灰色。
- 顶部区域简化：去掉 `BBBuddy`，保留日期和头像同一行。
- 指导区、今日节奏区改为更接近玻璃卡片风格。
- `今日节奏` 24 小时条改为圆角玻璃色块，并最终改为正方形，避免 iPhone 12 Pro Max 下被拉长。
- `今日记录 / X 次喂养` 改为单行展示，去掉 `今日记录` 文案。
- 时间轴改为单张白色/玻璃卡片内展示，左侧小 icon + 虚线连接；连接线高度调整为 34，非末尾行底部间距调整为 16。
- 底部 tab 按用户要求未改动。

### 首页今日节奏进入的统计分析页

- 默认展示当前宝宝所在月龄，不再先展示 `0-1月龄`。
- 可切换历史月份，不可切换未来月份。
- 当前月龄日期范围截止今天。
- 日期列表倒序，最近日期在上，例如 `D59` 优先展示，旧日期往下。
- 列表从 `VStack` 改为 `LazyVStack`，并关闭入口首屏隐式动画，缓解进入卡顿。

### 每日来访替代 yesterday's

- 首页已去掉 `yesterday's` 弹出卡片和定时触发逻辑。
- 设置页入口从 `yesterday's` 改为 `每日来访`，副标题为 `照护节奏 · 伙伴来访记录`。
- 归档页标题和空状态改为 `每日来访`。
- 来访卡文案从 `昨日产出` 改为 `来访奖励`。
- 伙伴详情中 `yesterday's` 文案改为 `每日来访`。
- 新增/使用 `DailyVisitorReportFactory`：每日来访 report 现在由陪伴页/归档页按需生成并保存，不再由首页弹出链路生成。
- 内部模型名 `YesterdayReport` 暂未重命名，主要为避免 Codable/key 数据迁移扩大范围；对用户可见文案已改为每日来访。

### 设置页 CSV 导出

- 设置页新增 `数据导出` 功能。
- 可导出全部历史记录为 CSV，保存流程走系统分享面板，用户可选择“存储到文件”。
- CSV 覆盖喂养、尿布、睡眠、体重、身高。
- 喂养记录如一次包含多个子项，会拆成多行，并保留 `source_session_id`。

### iOS 26 迁移清理

- 项目 deployment target 已确认是 iOS 26.0。
- 已清理 Swift 源码中的 `UIScreen.main` / `main.bounds` / `main.scale` 用法：
  - `FeedingSheet.swift`
  - `LiveIslandSceneView.swift`
  - `OtherPages.swift`
  - `CompanionPickerView.swift`
- 替代方式包括 SwiftUI `onGeometryChange`、`GeometryReader`、`containerRelativeFrame`、`windowScene?.screen.scale` / `traitCollection.displayScale`。

### 验证记录

- 多次使用 `xcrun swiftc -parse ...` 验证相关 Swift 文件，最近关键检查均通过。
- 完整 `xcodebuild -quiet -project BBB.xcodeproj -scheme BBB -destination generic/platform=iOS Simulator CODE_SIGNING_ALLOWED=NO build` 多次出现超过一分钟无输出的 Xcode 后端卡住情况，因此通常中断；完整 build 未稳定拿到结果。

### 后续注意事项

- 当前仓库工作树很脏，包含大量既有修改、删除和未跟踪文件。不要随意 revert、reset 或清理不属于当前任务的改动。
- 后续编辑前优先确认新路径 `/Volumes/PSSD/Projects/codex/BBB/BBT/BabyBuddy`，不要继续在旧桌面路径下改。
- 用户非常在意不覆盖别人上下文；如未来需要更新本文件，先读取现有内容，再追加或局部更新。
- 对外 UI 文案应使用 `每日来访`，避免再出现 `yesterday's`。


---

## 2026-06-17 补充上下文：桌面小组件 / WidgetKit 最近活动

> 本段为迁移后追加记录，保留上方既有上下文不动。来源是旧路径最后一轮桌面小组件排查与实现。后续继续 Widget、锁屏、实时活动、灵动岛时先读本段。

### 用户要求

- 先从桌面小组件开始，不一次性改锁屏、实时活动和灵动岛。
- 小组件优先展示 3 个最重要 activity：
  - 最近喂养，显示距离上次的时间。
  - 最近尿布，显示距离上次的时间。
  - 最近睡眠，显示距离上次的时间。
- 做 3 个尺寸：small / medium / large。
- 视觉参考用户给的 Widget 截图，但颜色、字体、风格使用 BBBuddy 自己的规范。
- 图标必须使用项目资产里的 `rhythm_feeding_icon`、`rhythm_diaper_icon`、`rhythm_sleep_icon`，不要继续使用 SF Symbols。
- 颜色参考“今日节奏”的颜色设置，并调整为更统一的玻璃/柔和视觉风格。

### 已实现方向

- 旧的 Last Feeding Widget 已被替换为 Recent Care Activity Widget 思路。
- `BaByBuddyWidget/BaByBuddyWidgetBundle.swift` 中主要结构：
  - `CareActivityWidgetProvider`
  - `CareActivityWidgetEntry`
  - `RecentCareActivityKind`
  - `RecentCareActivity`
  - `CareActivityWidgetView`
- Widget 继续沿用 kind：`WidgetStorageKey.lastFeedingWidgetKind` / `v.babybuddy.LastFeeding`，这样不扩大系统配置迁移范围。
- 支持 `.systemSmall`、`.systemMedium`、`.systemLarge`。
- Timeline 使用多个刷新点：0、15、30、45、60、90、120、180、240、360 分钟，保证“距离上次”文本可更新。
- 数据来源：
  - 喂养：`WidgetStorageKey.feedingSessions`
  - 宝宝信息：`WidgetStorageKey.babyInfo`
  - 尿布/睡眠：新增或使用 `WidgetStorageKey.careRecords = "care_records_v1"`
- `ActivityStore.persistCareRecords()` 会把 care records 同步写入 App Group，并调用 `WidgetCenter.shared.reloadTimelines(ofKind: WidgetStorageKey.lastFeedingWidgetKind)`。

### 样式与资源

- 三个 activity 的颜色参考今日节奏：
  - 喂养：偏紫，约 `#BDA6F2`
  - 尿布：偏金黄，约 `#D8A64E`
  - 睡眠：偏蓝紫，约 `#8F93E8`
- 小尺寸布局为 1 个大卡 + 2 个小卡的 mosaic。
- 中尺寸布局为 3 个横向 activity 卡。
- 大尺寸布局为 3 条更完整的 activity row。
- Widget 中的图标路径应是图片资源：
  - `.rhythmFeedingIcon`
  - `.rhythmDiaperIcon`
  - `.rhythmSleepIcon`
- 若用户仍看到 SF Symbol，优先排查是否运行的是旧扩展包或目标依赖没有触发重建，而不是先怀疑 SwiftUI 视图分支。

### 关键排查结论

- 用户曾反馈：多次运行、重新添加小组件后仍是之前 SF Symbol 版本。
- 根因之一：主 App target 之前没有显式依赖 `BaByBuddyWidgetExtension`，运行 `BBB` scheme 时可能嵌入旧的 Widget extension。
- 已在 `BBB.xcodeproj/project.pbxproj` 中为 `BBB` target 增加对 `BaByBuddyWidgetExtension` 的 target dependency。
- 用户随后粘贴 Widget 崩溃栈，关键帧包括：
  - `SwiftUI.CodableCGImage.export`
  - `_ArchivedViewHost.archiveStates`
  - `PNGWritePlugin::writePNG`
  - `_CSIRenditionBlockData _allocateImageBytes`
- 该栈更像 WidgetKit 在归档小组件视图时处理图片资源崩溃，不是“白底吞图”。
- 进一步发现：不要把主 App 的完整 `BBB/Assets.xcassets` 直接作为 Widget extension 的资源；它可能让扩展打包大量大图，增加 Widget 归档风险。

### Widget 资产处理

- Widget extension 应使用独立资产目录：`BaByBuddyWidget/Assets.xcassets`。
- 该目录只放 Widget 必需的 3 个 rhythm icon：
  - `rhythm_feeding_icon.imageset`
  - `rhythm_diaper_icon.imageset`
  - `rhythm_sleep_icon.imageset`
- 旧路径中曾从主 App 资产生成小尺寸副本：
  - 1x：64x64
  - 2x：128x128
  - 3x：192x192
- `project.pbxproj` 中 Widget target 的 Resources phase 应指向 `BaByBuddyWidget/Assets.xcassets`，不要指向主 App 的 `BBB/Assets.xcassets`。
- 后续如新路径中 Widget 仍崩溃，先检查生成后的 `BaByBuddyWidgetExtension.appex/Assets.car` 是否只包含这 3 个 rhythm icon，而不是整个主 App asset catalog。

### 旧路径最后验证记录

旧路径最后验证通过过：

```bash
xcodebuild -quiet -project BBB.xcodeproj -scheme BBB -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

并检查过嵌入到 App 内的 Widget 扩展资产：

```bash
xcrun assetutil --info /Users/vuyin/Library/Developer/Xcode/DerivedData/BBB-dacgdeozyfdzehfysugxbuslttem/Build/Products/Debug-iphonesimulator/BBB.app/PlugIns/BaByBuddyWidgetExtension.appex/Assets.car
```

当时确认 `Assets.car` 中只有：

- `rhythm_diaper_icon` 1x/2x/3x
- `rhythm_feeding_icon` 1x/2x/3x
- `rhythm_sleep_icon` 1x/2x/3x
- 少量 packed assets

### 迁移后接手建议

1. 先在新路径 `/Volumes/PSSD/Projects/codex/BBB/BBT/BabyBuddy` 检查这些旧路径改动是否完整迁移：
   - `BBB.xcodeproj/project.pbxproj`
   - `BBB/Models.swift`
   - `BBB/ActivityStore.swift`
   - `BaByBuddyWidget/BaByBuddyWidgetBundle.swift`
   - `BaByBuddyWidget/Assets.xcassets`
2. 如果用户继续反馈小组件仍是 SF Symbol：
   - 先确认 `BaByBuddyWidgetBundle.swift` 是否还存在 `Image(systemName:)` 的活动图标路径。
   - 再确认 `BBB` target 是否依赖并嵌入最新 `BaByBuddyWidgetExtension`。
   - 再检查 built app 内 `PlugIns/BaByBuddyWidgetExtension.appex/Assets.car`。
3. 如需要重测，优先用 `BBB` scheme 构建主 App，而不是只 build Widget target；用户实际运行 App 时依赖主 App 中嵌入的扩展。
4. 不要为解决 Widget 问题清理或 revert 其他大量工作树修改。当前项目有很多并行改动，必须小范围处理。

## 补充上下文：appstore-review 双版本审核分支（2026-06-17）

> 这段来自项目迁移前的 appstore-review 工作流整理；当前项目已迁移到 `/Volumes/PSSD/Projects/codex/BBB`。本段仅追加记录，避免覆盖其他线程上下文。

### 分支与版本定位

- 当前审核提交分支：`appstore-review`
- `APPSTORE_REVIEW` 是提交 App Store 审核 / TestFlight 审核用的版本开关。
- 审核版不展示“审核版”字样，只展示普通版本号，例如 `版本 1.0 (12)`。
- 开发版 / 非审核版功能更多，可以在个人页展示 `测试版` 标识，并附带版本号。
- 记录页保持不变。

### 审核版产品要求

- 成长页：审核版只保留 `相册` 和 `徽章册`，不显示书籍 / 直播等更复杂入口。
- 陪伴页：底部 tab 文案仍叫 `陪伴`，不能改成 `伙伴广场`。
- 陪伴页内容：审核版不显示直播陪伴页，而展示 BBBuddy 档案选择页的样式；避免自定义伙伴广场页面和右上角进入的 BBBuddy 页重复。
- 开发版：保留完整功能，包括直播陪伴、书籍等内部开发内容。

### 相关代码触点

- `BBB/AppVariant.swift`
  - 通过 `#if APPSTORE_REVIEW` 提供 `AppVariant.isAppStoreReview`。
  - `AppVariant.profileVersionText`：审核版只返回版本号；开发版返回 `测试版 · 版本 ...`。
- `BBB.xcodeproj/project.pbxproj`
  - BBB target 的 Debug / Release `SWIFT_ACTIVE_COMPILATION_CONDITIONS` 需要包含 `APPSTORE_REVIEW`，这样真机调试和 Release 审核构建都走审核 UI。
- `BBB/Models.swift`
  - `RootTab.companion.title` 应保持为 `陪伴`。
- `BBB/ContentView.swift`
  - 审核版 companion tab 使用 `CompanionSquareView()`。
  - 非审核版继续使用 `CompanionLiveView()`。
- `BBB/OtherPages.swift`
  - `CompanionSquareView` 应包装 `CompanionPickerView(isPresented: .constant(true), showsCloseButton: false, dismissesOnSelection: false, bottomContentPadding: 116)` 这一类嵌入式 BBBuddy 页面，而不是另一套重复的伙伴广场 UI。
- `BBB/CompanionPickerView.swift`
  - 需要保留嵌入式与 sheet 两种场景参数：
    - `showsCloseButton`
    - `dismissesOnSelection`
    - `bottomContentPadding`
- `BBB/GrowthView.swift`
  - 审核版走 `GrowthReviewView()`，只显示 `相册` 和 `徽章册`。
  - 非审核版保留原书本轮播体验。
- `BBB/ProfileView.swift`
  - 个人页底部版本信息根据 `AppVariant` 区分：审核版只显示版本号，开发版显示 `测试版`。

### 已通过的快速校验（迁移前路径执行）

- `swiftc -D APPSTORE_REVIEW -parse BBB/*.swift`
- `swiftc -parse BBB/*.swift`
- `plutil -lint BBB.xcodeproj/project.pbxproj BBB/Info.plist BBB/BBB.entitlements BaByBuddyWidget/Info.plist BaByBuddyWidgetExtension.entitlements`
- `xcodebuild -project BBB.xcodeproj -scheme BBB -showBuildSettings -configuration Debug` 中 BBB target 显示 `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG APPSTORE_REVIEW`。

### 后续注意

- 迁移后应在新路径 `/Volumes/PSSD/Projects/codex/BBB/BBT/BabyBuddy` 重新核对上述文件，因为当前 worktree 已包含大量其他线程 / 用户改动，不能回滚或覆盖。
- 如果真机仍看到直播界面或书籍界面，优先检查当前运行的 scheme / configuration 是否来自 BBB target 且带有 `APPSTORE_REVIEW`，然后执行 Clean Build Folder，必要时删除 iPhone 上旧 app 再重新安装。
- 当前 `SESSION_CONTEXT_LATEST.md` 已有其他上下文，后续继续追加小节，不要整文件覆盖。

---

## 2026-06-17 补充上下文：BabyBuddy Plus 会员入口与 StoreKit 订阅

> 本段在新路径 `/Volumes/PSSD/Projects/codex/BBB/BBT/BabyBuddy` 追加，保留上方已有上下文不动。

### 已迁移/已存在的 Plus 相关实现

- `BBB/PlusMembershipStore.swift`
  - StoreKit 2 会员状态层。
  - 商品 ID 固定为：
    - `v.babybuddy.plus.monthly`
    - `v.babybuddy.plus.yearly`
    - `v.babybuddy.plus.lifetime`
  - 对外状态包括 `isPlusActive`、`activePlan`、`products`、`purchaseState`、`statusTitle`、`profileSubtitle`。
  - 负责加载商品、购买、恢复购买、监听 transaction updates、刷新 current entitlements。
  - 终身商品购买后显示为 `终身会员`。
- `BBB/PlusMembershipView.swift`
  - Plus 会员页。
  - 文案定位：`和家人一起记录宝宝日常，把成长变成可以回看的纪念。`
  - 商品卡展示：月付、年付、终身；年付默认高亮推荐。
  - 包含开通、恢复购买、管理订阅入口。
  - 权益分组：
    - 一起照顾：家庭共享同步。
    - 留下纪念：无限制拍立得、无限制成就徽章、稀有 Buddy。
    - 看见成长：周/月成长回顾、完整历史导出。
    - 完整体验：全部小组件、全部 App 桌面图标、持续解锁 Plus 新功能。
  - 未实现或未测试权益统一显示 `规划中`，避免误导用户。
- `BBB/BBBApp.swift`
  - 注入 `PlusMembershipStore.shared`。
  - App 启动时调用 `configure()`。
  - App 回到 active 时刷新会员 entitlement。
- `BBB/ProfileView.swift`
  - 个人中心增加 `BabyBuddy Plus` 入口。
  - 会员入口副标题由 `PlusMembershipStore.profileSubtitle` 控制。
  - `家庭共享` 已接入 Plus 门槛：
    - 非 Plus 用户点击进入 Plus 会员页。
    - Plus 用户进入现有 `FamilySharingView`。
  - 目前只把家庭共享作为首个实际 Plus gate，未对拍立得、成就、Buddy、小组件、桌面图标做硬限制。
- `BBB.xcodeproj/project.pbxproj`
  - `PlusMembershipStore.swift` 和 `PlusMembershipView.swift` 已加入 BBB target。
- `docs/babybuddy-plus.md`
  - 记录 App Store Connect 商品配置、本地 StoreKit 测试步骤、已实现范围和后续权益接入顺序。

### 会员产品边界

- 免费版继续保留基础记录能力：喂养、睡眠、尿布、宝宝资料、基础 Buddy、基础成就/拍立得体验。
- Plus 首版定位是：家庭协作、纪念创作、成长回顾、外观扩展。
- UI 文案使用 `持续解锁 Plus 新功能`，不要写成 `未来全部功能更新`。
- 导出权益文案使用 `完整历史导出`，不要暗示免费用户无法取回基础数据。
- 白噪音和睡眠相关权益只能描述为睡眠环境与安抚辅助，不宣称治疗效果。

### 商品配置要求

- App Store Connect 需要配置：
  - 自动续期订阅：`v.babybuddy.plus.monthly`，7 天试用。
  - 自动续期订阅：`v.babybuddy.plus.yearly`，7 天试用。
  - 非消耗型项目：`v.babybuddy.plus.lifetime`，无试用。
- 月付和年付放同一订阅组，建议组名 `BabyBuddy Plus`。
- 终身商品不要放进订阅组。
- Xcode 本地 StoreKit 测试可按 `docs/babybuddy-plus.md` 创建 `BabyBuddyPlus.storekit`，再在 scheme Run Options 里选择该配置。

### 后续建议接入顺序

1. 家庭共享同步：已完成入口 gate，后续可增加会员页到家庭共享的更明确路径。
2. 完整历史导出：当前已有设置页 CSV 导出能力，后续可判断 Plus 后开放完整历史导出；免费版保留基础导出或提示说明。
3. 拍立得与成就徽章数量：免费版保留基础体验，Plus 移除数量限制。
4. 稀有 Buddy：Buddy 选择页增加 Plus 标记和开通引导。
5. 全部小组件：新增更多 widget kind 后，再按 Plus 状态决定展示和引导。
6. 全部 App 桌面图标：配置 Alternate Icons 后开放 Plus 选择入口。
7. 周/月成长回顾：基于现有记录、每日来访和统计页扩展，避免医疗化判断。

### 验证记录

- 旧路径实现阶段曾通过：
  - `xcrun swiftc -parse BBB/PlusMembershipStore.swift BBB/PlusMembershipView.swift BBB/ProfileView.swift BBB/BBBApp.swift`
  - `xcodebuild -project BBB.xcodeproj -scheme BBB -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- 迁移后新路径已确认这些 Plus 文件和 project target 引用存在。
- 新路径当前工作树很脏，包含大量既有修改、删除和未跟踪文件；不要为了 Plus 任务回退或清理无关改动。


---

## 补充上下文：成长页个人主页式改版

更新时间：2026-06-17（Asia/Shanghai）
记录者：Codex 当前线程追加，未覆盖本文件已有上下文。

### 路径说明

- 当前项目新路径：`/Volumes/PSSD/Projects/codex/BBB`。
- App 工程根目录：`/Volumes/PSSD/Projects/codex/BBB/BBT/BabyBuddy`。
- 后续成长页相关任务请优先在新路径下操作，不要再修改旧路径。

### 成长页目标

成长页 `BBB/GrowthView.swift` 已从旧“成长书本轮播”方向改为个人主页式成长中心：

- 页面背景使用首页同源 `HomeSoftBackground()`。
- 顶部为玻璃质感宝宝资料区。
- 中部为 3 段式 tab：`日历` / `拍立得` / `徽章`。
- 下方内容随 tab 切换，不再进入旧全屏书本内页。

### 资料模型变更

`BBB/Models.swift` 中 `BabyProfileData` 已新增：

- `heightCm: Double?`
- `weightKg: Double?`

兼容要求：

- 旧本地数据或 CloudKit 快照缺字段时应保持 `nil`。
- 成长页空值展示为 `-- cm`、`-- kg`。
- `BabyInfoEditView` 已增加身高、体重编辑行，允许为空。

### 成长页当前设计状态

最近一轮根据截图反馈已调整：

- 页面背景继续使用首页背景，不另做奇怪渐变底。
- 日历区容器改为浅背景上的白色/半透明白卡，而不是白底灰卡。
- 顶部头像 header：
  - 有头像照片时，采用业内常见的头像照片模糊封面 + 白色渐变遮罩方案。
  - 无头像照片时，回退首页同源浅渐变。
- 宝宝头像、名字、出生天数间距已重新调整。
- 已移除“男宝/女宝”单独展示。
- 出生天数改为名字下方展示。
- 月份标题支持左右切换。
- 日期圆点暂时不可点击，后续每日汇总页可以再接入跳转。
- 拍立得 tab 在空数据下会显示最近每日占位卡，不再整页空白。
- 拍照入口仍作为拍立得列表第一张卡，打开 `LiveIslandCameraLabView()`。
- 徽章 tab 使用 `BabyAchievementsView(showsHeader: false, isEmbedded: true)`，不再显示“宝宝成就”标题和已解锁数量。

### 相关文件

- `BBB/GrowthView.swift`
  - 新成长页主实现。
  - 当前在 git 状态中可能仍是未跟踪文件，注意确认 target membership / project file。
- `BBB/OtherPages.swift`
  - `BabyAchievementsView` 已增加：
    - `showsHeader: Bool`
    - `isEmbedded: Bool`
  - 完整徽章页保持原标题和进度；成长页内嵌时隐藏标题和进度。
- `BBB/BabyInfoEditView.swift`
  - 已加入身高、体重输入。
- `BBB/Models.swift`
  - `BabyProfileData` 与 `BabyProfileStore.create(...)` 已支持身高体重。
- `BBB.xcodeproj/project.pbxproj`
  - 需要确保 `GrowthView.swift` 在 Sources 中。

### 拍立得数据来源

成长页拍立得使用现有：

- `LiveIslandCameraLabStore.polaroids`
- `LiveIslandPolaroid`
- `LiveIslandCameraLabStore.image(for:)`

注意事项：

- 当前 store 从 Documents 下 `LiveIslandCameraLab/lab_state.json` 读取。
- 若用户之前没有拍过照片，`polaroids` 为空是正常的。
- 空状态现在用每日占位卡处理，不造假数据。
- 原拍立得入口如果进不去，先检查 `LiveIslandCameraLabView()` 是否还在工程里；新路径当前 git 状态里显示 `BBB/LiveIslandCameraLabView.swift` 被删除，同时 `Models.swift` 内也可能仍有相机实验视图实现，接手时需要核对真实代码位置。

### 验证记录

旧路径最后一次验证结果：

- `xcrun swiftc -parse BBB/GrowthView.swift BBB/ProfileView.swift BBB/BabyInfoEditView.swift BBB/Models.swift BBB/HomeView.swift BBB/OtherPages.swift` 通过。
- 完整 `xcodebuild` 被本机 CoreSimulator / Widget asset catalog 环境问题挡住：
  - `No available simulator runtimes for platform iphonesimulator`
  - `CoreSimulatorService connection became invalid`

迁移后建议在新路径重新验证：

```bash
cd /Volumes/PSSD/Projects/codex/BBB/BBT/BabyBuddy
xcrun swiftc -parse BBB/GrowthView.swift BBB/ProfileView.swift BBB/BabyInfoEditView.swift BBB/Models.swift BBB/HomeView.swift BBB/OtherPages.swift
xcodebuild -project BBB.xcodeproj -scheme BBB -destination "generic/platform=iOS Simulator" -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

如果仍失败且错误仍是 simulator runtime / asset catalog，不要误判为成长页 Swift 代码问题。

### 后续建议

1. 先在新路径确认 `GrowthView.swift` 是否已加入 project sources。
2. 用模拟器或预览实际看三种 tab：
   - 日历：背景和白卡层级是否符合首页。
   - 拍立得：无照片时是否有每日占位。
   - 徽章：是否隐藏标题和解锁数量。
3. 用户后续提到每日汇总页时，再给日期圆点接跳转或占位详情页。
