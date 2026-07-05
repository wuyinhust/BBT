# BabyBuddy Plus 配置与后续接入清单

本文记录 BabyBuddy Plus 首版真订阅配置、测试步骤和后续权益接入顺序。

## 商品配置

在 App Store Connect 创建以下商品：

| 类型 | Product ID | 展示名称 | 试用 |
| --- | --- | --- | --- |
| 自动续期订阅 | `v.babybuddy.plus.monthly` | BabyBuddy Plus 月付 | 7 天 |
| 自动续期订阅 | `v.babybuddy.plus.yearly` | BabyBuddy Plus 年付 | 7 天 |
| 非消耗型项目 | `v.babybuddy.plus.lifetime` | BabyBuddy Plus 终身 | 无 |

月付和年付放在同一个订阅组，组名建议为 `BabyBuddy Plus`。年付在 App 内默认高亮推荐。终身商品使用非消耗型项目，不放入订阅组。

App 内代码读取的商品 ID 来自 `PlusMembershipPlan`，不要在 UI 里另写一份商品 ID。

## Xcode 本地 StoreKit 测试

如果需要在本地模拟商品价格和购买流程：

1. 在 Xcode 中选择 `File > New > File... > StoreKit Configuration File`。
2. 文件建议命名为 `BabyBuddyPlus.storekit`。
3. 添加同上三个商品 ID。
4. 月付、年付设置为 Auto-Renewable Subscription，并加入同一个订阅组。
5. 终身设置为 Non-Consumable。
6. 在 `Product > Scheme > Edit Scheme... > Run > Options` 里选择这个 StoreKit Configuration。
7. 运行 App，进入个人中心的 `BabyBuddy Plus` 页面测试购买、取消、恢复购买。

本地 StoreKit 配置不会上传到 App Store Connect，也不会影响正式 App。正式商品仍以 App Store Connect 配置为准。

## 已实现

- 个人中心 `BabyBuddy Plus` 入口。
- Plus 会员页。
- 月付、年付、终身商品展示。
- StoreKit 2 商品加载、购买、恢复购买、交易监听。
- 当前会员状态展示：`免费版`、`Plus 会员`、`终身会员`。
- 未实现权益以 `规划中` 展示，避免误导用户。

## 后续权益接入顺序

建议按风险和产品价值分批接入：

1. 家庭共享同步：非 Plus 用户点击家庭共享时，引导到 Plus 页面；Plus 用户进入现有家庭共享流程。
2. 完整历史导出：新增导出页，支持照护记录、喂养记录、成就记录的 CSV 或 JSON 导出。
3. 拍立得与成就徽章数量：免费版保留基础体验，Plus 移除数量限制。
4. 稀有 Buddy：在 Buddy 选择页增加 Plus 标记和开通引导。
5. 全部小组件：新增更多 Widget kind 后，再按 Plus 状态决定展示口径。
6. 全部 App 桌面图标：配置 Alternate Icons 后，在 Plus 页面或设置页开放选择入口。
7. 周/月成长回顾：基于现有记录和 yesterday's 报告能力扩展，不做医疗化判断。

## 文案边界

- 使用 `持续解锁 Plus 新功能`，不要写成 `未来全部功能更新`。
- 使用 `完整历史导出`，避免暗示免费版用户无法取回基础数据。
- 白噪音和睡眠相关权益只描述为睡眠环境与安抚辅助，不宣称治疗效果。
