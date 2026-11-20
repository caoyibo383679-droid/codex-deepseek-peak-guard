---
name: deepseek-peak-guard
description: "Guard planned or billable DeepSeek API usage against Beijing-time peak hours and steer non-urgent work into the off-peak discount window."
---

# DeepSeek Peak Guard

Use this skill when helping with a request that will call, test, benchmark,
batch, or schedule the DeepSeek API.

Treat API cost control as a real constraint: defer non-urgent billable usage to
the off-peak discount window, but do not block urgent or explicitly requested
work.

The `UserPromptSubmit` hook delegates to `scripts/guard.ps1`. The hook reads
this skill's `enabled` setting from the global Codex `config.toml`; disabling
**DeepSeek Peak Guard** in Codex's Skills settings stops the global prompt
interception.

## Check before the first paid call

1. Determine the current time in Beijing (`Asia/Shanghai`) unless the user
   specifies another timezone.
2. Apply the peak schedule shown in DeepSeek's pricing documentation. At the
   time this project was written, Chinese statutory working weekdays use peak
   windows of 09:00–12:00 and 14:00–18:00. Weekends and Chinese statutory
   holidays are off-peak all day. Verify the provider's current pricing before
   relying on an exact discount.
3. If the work is non-urgent and currently peak, stop before the paid call and
   ask the user to choose whether to continue. Include the current peak window
   and the next off-peak start. Do not proceed unless the user explicitly
   chooses to continue.
4. If the user chooses to continue, or the work is needed for debugging,
   reduce avoidable spend: choose the cheapest suitable model, cap output
   length, batch requests, avoid repeated retries, and estimate token usage
   where practical.
5. Never invent a price, discount, or savings amount. Never claim a reminder
   or scheduled run exists unless it has been verified.

## During implementation

Keep API keys out of logs and source control. Prefer dry runs and small smoke
tests so a mistake does not consume a large batch. When the task can be
separated, run minimal non-billable preparation immediately and leave only the
paid call for off-peak.

