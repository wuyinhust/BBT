# BBBuddy E·A·S·Y 颜色体系

> 目的：把 BBBuddy 的核心育儿循环转译成可复用的色彩语义，形成「柔和底座 + 清晰照护信号 + 状态反馈」的视觉系统。

## 1. 核心概念

E·A·S·Y 来自宝宝照护中的经典节奏：

- **E / Eat**：吃、喂养、亲喂、瓶喂、辅食。
- **A / Activity**：玩、尿布、翻身、Tummy Time、清醒互动、日常照护。
- **S / Sleep**：睡觉、入睡、睡眠记录、睡眠节奏。
- **Y / Yearning**：基于 Eat、Activity、Sleep 的当前节奏，估算宝宝的探索准备度与状态窗口，帮助判断更适合互动、观察，还是准备接觉。

这套体系不照搬 monday.com 的高饱和 SaaS 彩虹色，而是借鉴它的结构逻辑：

**底座要安静，照护信号要清楚，状态反馈要克制。**

## 2. 当前代码基础

当前 `DesignToken` 保留柔和紫作为旧品牌兼容色，并新增了更安静的底座 token：

- 旧主色：`#BDA6F2`
- 柔粉：`#F4C7D9`
- 辅助蓝：`#A5C8FF`
- 背景：`#FAFAFC`
- 标题：`#282738`
- 正文：`#737286`
- 分割线：`#E5E3EC`

当前照护色已经有分散雏形：

- 喂养：偏紫 / 蓝 / 橙
- 尿布：偏金黄
- 睡眠：偏蓝紫
- 完成或安全：偏绿
- 警告或卡住：偏红

升级重点不是增加更多颜色，而是统一语义，让同一类信息在首页、记录页、Widget、Live Activity、编辑页中保持一致。

## 3. 色彩结构

### 3.1 安静底座

底座负责专业感、可读性和长时间使用的舒适度，不承担情绪表达。

| Token | 建议色值 | 用途 |
| --- | --- | --- |
| `canvas` | `#FAFAFC` | App 大背景，替代过强的彩色底 |
| `surface` | `#FFFFFF` | 卡片、表单、弹层主体 |
| `surfaceSoft` | `#F6F2FF` | 轻品牌背景、选中弱底色 |
| `borderSubtle` | `#E5E3EC` | 分割线、卡片描边 |
| `textStrong` | `#282738` | 标题、关键数字 |
| `textMuted` | `#737286` | 说明文字、辅助信息 |

### 3.2 E·A·S·Y 主语义色

| 节奏 | 语义 | 色名 | 建议主色 | 软背景 | 文字色 | 设计性格 |
| --- | --- | --- | --- | --- | --- | --- |
| E / Eat | 喂养、吃、营养输入 | 鸢尾紫 Iris | `#7C5CFF` | `#EDE7FF` | `#4936A8` | 明确、可靠、有能量 |
| A / Activity | 玩、尿布、翻身、Tummy Time、清醒互动 | 山茶粉 Camellia | `#FF7A90` | `#FFE8EE` | `#9B3147` | 活跃、亲密、温暖互动 |
| S / Sleep | 睡眠、休息、夜间节奏 | 飞燕蓝 Delphinium | `#2F80ED` | `#E7F1FF` | `#1856B6` | 安静、稳定、放松 |
| Y / Yearning | 探索准备度、当前状态窗口、节奏反馈 | 荚蒾绿 Viburnum | `#29B87A` | `#E4F8EE` | `#187048` | 通畅、可探索、轻松状态 |

说明：

- E 使用品牌鸢尾紫，承接当前主色资产，但增强 CTA 与状态识别。
- A 不再只等于尿布黄。Activity 是清醒期照护与互动，使用山茶粉作为大类色；尿布作为 A 内部子类，改为同色系暖橙。
- S 从蓝紫改为更冷、更明确的飞燕蓝，避免和 E 的鸢尾紫在 Widget 与小尺寸入口里混在一起。
- 色名统一使用“花名 + 色相”命名，用于设计沟通和文档表达；代码仍保留 `easyEat`、`easySleep` 这类语义 token，避免视觉命名影响业务含义。
- Y 是状态反馈色，不是普通记录分类。它应该少量用于 Yearning 分数、状态解释、节奏建议和详情入口。

### 3.3 E 内部子类色

Eat 默认使用鸢尾紫。只有需要在喂养内部快速区分的类型使用子类色，避免给用户增加过多记忆成本：

| 子类 | 色名 | 建议色值 | 用途 |
| --- | --- | --- | --- |
| 奶粉瓶喂 | 鸢尾紫 Iris | `#7C5CFF` | E 默认喂养色 |
| 母乳瓶喂 | 鸢尾紫 Iris | `#7C5CFF` | 与瓶喂保持同一视觉语义 |
| 母乳亲喂 | 芍药紫 Peony | `#B56CFF` | 亲喂计时、亲喂统计、亲喂入口 |
| 宝宝辅食 | 藤萝紫 Wisteria | `#8E4DFF` | 辅食记录、辅食选择、辅食统计 |

### 3.4 A 内部子类色

Activity 默认使用山茶粉。只有尿布、洗澡使用子类色；其他活动继续使用山茶粉，降低识别和学习成本：

