[CmdletBinding()]
param(
    [ValidateSet("Auto", "Allow", "Deny")]
    [string]$TestDecision = "Auto",

    [switch]$ForcePeak,

    [string]$SkillConfigPath = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Text.UTF8Encoding]::new($false)

function ConvertTo-AsciiJson {
    param([string]$Json)

    $builder = [Text.StringBuilder]::new($Json.Length)
    foreach ($character in $Json.ToCharArray()) {
        $code = [int]$character
        if ($code -ge 32 -and $code -le 126) {
            [void]$builder.Append($character)
        }
        else {
            [void]$builder.Append(('\u{0:x4}' -f $code))
        }
    }
    $builder.ToString()
}

function Decode-Text {
    param([string]$Base64)
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64))
}

$noInputReason = Decode-Text "RGVlcFNlZWsg6auY5bOw5pyf5a6I6Zeo5rKh5pyJ5pS25Yiw5Lu75Yqh5L+h5oGv77yM5bey5Li66YG/5YWN6K+v5omj6LS56ICM5YGc5q2i5pys5qyh5Lu75Yqh44CC"
$failureReason = Decode-Text "RGVlcFNlZWsg6auY5bOw5pyf5a6I6Zeo6L+Q6KGM5aSx6LSl77yM5bey5Li65L+d5oqk6LS555So6ICM5YGc5q2i5pys5qyh5Lu75Yqh44CC"
$reasonTemplate = Decode-Text "5b2T5YmN5aSE5LqOIERlZXBTZWVrIOmrmOWzsOaXtuaute+8iHswfe+8jOWMl+S6rOaXtumXtO+8ie+8jOe7p+e7reS7u+WKoeS8muaMiemrmOWzsOS7t+iuoei0ueOAgg=="
$question = Decode-Text "5piv5ZCm57un57ut5pys5qyh5Lu75Yqh77yf"
$title = Decode-Text "RGVlcFNlZWsg6auY5bOw5pyf5o+Q6YaS"
$cancelledSuffix = Decode-Text "IOS7u+WKoeW3suWPlua2iO+8jOayoeacieWPkemAgeaooeWei+ivt+axguOAgg=="

function Test-SkillEnabled {
    param([string]$ConfigPath)

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return $true
    }

    $skillPath = [IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "..\SKILL.md")
    )
    $inSkillsConfig = $false
    $matchesGuardSkill = $false
    $enabled = $true

    foreach ($line in Get-Content -LiteralPath $ConfigPath) {
        $trimmed = $line.Trim()

        if ($trimmed -eq "[[skills.config]]") {
            $inSkillsConfig = $true
            $matchesGuardSkill = $false
            $enabled = $true
            continue
        }

        if ($trimmed.StartsWith("[[") -and $trimmed -ne "[[skills.config]]") {
            if ($inSkillsConfig -and $matchesGuardSkill) {
                return $enabled
            }

            $inSkillsConfig = $false
            continue
        }

        if (-not $inSkillsConfig) {
            continue
        }

        if ($trimmed -match "^path\s*=\s*(.+)$") {
            $configuredPath = $Matches[1].Trim().Trim([char]39).Trim([char]34)
            try {
                $matchesGuardSkill = (
                    [IO.Path]::GetFullPath($configuredPath) -ieq $skillPath
                )
            }
            catch {
                $matchesGuardSkill = $false
            }
            continue
        }

        if ($trimmed -match "^enabled\s*=\s*(true|false)\s*$") {
            $enabled = $Matches[1] -eq "true"
        }
    }

    if ($inSkillsConfig -and $matchesGuardSkill) {
        return $enabled
    }

    return $true
}

function Stop-DeepSeekPrompt {
    param([string]$Reason)

    $json = @{
        decision = "block"
        reason = $Reason
        systemMessage = $Reason
    } | ConvertTo-Json -Compress

    [Console]::Out.WriteLine((ConvertTo-AsciiJson $json))
    exit 0
}

try {
    $chinaTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")
    $now = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $chinaTimeZone)
    $isWeekend = $now.DayOfWeek -in @(
        [DayOfWeek]::Saturday,
        [DayOfWeek]::Sunday
    )

    $isPeak = (-not $isWeekend) -and (
        (($now.TimeOfDay -ge [TimeSpan]::FromHours(9)) -and ($now.TimeOfDay -lt [TimeSpan]::FromHours(12))) -or
        (($now.TimeOfDay -ge [TimeSpan]::FromHours(14)) -and ($now.TimeOfDay -lt [TimeSpan]::FromHours(18)))
    )

    # Statutory holidays are off-peak. Add one YYYY-MM-DD date per line to
    # deepseek-holidays.txt when the official calendar for a new year is out.
    $holidayPath = Join-Path $PSScriptRoot "deepseek-holidays.txt"
    if ($isPeak -and (Test-Path -LiteralPath $holidayPath)) {
        $today = $now.ToString("yyyy-MM-dd")
        $holidayDates = Get-Content -LiteralPath $holidayPath |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith("#") }

        if ($holidayDates -contains $today) {
            $isPeak = $false
        }
    }

    if ($ForcePeak) {
        $isPeak = $true
    }

    if (-not $isPeak) {
        exit 0
    }
    $codexConfigPath = if ([string]::IsNullOrWhiteSpace($SkillConfigPath)) {
        Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\config.toml"
    }
    else {
        $SkillConfigPath
    }

    if (-not (Test-SkillEnabled -ConfigPath $codexConfigPath)) {
        exit 0
    }

    $rawInput = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        Stop-DeepSeekPrompt $noInputReason
    }

    $payload = $rawInput | ConvertFrom-Json
    $model = [string]$payload.model

    # Leave non-DeepSeek providers untouched if the user switches models.
    if ($model -notmatch "(?i)deepseek") {
        exit 0
    }


    $window = if ($now.Hour -lt 12) { "09:00-12:00" } else { "14:00-18:00" }
    $reason = $reasonTemplate -f $window

    if ($TestDecision -eq "Allow") {
        exit 0
    }

    if ($TestDecision -eq "Deny") {
        Stop-DeepSeekPrompt ($reason + $cancelledSuffix)
    }

    Add-Type -AssemblyName PresentationFramework
    $choice = [System.Windows.MessageBox]::Show(
        ($reason + "`r`n`r`n" + $question),
        $title,
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning,
        [System.Windows.MessageBoxResult]::No
    )

    if ($choice -eq [System.Windows.MessageBoxResult]::Yes) {
        exit 0
    }

    Stop-DeepSeekPrompt ($reason + $cancelledSuffix)
}
catch {
    # Fail closed: a broken guard must not silently spend at peak prices.
    Stop-DeepSeekPrompt $failureReason
}
