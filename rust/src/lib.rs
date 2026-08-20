pub mod api;
mod test;
mod frb_generated;
// sync 引擎模块：默认不参与编译/FFI 分析（flutter_rust_bridge_codegen 对
// 该模块的单元结构存在 MIR 遍历问题）。启用：cargo build --features sync-engine。
#[cfg(feature = "sync-engine")]
pub mod sync;
