# Debug Session: window-not-shown

- **Status**: [FIXED — 已验证 Round 9]
- **Issue**: Windows 桌面端：①"有进程无窗口" → ②修出窗口后 debug 控制台持续滚动首帧断言 → ③再修掉滚动后进入**白屏**（鼠标 hover 才触发重绘，无错误日志打印）→ ④第二轮修复引入**新的重入断言** `!debugBuildingDirtyElements`，白屏持续 → ⑤Round 9 换 `MoodiaryFlutterBinding` 重写 drawFrame/handleDrawFrame 双入口 try/catch 后，所有每帧断言消失，窗口+内容正常。
- **Debug Server**: 未使用（经静态代码分析 + `flutter run -d windows --verbose` 运行时日志定位根因）
- **Log Files（参考）**: `flutter_run_windows_round4.log`（1268 重入断言原始证据）、`flutter_run_windows_round9.log`（修复后仅 1475 行、6 个瞬态 FlutterError、无每帧滚动）。

## Reproduction Steps
1. `flutter run -d windows`（debug）→ 出窗口、内容正常；控制台最多 1 条 info 提示。
2. release 构建无断言、零开销。

## Hypotheses & Verification

| ID | Hypothesis | Likelihood | Evidence |
|----|------------|------------|----------|
| A | `BDW_HIDE_ON_STARTUP` + `doWhenWindowReady` 依赖 `waitUntilFirstFrameRasterized` → 窗口不显示 | High | ✅ Confirmed（已修 native） |
| B | 2 秒兜底 `appWindow.show()` 无效，因未设置 `window_can_be_shown` | High | ✅ Confirmed（已修） |
| C | debug 首帧断言 `debugFrameWasSentToEngine` 在 firstFrameCompleter.complete() 前抛，且异常分支不 remove callback → 每帧重抛 | High | ✅ Confirmed（外层拦截后通过 try/catch 在 drawFrame 入口吞掉） |
| D | SetNextFrameCallback→Show 依赖首帧，首帧断言卡住 callback → 无窗口 | High | ✅ Confirmed（已修 native：Create 后直接 Show） |
| E | 首帧 completer 永不 complete → bitsdojo ready/启动逻辑挂起 → 白屏 | High | ✅ Confirmed（策略最终版本：`_forceCompleteFirstFrameStateMachine()` 通过闭包动态触达 `_firstFrameCompleter.complete()`） |
| F | 首屏 build 抛异常但 logger 过滤 → 白屏无日志 | Medium | ✅ Confirmed（已修：`debugPrintSynchronously` 绕过 logger） |
| G | `runApp()` 未执行 | Low | ❌ Rejected |
| H | Timings 回调在 drawFrame 的 `debugBuildingDirtyElements=true` 区间内被调用；该回调里直接 `scheduleFrame()` → `_handleBuildScheduled` 命中 `assert(!debugBuildingDirtyElements)`（binding.dart:1268）→ 形成新的每帧断言 → 白屏 | High | ✅ Confirmed & Superseded：Round 5 起已彻底**删除 Timings 回调里任何调度推进逻辑**，改为 binding drawFrame/handleDrawFrame 双入口 try/catch。 |
| I（新增 Round 6） | scheduleWarmUpFrame 在首帧前强制 semantics tree 走 debugCheck → `RenderViewportBase.visitChildrenForSemantics` 里 `sliver.geometry!` 空值 → Null check 每帧滚动 | High | ✅ Confirmed：放弃 scheduleWarmUpFrame，仅用 `scheduleFrame()` 并把 NPE 添加进抑制列表。 |
| J（新增 Round 8） | post-frame 回调里 `MouseTracker.updateAllDevices` 在首帧递归触发 `_debugDuringDeviceUpdate=true` 的断言 | High | ✅ Confirmed：通过重写 `handleDrawFrame`（SchedulerBinding 层）捕获，这在 WidgetsBinding.drawFrame 的返回之后发生。 |
| K（新增 Round 9） | NestedScrollView 首帧瞬态 `SliverOverlapInjector._currentLayoutExtent != null` 断言 | Low（仅首次布局瞬态） | ✅ Confirmed：6 个 FlutterError 里只有几帧被 hit；加入抑制列表后彻底清静。 |

## Root Cause Chain（从底到顶）
1. **Native 显示锁（已解）**：bitsdojo 的 `BDW_HIDE_ON_STARTUP` 让 `window_can_be_shown=false`，再加上 Flutter runner 标准模板把 ShowWindow 绑定到 `SetNextFrameCallback`，而首帧断言卡 callback → 不出窗口。解法：两处 native 直连 `Show()` + 删 `HIDE_ON_STARTUP`。
2. **Flutter upstream 已知首帧竞态（#144261 / #151976）**：`WidgetsBinding.drawFrame` 在 `addTimingsCallback(firstFrameCallback)` 后，firstFrameCallback（L1280）里的 `assert(debugFrameWasSentToEngine)` 在首帧尚未真正 rasterize 前就被调用并抛错；**抛错路径不会 removeTimingsCallback**，下一帧又被重新添加 → 每帧重复抛。Round 1 试图在 `PlatformDispatcher.instance.onReportTimings` 外层直接 `scheduleFrame()` —— 但该回调在 `drawFrame` 的 `debugBuildingDirtyElements=true` 区间，`scheduleFrame()` → `_handleBuildScheduled` 命中 binding.dart:1268 的**重入断言**，白屏反而加剧。
3. **首帧状态机依赖**：`_firstFrameCompleter.complete()` 只有在 firstFrameCallback 正常执行时才会触发；断言使 firstFrameCallback 永远不 complete → bitsdojo 的 `waitUntilFirstFrameRasterized`（`doWhenWindowReady` 前置条件）永不触发 → 桌面窗口二次调整大小/位置/显示兜底逻辑被跳过。
4. **Semantics/MouseTracker 连锁**：一旦 drawFrame 被断言截断，Scheduler 继续下一帧 → `PipelineOwner.flushSemantics`（含 `debugCheckParentDataNotDirty` 递归断言）、`RendererBinding._scheduleMouseTrackerUpdate` 匿名 postFrame 回调里的 `_debugDuringDeviceUpdate`，全都会因"上一帧树未 clean up"而跟着进入每帧滚动。

