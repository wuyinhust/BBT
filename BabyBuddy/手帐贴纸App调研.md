# 手帐贴纸 App 调研

本文用于沉淀 BabyBuddy 后续“贴纸手帐”方向的产品与技术调研。当前只做调研备忘，不进入开发。

## 结论摘要

日韩手帐类 App 的核心体验通常不是 AI 自动生成，而是：

- 模板降低排版门槛。
- 贴纸、胶带、纸张、字体、封面形成手帐感。
- 用户在页面上添加照片、文字、贴纸并进行轻量编辑。
- 最终以图片、PDF、打印小卡或外部笔记 App 素材的形式导出。

对 BabyBuddy 更合适的方向是：

> 宝宝场景模板 + 可编辑贴纸模块 + 宝宝照片抠图贴纸 + 高清导出。

不建议第一版做复杂 AI、完整自由画布或直接写入 iOS 系统 Live Stickers。应先做 App 内贴纸手帐，再评估 iMessage Sticker Extension。

## tinytype / 排版小动物

### 已确认

tinytype 在 App Store 上的定位是“你的文字排版助手”，强调让文字记录变成不同风格的卡片。公开描述里有多个小动物角色，每个小动物对应不同风格，例如日系、北欧、旅行明信片、复古编辑部、通知奖状、千禧童年、杂志风等。

App Store 隐私信息显示开发者声明不收集数据。结合其工具类定位和风格描述，核心生成能力更像本地模板渲染，而不是云端 AI 作图。

来源：

- https://apps.apple.com/us/app/%E6%8E%92%E7%89%88%E5%B0%8F%E5%8A%A8%E7%89%A9-tinytype-%E4%BD%A0%E7%9A%84%E6%96%87%E5%AD%97%E6%8E%92%E7%89%88%E5%8A%A9%E6%89%8B/id6749688592

### 技术推断

tinytype 更可能采用：

- 人格化风格包：小动物就是风格选择器。
- 本地模板引擎：模板定义字体、色调、图片槽、文字槽、边框、阴影、纹理。
- 自动排版规则：根据标题和正文长度调字号、行高、留白和模块位置。
- 本地导出：将 SwiftUI/UIKit/CoreGraphics 画布渲染为图片。

目前没有可靠公开资料证明它支持复杂多图拼贴。更保守的判断是：如果支持图片，也更可能是单张图片插入模板，而非多图相册编辑器。

### 对 BabyBuddy 的启发

tinytype 的可借鉴点是“风格人格化 + 极简输入 + 高质量模板”。但 BabyBuddy 当前更想做贴纸手帐，因此 tinytype 适合作为“模板审美和轻量生成”的参考，不应作为完整产品形态的唯一参考。

## 日韩贴纸手帐 App 形态

### Stickroom

#### 已确认

Stickroom 官方定位是 digital diary and sticker app，重点是连接创作者和用户，购买或使用数字贴纸，并可通过 drag-and-drop 把贴纸用于 GoodNotes 等笔记 App。

来源：

- https://www.stickroom.io/en

#### 技术推断

Stickroom 更像“贴纸素材平台 + 素材管理器”，不一定是完整手帐编辑器。核心能力可能包括：

- 贴纸素材商城。
- 创作者上传和销售素材。
- 用户收藏、下载、拖拽导出贴纸。
- 与 GoodNotes 等外部笔记 App 的素材流转。

#### 对 BabyBuddy 的启发

贴纸可以作为长期内容资产，而不是一次性功能。BabyBuddy 可以先做内置育儿贴纸，后续扩展成宝宝成长贴纸包、月龄贴纸包、喂养/睡眠/尿布贴纸包。

### Jakku-Dakku

#### 已确认

公开介绍中，Jakku-Dakku 强调写手帐、剪贴 sticker、选择 diary/planner 和 sticker，形式接近韩式“다꾸”。

来源：

- https://spark.mwm.ai/en/apps/id/1604145147

#### 技术推断

它更像“手写/绘图 + 手帐页面 + 贴纸素材”的产品。可能包含：

- 手帐页面背景。
- 笔刷或手写工具。
- 贴纸插入。
- 页面导出或保存。

