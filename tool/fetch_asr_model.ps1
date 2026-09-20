<#
端侧实时转写资源获取脚本（批次 103 起）。

做四件事（全部可重复执行，已存在则跳过）：
  1) sherpa-onnx Android 预编译库（arm64-v8a / x86_64）→ android/app/src/main/jniLibs/
  2) sherpa-onnx Kotlin API 源码 → android/app/src/main/kotlin/com/k2fsa/sherpa/onnx/
  3) 端侧模型（silero VAD + Paraformer-large int8 中文）→ .tools/asr/models/
  4) 可选：把模型推送到已连接设备（-PushToDevice）

用法：
  pwsh -ExecutionPolicy Bypass -File tool\fetch_asr_model.ps1
  pwsh -ExecutionPolicy Bypass -File tool\fetch_asr_model.ps1 -PushToDevice -Serial 127.0.0.1:7555

网络说明（本机实测）：GitHub 直连很慢 → 统一走 ghfast.top 镜像；
模型走 ModelScope（国内，快）；HuggingFace 本机不可达，故不使用。
#>
param(
  [switch]$PushToDevice,
  [string]$Serial = '',
  [string]$Pkg = 'cn.yooss.moodiary.debug',
  [string]$Adb = 'D:\AndroidSDK\platform-tools\adb.exe',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $root '.tools\asr'
$modelDir = Join-Path $cache 'models'
$kotlinDst = Join-Path $root 'android\app\src\main\kotlin\com\k2fsa\sherpa\onnx'
$jniDst = Join-Path $root 'android\app\src\main\jniLibs'
New-Item -ItemType Directory -Force -Path $cache, $modelDir, $kotlinDst, $jniDst | Out-Null

$SherpaVersion = 'v1.13.8'
$Mirror = 'https://ghfast.top/'
$Gh = 'https://github.com/k2-fsa/sherpa-onnx/releases/download'
$Raw = "https://github.com/k2-fsa/sherpa-onnx/raw/$SherpaVersion/sherpa-onnx/kotlin-api"

function Fetch([string]$url, [string]$out) {
  if ((Test-Path $out) -and -not $Force -and (Get-Item $out).Length -gt 0) {
    Write-Host "  · 已存在：$(Split-Path -Leaf $out)"
    return
  }
  Write-Host "  · 下载 $url"
  # 单个文件 >2MB 走镜像（GitHub 直连慢）；小文件直连
  $final = if ($url -like 'https://github.com/*' -and $url -match 'releases/download') {
    $Mirror + $url
  } else {
    $url
  }
  & curl.exe -sL --retry 5 --retry-delay 3 -o $out $final
  if (-not (Test-Path $out) -or (Get-Item $out).Length -eq 0) {
    throw "下载失败：$url"
  }
}

Write-Host '[1/4] sherpa-onnx Android 预编译库'
$tar = Join-Path $cache 'sherpa-android.tar.bz2'
Fetch "$Gh/$SherpaVersion/sherpa-onnx-$SherpaVersion-android.tar.bz2" $tar
$extract = Join-Path $cache 'android-extract'
if (-not (Test-Path $extract) -or $Force) {
  if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
  New-Item -ItemType Directory -Force -Path $extract | Out-Null
  & tar.exe -xjf $tar -C $extract
}
foreach ($abi in @('arm64-v8a', 'x86_64')) {
  $src = Join-Path $extract "jniLibs\$abi"
  $dst = Join-Path $jniDst $abi
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  # 只取 JNI 库（Kotlin API 依赖它）+ onnxruntime；c-api / cxx-api 走 Dart FFI 才需要，
  # Android 侧不用，剔除以减小安装包。
  Copy-Item -Force (Join-Path $src 'libsherpa-onnx-jni.so') $dst
  Copy-Item -Force (Join-Path $src 'libonnxruntime.so') $dst
  Write-Host "  · $abi → $(Join-Path $jniDst $abi)"
}

Write-Host '[2/4] sherpa-onnx Kotlin API 源码'
$files = & curl.exe -sL "https://api.github.com/repos/k2-fsa/sherpa-onnx/contents/sherpa-onnx/kotlin-api?ref=$SherpaVersion" |
  ConvertFrom-Json
foreach ($f in $files) {
  if ($f.name -notlike '*.kt') { continue }
  Fetch "$Raw/$($f.name)" (Join-Path $kotlinDst $f.name)
}
Write-Host "  · Kotlin API 共 $($files.Count) 个文件 → $kotlinDst"

# 2.1 自检样例音频（16k/mono/16bit 真实人声）→ Android assets
#     来源：paraformer-zh-small 包内 test_wavs；用真实语音才能验证"识别正确"
$selfTestWav = Join-Path $root 'android\app\src\main\assets\asr_selftest.wav'
if ((-not (Test-Path $selfTestWav)) -or $Force) {
  $sampleDir = Join-Path $cache 'small-extract\sherpa-onnx-paraformer-zh-small-2024-03-09'
  $sampleWav = Join-Path $sampleDir 'test_wavs\0.wav'
  if (-not (Test-Path $sampleWav) -or $Force) {
    $smallTar = Join-Path $cache 'paraformer-small.tar.bz2'
    Fetch "$Gh/asr-models/sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2" $smallTar
    if (Test-Path $smallTar) {
      & tar.exe -xjf $smallTar -C (Join-Path $cache 'small-extract')
    }
  }
  if (Test-Path $sampleWav) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $selfTestWav) | Out-Null
    Copy-Item -Force $sampleWav $selfTestWav
    Write-Host '  · 自检样例音频 → android/app/src/main/assets/asr_selftest.wav'
  }
}