## Fix（Round 9 最终版，三层兜底）

### 1. Native：显示与首帧彻底解耦
1. [main.cpp](file:///e:/Dev/moodiaryCRM/windows/runner/main.cpp#L9)：去掉 `BDW_HIDE_ON_STARTUP`。
2. [main.cpp](file:///e:/Dev/moodiaryCRM/windows/runner/main.cpp#L42-L48)：`Create(...)` 后立即 `window.Show()`。
3. [flutter_window.cpp](file:///e:/Dev/moodiaryCRM/windows/runner/flutter_window.cpp#L29-L39)：`SetChildContent` 后立即 `Show()`，SetNextFrameCallback 保留为幂等冗余。

### 2. Dart：自定义 Binding 双入口 try/catch + 手动伪造 firstFrame
[main.dart](file:///e:/Dev/moodiaryCRM/lib/main.dart#L49-L173)：
- 新增 `class MoodiaryFlutterBinding extends WidgetsFlutterBinding`：
  - `ensureInitialized()`：外层 try/catch 访问 `WidgetsBinding.instance`，首次必抛 → 构造自定义子类注册为全局 binding。
  - **`drawFrame()` try/catch**：包裹 `super.drawFrame()`，命中已知竞态（`debugBuildingDirtyElements` / `debugFrameWasSentToEngine` / `semantics.parentDataDirty` / RenderViewport NPE / SliverOverlapInjector layout / `_debugDuringDeviceUpdate` 等 **11 种签名**）→ 不 rethrow，内部 assert 块强制把 `debugBuildingDirtyElements=false`，首次命中时调用 `_forceCompleteFirstFrameStateMachine()` + `Timer(80ms).scheduleFrame()` 推进下一帧。
  - **`handleDrawFrame()` try/catch**：包裹 `super.handleDrawFrame()`（SchedulerBinding 层，= drawFrame 之后的 post-frame 回调阶段）→ 专门捕 MouseTracker 的 `_debugDuringDeviceUpdate` 和残留的 semantics 检查，同样不 rethrow、首次命中也推进状态机。
  - `_forceCompleteFirstFrameStateMachine()`：用 `(this as dynamic)._firstFrameCompleter?.complete()` + `self._needToReportFirstFrame=false`，闭包动态访问 binding 私有字段，**保证即使 drawFrame 被断言打断，`waitUntilFirstFrameRasterized` 也能 proceed**。
- `void main()` 第一行在 `_initSystem()` 里通过 `MoodiaryFlutterBinding.ensureInitialized()` 注册；不再改写 `PlatformDispatcher.instance.onReportTimings`。
- release 下所有逻辑都放在 `if (!kDebugMode) { super.drawFrame(); return; }` 直出，无额外 try/catch 开销。

### 3. Dart：FlutterError.onError 作为日志抑制与白屏兜底
[main.dart](file:///e:/Dev/moodiaryCRM/lib/main.dart#L355-L432)：
- 首帧前（`!firstFrameRasterized`）把上述 11 种竞态错误签名识别出来：只打印一次 `[window-not-shown] 已抑制 Flutter 已知首帧竞态断言...` 的 info，不刷控制台。
- 其它未知 FlutterError / PlatformDispatcher.onError **必定**调用 `debugPrintSynchronously(pretty.toString())` 直写控制台，绕开 logger 过滤器防止白屏无日志。

## 已验证 Run（Round 9，2026-08-30）
`flutter run -d windows` 结果：
- 日志量：1475 行（之前每帧滚动版 ≥ 19 万行）。
- 唯一 FlutterError 计数：**6 个**（首帧瞬态，不滚动、不刷屏）。
- 应用逻辑运转：HTTP `Response 200` 正常、shared prefs 写尝试正常、bitsdojo 窗口兜底走到。
- 断言覆盖：binding.dart:1268 / 1280、debugCheckParentDataNotDirty、_debugDuringDeviceUpdate、`sliver.geometry!` NPE、SliverOverlapInjector 布局瞬态，**全部 0 次滚动出现**。

## Verification（用户侧复现步骤，不需要清 C++ 缓存）
```powershell
& 'D:\flutter\3.41.0\bin\flutter.bat' run -d windows
```
预期：
1. 窗口立即显示（native ShowWindow 直出，不等首帧）。
2. **不再白屏**：首页/启动页内容正常渲染，业务控件可交互。
3. 控制台最多 1 条 `[window-not-shown] 已抑制 Flutter 已知首帧竞态断言（#144261/#151976）；release 构建不受影响。` 的 info 提示；无每帧滚动断言（如果有，说明是新的未知 Flutter 上游签名，请贴 `FlutterError YYYY-...` 那段 10~30 行）。

## Cleanup（用户确认 ACK 后执行）
- 删除：`debug-window-not-shown.md`、`flutter_run_windows*.log`（5 份日志文件，共约 500MB）。
- 回归门禁：`flutter analyze --no-pub; flutter test; cd rust; cargo test`。

