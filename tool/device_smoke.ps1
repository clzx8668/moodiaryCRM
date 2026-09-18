<#
真机冒烟脚本（批次 86 起）：在已连接的 Android 设备上自动跑一遍「采集链路」关键项，
每步截图存盘，输出 PASS/FAIL 摘要。

用法：
  # 单设备
  powershell -ExecutionPolicy Bypass -File tool\device_smoke.ps1
  # 指定设备与输出目录
  powershell -ExecutionPolicy Bypass -File tool\device_smoke.ps1 -Serial A2NMVB1806003756 -OutDir E:\temp\smoke

检查项：
  1) 应用可启动（前台为 MainActivity）
  2) 快捷收集面板可打开
  3) 输入文字后按「回车」= 换行，面板不被自动提交（本次修复重点）
  4) 关闭面板再打开：草稿仍在（临时记忆）
  5) 系统分享链接 → 2 秒内即出现笔记（先落地）

前置：设备已解锁并保持亮屏（脚本会先唤醒，但不会也无法解锁）。
#>
param(
  [string]$Serial = '',
  [string]$Adb = 'D:\AndroidSDK\platform-tools\adb.exe',
  [string]$Pkg = 'cn.yooss.moodiary.debug',
  [string]$Activity = 'cn.yooss.moodiary.debug/cn.yooss.moodiary.MainActivity',
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
if (-not $OutDir) { $OutDir = Join-Path $env:TEMP ("moodiary_smoke_" + (Get-Date -Format 'MMdd_HHmmss')) }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not $Serial) {
  $lines = & $Adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' }
  if (-not $lines) { throw "没有已授权的设备（请确认已解锁并允许 USB 调试）" }
  $Serial = ($lines[0] -split '\s+')[0]
}

$results = [ordered]@{}
function Adb { & $Adb -s $Serial @args }
function Shot([string]$name) { Adb exec-out screencap -p > (Join-Path $OutDir "$name.png") }
function UiDump {
  Adb shell uiautomator dump /sdcard/_smoke.xml | Out-Null
  return (Adb shell cat /sdcard/_smoke.xml)
}
function Say([string]$step, [bool]$ok, [string]$extra = '') {
  $tag = if ($ok) { 'PASS' } else { 'FAIL' }
  Write-Host ("[{0}] {1} {2}" -f $tag, $step, $extra)
  $script:results[$step] = "$tag $extra"
}

Write-Host "device=$Serial  out=$OutDir"
Adb shell input keyevent KEYCODE_WAKEUP | Out-Null
Start-Sleep -Seconds 1

# 0) 锁屏检查（不自动解锁）
$focus = (Adb shell "dumpsys window | grep -E 'mCurrentFocus'" | Select-Object -First 1)
if ($focus -match 'NotificationShade|StatusBar|Keyguard') {
  Say '0 设备已解锁' $false '当前在锁屏/通知栏，请在手机上解锁后重跑'
  Shot '00_locked'
  Write-Host "`n结果："; $results.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" }
  exit 2
}
Say '0 设备已解锁' $true

# 1) 启动应用
Adb shell am force-stop $Pkg | Out-Null
Adb shell am start -n $Activity | Out-Null
Start-Sleep -Seconds 18
$focus = (Adb shell "dumpsys window | grep -E 'mCurrentFocus'" | Select-Object -First 1)
Say '1 应用可启动（前台 MainActivity）' ($focus -match 'MainActivity')
Shot '01_home'
$size = (Adb shell wm size | Select-Object -Last 1)
$m = [regex]::Match($size, '(\d+)x(\d+)')
$W = [int]$m.Groups[1].Value; $H = [int]$m.Groups[2].Value
Write-Host "  screen=${W}x${H}"

# 2) 打开快捷收集（FAB 在右下角；不同机型比例略有差异，失败时脚本会给出坐标提示）
$fabX = [int]($W * 0.855); $fabY = [int]($H * 0.85)
Adb shell input tap $fabX $fabY | Out-Null
Start-Sleep -Seconds 3
$dump = UiDump
$panelOpen = $dump -match '记点什么'
if (-not $panelOpen) {
  # 兜底：再试一个常见位置（贴底栏上方）
  Adb shell input tap ([int]($W * 0.9)) ([int]($H * 0.9)) | Out-Null
  Start-Sleep -Seconds 2
  $dump = UiDump
  $panelOpen = $dump -match '记点什么'
}
Say '2 快捷收集面板可打开' $panelOpen "(tap=$fabX,$fabY)"
Shot '02_panel'
if (-not $panelOpen) {
  Write-Host "`n结果："; $results.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" }
  exit 3
}

# 3) 输入 + 回车：应只换行，不自动提交
$probe = 'smoke-line-1'
Adb shell input text $probe | Out-Null
Start-Sleep -Seconds 1
Adb shell input keyevent 66 | Out-Null
Adb shell input text 'smoke-line-2' | Out-Null
Start-Sleep -Seconds 1
$dump = UiDump
$stillOpen = $dump -match 'smoke-line-1'
$twoLines = ($dump -match 'smoke-line-1') -and ($dump -match 'smoke-line-2')
Say '3 回车=换行、面板未被自动提交' ($stillOpen -and $twoLines)
Shot '03_enter_newline'

# 4) 草稿记忆：点面板外关闭 → 重开 → 内容还在
Adb shell input tap ([int]($W * 0.5)) ([int]($H * 0.08)) | Out-Null
Start-Sleep -Seconds 2
Adb shell input tap $fabX $fabY | Out-Null
Start-Sleep -Seconds 3
$dump = UiDump
$draftKept = $dump -match 'smoke-line-1'
Say '4 草稿临时记忆（关掉再开仍在）' $draftKept
Shot '04_draft'

# 清理：删掉测试文字并关闭面板
1..40 | ForEach-Object { Adb shell input keyevent 67 | Out-Null }
Start-Sleep -Seconds 1
Adb shell input tap ([int]($W * 0.5)) ([int]($H * 0.08)) | Out-Null
Start-Sleep -Seconds 2

# 5) 分享链接 → 先落地（2 秒内出现笔记）
$url = 'https://example.com/smoke-' + (Get-Random)
Adb logcat -c | Out-Null
Adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT $url -n $Activity | Out-Null
Start-Sleep -Seconds 2
$dumpEarly = UiDump
Say '5 分享链接先落地（2s 内入库）' ($dumpEarly -match 'smoke-')
Shot '05_share_fast'

Write-Host "`n===== 结果 ====="
$results.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" }
$failed = ($results.Values | Where-Object { $_ -like 'FAIL*' }).Count
Write-Host "`n截图目录: $OutDir"
exit ([int]($failed -gt 0))
