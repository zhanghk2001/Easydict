# 兼容百炼 Chat Completions

- 状态：completed
- 创建日期：2026-11-24
- 负责人：Codex
- 关联 Issue/PR：#1132

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `gpt-6.2-sol`
- **Environment:** `macOS 27.0 / Xcode Unknown (Unknown)`

## 背景

从陪读蛙复制百炼 Base URL 到 Easydict 会漏掉请求路径。部分 Qwen 配置还依赖陪读蛙传递的 `enable_thinking`。

## 目标与范围

- 目标结果：自定义 OpenAI 可使用百炼 Base URL，并将 Qwen 的翻译请求与陪读蛙的默认思考设置对齐。
- 允许修改路径：OpenAI 请求层、自定义 OpenAI 服务、Prompt 渲染及相关测试。
- 同任务 history：`docs/histories/2026-11/2026-11-24-dashscope-chat-compatibility.md`
- 用户限制：独立 fork 分支，无需真实密钥进行 mock 测试。
- 非目标：Qwen-MT 专用协议及 Responses API。
- 验收标准：相同的官方基地址和完整地址生成同一路径。流式和非流式均能提取译文。

## 工作计划

1. 核对双方源码和锁定的 SDK。
2. 实现百炼地址和请求参数兼容。
3. 执行离线回归测试并审查后提交。

## 风险与决策

- 仅对自定义 OpenAI 中受识别的百炼 HTTPS 地址应用专属参数。
- 保留显式思考模型及第三方代理的请求行为。

## 进度

- [x] 对照应用和 SDK 源码。
- [x] 实现并完成可用的离线验证。

## 验证

- 使用 SwiftPM 与 MacPaw OpenAI 0.5.1 编译实际传输和 Prompt 源文件，9 项离线测试通过。
- 工程配置与 Swift 源文件语法检查通过。
- 缺少完整 Xcode，未运行应用测试目标或 UI 验收。未调用百炼线上 API。

## 完成条件

- 回归检查通过，记录应用构建和真实 API 验证的可用范围。
