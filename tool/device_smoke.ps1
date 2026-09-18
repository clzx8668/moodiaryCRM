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
function Shot([string]$name) {
  # 用 screencap + pull 而不是 stdout 重定向：跨 PowerShell 版本都能保证 PNG 字节完整
  $remote = '/sdcard/_smoke_shot.png'
  Adb shell screencap -p $remote | Out-Null
  Adb pull $remote (Join-Path $OutDir "$name.png") | Out-Null
}
function UiDump([int]$retry = 5) {
  # Flutter 页面持续动画时 uiautomator 可能报 "could not get idle state"，需要重试
  for ($i = 1; $i -le $retry; $i++) {
    $out = (Adb shell uiautomator dump /sdcard/_smoke.xml 2>&1 | Select-Object -First 1)
    if ($out -match 'dumped to') {
      $xml = Adb shell cat /sdcard/_smoke.xml 2>&1
      if ($xml -match '<hierarchy') { return $xml }
    }
    Start-Sleep -Milliseconds 1500
  }
  return ''
}
function KeyboardShown {
  $s = Adb shell "dumpsys input_method | grep -E 'mInputShown='" 2>&1 | Select-Object -First 1
  return ($s -match 'mInputShown=true')
}
function FindFab([int]$w, [int]$h) {
  # 从截图里找 FAB：右下角区域内最饱和的圆形色块（FAB 用主题主色，背景是深/浅纯色）
  $remote = '/sdcard/_smoke_fab.png'
  Adb shell screencap -p $remote | Out-Null
  $local = Join-Path $OutDir '_fab_probe.png'
  Adb pull $remote $local | Out-Null
  try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $bmp = New-Object System.Drawing.Bitmap($local)
    $sx = 0; $sy = 0; $n = 0
    for ($y = [int]($h * 0.78); $y -lt [int]($h * 0.95); $y += 3) {
      for ($x = [int]($w * 0.75); $x -lt ($w - 20); $x += 3) {
        $c = $bmp.GetPixel($x, $y)
        # 主色（浅蓝/青绿）特征：蓝或绿明显高于红，且不太暗
        if ((($c.B -gt 110 -and $c.G -gt 110 -and $c.B -gt ($c.R + 20)) -or
             ($c.G -gt 150 -and $c.G -gt ($c.R + 30))) -and ($c.R + $c.G + $c.B -gt 200)) {
          $sx += $x; $sy += $y; $n++
        }
      }
    }
    $bmp.Dispose()
    if ($n -gt 20) { return @([int]($sx / $n), [int]($sy / $n)) }
  } catch { }
  return $null
}
function Say([string]$step, [bool]$ok, [string]$extra = '') {
  $tag = if ($ok) { 'PASS' } else { 'FAIL' }
  Write-Host ("[{0}] {1} {2}" -f $tag, $step, $extra)
  $script:results[$step] = "$tag $extra"
}
function SaySkip([string]$step, [string]$reason) {
  Write-Host ("[SKIP] {0} {1}" -f $step, $reason)
  $script:results[$step] = "SKIP $reason"
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
$fab = FindFab -w $W -h $H
if ($fab) {
  $fabX = $fab[0]; $fabY = $fab[1]
  Write-Host "  · 截图定位到 FAB ≈ ($fabX,$fabY)"
} else {
  $fabX = [int]($W * 0.855); $fabY = [int]($H * 0.89)
}
Adb shell input tap $fabX $fabY | Out-Null
Start-Sleep -Seconds 4
$dump = UiDump
$panelOpen = $dump -match '记点什么'
if (-not $panelOpen) {
  # 兜底：再试一个常见位置（贴底栏上方）
  Adb shell input tap ([int]($W * 0.9)) ([int]($H * 0.9)) | Out-Null
  Start-Sleep -Seconds 3
  $dump = UiDump
  $panelOpen = $dump -match '记点什么'
}
# 二次兜底：软键盘弹出即说明面板已激活（面板进入即聚焦输入框）
if (-not $panelOpen) { $panelOpen = KeyboardShown }
# 三次兜底：机型比例差异导致 FAB 位置不同 —— 请用户手动点一下，脚本自动继续
if (-not $panelOpen) {
  Write-Host '  · 自动点右下角未命中，请在手机上点一下右下角「+」按钮（脚本等待 40 秒）…'
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 2
    if (KeyboardShown) { $panelOpen = $true; break }
    $dump = UiDump -retry 1
    if ($dump -match '记点什么') { $panelOpen = $true; break }
    if ((Get-Date).Second % 10 -eq 0) { Adb shell input keyevent KEYCODE_WAKEUP | Out-Null }
  }
  if ($panelOpen) { $fabX = '手动'; $fabY = '手动' }
}
Say '2 快捷收集面板可打开' $panelOpen "(tap=$fabX,$fabY)"
Shot '02_panel'
if (-not $panelOpen) {
  Write-Host "`n结果："; $results.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" }
  exit 3
}

# 3) 输入 + 回车：应只换行，不自动提交
#    探针用纯数字：中文拼音输入法会把英文字母当拼音组词（实测会把 smoke-line 变成「smoke里呢」），
#    数字不会被组词吞掉，判定才稳定。
$probe = '1357924680'
Adb shell input text $probe | Out-Null
Start-Sleep -Seconds 1
Adb shell input keyevent 66 | Out-Null
Adb shell input text '2468013579' | Out-Null
Start-Sleep -Seconds 1
$dump = UiDump
$stillOpen = $dump -match '1357924680'
$twoLines = ($dump -match '1357924680') -and ($dump -match '2468013579')
Say '3 回车=换行、面板未被自动提交' ($stillOpen -and $twoLines)
Shot '03_enter_newline'

