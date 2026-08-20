# moodiaryCRM 多 Agent 协作约定（项目级）

本文件对在本仓库工作的所有 Codex 会话与子代理生效，与全局 AGENTS.md 叠加。

## 项目速览

- Flutter 3.32.0（锁定，勿用 3.41.0：meta 1.16.0 冲突）+ GetX + Isar 4.0-dev.14 + flutter_rust_bridge 2.9.0
- Rust 1.96（`rust/`，crate `moodiary_rust`）
- 服务端 Ktor 3 + Kotlin 2.0.21 + MongoDB（`server/`，脚手架）
- 二次开发总纲：[docs/二次开发计划.md](docs/二次开发计划.md)
- 架构文档：[docs/轻智能终端-完整架构设计执行指导文档.md](docs/轻智能终端-完整架构设计执行指导文档.md)
- 岗位配置：[docs/开发岗位配置.md](docs/开发岗位配置.md)

## 环境命令（Windows PowerShell）

```powershell
$env:PUB_HOSTED_URL='https://pub.dev'
$env:GIT_CONFIG_COUNT='1'
$env:GIT_CONFIG_KEY_0='url.https://ghfast.top/https://github.com/.insteadOf'
$env:GIT_CONFIG_VALUE_0='https://github.com/'
& 'D:\flutter\3.32.0\bin\flutter.bat' pub get
& 'D:\flutter\3.32.0\bin\flutter.bat' analyze --no-pub
cd rust; cargo check; cargo test
cd server; .\gradlew.bat build
```

注意：flutter 需要提升权限运行（写入 SDK 缓存）；若报 lockfile 错误，先删除 `D:\flutter\3.32.0\bin\cache\lockfile`。

## 硬性规则

1. 新功能代码放 `lib/features/`（Flutter）或 `rust/src/` 新模块（Rust），不散落进上游 `lib/pages/`。
2. 跨层接口契约先行：FFI（`rust/src/api/ffi_api.rs`）、Isar schema、REST 由主协调定稿后再并行实现。
3. 分支：`feat/<任务ID>`；提交规范 `<type>(<scope>): <subject>`。
4. 测试门禁：改 Rust 必须 `cargo test`；改 Flutter 必须 `flutter analyze`；改 server 必须 `gradlew test`。
5. Isar 模型改动后必须重新生成：`dart run build_runner build --delete-conflicting-outputs`。
6. 不修改上游 lock 版本约束（meta 1.16.0 等）；升级依赖需主协调批准。
7. 涉及数据迁移的变更必须幂等 + 写迁移日志。
