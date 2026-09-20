pub mod api;
// 端侧语音识别内核（Windows/FFI）：只在 `api::asr_bridge` 里被调用，
// 刻意放在 `crate::api` 之外，避免 flutter_rust_bridge 把内部的
// PathBuf / c_int 等实现细节当成 FFI 类型导出。
mod asr_native;
mod test;
mod frb_generated;
// sync 引擎模块：默认不参与编译/FFI 分析（flutter_rust_bridge_codegen 对
// 该模块的单元结构存在 MIR 遍历问题）。启用：cargo build --features sync-engine。
#[cfg(feature = "sync-engine")]
pub mod sync;
