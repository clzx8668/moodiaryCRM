//! 端侧（离线）语音识别：Windows 侧实现。
//!
//! 与 Android 侧（Kotlin + JNI）同构：**PCM 进来，文本出去**。
//! 这里用 sherpa-onnx 的 C API（`sherpa-onnx-c-api.dll`）+ runtime 动态加载，
//! 所以构建期不需要任何原生依赖；运行时 DLL 缺失则整体降级（返回 Err，上层回落云端）。
//!
//! 结构体布局严格对照 `c-api.h`（v1.13.8）；`asr_layout_selftest()` 会校验关键
//! 结构体尺寸与入口可解析，避免 ABI 漂移后静默出错。

use std::ffi::{CStr, CString, c_char, c_float, c_int, c_void};
use std::path::{Path, PathBuf};
use std::ptr;

use libloading::{Library, Symbol};

// ---------------------------------------------------------------- C 结构体

#[repr(C)]
#[derive(Clone, Copy)]
struct SileroVadModelConfig {
    model: *const c_char,
    threshold: c_float,
    min_silence_duration: c_float,
    min_speech_duration: c_float,
    window_size: c_int,
    max_speech_duration: c_float,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct TenVadModelConfig {
    model: *const c_char,
    threshold: c_float,
    min_silence_duration: c_float,
    min_speech_duration: c_float,
    window_size: c_int,
    max_speech_duration: c_float,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct VadModelConfig {
    silero_vad: SileroVadModelConfig,
    sample_rate: c_int,
    num_threads: c_int,
    provider: *const c_char,
    debug: c_int,
    ten_vad: TenVadModelConfig,
}

#[repr(C)]
struct SpeechSegment {
    start: c_int,
    samples: *mut c_float,
    n: c_int,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct FeatureConfig {
    sample_rate: c_int,
    feature_dim: c_int,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineTransducerModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    joiner: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineParaformerModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineNemoEncDecCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineWhisperModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    language: *const c_char,
    task: *const c_char,
    tail_paddings: c_int,
    enable_token_timestamps: c_int,
    enable_segment_timestamps: c_int,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineTdnnModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineSenseVoiceModelConfig {
    model: *const c_char,
    language: *const c_char,
    use_itn: c_int,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineMoonshineModelConfig {
    preprocessor: *const c_char,
    encoder: *const c_char,
    uncached_decoder: *const c_char,
    cached_decoder: *const c_char,
    merged_decoder: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineFireRedAsrModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineDolphinModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineZipformerCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineCanaryModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    src_lang: *const c_char,
    tgt_lang: *const c_char,
    use_pnc: c_int,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineWenetCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineOmnilingualAsrCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineMedAsrCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineFunAsrNanoModelConfig {
    encoder_adaptor: *const c_char,
    llm: *const c_char,
    embedding: *const c_char,
    tokenizer: *const c_char,
    system_prompt: *const c_char,
    user_prompt: *const c_char,
    max_new_tokens: c_int,
    temperature: c_float,
    top_p: c_float,
    seed: c_int,
    language: *const c_char,
    itn: c_int,
    hotwords: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineFireRedAsrCtcModelConfig {
    model: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineQwen3AsrModelConfig {
    conv_frontend: *const c_char,
    encoder: *const c_char,
    decoder: *const c_char,
    tokenizer: *const c_char,
    max_total_len: c_int,
    max_new_tokens: c_int,
    temperature: c_float,
    top_p: c_float,
    seed: c_int,
    hotwords: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineCohereTranscribeModelConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    language: *const c_char,
    use_punct: c_int,
    use_itn: c_int,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineModelConfig {
    transducer: OfflineTransducerModelConfig,
    paraformer: OfflineParaformerModelConfig,
    nemo_ctc: OfflineNemoEncDecCtcModelConfig,
    whisper: OfflineWhisperModelConfig,
    tdnn: OfflineTdnnModelConfig,
    tokens: *const c_char,
    num_threads: c_int,
    debug: c_int,
    provider: *const c_char,
    model_type: *const c_char,
    modeling_unit: *const c_char,
    bpe_vocab: *const c_char,
    telespeech_ctc: *const c_char,
    sense_voice: OfflineSenseVoiceModelConfig,
    moonshine: OfflineMoonshineModelConfig,
    fire_red_asr: OfflineFireRedAsrModelConfig,
    dolphin: OfflineDolphinModelConfig,
    zipformer_ctc: OfflineZipformerCtcModelConfig,
    canary: OfflineCanaryModelConfig,
    wenet_ctc: OfflineWenetCtcModelConfig,
    omnilingual: OfflineOmnilingualAsrCtcModelConfig,
    medasr: OfflineMedAsrCtcModelConfig,
    funasr_nano: OfflineFunAsrNanoModelConfig,
    fire_red_asr_ctc: OfflineFireRedAsrCtcModelConfig,
    qwen3_asr: OfflineQwen3AsrModelConfig,
    cohere_transcribe: OfflineCohereTranscribeModelConfig,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineLmConfig {
    model: *const c_char,
    scale: c_float,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct HomophoneReplacerConfig {
    dict_dir: *const c_char,
    lexicon: *const c_char,
    rule_fsts: *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineRecognizerConfig {
    feat_config: FeatureConfig,
    model_config: OfflineModelConfig,
    lm_config: OfflineLmConfig,
    decoding_method: *const c_char,
    max_active_paths: c_int,
    hotwords_file: *const c_char,
    hotwords_score: c_float,
    rule_fsts: *const c_char,
    rule_fars: *const c_char,
    blank_penalty: c_float,
    hr: HomophoneReplacerConfig,
}

type VadHandle = *const c_void;
type RecognizerHandle = *const c_void;
type StreamHandle = *const c_void;

/// `SherpaOnnxOfflineRecognizerResult` 的前 4 个字段（只取 text 即可）
#[repr(C)]
#[derive(Clone, Copy)]
struct OfflineRecognizerResult {
    text: *const c_char,
    timestamps: *mut c_float,
    count: c_int,
    tokens: *const c_char,
}

// ---------------------------------------------------------------- 动态库入口

type FnCreateVad =
    unsafe extern "C" fn(*const VadModelConfig, c_float) -> VadHandle;
type FnDestroyVad = unsafe extern "C" fn(VadHandle);
type FnVadAccept = unsafe extern "C" fn(VadHandle, *const c_float, c_int);
type FnVadEmpty = unsafe extern "C" fn(VadHandle) -> c_int;
type FnVadFront = unsafe extern "C" fn(VadHandle) -> *const SpeechSegment;
type FnVadPop = unsafe extern "C" fn(VadHandle);
type FnVadReset = unsafe extern "C" fn(VadHandle);
type FnVadFlush = unsafe extern "C" fn(VadHandle);
type FnDestroySegment = unsafe extern "C" fn(*const SpeechSegment);

type FnCreateRecognizer =
    unsafe extern "C" fn(*const OfflineRecognizerConfig) -> RecognizerHandle;
type FnDestroyRecognizer = unsafe extern "C" fn(RecognizerHandle);
type FnCreateStream = unsafe extern "C" fn(RecognizerHandle) -> StreamHandle;
type FnDestroyStream = unsafe extern "C" fn(StreamHandle);
type FnAcceptWaveform =
    unsafe extern "C" fn(StreamHandle, c_int, *const c_float, c_int);
type FnDecode = unsafe extern "C" fn(RecognizerHandle, StreamHandle);
type FnStreamResult =
    unsafe extern "C" fn(StreamHandle) -> *const OfflineRecognizerResult;
type FnDestroyResult = unsafe extern "C" fn(*const OfflineRecognizerResult);

/// 原生库 + 全部入口（加载一次，进程内复用）
struct Native {
    _lib: Library,
    _rt: Library,
    vad_create: FnCreateVad,
    vad_destroy: FnDestroyVad,
    vad_accept: FnVadAccept,
    vad_empty: FnVadEmpty,
    vad_front: FnVadFront,
    vad_pop: FnVadPop,
    vad_reset: FnVadReset,
    vad_flush: FnVadFlush,
    seg_destroy: FnDestroySegment,
    rec_create: FnCreateRecognizer,
    rec_destroy: FnDestroyRecognizer,
    stream_create: FnCreateStream,
    stream_destroy: FnDestroyStream,
    accept_waveform: FnAcceptWaveform,
    decode: FnDecode,
    stream_result: FnStreamResult,
    result_destroy: FnDestroyResult,
}

unsafe fn sym<T: Copy>(lib: &Library, name: &str) -> Result<T, String> {
    let s: Symbol<T> = unsafe {
        lib.get(name.as_bytes())
            .map_err(|e| format!("缺少符号 {name}：{e}"))?
    };
    Ok(*s)
}

impl Native {
    /// 从 `dir` 目录加载 `sherpa-onnx-c-api.dll` + `onnxruntime.dll`
    fn load(dir: &Path) -> Result<Self, String> {
        let dll = dir.join("sherpa-onnx-c-api.dll");
        if !dll.exists() {
            return Err(format!("未找到 {}", dll.display()));
        }
        // 先加载 onnxruntime，保证 sherpa 的依赖已就绪
        let rt_path = dir.join("onnxruntime.dll");
        let rt = if rt_path.exists() {
            unsafe {
                Library::new(&rt_path).map_err(|e| format!("加载 onnxruntime 失败：{e}"))?
            }
        } else {
            return Err(format!("未找到 {}", rt_path.display()));
        };
        let lib = unsafe {
            Library::new(&dll).map_err(|e| format!("加载 sherpa-onnx 失败：{e}"))?
        };
        unsafe {
            Ok(Self {
                vad_create: sym(&lib, "SherpaOnnxCreateVoiceActivityDetector")?,
                vad_destroy: sym(&lib, "SherpaOnnxDestroyVoiceActivityDetector")?,
                vad_accept: sym(&lib, "SherpaOnnxVoiceActivityDetectorAcceptWaveform")?,
                vad_empty: sym(&lib, "SherpaOnnxVoiceActivityDetectorEmpty")?,
                vad_front: sym(&lib, "SherpaOnnxVoiceActivityDetectorFront")?,
                vad_pop: sym(&lib, "SherpaOnnxVoiceActivityDetectorPop")?,
                vad_reset: sym(&lib, "SherpaOnnxVoiceActivityDetectorReset")?,
                vad_flush: sym(&lib, "SherpaOnnxVoiceActivityDetectorFlush")?,
                seg_destroy: sym(&lib, "SherpaOnnxDestroySpeechSegment")?,
                rec_create: sym(&lib, "SherpaOnnxCreateOfflineRecognizer")?,
                rec_destroy: sym(&lib, "SherpaOnnxDestroyOfflineRecognizer")?,
                stream_create: sym(&lib, "SherpaOnnxCreateOfflineStream")?,
                stream_destroy: sym(&lib, "SherpaOnnxDestroyOfflineStream")?,
                accept_waveform: sym(&lib, "SherpaOnnxAcceptWaveformOffline")?,
                decode: sym(&lib, "SherpaOnnxDecodeOfflineStream")?,
                stream_result: sym(&lib, "SherpaOnnxGetOfflineStreamResult")?,
                result_destroy: sym(&lib, "SherpaOnnxDestroyOfflineRecognizerResult")?,
                _rt: rt,
                _lib: lib,
            })
        }
    }
}

// ---------------------------------------------------------------- 引擎

/// 端侧识别引擎：VAD 切句 + Paraformer 逐句识别。
pub struct OfflineAsrEngine {
    native: Native,
    vad: VadHandle,
    recognizer: RecognizerHandle,
    /// 会话内已识别文本（供 `take_text` 取用）
    pending: Vec<String>,
    /// C 字符串必须比原生句柄活得更久
    _keep_alive: Vec<CString>,
}

unsafe impl Send for OfflineAsrEngine {}
// FRB 的 RustOpaque 包装要求被包装类型 Send + Sync；我们的句柄只在
// `asr_bridge` 的全局互斥锁内使用，串行访问，因此断言 Sync 是安全的。
unsafe impl Sync for OfflineAsrEngine {}

fn cstring(s: &Path) -> Result<CString, String> {
    CString::new(s.to_string_lossy().replace('\\', "/"))
        .map_err(|e| format!("路径含非法字符：{e}"))
}

impl OfflineAsrEngine {
    /// 加载模型并建好 VAD/识别器。
    ///
    /// `model_dir` 内需含三个模型文件；`lib_dir` 是 `sherpa-onnx-c-api.dll`
    /// 与 `onnxruntime.dll` 所在目录（默认与模型同目录，便于单目录部署）。
    pub fn create(
        model_dir: &Path,
        lib_dir: Option<&Path>,
        num_threads: c_int,
    ) -> Result<Self, String> {
        let native = Native::load(lib_dir.unwrap_or(model_dir))?;
        let vad_model = cstring(&model_dir.join("silero_vad.onnx"))?;
        let asr_model = cstring(&model_dir.join("model.int8.onnx"))?;
        let tokens = cstring(&model_dir.join("tokens.txt"))?;
        let provider = CString::new("cpu").unwrap();

        let vad_cfg = VadModelConfig {
            silero_vad: SileroVadModelConfig {
                model: vad_model.as_ptr(),
                threshold: 0.4,
                min_silence_duration: 0.3,
                min_speech_duration: 0.12,
                window_size: 512,
                max_speech_duration: 20.0,
            },
            sample_rate: 16000,
            num_threads: 1,
            provider: provider.as_ptr(),
            debug: 0,
            ten_vad: TenVadModelConfig {
                model: ptr::null(),
                threshold: 0.5,
                min_silence_duration: 0.25,
                min_speech_duration: 0.25,
                window_size: 256,
                max_speech_duration: 5.0,
            },
        };
        let vad = unsafe { (native.vad_create)(&vad_cfg, 30.0) };
        if vad.is_null() {
            return Err("VAD 创建失败（检查 silero_vad.onnx）".into());
        }

        let mut cfg: OfflineRecognizerConfig = unsafe { std::mem::zeroed() };
        cfg.feat_config = FeatureConfig {
            sample_rate: 16000,
            feature_dim: 80,
        };
        cfg.model_config.paraformer = OfflineParaformerModelConfig {
            model: asr_model.as_ptr(),
        };
        cfg.model_config.tokens = tokens.as_ptr();
        cfg.model_config.num_threads = num_threads;
        cfg.model_config.provider = provider.as_ptr();
        cfg.decoding_method = ptr::null();
        cfg.lm_config.model = ptr::null();
        let recognizer = unsafe { (native.rec_create)(&cfg) };
        if recognizer.is_null() {
            unsafe { (native.vad_destroy)(vad) };
            return Err("识别器创建失败（检查 model.int8.onnx / tokens.txt）".into());
        }

        Ok(Self {
            native,
            vad,
            recognizer,
            pending: Vec::new(),
            _keep_alive: vec![vad_model, asr_model, tokens, provider],
        })
    }

    /// 开始一次会话（清空 VAD 与待取文本）
    pub fn start(&mut self) {
        unsafe { (self.native.vad_reset)(self.vad) };
        self.pending.clear();
    }

    /// 送入一块 16k/mono 的 PCM（f32，范围 [-1,1]）
    pub fn accept(&mut self, samples: &[f32]) {
        if samples.is_empty() {
            return;
        }
        let mut off = 0usize;
        while off < samples.len() {
            let len = (512).min(samples.len() - off);
            unsafe { (self.native.vad_accept)(self.vad, samples[off..].as_ptr(), len as c_int) };
            off += len;
        }
        self.drain();
    }

    /// 收尾：把尾段吐出并识别
    pub fn flush(&mut self) {
        unsafe { (self.native.vad_flush)(self.vad) };
        self.drain();
    }

    /// 取走本会话新识别出来的文本（按句拼接）
    pub fn take_text(&mut self) -> String {
        let s = self.pending.concat();
        self.pending.clear();
        s
    }

    fn drain(&mut self) {
        loop {
            let empty = unsafe { (self.native.vad_empty)(self.vad) };
            if empty != 0 {
                break;
            }
            let seg = unsafe { (self.native.vad_front)(self.vad) };
            if seg.is_null() {
                break;
            }
            let (samples, n) = unsafe { ((*seg).samples, (*seg).n) };
            if !samples.is_null() && n > 0 {
                let slice = unsafe { std::slice::from_raw_parts(samples, n as usize) };
                if let Some(text) = self.recognize(slice) {
                    self.pending.push(text);
                }
            }
            unsafe { (self.native.seg_destroy)(seg) };
            unsafe { (self.native.vad_pop)(self.vad) };
        }
    }

    fn recognize(&self, samples: &[f32]) -> Option<String> {
        let stream = unsafe { (self.native.stream_create)(self.recognizer) };
        if stream.is_null() {
            return None;
        }
        let mut out = None;
        unsafe {
            (self.native.accept_waveform)(
                stream,
                16000,
                samples.as_ptr(),
                samples.len() as c_int,
            );
            (self.native.decode)(self.recognizer, stream);
            let r = (self.native.stream_result)(stream);
            if !r.is_null() {
                let text = (*r).text;
                if !text.is_null() {
                    let s = CStr::from_ptr(text).to_string_lossy().trim().to_string();
                    if !s.is_empty() {
                        out = Some(s);
                    }
                }
                (self.native.result_destroy)(r);
            }
            (self.native.stream_destroy)(stream);
        }
        out
    }
}

impl Drop for OfflineAsrEngine {
    fn drop(&mut self) {
        unsafe {
            if !self.recognizer.is_null() {
                (self.native.rec_destroy)(self.recognizer);
            }
            if !self.vad.is_null() {
                (self.native.vad_destroy)(self.vad);
            }
        }
    }
}

// ---------------------------------------------------------------- 便捷入口

/// 把 16 位小端 PCM 转成 f32
pub fn pcm16_to_f32(bytes: &[u8]) -> Vec<f32> {
    let count = bytes.len() / 2;
    let mut out = Vec::with_capacity(count);
    for i in 0..count {
        let v = i16::from_le_bytes([bytes[i * 2], bytes[i * 2 + 1]]);
        out.push(v as f32 / 32768.0);
    }
    out
}

/// 从 WAV 字节流里剥出 PCM 数据段（跳过 RIFF 头，兼容额外 chunk）
pub fn wav_pcm16(wav: &[u8]) -> Option<Vec<u8>> {
    if wav.len() < 44 {
        return None;
    }
    let mut off = 12usize;
    while off + 8 <= wav.len() {
        let id = &wav[off..off + 4];
        let size = u32::from_le_bytes([wav[off + 4], wav[off + 5], wav[off + 6], wav[off + 7]])
            as usize;
        if id == b"data" {
            let start = off + 8;
            let end = (start + size).min(wav.len());
            if end <= start {
                return None;
            }
            return Some(wav[start..end].to_vec());
        }
        off += 8 + size + (size & 1);
    }
    None
}

/// 默认模型目录（应用支持目录由 Dart 侧给出，这里只提供兜底）。
pub fn default_model_dir() -> Option<PathBuf> {
    dirs_appdata().map(|p| p.join("moodiary").join("asr"))
}

fn dirs_appdata() -> Option<PathBuf> {
    std::env::var_os("APPDATA").map(PathBuf::from)
}

/// 结构体尺寸校验：与 `c-api.h`（x86_64）对齐；不符说明头文件版本变了。
pub fn layout_selftest() -> String {
    let vad = std::mem::size_of::<VadModelConfig>();
    let silero = std::mem::size_of::<SileroVadModelConfig>();
    let rec = std::mem::size_of::<OfflineRecognizerConfig>();
    let model = std::mem::size_of::<OfflineModelConfig>();
    format!(
        "vad={vad} silero={silero} recognizer={rec} model={model}"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn struct_layout_matches_c_api_126() {
        // 尺寸按 c-api.h（x86_64，MSVC 布局）逐字段推导；如 sherpa-onnx 升级导致
        // 结构体变化，这里会先失败，避免运行期静默踩内存。
        assert_eq!(std::mem::size_of::<SileroVadModelConfig>(), 32);
        assert_eq!(std::mem::size_of::<TenVadModelConfig>(), 32);
        assert_eq!(std::mem::size_of::<VadModelConfig>(), 88);
        assert_eq!(std::mem::size_of::<SpeechSegment>(), 24);
        assert_eq!(std::mem::size_of::<OfflineTransducerModelConfig>(), 24);
        assert_eq!(std::mem::size_of::<OfflineWhisperModelConfig>(), 48);
        assert_eq!(std::mem::size_of::<OfflineRecognizerResult>(), 32);
    }

    #[test]
    fn pcm16_decoding_handles_negative_values() {
        let bytes = vec![0x00, 0x80, 0xFF, 0x7F, 0x00, 0x00];
        let f = pcm16_to_f32(&bytes);
        assert_eq!(f.len(), 3);
        assert!((f[0] + 1.0).abs() < 1e-6, "-32768 → -1.0");
        assert!((f[1] - 32767.0 / 32768.0).abs() < 1e-6);
        assert_eq!(f[2], 0.0);
    }

    #[test]
    fn wav_extracts_data_chunk() {
        let mut wav = vec![0u8; 44];
        wav[0..4].copy_from_slice(b"RIFF");
        wav[8..12].copy_from_slice(b"WAVE");
        wav[12..16].copy_from_slice(b"fmt ");
        wav[16..20].copy_from_slice(&16u32.to_le_bytes());
        wav[36..40].copy_from_slice(b"data");
        wav[40..44].copy_from_slice(&4u32.to_le_bytes());
        wav.extend_from_slice(&[1, 2, 3, 4]);
        assert_eq!(wav_pcm16(&wav).unwrap(), vec![1, 2, 3, 4]);
    }

    /// 真机（本机 Windows）端到端自检：需要先跑 `tool/fetch_asr_model.ps1` 拉齐
    /// prebuilt 库 + 模型。默认忽略（CI/无模型环境），需要时显式开启：
    /// `cargo test --lib asr_windows_smoke -- --ignored --nocapture`
    #[test]
    #[ignore = "需要本地 sherpa-onnx 预编译库与模型"]
    fn asr_windows_smoke() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
        let lib_dir = which_prebuilt_lib(&root).expect("未找到 .tools/asr 下的 Windows 预编译库");
        let model_dir = root.join(".tools").join("asr").join("models");
        let wav = which_sample_wav(&root).expect("未找到自检样例 wav");

        let bytes = std::fs::read(&wav).unwrap();
        let pcm = wav_pcm16(&bytes).expect("WAV 无 data 段");

        // 把 DLL 目录加到搜索路径（Windows 上 Library::new 需要能解析依赖）
        let old_path = std::env::var("PATH").unwrap_or_default();
        unsafe {
            std::env::set_var("PATH", format!("{};{}", lib_dir.display(), old_path));
        }

        let mut engine = OfflineAsrEngine::create(&model_dir, Some(&lib_dir), 2)
            .expect("创建端侧引擎失败");
        engine.start();
        engine.accept(&pcm16_to_f32(&pcm));
        engine.flush();
        let text = engine.take_text();
        println!("[asr smoke] 识别结果：{text}");
        assert!(!text.trim().is_empty(), "识别结果为空，链路可能没通");
    }

    fn which_prebuilt_lib(root: &Path) -> Option<PathBuf> {
        let base = root.join(".tools").join("asr").join("win-extract");
        let mut stack = vec![base];
        while let Some(dir) = stack.pop() {
            for e in std::fs::read_dir(&dir).ok()? {
                let p = e.ok()?.path();
                if p.is_dir() {
                    stack.push(p);
                } else if p.file_name().is_some_and(|n| n == "sherpa-onnx-c-api.dll") {
                    return p.parent().map(|d| d.to_path_buf());
                }
            }
        }
        None
    }

    fn which_sample_wav(root: &Path) -> Option<PathBuf> {
        let p = root
            .join("android")
            .join("app")
            .join("src")
            .join("main")
            .join("assets")
            .join("asr_selftest.wav");
        p.exists().then_some(p)
    }
}
