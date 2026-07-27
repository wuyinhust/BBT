# BBBuddy 深色模式与 Color Set 审计

更新时间：2026-07-18

## 目标与确认门

- 视觉方向：中性炭灰底座加极低饱和紫灰氛围，紫色只承担品牌焦点，不承担大面积背景。
- 外观策略：正式版提供“跟随系统 / 浅色 / 深色”，默认跟随系统。
- 第一阶段已迁移首页、快捷记录、设置三张真实页面，并提供 Debug Demo。
- 用户已确认中性炭灰微紫方案，第二阶段已开始并正式解除主 App 与 Onboarding 的浅色锁。
- 第二阶段覆盖主 App、Widget、Live Activity 与灵动岛；Widget 和系统活动始终跟随系统外观。

## 基线问题

以下统计排除了中央 `DesignToken` 与不再进入 Target 的旧 `FeedingSheet.swift`：

- 约 535 处 `Color(hex:)` 硬编码，分布于 18 个 Swift 文件。
- 约 531 处直接白色或黑色用法。
- 295 个不同 Hex 值，页面局部调色远多于稳定语义角色。
- `BBBApp` 与 `OnboardingView` 各自存在一次 `.preferredColorScheme(.light)`。
- 主 App、Widget、首页玻璃、设置背景和成就背景分别维护独立底座。
- Widget 的 `WidgetEASYPalette` 与主 App 重复维护同一组 EASY Hex。

## 视觉问题分类

### Contrast

- 浅紫主按钮部分状态与白字对比不足；新 `PrimaryAction #7654F4` 与白字对比为 4.83:1。
- 小字号说明文字存在低透明度叠加，暗色环境会进一步失去可读性。
- EASY 主色不能直接承担小号正文；必须使用各自的 `Text` 角色。

### Repetition 与 Unity

- `HomeSoftBackground`、`ProfileSoftBackground`、`recordBackground`、`achievementSoftBackground` 使用四套无关联渐变。
- 白卡、玻璃卡、表单卡的填充与描边没有共享组件。
- 旧喂养紫、旧睡眠蓝紫、尿布黄和普通成功绿仍绕过 EASY Token。
- Yearning 绿与普通成功状态需要分离，奖励色也不能复用 Yearning。

### Dark Mode 风险

- 固定白色表面和固定深色文字会形成白块、黑字丢失或“半黑半白”页面。
- 固定浅色渐变叠加系统 Material 时，暗色层级不可预测。
- 图片、相机、视频、照片导出属于内容渲染域，不能跟随 UI Token 反转。

## 新语义 Color Set

共享资源位于 `Shared/BBBuddyColors.xcassets`，只包含颜色，并同时加入 App 与 Widget Target。

基础角色：

| 角色 | 浅色 | 深色 |
| --- | --- | --- |
| Canvas | `#F8F7FA` | `#131318` |
| Surface | `#FFFFFF` | `#1C1C23` |
| Surface Raised | `#FFFFFF` | `#24242C` |
| Surface Soft | `#F3F0F8` | `#2A2932` |
| Border | `#E2DEE8` | `#403E49` |
| Text Strong | `#282738` | `#F4F1FA` |
| Text Muted | `#706B7C` | `#BBB5C8` |
| Text Faint | `#756F7F` | `#9D96AA` |
| Primary Action | `#7654F4` | `#7654F4` |

EASY 每个类别均有 `Main / Soft / Text` 三层角色。普通 success、warning、error、reward 使用独立三层角色，不占用 Yearning。

### 第一轮视觉反馈修订

第一轮深墨紫样板被确认“紫色过于显眼”。第二轮不再把紫色作为环境底色，而采用以下规则：

- Canvas、Surface、Raised、Soft 全部改为近中性炭灰，只保留很小的蓝紫通道差。
- 首页顶部 EASY 混色背景在深色模式改为 Canvas / Surface Soft 过渡，紫、蓝、橙光晕透明度降至原来的三分之一以下。
- 设置页深色背景移除大面积粉紫混色，品牌紫与奖励色只保留约 5.5% / 7% 的局部光晕。
- Primary、选中日期、保存按钮和品牌图标继续使用紫色，维持焦点、识别度与操作层级。

## 方案一兼容回退

如果“明暗一起重塑”未通过样板确认，页面代码不回退。只将共享 Catalog 的浅色基础角色替换为：

| 角色 | 兼容浅色值 |
| --- | --- |
| Canvas | `#FAFAFC` |
| Surface | `#FFFFFF` |
| Surface Soft | `#F6F2FF` |
| Border | `#E5E3EC` |
| Text Strong | `#282738` |
| Text Muted | `#737286` |
| Primary Action | `#7C5CFF` |

