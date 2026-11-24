## 2026-11-24 | 任务：兼容百炼 Chat Completions

**Links:** [执行计划](../../exec-plans/completed/2026-11/2026-11-24-dashscope-chat-compatibility.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `gpt-6.2-sol`
- **Environment:** `macOS 27.0 / Xcode Unknown (Unknown)`

### 用户请求

对照 Read Frog 的 Alibaba Cloud 配置，修复 Easydict 自定义 OpenAI 的百炼接入，并在 fork 的独立分支添加离线回归测试。

### 变更

- 自定义 OpenAI 接受百炼官方 Base URL 和完整 Chat Completions URL。
- 流式与非流式请求对匹配的 Qwen 模型应用 `enable_thinking: false`。显式思考模型保留服务器默认值。
- 自定义 Prompt 从当前请求读取文本和语言，设置页的验证也可填入测试句。

### 设计意图

迁移 Read Frog 的百炼翻译请求行为。将专属参数限制在已识别的官方 HTTPS 端点，同时继续从 `content` 提取正式译文。

### 验证

- SwiftPM 离线测试通过 9 项。测试使用生产传输和 Prompt 源文件、MacPaw OpenAI 0.5.1、轻量宿主类型和 URLProtocol 模拟响应。
- `git diff --check`、`plutil -lint` 和 Swift 语法检查通过。
- `xcodebuild test` 因未安装完整 Xcode 受阻。未进行应用界面验证或百炼真实请求验证。

### 受影响文件

- `Easydict/Swift/Service/CustomOpenAI/CustomOpenAIService.swift`
- `Easydict/Swift/Service/OpenAI/` 下的传输及 Prompt 处理
- `EasydictTests/Service/OpenAI/DashScopeChatCompatibilityTests.swift`
- `Easydict.xcodeproj/project.pbxproj`

### 后续事项

使用完整 Xcode 构建应用，使用实际区域、模型和密钥从设置页及翻译窗口验证。
