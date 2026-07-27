# BBBuddy 本地化说明

## 支持语言

- 简体中文（`zh-Hans`，开发语言）
- 繁体中文（`zh-Hant`）
- English（`en`）

App 默认使用 iOS“语言与地区”中优先级最高的受支持语言。用户也可以在：

`设置 → App → BBBUDDY → 语言`

为 BBBUDDY 单独选择语言。项目不维护第二套 App 内语言状态，避免系统设置、Widget、日期格式和 App 自己的选择相互冲突。

## 实现约定

- 静态 SwiftUI 文案进入 `BBB/Localizable.xcstrings`。
- 相机、相册、麦克风和运动权限说明进入 `BBB/InfoPlist.xcstrings`。
- `AppLocalization` 只处理模型或格式化代码拼出的动态文本；未知 key 原样返回，因此宝宝名字、备注等用户内容不会被翻译。
- 日期和时间通过 `AppDateTimeFormat` 使用 App 语言，并保留用户的地区、日历和 12/24 小时制偏好。
- 时长、天数、记录数、人数、照片数和月龄通过 `AppQuantityFormat` 处理英语单复数与中文量词。
- 列表使用 `ListFormatter`，不手写中文顿号或英文逗号/and。
- `kg`、`cm`、`ml` 等现有记录单位保持数据模型的标准单位；显示名称可以本地化，但不因语言切换改变已记录数值。
- App 与 Widget 共用同一套 String Catalog 和格式化入口。

## 不翻译的产品词

以下名称保持产品定义的拼写和大小写，不做字面翻译：

- BBBuddy
- BBBUCKS
- EASY
- YOU
- Yearning
- Plus（作为会员产品名的一部分）
- Buddy 的英文专名，如 Loppy、Sika、Fenny

英文界面优先显示 Buddy 英文专名；简体和繁体中文界面保留中文专名。物种、气质、介绍和现实分布按所选语言重新表达。

## 新增文案流程

1. SwiftUI 静态文案直接使用支持本地化的 `Text`、`Button`、`Label`、`navigationTitle` 等原生 API。
2. 枚举或模型返回的展示文案使用 `.localized`，不要修改持久化 raw value。
3. 含数量的句子使用 `AppQuantityFormat` 或新增语义格式 key，不直接拼接“条/位/张/分钟”。
4. 含多项内容的自然语言列表使用 `AppLocalization.list(_:)`。
5. 新增翻译后至少运行：
   - `xcrun xcstringstool compile --dry-run --output-directory /tmp/bbb-localizations BBB/Localizable.xcstrings`
   - 三种语言的格式占位符一致性检查
   - App + Widget 完整构建

## 本轮未改界面的后续建议

本轮没有改动布局或新增控件。后续如允许调整界面，建议按优先级处理：

1. 在“设置 → 使用偏好”增加只读“语言”行，显示当前语言并跳转系统 App 设置页；仍不自建语言 Picker。
2. 将首页模式的分段选择器改为可容纳两行的原生选择卡。英文 `Quick Records` 在窄屏分段控件中可能需要压缩。
3. Buddy 三列卡片的物种信息允许两行或只在详情卡完整显示。英文物种名通常明显长于中文。
4. Onboarding 的英文标题允许更灵活的字号和行数，避免长标题依赖 `minimumScaleFactor` 变得过小。
5. 若要支持英制单位，在设置中增加独立的“单位制：跟随地区 / 公制 / 英制”，显示层转换 `kg/cm/ml`，持久化层继续保存标准单位。
6. 对英文、简体、繁体分别做 Dynamic Type 与 VoiceOver 截屏巡检，重点检查按钮、分段控件、Buddy 卡片和 Live Activity。
