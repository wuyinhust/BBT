# TestFlight 内部测试发布流程

这套流程先覆盖内部 TestFlight：归档、导出 IPA、上传 App Store Connect、等待 Apple 处理完成、分配到内部测试组。

## 1. 准备 App Store Connect API Key

在 App Store Connect 创建 API Key 后，把 `.p8` 文件放在仓库外，例如：

```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
```

不要把 `.p8` 提交到仓库。
上传脚本使用 `altool`，所以文件名和目录需要保持 `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8`。

## 2. 配置环境变量

```bash
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="00000000-0000-0000-0000-000000000000"
export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"

export APPLE_TEAM_ID="73AUQDMCJ2"
export APP_BUNDLE_ID="v.babybuddy"
export TESTFLIGHT_INTERNAL_GROUP="内部测试"
```

可选参数：

```bash
export PROJECT_PATH="BBB.xcodeproj"
export SCHEME="BBB"
export CONFIGURATION="Release"
export APP_MARKETING_VERSION="0.0.3"
export APP_BUILD_NUMBER="1"
export TESTFLIGHT_PROCESSING_TIMEOUT_MINUTES="60"
export TESTFLIGHT_POLL_INTERVAL_SECONDS="60"
```

如果没有指定 `APP_MARKETING_VERSION` / `APP_BUILD_NUMBER`，分配脚本会使用 App Store Connect 中最近上传的 build。

## 3. 上传内部 TestFlight build

```bash
chmod +x scripts/testflight_internal_upload.sh
scripts/testflight_internal_upload.sh
```

脚本会生成 `build/testflight-internal/ExportOptions.plist`，并启用：

```text
testFlightInternalTestingOnly = true
iCloudContainerEnvironment = Production
```

也就是说，这个构建只适合内部 TestFlight，不会用于外部测试或 App Store 正式发布。

## 4. 分配到内部测试组

上传完成后，Apple 需要处理 build。然后运行：

```bash
node scripts/testflight_assign_internal_group.mjs
```

脚本会：

1. 用 bundle id 找到 App。
2. 找到 `TESTFLIGHT_INTERNAL_GROUP` 指定的内部测试组。
3. 轮询最新 build 的 processing 状态。
4. 状态变成 `VALID` 后，把 build 分配到该测试组。

## 5. 一条命令串起来

```bash
scripts/testflight_internal_upload.sh
node scripts/testflight_assign_internal_group.mjs
```

## 常见问题

- `Missing required environment variable`: 先补齐第 2 步的环境变量。
- `No beta group named ... found`: 先在 App Store Connect 的 TestFlight 里创建同名内部测试组，或把 `TESTFLIGHT_INTERNAL_GROUP` 改成现有组名。
- 签名失败：确认 App ID、CloudKit、App Groups、Widget extension 的 capability 和 provisioning profile 都已经在开发者后台/App Store Connect 可用。
- build 一直不是 `VALID`：登录 App Store Connect 查看 Processing 或 Invalid Binary 详情。