| 子类 | 色名 | 建议色值 | 用途 |
| --- | --- | --- | --- |
| 玩 / 清醒互动 / 趴卧 / 抚触 / 故事 / 户外 / 刷牙 | 山茶粉 Camellia | `#FF7A90` | Activity 默认色 |
| 尿布 | 金盏橙 Calendula | `#F59A6B` | 尿布记录、尿布 Widget、尿布图标 |
| 洗澡 | 荷花粉 Lotus | `#FF9AAE` | 洗澡记录、清洁护理入口 |

## 4. 使用原则

### 4.1 底座安静

大面积背景、卡片和表单不要使用高饱和颜色。默认使用 `canvas`、`surface`、`borderSubtle`、`textStrong`、`textMuted`。

### 4.2 数据跳出来

E/A/S/Y 色只用于用户需要快速识别的对象：

- 首页节奏模块
- 记录入口
- 最近记录标签
- Widget 三卡片
- Live Activity 状态点
- 图标底色
- 关键数字或进度条

### 4.3 Y 要稀缺

Yearning 不是第四个普通记录分类，而是由 Eat、Activity、Sleep 推导出的状态反馈。

适合使用 Y 的场景：

- 首页今日节奏里的 Y 状态卡。
- Yearning 详情页里的分数、状态解释和建议。
- 月龄卡的近 7 日平均状态。
- 温和提醒「适合互动」「温和观察」「准备接觉」。

不适合使用 Y 的场景：

- 普通按钮。
- 未完成状态。
- 错误提示。
- 每个页面都出现的装饰背景。

### 4.4 同一语义跨端一致

首页、记录页、编辑页、Widget、Live Activity 应使用同一组 E/A/S/Y token。不要让「喂养」在首页是紫色，在详情页变蓝色，在 Widget 又变粉色。

## 5. SwiftUI Token 建议

后续可在 `DesignToken` 中逐步增加语义 token：

```swift
enum DesignToken {
    static let canvas = Color(hex: "#FAFAFC")
    static let surface = Color.white
    static let surfaceSoft = Color(hex: "#F6F2FF")
    static let borderSubtle = Color(hex: "#E5E3EC")

    static let textStrong = Color(hex: "#282738")
    static let textMuted = Color(hex: "#737286")

    static let easyEat = Color(hex: "#7C5CFF")
    static let easyEatSoft = Color(hex: "#EDE7FF")

    static let easyActivity = Color(hex: "#FF7A90")
    static let easyActivitySoft = Color(hex: "#FFE8EE")

    static let easySleep = Color(hex: "#2F80ED")
    static let easySleepSoft = Color(hex: "#E7F1FF")

    static let easyYearning = Color(hex: "#29B87A")
    static let easyYearningSoft = Color(hex: "#E4F8EE")

    static let feedingBottle = Color(hex: "#7C5CFF")
    static let feedingBottleSoft = Color(hex: "#EDE7FF")
    static let feedingBreast = Color(hex: "#B56CFF")
    static let feedingBreastSoft = Color(hex: "#F3E8FF")
    static let feedingSolid = Color(hex: "#8E4DFF")
    static let feedingSolidSoft = Color(hex: "#EFE7FF")

    static let activityDiaper = Color(hex: "#F59A6B")
    static let activityDiaperSoft = Color(hex: "#FFF0E8")
    static let activityBath = Color(hex: "#FF9AAE")
    static let activityBathSoft = Color(hex: "#FFEAF0")
    static let activityTummyTime = Color(hex: "#FF7A90")
    static let activityComfort = Color(hex: "#FF7A90")
}
```

## 6. 页面落地建议

### 首页

- 今日节奏主模块按 E/A/S/Y 呈现。
- Eat、Activity、Sleep 用清晰色点或小卡片标识。
- Yearning 只作为状态反馈和详情入口，不作为普通记录按钮。

### 记录页

- 主记录入口按 E/A/S 分类。
- Activity 入口下可以细分尿布、Tummy Time、玩、安抚。
- 普通未选中态使用白卡和轻描边，选中态使用对应 soft 背景。

### Widget

- 最近喂养：`easyEat`
- 最近活动 / 尿布：`easyActivity` 或 `activityDiaper`
- 最近睡眠：`easySleep`
- 如果三项形成稳定节奏，可出现很轻的 `easyYearning` 状态提示。
- Widget target 使用本地 palette 复制同一组 hex，不直接依赖主 App 的 `DesignToken`。

### 成就与贴纸

- 成就与贴纸暂不直接复用 Yearning 语义。
- 如果后续需要庆祝反馈，应单独建立奖励色或动效规则，避免和 Yearning 状态混淆。

## 7. 文案语气

EASY 不是冷冰冰的数据分类，而是给家长的节奏感和松弛感。

可用文案方向：

- 「现在适合温和互动」
- 「宝宝状态不错，可以多观察一点」
- 「节奏稳定，适合轻松陪玩」
- 「有点困了，准备接觉」
- 「先减少刺激，等下一轮节奏」

避免文案：

- 「任务完成」
- 「流程闭环」
- 「育儿 KPI 达成」
- 「系统检测到周期结束」

## 8. 后续实施顺序

1. 在 `DesignToken` 中新增 E/A/S/Y 语义 token，不立即删除旧 token。
2. 先替换首页今日节奏和 Widget 的喂养 / 活动 / 睡眠颜色。
3. 再统一记录页入口、编辑页、状态标签。
4. 最后处理成就、贴纸、Live Activity、Dynamic Island 的奖励反馈色。
5. 稳定后再决定是否把旧的 `primary`、`primarySoft` 等迁移到新命名。