#### 对 BabyBuddy 的启发

BabyBuddy 不一定要做完整手写绘图，但可以借鉴“贴纸和纸张先行”的体验：用户先看到漂亮背景和贴纸，再填内容。

### DDiary Pro

#### 已确认

DDiary Pro 的 App Store 描述包含手写、照片、文本框、尺、套索、月/周/日/日记/备忘、主题、字体、内置纸张和贴纸等能力。

来源：

- https://apps.apple.com/kr/app/ddiary-pro-%EC%86%90%EC%9C%BC%EB%A1%9C-%EC%93%B0%EB%8A%94-%EB%94%94%EC%A7%80%ED%84%B8-%EB%8B%A4%EC%9D%B4%EC%96%B4%EB%A6%AC/id1530167434

#### 技术推断

DDiary Pro 更像 iPad 数字手帐/笔记本，技术上可能使用：

- PencilKit 或自研绘图层。
- 页面对象层：照片、文本、贴纸。
- 套索选择和对象编辑。
- 日历/周计划/日记等模板页。

#### 对 BabyBuddy 的启发

完整 PencilKit 手写系统不适合作为 BabyBuddy v1。我们应借鉴“照片 + 文本框 + 贴纸 + 模板页”，不复制完整笔记 App 能力。

### Lifebear / Seal

#### 已确认

Lifebear 是日历、ToDo、笔记、日记一体化工具，强调换肤和 stamp 装饰。Seal 更聚焦于把 sticker/stamp 拖到日历中管理日程。

来源：

- https://apps.apple.com/jp/app/lifebear-%E3%82%AB%E3%83%AC%E3%83%B3%E3%83%80%E3%83%BC%E3%81%A8%E6%89%8B%E5%B8%B3%E3%81%A7%E4%BA%88%E5%AE%9A%E8%A1%A8%E3%82%B9%E3%82%B1%E3%82%B8%E3%83%A5%E3%83%BC%E3%83%AB%E7%AE%A1%E7%90%86/id538340426
- https://apps.apple.com/jp/app/seal-sticker-calendar/id1530169942

#### 技术推断

这类产品不是自由手帐画布，而是“日历格子 + stamp”。核心数据结构比较简单：

- 日期。
- 当日记录。
- 贴纸/stamp 列表。
- 主题皮肤。

#### 对 BabyBuddy 的启发

BabyBuddy 的喂养、睡眠、尿布和成长事件天然适合“日期 + 贴纸”。后续可以考虑在记录日历中贴奶瓶、月亮、尿布、便便、辅食等图标，形成育儿日历。

### ほぼ日手帳 App

#### 已确认

ほぼ日手帳 App 不是贴纸编辑器，而是把照片、地点、日程等生活信息收集起来，用户可以选择“今日封面”，并打印成适合贴进实体手帐的尺寸。

来源：

- https://apps.apple.com/jp/app/%E3%81%BB%E3%81%BC%E6%97%A5%E6%89%8B%E5%B8%B3%E3%82%A2%E3%83%97%E3%83%AA-life%E3%81%AEbook/id6476838032

#### 技术推断

它的重点不是自由编辑，而是：

- 自动汇总当天素材。
- 选择照片或封面。
- 生成适合实体手帐的打印素材。

#### 对 BabyBuddy 的启发

BabyBuddy 可以考虑“可打印宝宝小卡”方向：月龄卡、第一次卡、喂养里程碑卡、睡眠记录卡。贴纸手帐不只用于社交分享，也可以服务实体纪念册。

## CanJournals / 手帐罐头重点拆解

### 已确认

CanJournals 的定位是“简单地制作漂亮手帐”。官方和商店页描述显示，它支持：

- 上传日常照片。
- 写简单 memo。
- 大量设计模板。
- 可爱贴纸。
- masking tape / 胶带。
- 空白页模式。
- 类似 Notion / 飞书的模块式编辑。
- 模板、贴纸、胶带、字体、封面持续更新。
- Premium 订阅或买断。
- 云同步。
- 整本手帐 PDF 导出。
- 高质量渲染模式。

来源：

