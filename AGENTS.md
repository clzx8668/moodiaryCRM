# moodiaryCRM 多 Agent 协作约定（项目级）

本文件对在本仓库工作的所有 Codex 会话与子代理生效，与全局 AGENTS.md 叠加。

## 项目速览

- Flutter 3.41.0（.fvmrc）+ GetX + Drift(SQLite) + flutter_rust_bridge 2.11.1
- 智能表格：pluto_grid 8.1（CRM 顶部 Tab / 业务对象页）
- Rust 1.96（`rust/`，crate `moodiary_rust`）
- 服务端 Ktor 3 + Kotlin 2.0.21 + MongoDB（`server/`，脚手架）
- 二次开发总纲：[docs/二次开发计划.md](docs/二次开发计划.md)
- 架构文档：[docs/轻智能终端-完整架构设计执行指导文档.md](docs/轻智能终端-完整架构设计执行指导文档.md)
- 岗位配置：[docs/开发岗位配置.md](docs/开发岗位配置.md)
- Twenty 数据对象对接：[docs/twenty-数据对象对接指导.md](docs/twenty-数据对象对接指导.md)

## 环境命令（Windows PowerShell）

```powershell
$env:PUB_HOSTED_URL='https://pub.dev'
& 'D:\flutter\3.41.0\bin\flutter.bat' pub get
& 'D:\flutter\3.41.0\bin\flutter.bat' analyze --no-pub
cd rust; cargo check; cargo test
cd server; .\gradlew.bat build
```

注意：flutter 命令在本沙箱需提升权限（写入 SDK 缓存）；若报 lockfile 错误，先删除
`D:\flutter\3.41.0\bin\cache\lockfile`；Android 构建需
`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 且先 `gradlew --stop`。

注意 2：本机默认 pub 源为中国镜像（pub.flutter-io.cn），会把 `flutter_inappwebview`
系列解析到不兼容新版导致 Windows 构建失败。已在 pubspec.yaml 用 dependency_overrides
锁定兼容版本（js 0.6.7 / web 1.1.1 / inappwebview 全家 beta.2），两种源均可构建；
仍建议统一 `$env:PUB_HOSTED_URL='https://pub.dev'` 保持 lockfile 稳定。

注意 3：集成测试（integration 标签）默认跳过，需真实 Twenty 环境：
`flutter test --tags integration --run-skipped test/integration/twenty_integration_test.dart`。

## 硬性规则

1. 新功能代码放 `lib/features/`（Flutter）或 `rust/src/` 新模块（Rust），不散落进上游 `lib/pages/`。
2. 跨层接口契约先行：FFI（`rust/src/api/ffi_api.rs`）、Isar schema、REST 由主协调定稿后再并行实现。
3. 分支：`feat/<任务ID>`；提交规范 `<type>(<scope>): <subject>`。
4. 测试门禁：改 Rust 必须 `cargo test`；改 Flutter 必须 `flutter analyze`；改 server 必须 `gradlew test`。
5. Drift schema / json_serializable 模型改动后必须重新生成：
   `dart run build_runner build --delete-conflicting-outputs`（沙箱内需提升权限联网）。
6. 不随意放宽上游 lock 版本约束；升级/新增依赖需主协调批准（本阶段已批准 pluto_grid）。
7. 涉及数据迁移的变更必须幂等 + 写迁移日志。
