<#
Windows 端侧转写资源获取脚本（批次 103，M5）。

做两件事：
  1) 下载 sherpa-onnx Windows x64 预编译库（no-tts 版），解出
     `sherpa-onnx-c-api.dll` / `onnxruntime.dll` / `onnxruntime_providers_shared.dll`
     到 `.tools/asr/models/`（运行时目录，与应用私有目录一致）；
  2) 可选 `-InstallTo <目录>`：把运行库复制到桌面版构建产物目录旁，
     方便开发期直接跑 `moodiary.exe` 验证。

模型文件（silero_vad.onnx / model.int8.onnx / tokens.txt）由
`tool/fetch_asr_model.ps1` 负责，两者共用同一个 models 目录。

用法：
  pwsh -ExecutionPolicy Bypass -File tool\fetch_asr_windows.ps1
  pwsh -ExecutionPolicy Bypass -File tool\fetch_asr_windows.ps1 -InstallTo build\windows\x64\runner\Release
#>
param(
  [string]$InstallTo = '',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $root '.tools\asr'
$modelDir = Join-Path $cache 'models'
New-Item -ItemType Directory -Force -Path $cache, $modelDir | Out-Null

$SherpaVersion = 'v1.13.8'
$Asset = "sherpa-onnx-$SherpaVersion-win-x64-shared-MD-Release-no-tts.tar.bz2"
$Url = "https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/$SherpaVersion/$Asset"

$tar = Join-Path $cache 'sherpa-win.tar.bz2'
if ((-not (Test-Path $tar)) -or $Force) {
  Write-Host "下载 $Asset（约 18MB）"
  & curl.exe -sL --retry 5 --retry-delay 3 -o $tar $Url
  if (-not (Test-Path $tar) -or (Get-Item $tar).Length -eq 0) { throw "下载失败：$Url" }
}

$extract = Join-Path $cache 'win-extract'
if ((-not (Test-Path $extract)) -or $Force) {
  New-Item -ItemType Directory -Force -Path $extract | Out-Null
  & tar.exe -xjf $tar -C $extract
}

# 找到 bin 目录（解出来的包名随版本变化，这里自动定位）
$binDir = Get-ChildItem -Path $extract -Recurse -Filter 'sherpa-onnx-c-api.dll' |
  Select-Object -First 1 -ExpandProperty DirectoryName
if (-not $binDir) { throw "解包后没找到 sherpa-onnx-c-api.dll（$extract）" }

$winLibs = @(
  'sherpa-onnx-c-api.dll',
  'onnxruntime.dll',
  'onnxruntime_providers_shared.dll'
)
foreach ($n in $winLibs) {
  $src = Join-Path $binDir $n
  if (Test-Path $src) {
    Copy-Item -Force $src (Join-Path $modelDir $n)
    $mb = [math]::Round((Get-Item $src).Length / 1MB, 2)
    Write-Host "  · $n  $mb MB → $modelDir"
  } else {
    Write-Host "  · 跳过（包内没有）：$n"
  }
}

if ($InstallTo) {
  if (-not (Test-Path $InstallTo)) { throw "目标目录不存在：$InstallTo" }
  foreach ($n in $winLibs) {
    $src = Join-Path $modelDir $n
    if (Test-Path $src) {
      Copy-Item -Force $src (Join-Path $InstallTo $n)
      Write-Host "  · 已复制到 $InstallTo\$n"
    }
  }
}

Write-Host ''
Write-Host '完成。运行库目录：' $modelDir
Write-Host '提示：应用首次启动时，把该目录下的 DLL 与三个模型文件一起放到'
Write-Host '      %APPDATA%\moodiary\asr\ 即可启用 Windows 端侧转写。'
