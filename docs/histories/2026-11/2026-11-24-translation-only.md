## 2026-11-24 | 任务：精简划词与截图翻译

**Links:** [执行计划](../../exec-plans/completed/2026-11/2026-11-24-translation-only.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `gpt-6.2-sol`
- **Environment:** `macOS 27.0 / Xcode Unknown (Unknown)`

### 用户请求

在个人 fork 只保留划词翻译、截图翻译和自定义 LLM，减少无关的常驻工作。

### 变更

- 两个入口使用同一个固定浮窗，截图仍用系统 OCR。
- 复用自定义 OpenAI 实例标识，精简版服务顺序单独保存。
- 移除无关的菜单项目和全局快捷键。减少启动后台任务，译文窗口使用纯文本和复制入口。

### 设计意图

保留既有选择和截图机制，收窄实际会初始化的功能。设置层继续管理自定义地址、模型和提示词。复用百炼兼容实现。

### 验证

- `git diff --check` 和 Swift 源文件语法检查通过。
- 源码检查覆盖窗口选择、旧服务标识迁移、默认快捷键、后台任务与本地 OCR。
- `xcodebuild build` 因没有完整 Xcode 未能执行构建。未运行界面验收和内存对照。

### 受影响文件

- `Easydict/App/` 启动入口和代理
- `Easydict/Swift/Feature/` 配置与快捷键
- `Easydict/Swift/Service/` 自定义 OpenAI 与服务列表
- `Easydict/Swift/Utility/GlobalContext.swift`
- `Easydict/Swift/View/` 菜单及设置
- `Easydict/objc/ViewController/` 查询浮窗和译文按钮

### 后续事项

在 Xcode 构建后验证两个入口及辅助功能、屏幕录制授权。分别记录首次启动空闲、执行划词与截图后的实际内存。