Write-Host '[3/4] 端侧模型'
# 3.1 VAD（silero）
Fetch "$Gh/asr-models/silero_vad.onnx" (Join-Path $modelDir 'silero_vad.onnx')
# 3.2 Paraformer-small 中文 int8（sherpa-onnx 官方包，约 78MB）
#
# 为什么用 small 而不是最初选的 large(227MB)：
#   · 体积：78MB vs 227MB，移动端安装/内存压力小一个量级；
#   · 实测：227MB 模型在 MuMu 等 x86_64 模拟器上会在 ONNX Runtime 建会话时
#     静默整进程退出（无 tombstone、无异常），真机上也更容易被系统回收；
#   · 效果：paraformer-zh-small 是官方主推的中文轻量非自回归模型，中文识别足够用，
#     云端精修仍作为兜底（保留原方案）。
$asr = Join-Path $modelDir 'model.int8.onnx'
$tokensTxt = Join-Path $modelDir 'tokens.txt'
if ((-not (Test-Path $asr)) -or (-not (Test-Path $tokensTxt)) -or $Force) {
  $smallTar = Join-Path $cache 'paraformer-small.tar.bz2'
  Fetch "$Gh/asr-models/sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2" $smallTar
  $smallDir = Join-Path $cache 'small-extract'
  New-Item -ItemType Directory -Force -Path $smallDir | Out-Null
  & tar.exe -xjf $smallTar -C $smallDir
  $src = Join-Path $smallDir 'sherpa-onnx-paraformer-zh-small-2024-03-09'
  Write-Host '  · 解出 Paraformer-small int8 模型与词表'
  Copy-Item -Force (Join-Path $src 'model.int8.onnx') $asr
  Copy-Item -Force (Join-Path $src 'tokens.txt') $tokensTxt
}

# 3.3 兜底词表：若模型包没给 tokens.txt，则用 ModelScope 的 tokens.json 转写。
#     ModelScope 给的是**数组**：下标即 token id，元素即 token 文本。
#     输出格式与 sherpa-onnx symbol-table.cc 的 ReadTokens 对齐：`<token> <id>`
if (-not (Test-Path $tokensTxt)) {
  $json = Join-Path $cache 'tokens.json'
  Fetch 'https://www.modelscope.cn/models/iic/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-onnx/resolve/master/tokens.json' $json
  $map = Get-Content -Raw -Encoding UTF8 $json | ConvertFrom-Json
  $lines = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $map.Count; $i++) {
    $tok = [string]$map[$i]
    if ($tok.Length -eq 0) {
      $lines.Add("$i")
    } elseif ($tok.Contains(' ')) {
      # 形如 "<|startofspeech|> 0" 的复合条目：原样保留
      $lines.Add($tok)
    } else {
      $lines.Add("$tok $i")
    }
  }
  [System.IO.File]::WriteAllLines($tokensTxt, $lines, [System.Text.UTF8Encoding]::new($false))
  Write-Host "  · tokens.txt 生成：$($lines.Count) 行"
}

foreach ($n in @('silero_vad.onnx', 'model.int8.onnx', 'tokens.txt')) {
  $p = Join-Path $modelDir $n
  $mb = [math]::Round((Get-Item $p).Length / 1MB, 2)
  Write-Host "  · $n  $mb MB"
}

Write-Host '[4/4] 推送模型到设备（可选）'
if ($PushToDevice) {
  if (-not $Serial) {
    $line = (& $Adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' } | Select-Object -First 1)
    if (-not $line) { throw '没有已授权设备' }
    $Serial = ($line -split '\s+')[0]
  }
  $remote = "/data/local/tmp/asr"
  & $Adb -s $Serial shell "rm -rf $remote; mkdir -p $remote"
  foreach ($n in @('silero_vad.onnx', 'model.int8.onnx', 'tokens.txt')) {
    & $Adb -s $Serial push (Join-Path $modelDir $n) "$remote/$n" | Out-Null
  }
  # 放进应用私有目录（run-as 免 root）
  $filesDir = (& $Adb -s $Serial shell "run-as $Pkg pwd" 2>&1) -join ''
  if ($filesDir -match '/') {
    & $Adb -s $Serial shell "run-as $Pkg mkdir -p files/asr"
    foreach ($n in @('silero_vad.onnx', 'model.int8.onnx', 'tokens.txt')) {
      & $Adb -s $Serial shell "cat $remote/$n | run-as $Pkg sh -c 'cat > files/asr/$n'" | Out-Null
    }
    Write-Host "  · 已推送到 $Pkg 的 files/asr/"
  } else {
    Write-Host "  · 设备上没有 $Pkg（先安装一次 App 再推送），模型已放到 $remote"
  }
} else {
  Write-Host '  · 跳过（加 -PushToDevice 可自动推送）'
}

Write-Host ''
Write-Host '完成。模型目录：' $modelDir
