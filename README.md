# DeepSeek Peak Guard for Codex

An unofficial Codex skill and `UserPromptSubmit` hook that prevents accidental
DeepSeek API usage during peak-price hours.

The guard runs locally before the model request. During a peak window, Codex
shows a confirmation dialog before continuing. Choosing **No**, or closing the
dialog, cancels the request without sending it to DeepSeek.

## Features

- Runs before the billable model request
- Uses Beijing time and DeepSeek's weekday peak windows
- Allows all requests during weekends and configured statutory holidays
- Skips non-DeepSeek models
- Handles daylight-independent China Standard Time conversion
- Fails closed during peak hours if the guard cannot complete
- Uses JSON Unicode escapes so Windows PowerShell cannot corrupt Chinese text
- Includes no API key, account data, or model credentials

## Requirements

- Codex with `UserPromptSubmit` hook support
- Windows PowerShell 5.1 or later
- The DeepSeek model provider configured in Codex

> DeepSeek's pricing schedule can change. This project is not affiliated with
> DeepSeek or OpenAI. Verify the provider's current pricing documentation.

## Install

1. Copy this repository to:

   ```text
   %USERPROFILE%\.codex\skills\deepseek-peak-guard
   ```

2. Add the following to `%USERPROFILE%\.codex\config.toml` and replace
   `YOUR_USERNAME` with your Windows username:

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
   statusMessage = "Checking DeepSeek peak pricing"
   ```

3. Restart Codex.

4. Approve the hook when Codex asks for hook trust.

Current Codex versions use the `UserPromptSubmit` event name exactly. The
snake-case form `user_prompt_submit` is not equivalent.

## How it works

The hook receives a JSON object containing the active model and prompt. It
checks Beijing time before parsing the prompt:

1. Off-peak: exit immediately and let the request proceed.
2. Peak: check the model, show a confirmation dialog, and block on **No**.
3. Failure during peak: fail closed and cancel the request.

The guard does not add `additionalContext`, so normal successful requests do
not receive extra model tokens from the hook.

## Holiday calendar

Add one date per line in `scripts/deepseek-holidays.txt`:

```text
2026-10-01
2026-10-02
```

Lines beginning with `#` are ignored. Weekends are detected automatically.

## Manual tests

Force the peak branch and return a block response without opening a dialog:

```powershell
$inputJson = '{"model":"deepseek-flash","prompt":"test"}'
$inputJson | powershell.exe -NoProfile -STA -ExecutionPolicy Bypass `
  -File .\scripts\guard.ps1 -ForcePeak -TestDecision Deny
```

During off-peak hours, the command below should exit with code `0` and produce
no output:

```powershell
$inputJson = '{"model":"deepseek-flash","prompt":"test"}'
$inputJson | powershell.exe -NoProfile -STA -ExecutionPolicy Bypass `
  -File .\scripts\guard.ps1
```

## Security

Do not commit `%USERPROFILE%\.codex\config.toml`, API keys, auth files, session
logs, or local backups. This repository's `.gitignore` excludes common examples,
but always inspect staged files before publishing.

## License

MIT