- https://www.cjournals.online/
- https://apps.apple.com/jp/app/canjournals-%E8%A8%98%E9%8C%B2%E3%83%8E%E3%83%BC%E3%83%88-%E6%89%8B%E5%B8%B3-%E6%89%8B%E8%B3%AC-%E3%83%A1%E3%83%A2%E6%97%A5%E8%A8%98/id6670348022
- https://apps.apple.com/cn/app/%E6%89%8B%E5%B8%90%E7%BD%90%E5%A4%B4-%E6%97%A5%E8%AE%B0-%E6%89%8B%E8%B4%A6-%E6%8E%92%E7%89%88%E5%8A%A9%E6%89%8B-%E5%8A%A8%E7%89%A9-%E6%B8%A9%E6%9A%96%E9%99%AA%E4%BC%B4%E8%AE%B0%E5%BD%95-%E6%9A%96%E6%9A%96/id6670348022

### 产品结构判断

CanJournals 不是 tinytype 那种“输入文字生成卡片”的单一工具，而是一个轻量数字手帐系统。它大概由三层组成：

1. 模板页：用户选 daily、weekly、monthly、旅行、探店、影视书评等场景模板。
2. 自由页/模块页：空白页里可添加模块，类似 Notion/飞书，而不是 Photoshop 式无限复杂编辑器。
3. 素材系统：贴纸、胶带、字体、封面、背景、block templates 持续更新。

### 技术实现推断

CanJournals 大概率维护一棵页面对象树：

```text
Notebook
  Page
    Background
    Blocks / Elements
      TextBlock
      ImageBlock
      StickerBlock
      TapeBlock
      DateBlock
      TemplateBlock
```

每个元素保存：

```text
id
type
position / frame
size
rotation
zIndex
style
assetID
text
fontID
color
```

同时存在两套渲染路径：

- 编辑渲染：支持点击、拖动、缩放、删除、换字体、换贴纸。
- 导出渲染：高质量渲染成图片或 PDF。

App Store 更新日志中出现高质量渲染、notebook export rendering speed、PDF export sorting 等信息，说明它有专门的导出管线，而不是简单截图。

### 照片能力判断

CanJournals 明确支持添加照片。公开反馈中有用户希望未来每天可以添加更多照片，这暗示它的主流程可能偏“每天一页/少量照片”，不是九宫格相册工具。

对 BabyBuddy 的判断：

- v1 不必做复杂多图拼贴。
- 可以先支持 1-3 张照片或贴纸元素。
- 核心放在宝宝抠图贴纸和手帐页面装饰，而不是相册排版。

### 贴纸和胶带实现推断

CanJournals 的贴纸和胶带更可能是 App 内素材资产，而非系统 Live Stickers。技术上可能是：

- 内置 PNG/WebP/SVG/PDF 素材包。
- 按分类管理贴纸。
- 高级贴纸订阅解锁。
- 用户点击后插入页面。
- 贴纸支持移动、缩放、旋转、删除。
- 胶带可能是可拉伸图片，使用 9-slice 或重复纹理。

### 对 BabyBuddy 的启发

最值得借鉴的不是单个功能，而是结构：

1. 模板降低审美门槛。
2. 模块降低编辑复杂度。
3. 贴纸和胶带提供手帐感。
4. 字体和封面提升个性化。
5. 高清导出保证成品可分享或打印。
6. 持续素材更新形成长期价值。

BabyBuddy 对应可以是：

1. 宝宝场景模板。
2. 育儿记录模块。
3. 宝宝照片抠图贴纸。
4. 月龄/喂养/睡眠/成长贴纸。
5. 高清导出和分享。
6. 后续增加素材包。

## 技术实现模式总结

### 模板页

模板定义页面尺寸、背景、照片槽、文本槽、装饰位、默认字体和色彩。优点是效果稳定，用户不用懂设计。

适合 BabyBuddy：

- 月龄纪念页。
- 第一次系列。
- 今日喂养记录。
- 睡眠观察。
- 成长日记。

### 模块编辑

用户不是完全自由绘图，而是在页面里插入模块。模块可以是照片、文字、贴纸、胶带、日期章、记录卡。

适合 BabyBuddy：