EASY 兼容方案继续使用 `EASY颜色体系.md` 中的既有浅色值。

## 允许保留的固定颜色

最终硬编码扫描只允许以下明确例外，并必须通过命名 Palette 表达：

- 相机取景、视频播放的物理黑底。
- 照片滤镜、贴纸、水印与导出图片中的固定渲染色。
- 阴影黑、彩色表面上的白色文字、玻璃高光。
- 透明命中区域。
- `LiveSceneRenderPalette` 中的直播小木屋画面色；其绿色场景与直播层级属于内容舞台，不是 App 通用画布。
- `CompanionRenderPalette` 中的伙伴毛色与插画识别色；Onboarding 的性格标签已改用语义 EASY / 状态角色。

UI 画布、文字、表面、表单、边框、状态和 EASY 颜色不得出现在例外清单中。

## 阶段验收记录

- [x] 建立 51 个共享动态 Color Set，并同时加入 App 与 Widget Resources。
- [x] 共享 Color Set 通过 App + Widget 真机 Debug 构建与通用 iOS Simulator Debug 构建。
- [x] 首页、快捷记录、设置三张真实 View 的样板范围不再直接使用 Hex 或 UI 白/黑色。
- [x] Debug 设置页增加只读样板入口；首页样板额外屏蔽周期重建与奖励写入。
- [x] 新增 `scripts/audit_hardcoded_colors.sh`；第一阶段收尾复扫的全 App 第二阶段基线为 914 处未登记用法。
- [x] 首页浅色 / 深色截图。
- [x] 快捷记录浅色 / 深色截图。
- [x] 设置页浅色 / 深色截图。
- [x] 统一玻璃组件在“降低透明度”开启时使用不透明 `Surface Raised`。
- [x] 用户确认样板后移除全局浅色锁，并接入 System / Light / Dark 外观设置。
- [x] Widget、Live Activity、灵动岛删除独立 Hex Palette，改为共享 Color Set 且跟随系统外观。
- [x] 首页、快捷记录、设置、资料、体重身高、记录编辑、统计分析、探索准备度、陪伴选择与陪伴场景抽屉完成语义色迁移。
- [x] 成长、成就、相机/媒体外壳、旧记录器与固定渲染色例外完成最终收口。

截图状态（2026-07-16）：六张截图已使用真实生产 View 在专用的 iPhone 12 Pro Max
模拟器（iOS 26.3）完成，统一固定为 09:41、满电与相同设备状态；文件位于
`docs/dark-mode-demo/`。逐张检查后，首页深色 E/A/S/Y 指标卡已改为随外观切换的语义色，
快捷记录的遮罩/弹层/输入/主操作，以及设置页的分组/长列表/说明文字/分割线均通过明暗
对照检查。收到第一轮视觉反馈后，三张深色图已使用中性炭灰微紫方案重新构建、安装并覆盖
拍摄；浅色值未改变。

本轮完整 App + Widget 模拟器构建还暴露并修复了两个与截图路径相关的发布阻塞：

- Onboarding 字体缩放调用将不兼容的 `.caption` 修正为 `UIFont.TextStyle.caption1`。
- 已废弃的 `FeedingSheet.swift` 被意外重新加入 App Sources，导致 `InteractiveBottleView`
  重复定义；现已从 Sources 移除，Debug 测试入口也改为当前 `QuickRecordDarkModeDemo`。

阶段二完成（2026-07-18）：全局审计已从 914 处未登记用法降至 0 处。成长相册、相机预览、滤镜、
照片导出、陪伴场景、体重/身高、尿布、睡眠与共享记录器全部改为语义 UI 色，或收敛为明确命名的
固定渲染 Palette。完整 App + Widget Simulator Debug 构建在本轮前已通过；专用 iPhone 12 Pro Max
Simulator 的系统启动服务仍偶发停在苹果标志，因此本轮未将启动画面误判为 App 白屏，待 Simulator
服务恢复后补跑设备截图回归。

验证命令：

```sh
scripts/audit_hardcoded_colors.sh --report
xcodebuild -quiet -project BBB.xcodeproj -scheme BBB -configuration Debug \
  -destination 'id=00008101-000608920AB8001E' \
  -derivedDataPath /tmp/BBB-DarkModeDemo build
xcodebuild -quiet -project BBB.xcodeproj -scheme BBB -configuration Debug \
  -destination 'id=8C1D3227-7FF4-45F1-8A20-1BFB5084026B' \
  -derivedDataPath /tmp/BBB-DarkModeDemo-Simulator build
```
