//! 开发期探针：对一段 wav 做"原样 / 归一化"两次识别，比较效果。
//!
//! 用法（需本机已有 sherpa-onnx 预编译库与模型，见 tool/fetch_asr_window*.ps1）：
//!   cargo run --example asr_probe -- <wav> [<wav2> ...]
//!
//! 目的：验证"录音电平偏低"是不是识别变差的直接原因 —— 这决定了我们
//! 是应该改录音增益，还是在喂模型前做归一化。
use std::path::{Path, PathBuf};

use moodiary_rust::api::asr_bridge;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() {
        eprintln!("用法: asr_probe <wav> [<wav2> ...]");
        std::process::exit(2);
    }
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    let model_dir = root.join(".tools").join("asr").join("models");
    let lib_dir = find_lib_dir(&root).expect("未找到 Windows 预编译库目录");
    let old = std::env::var("PATH").unwrap_or_default();
    unsafe {
        std::env::set_var("PATH", format!("{};{}", lib_dir.display(), old));
    }

    for wav in &args {
        let bytes = match std::fs::read(wav) {
            Ok(b) => b,
            Err(e) => {
                println!("{wav}: 读取失败 {e}");
                continue;
            }
        };
        println!("=== {}", wav);
        match stats(&bytes) {
            Some((peak, rms, dur)) => println!(
                "  峰值 {:.1}% FS  RMS {:.1}% FS  时长 {:.2}s",
                peak * 100.0,
                rms * 100.0,
                dur
            ),
            None => println!("  （无法解析）"),
        }

        let raw = asr_bridge::asr_transcribe_pcm16_wav(
            model_dir.to_string_lossy().into(),
            lib_dir.to_string_lossy().into(),
            bytes.clone(),
            2,
        );
        let boosted = asr_bridge::asr_transcribe_pcm16_wav(
            model_dir.to_string_lossy().into(),
            lib_dir.to_string_lossy().into(),
            normalize_wav(&bytes, 0.7),
            2,
        );
        println!("  原样   : {raw:?}");
        println!("  归一化 : {boosted:?}");
    }
}

fn find_lib_dir(root: &Path) -> Option<PathBuf> {
    let base = root.join(".tools").join("asr").join("win-extract");
    let mut stack = vec![base];
    while let Some(dir) = stack.pop() {
        let entries = std::fs::read_dir(&dir).ok()?;
        for e in entries.flatten() {
            let p = e.path();
            if p.is_dir() {
                stack.push(p);
            } else if p.file_name().is_some_and(|n| n == "sherpa-onnx-c-api.dll") {
                return p.parent().map(|d| d.to_path_buf());
            }
        }
    }
    None
}

/// (峰值, RMS, 时长秒)
fn stats(wav: &[u8]) -> Option<(f32, f32, f32)> {
    let pcm = moodiary_rust::asr_native_wav_pcm16(wav)?;
    let samples = moodiary_rust::asr_native_pcm16_to_f32(&pcm);
    if samples.is_empty() {
        return None;
    }
    let peak = samples.iter().fold(0.0f32, |m, s| m.max(s.abs()));
    let rms = (samples.iter().map(|s| s * s).sum::<f32>() / samples.len() as f32).sqrt();
    Some((peak, rms, samples.len() as f32 / 16000.0))
}

fn normalize_wav(wav: &[u8], target_peak: f32) -> Vec<u8> {
    let pcm = moodiary_rust::asr_native_wav_pcm16(wav).unwrap_or_default();
    let samples = moodiary_rust::asr_native_pcm16_to_f32(&pcm);
    let peak = samples.iter().fold(0.0f32, |m, s| m.max(s.abs()));
    if peak <= 0.0001 {
        return wav.to_vec();
    }
    let gain = (target_peak / peak).clamp(1.0, 12.0);
    let mut out = pcm.clone();
    for i in (0..out.len().saturating_sub(1)).step_by(2) {
        let v = i16::from_le_bytes([out[i], out[i + 1]]) as f32 * gain;
        let v = v.clamp(-32767.0, 32767.0) as i16;
        let b = v.to_le_bytes();
        out[i] = b[0];
        out[i + 1] = b[1];
    }
    // 拼回 WAV 头 + 数据（复用原始头，只换 data 长度）
    let mut result = wav[..44.min(wav.len())].to_vec();
    if result.len() >= 44 {
        let n = out.len() as u32;
        result[4..8].copy_from_slice(&(36u32 + n).to_le_bytes());
        result[40..44].copy_from_slice(&n.to_le_bytes());
    }
    result.extend_from_slice(&out);
    result
}
