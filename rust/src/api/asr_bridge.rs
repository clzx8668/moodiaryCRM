//! 端侧语音识别的 FFI 桥（批次 103）。
//!
//! 上层（Dart）用 handle 句柄操作一个常驻引擎：
//! `create → start → accept(pcm16)… → flush → takeText`，最后 `destroy`。
//! 数据面只传 `Vec<u8>`（16k/mono/int16 小端），不引入复杂 DTO。
//!
//! 平台差异：目前只有 Windows 有原生实现；其它平台 `asrIsAvailable()` 返回 false，
//! 上层自动回落到云端转写（与 Android 侧 Kotlin 实现的行为一致）。

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

use crate::asr_native::{self, OfflineAsrEngine};

fn registry() -> &'static Mutex<HashMap<u64, OfflineAsrEngine>> {
    static REG: OnceLock<Mutex<HashMap<u64, OfflineAsrEngine>>> = OnceLock::new();
    REG.get_or_init(|| Mutex::new(HashMap::new()))
}

static NEXT_ID: AtomicU64 = AtomicU64::new(1);

fn lock() -> std::sync::MutexGuard<'static, HashMap<u64, OfflineAsrEngine>> {
    match registry().lock() {
        Ok(g) => g,
        Err(poisoned) => poisoned.into_inner(),
    }
}

/// 本平台是否提供端侧识别实现（Windows = true；其它平台留给后续里程碑）
pub fn asr_is_available() -> bool {
    cfg!(target_os = "windows")
}

/// 结构体布局自检：返回一行人类可读的尺寸对照，便于排查 ABI 漂移。
pub fn asr_layout_selftest() -> String {
    asr_native::layout_selftest()
}

/// 直接对一段 WAV 做端侧识别（不做 VAD 切句），返回识别文本。
/// 用于"模型能不能跑通"的最小验证。
pub fn asr_transcribe_pcm16_wav(
    model_dir: String,
    lib_dir: String,
    wav_bytes: Vec<u8>,
    num_threads: i32,
) -> Result<String, String> {
    let pcm = asr_native::wav_pcm16(&wav_bytes).ok_or("WAV 里没有找到 data 段")?;
    let libs = PathBuf::from(&lib_dir);
    let libs = (!lib_dir.trim().is_empty()).then_some(libs.as_path());
    let mut engine = OfflineAsrEngine::create(
        &PathBuf::from(model_dir),
        libs,
        num_threads.max(1),
    )?;
    engine.start();
    engine.accept(&asr_native::pcm16_to_f32(&pcm));
    engine.flush();
    Ok(engine.take_text())
}

/// 默认模型目录（Dart 侧通常显式传目录，这里仅作兜底）
pub fn asr_default_model_dir() -> String {
    asr_native::default_model_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .to_string_lossy()
        .to_string()
}

/// 创建端侧引擎（加载模型，几百毫秒到数秒）。返回句柄；失败返回错误文案。
#[flutter_rust_bridge::frb(sync)]
pub fn asr_create(
    model_dir: String,
    lib_dir: String,
    num_threads: i32,
) -> Result<u64, String> {
    if !asr_is_available() {
        return Err("当前平台未提供端侧识别实现".into());
    }
    let dir = PathBuf::from(&model_dir);
    let libs = PathBuf::from(&lib_dir);
    let libs = (!lib_dir.trim().is_empty()).then_some(libs.as_path());
    let engine = OfflineAsrEngine::create(&dir, libs, num_threads.max(1))?;
    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    lock().insert(id, engine);
    Ok(id)
}

/// 开始一次会话
#[flutter_rust_bridge::frb(sync)]
pub fn asr_start(handle: u64) -> Result<(), String> {
    let mut reg = lock();
    let engine = reg.get_mut(&handle).ok_or("引擎句柄无效")?;
    engine.start();
    Ok(())
}

/// 送入一块 PCM（16k/mono/int16 小端）
#[flutter_rust_bridge::frb(sync)]
pub fn asr_accept_pcm16(handle: u64, pcm: Vec<u8>) -> Result<(), String> {
    let samples = asr_native::pcm16_to_f32(&pcm);
    let mut reg = lock();
    let engine = reg.get_mut(&handle).ok_or("引擎句柄无效")?;
    engine.accept(&samples);
    Ok(())
}

/// 收尾：吐出尾段
#[flutter_rust_bridge::frb(sync)]
pub fn asr_flush(handle: u64) -> Result<(), String> {
    let mut reg = lock();
    let engine = reg.get_mut(&handle).ok_or("引擎句柄无效")?;
    engine.flush();
    Ok(())
}

/// 取走新识别出来的文本（调用后清空）
#[flutter_rust_bridge::frb(sync)]
pub fn asr_take_text(handle: u64) -> Result<String, String> {
    let mut reg = lock();
    let engine = reg.get_mut(&handle).ok_or("引擎句柄无效")?;
    Ok(engine.take_text())
}

/// 释放引擎
#[flutter_rust_bridge::frb(sync)]
pub fn asr_destroy(handle: u64) -> Result<(), String> {
    lock().remove(&handle);
    Ok(())
}

