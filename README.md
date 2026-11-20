# DeepSeek 错峰守门

[简体中文](README.md) | [English](README.en.md)

一个非官方的 Codex Skill 与 `UserPromptSubmit` Hook，用于在 DeepSeek 高峰
计费时段阻止误触发的 API 请求。

Hook 会在模型请求发出前于本地运行。进入高峰时段后，Codex 会先显示确认窗口：
选择“否”或关闭窗口，本次请求会被取消，不会发送给 DeepSeek。

## 功能

- 在计费请求发出前拦截
- 使用北京时间判断 DeepSeek 工作日高峰时段
- 周末和法定节假日全天放行
- 自动跳过非 DeepSeek 模型
- 非高峰期直接放行，不读取或解析消息内容
- 高峰期脚本异常时采取保守策略，停止本次请求
- 使用 JSON Unicode 转义，避免 Windows PowerShell 造成中文乱码
- 不包含 API Key、账号信息或模型凭据

## 环境要求

- 支持 `UserPromptSubmit` Hook 的 Codex
- Windows PowerShell 5.1 或更高版本
- 已在 Codex 中配置 DeepSeek 模型提供商

> DeepSeek 的价格和时段可能变化。本项目与 DeepSeek、OpenAI 均无隶属关系，
> 使用前请核对服务商最新的价格文档。

## 安装

1. 将仓库复制到：

   ```text
   %USERPROFILE%\.codex\skills\deepseek-peak-guard
   ```

2. 在 `%USERPROFILE%\.codex\config.toml` 中加入以下内容，并将
   `YOUR_USERNAME` 替换为你的 Windows 用户名：

   ```toml
   [[skills.config]]
   path = 'C:\Users\YOUR_USERNAME\.codex\skills\deepseek-peak-guard\SKILL.md'
   enabled = true

   [[hooks.UserPromptSubmit]]
   matcher = ".*"

   [[hooks.UserPromptSubmit.hooks]]
   type = "command"
   command = 'powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "C:\Users\YOUR_USERNAME\.codex\skills\deepseek-peak-guard\scripts\guard.ps1"'
   timeout = 600
   statusMessage = "检查 DeepSeek 高峰期"
   ```

3. 重启 Codex。

4. Codex 询问是否信任 Hook 时选择允许。

当前 Codex 版本要求事件名严格写为 `UserPromptSubmit`。全小写写法
`user_prompt_submit` 不会被识别为同一个事件。

## 工作方式

Hook 接收的 JSON 中包含当前模型和用户消息。脚本会先判断北京时间：

1. 非高峰期：立即放行，不解析消息。
2. 高峰期：检查模型，显示确认窗口。
3. 高峰期脚本异常：取消请求，避免意外按高峰价计费。

本 Hook 不添加 `additionalContext`，因此正常任务不会因为守门逻辑额外消耗
输入 Token。

## 法定节假日

在 `scripts/deepseek-holidays.txt` 中每行添加一个日期：

```text
2026-10-01
2026-10-02
```

以 `#` 开头的行会被忽略，周末会自动判断。

## 手动测试

强制进入高峰期分支，并直接返回拦截结果：

```powershell
$inputJson = '{"model":"deepseek-flash","prompt":"test"}'
$inputJson | powershell.exe -NoProfile -STA -ExecutionPolicy Bypass `
  -File .\scripts\guard.ps1 -ForcePeak -TestDecision Deny
```

非高峰期执行下面的命令时，应当退出码为 `0` 且没有输出：

```powershell
$inputJson = '{"model":"deepseek-flash","prompt":"test"}'
$inputJson | powershell.exe -NoProfile -STA -ExecutionPolicy Bypass `
  -File .\scripts\guard.ps1
```

## 安全说明

不要提交 `%USERPROFILE%\.codex\config.toml`、API Key、认证文件、会话日志
或本地备份。`.gitignore` 已排除常见敏感文件，但提交前仍应检查暂存内容。

## 许可证

MIT