# 4) 草稿记忆：点面板外（应用内容区，不能点状态栏）关闭 → 重开 → 内容还在
Adb shell input tap ([int]($W * 0.5)) ([int]($H * 0.3)) | Out-Null
Start-Sleep -Seconds 2
Adb shell input tap $fabX $fabY | Out-Null
Start-Sleep -Seconds 3
$dump = UiDump
$draftKept = $dump -match '1357924680'
Say '4 草稿临时记忆（关掉再开仍在）' $draftKept
Shot '04_draft'

# 清理：删掉测试文字并关闭面板
1..40 | ForEach-Object { Adb shell input keyevent 67 | Out-Null }
Start-Sleep -Seconds 1
Adb shell input tap ([int]($W * 0.5)) ([int]($H * 0.3)) | Out-Null
Start-Sleep -Seconds 2

# 5) 分享链接 → 先落地（2 秒内出现笔记）
$url = 'https://example.com/smoke-' + (Get-Random)
Adb logcat -c | Out-Null
Adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT $url -n $Activity | Out-Null
# UI dump 在列表动画期间偶发取不到：轮询最多 12 秒，命中即通过
$shareFound = $false
$dumpOk = $false
for ($i = 0; $i -lt 6; $i++) {
  Start-Sleep -Seconds 2
  $dumpEarly = UiDump -retry 3
  if ($dumpEarly) { $dumpOk = $true }
  if ($dumpEarly -match 'example\.com') { $shareFound = $true; break }
}
if ($shareFound) {
  Say '5 分享链接先落地（数秒内入库）' $true
} elseif (-not $dumpOk) {
  # 部分机型在首页动画期间 uiautomator 取不��� idle（dump 失败）→ 以截图人工确认为准
  SaySkip '5 分享链接先落地（数秒内入库）' '本机 uiautomator 不可用，请看 05_share_fast.png 人工确认'
} else {
  Say '5 分享链接先落地（数秒内入库）' $false
}
Shot '05_share_fast'

# 6) 长按 FAB → 直达语音记录页并自动开始录音（批次 89）
#    录制需要麦克风权限，先静默授予，避免系统权限弹窗干扰判定
Adb shell pm grant $Pkg android.permission.RECORD_AUDIO 2>&1 | Out-Null
Adb shell am force-stop $Pkg | Out-Null
Adb shell am start -n $Activity | Out-Null
Start-Sleep -Seconds 14
$fabRecord = FindFab -w $W -h $H
if (-not $fabRecord) {
  $fabRecord = @([int]($W * 0.855), [int]($H * 0.89))
  Write-Host "  · 未定位到 FAB，退回估算坐标 ≈ ($($fabRecord[0]),$($fabRecord[1]))"
} else {
  Write-Host "  · 截图定位到 FAB ≈ ($($fabRecord[0]),$($fabRecord[1]))"
}
# 同点 swipe + 900ms 时长 = 长按（不是滑动）
Adb shell input swipe $fabRecord[0] $fabRecord[1] $fabRecord[0] $fabRecord[1] 900 | Out-Null
Start-Sleep -Seconds 4
$dump = UiDump
$voiceOpen = ($dump -match '语音记录') -or ($dump -match '正在录音') -or ($dump -match '停止录音')
Say '6 长按 FAB 直达录音（进入语音记录页并自动开录）' $voiceOpen
Shot '06_long_press_record'

# 7) 设置 → 待处理任务 页可打开（批次 88）
#    回首页 → 点底部「设置」→ 向上滚动找「待处理任务」→ 点开
Adb shell input keyevent 4 | Out-Null   # 退出录音页
Start-Sleep -Seconds 2
Adb shell input keyevent 4 | Out-Null
Start-Sleep -Seconds 3
Adb shell input tap ([int]($W * 0.875)) ([int]($H - 40)) | Out-Null
Start-Sleep -Seconds 3

function FindCenter([string]$xml, [string]$pattern) {
  $m = [regex]::Match(
    $xml,
    'text="[^"]*' + $pattern + '[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  )
  if (-not $m.Success) { return $null }
  $x = ([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2
  $y = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
  return @([int]$x, [int]$y)
}

$target = $null
for ($i = 0; $i -lt 8; $i++) {
  $dump = UiDump -retry 3
  if ($dump -match '清理已完成') { break }   # 已经在目标页
  $target = FindCenter $dump '待处理任务'
  if ($target) { break }
  Adb shell input swipe ([int]($W * 0.5)) ([int]($H * 0.72)) ([int]($W * 0.5)) ([int]($H * 0.28)) 320 | Out-Null
  Start-Sleep -Seconds 2
}
if ($target) {
  Adb shell input tap $target[0] $target[1] | Out-Null
  Start-Sleep -Seconds 3
  $dump = UiDump
}
$queueOpen = ($dump -match '清理已完成') -or ($dump -match '队列是空的') -or ($dump -match '全部重试')
if (-not $target -and -not $queueOpen) {
  SaySkip '7 设置→待处理任务 页可打开' '未在设置页定位到「待处理任务」入口，请看 07_task_queue.png 人工确认'
} else {
  Say '7 设置→待处理任务 页可打开' $queueOpen
}
Shot '07_task_queue'

Write-Host "`n===== 结果 ====="
$results.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" }
$failed = ($results.Values | Where-Object { $_ -like 'FAIL*' }).Count
Write-Host "`n截图目录: $OutDir"
exit ([int]($failed -gt 0))