- 降低自由画布复杂度。
- 保留手帐可玩性。
- 便于保存为结构化 JSON，后续可重新编辑。

### 贴纸素材库

贴纸是手帐类 App 的长期资产。素材库通常需要分类、收藏、最近使用、解锁状态。

适合 BabyBuddy 的贴纸分类：

- 宝宝抠图贴纸。
- 月龄数字。
- 喂养：奶瓶、母乳、辅食、勺子。
- 睡眠：月亮、星星、小床。
- 尿布/便便。
- 成长事件：第一次翻身、第一次爬、第一次走。
- 情绪和气质：开心、困、哭、兴奋、慢热。

### 自由画布

自由画布支持拖动、缩放、旋转、层级调整和删除。完整自由画布实现成本高，但 v1 可以做轻量版本。

最小能力：

- 拖动。
- 缩放。
- 旋转。
- 删除。
- 置顶/置底。
- 选中态不导出。

### 导出管线

手帐 App 通常需要独立导出管线，不能只依赖屏幕截图。

BabyBuddy 可用：

- SwiftUI `ImageRenderer` 导出 PNG。
- 后续如做整本导出，再考虑 PDF。
- 导出尺寸应固定为高清尺寸，例如 1440px 长边或 4:5 画布比例。

## iOS 贴纸能力边界

### App 内贴纸

这是最可控的方向。BabyBuddy 自己生成透明 PNG 贴纸，保存在 App Documents 中，在自己的手帐画布里使用。

当前工程已经有接近可复用的能力：

- `VNGenerateForegroundInstanceMaskRequest` 生成主体蒙版。
- 裁掉透明边缘。
- 添加阴影。
- 保存 PNG。

### iMessage Sticker Extension

Apple 官方支持第三方 iMessage sticker app / sticker pack。`MSSticker` 是 Messages 里的贴纸对象，可以作为新消息发送或贴到气泡上。

来源：

- https://developer.apple.com/documentation/messages/mssticker
- https://developer.apple.com/imessage/

这可以作为 BabyBuddy v2：新增 Messages Extension，把宝宝贴纸作为 iMessage 贴纸包使用。

### 系统 Live Stickers

系统 Live Stickers 更偏用户在照片/信息里自己创建和使用。Apple 支持用户在 Messages 里创建 Live Stickers，也支持下载第三方 sticker app，但普通 App 没有稳定公开 API 可以直接把自制贴纸写入系统 Live Stickers 库。

来源：

- https://support.apple.com/guide/iphone/send-stickers-iph37b0bfe7b/ios

因此 BabyBuddy 不应在 v1 承诺“直接加入系统贴纸库”。更稳妥的说法是：

- App 内可以生成和使用贴纸。
- 可以导出透明 PNG。
- 后续可以做 iMessage Sticker Extension。
- 用户如果想加入系统 Live Stickers，可通过系统照片/信息能力自行创建。

## 对 BabyBuddy 的建议

### 推荐方向

BabyBuddy 应走 CanJournals 式中间路线：

> 模板页 + 可编辑贴纸模块。

不要一开始做纯自由画布，也不要只做固定卡片。模板保证好看，贴纸模块保证手帐感。

### v1 最小闭环

- 选择一个宝宝手帐模板。
- 添加宝宝照片，自动生成抠图贴纸。
- 添加文字便签。
- 添加日期/月龄贴纸。
- 添加喂养/睡眠/便便/成长事件贴纸。
- 支持拖动、缩放、旋转、删除。
- 导出图片。
- 保存历史。

### v2 可考虑

- 多图模板。
- iMessage Sticker Extension。
- 整本手帐 PDF 导出。
- 可打印宝宝贴纸页。
- 素材包持续更新。
- 贴纸收藏和最近使用。
- 从喂养/睡眠/尿布记录自动生成手帐元素。

## 暂不开发的待决问题

- 是否支持多图拼贴，还是只支持少量照片贴纸。
- 是否新增 iMessage Sticker Extension。
- 是否做完整自由画布。
- 是否做整本 PDF 导出。
- 是否做打印尺寸模板。
- 是否做素材订阅或素材包解锁。
- 是否把手帐页和现有喂养/睡眠/尿布记录关联。

