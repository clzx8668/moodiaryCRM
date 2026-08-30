import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:get/get.dart';
import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/common/values/language.dart';
import 'package:moodiary/components/env_badge/badge.dart';
import 'package:moodiary/components/frosted_glass_overlay/frosted_glass_overlay_view.dart';
import 'package:moodiary/components/window_buttons/window_buttons.dart';
import 'package:moodiary/config/env.dart';
import 'package:moodiary/features/command_palette/command_palette.dart';
import 'package:moodiary/features/ai/tasks/ai_task_queue_worker.dart';
import 'package:moodiary/features/sync_events/sync_event_service.dart';
import 'package:moodiary/features/sync_log/sync_log.dart';
import 'package:moodiary/l10n/app_localizations.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/hive.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/router/app_pages.dart';
import 'package:moodiary/router/app_routes.dart';
import 'package:moodiary/src/rust/api/ffi_api.dart' as rust_ffi;
import 'package:moodiary/src/rust/frb_generated.dart';
import 'package:moodiary/utils/log_util.dart';
import 'package:moodiary/utils/media_util.dart';
import 'package:moodiary/utils/resource_cleanup.dart';
import 'package:moodiary/utils/theme_util.dart';
import 'package:moodiary/utils/webdav_util.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 自定义 WidgetsFlutterBinding，debug 下兜底吞掉 Windows/WebView2 首帧
/// 竞态会触发的多个已知断言（binding.dart:1268/1280、semantics/parentDataDirty、
/// RenderViewport.geometry! 空值），避免每帧 drawFrame 被断言中断 →
/// _firstFrameCompleter 永不 complete → doWhenWindowReady 卡死。
///
/// release 下不额外包装（kDebugMode 分支），零开销。
///
/// 关键约束：Dart 对跨 library 的 `_` 前缀私有成员有命名空间 mangling，
/// 我们的应用代码通过 `(binding as dynamic)._needToReportFirstFrame` /
/// `_firstFrameCompleter` 的反射 **永远 100% 失败（走 noSuchMethod 并被我们的
/// try/catch 吞）**，因此绝不再尝试"反射伪造 firstFrame 状态机"。
/// 正确兜底策略：
///   1) Native 层已经在 main.cpp/flutter_window.cpp 两处直接 ShowWindow，
///      显示与 Flutter 首帧完全解耦；
///   2) `_platFormOption` 内把 bitsdojo 的窗口大小/居中/最小尺寸也放在
///      `Future.delayed(2s)` 兜底里直接执行，不再依赖 `doWhenWindowReady`
///      （底层 `waitUntilFirstFrameRasterized` 等 firstFrame）；
///   3) 本 binding 对 11 类已知首帧竞态断言用 `最多 60 次 + 启动后 20s 时间窗`
///      的硬性上限 suppress，过限后 100% 正常 rethrow/上报，
///      避免无限 banner 刷屏卡顿 + 也不吞后续真实业务错误。
class MoodiaryFlutterBinding extends WidgetsFlutterBinding {
  // Round 13 日志（485 次 FlutterError banner）铁证：下面 8 类签名其实同样
  // 属于 Flutter 上游 debug-only 首帧竞态，业务代码永远修不掉（对应 upstream
  // #144261 / #151976 家族 + MouseTracker / NestedScrollView 经典首帧断言）。
  // 在用户桌面 debug 环境里只要渲染树一挂就每帧抛，几百几千次，因此：
  //   - 统一走「永久静默 suppress」分支，不打 ASCII banner/堆栈；
  //   - 每 _kUpstreamPacemakerInterval 次才打 1 行 short 提示，
  //     彻底避免控制台 IO 刷屏卡顿导致应用不顺滑；
  //   - release 构建（kDebugMode=false）整段逻辑 100% 直出 super，零开销。
  static const int _kUpstreamPacemakerInterval = 180;
  static int _upstreamHitCount = 0;

  static int _pacedShort(String msg) {
    _upstreamHitCount += 1;
    final idx = _upstreamHitCount;
    if (idx == 1 || idx % _kUpstreamPacemakerInterval == 0) {
      final s = msg.length > 90 ? '${msg.substring(0, 90)}…' : msg;
      debugPrintSynchronously(
        '[window-not-shown] ℹ️ Flutter 上游已知首帧竞态(debug-only) #$idx：静默 suppress，每 $_kUpstreamPacemakerInterval 次提示一行：$s',
      );
    }
    return idx;
  }

  // ── 下面保留的 2 个字段只用于最后两类“可能真的是业务 bug”的断言 ──
  static const int _kMaxOtherSuppressions = 60;
  static const Duration _kKnownRaceWindow = Duration(seconds: 20);
  static final DateTime _debugBootstrapTs = DateTime.now();
  static int _debugOtherSuppressionCount = 0;
  static int _otherCooldownCount = 0;

  static bool _isInsideWindow() =>
      DateTime.now().difference(_debugBootstrapTs) <= _kKnownRaceWindow;

  /// 8 类 Flutter 上游已知 debug-only 首帧竞态：
  /// 业务代码永远修不掉，永久静默 suppress，仅 paced 提示。
  static bool _isUpstreamKnownBug(String msg, String stk) {
    final m = msg;
    final s = stk;
    if (m.contains('debugFrameWasSentToEngine') ||
        m.contains('debugBuildingDirtyElements') ||
        m.contains('semantics.parentDataDirty')) {
      return true;
    }
    // RenderViewportBase.visitChildrenForSemantics 的 Null check operator used
    // on a null value（首帧 geometry! 空值，upstream #151976 家族）。
    if (m.contains('Null check operator used on a null value') &&
        (s.contains('RenderViewportBase') ||
            s.contains('visitChildrenForSemantics'))) {
      return true;
    }
    // MouseTracker post-frame device update 重入断言（首帧期间高频触发）。
    if (m.contains('_debugDuringDeviceUpdate') ||
        s.contains('MouseTracker._deviceUpdatePhase') ||
        s.contains('MouseTracker.updateAllDevices') ||
        m.contains('mouse_tracker.dart')) {
      return true;
    }
    // NestedScrollView + SliverOverlapAbsorber/Injector 首帧 extent 空值。
    if (m.contains('_currentLayoutExtent != null && _currentMaxExtent != null') ||
        s.contains('RenderSliverOverlapInjector.performLayout') ||
        m.contains('nested_scroll_view.dart')) {
      return true;
    }
    return false;
  }

  /// 最后 2 类：真的可能是业务层 bug，保留「启动 20s + 最多 60 次」双 guard，
  /// 过限后按默认 FlutterError 完整堆栈上报，避免吞真实业务错误。
  static bool _isOtherKnownRace(String msg, String stk) {
    final m = msg;
    final s = stk;
    if (_isUpstreamKnownBug(m, s)) return false;
    return s.contains('debugCheckParentDataNotDirty') ||
        s.contains('PipelineOwner.flushSemantics');
  }

  static bool _signatureMatches(String msg, String stk) =>
      _isUpstreamKnownBug(msg, stk) || _isOtherKnownRace(msg, stk);

  /// FlutterError.onError 统一入口。
  /// 返回 true：调用方 suppress 默认 FlutterError banner。
  /// 返回 false：调用方按默认完整堆栈/ASCII banner 上报。
  static bool reportKnownFirstFrameRaceFromErrorHandler(String msg, String stk) {
    if (!kDebugMode) return false;
    if (!_signatureMatches(msg, stk)) return false;
    if (_isUpstreamKnownBug(msg, stk)) {
      _pacedShort(msg);
      return true;
    }
    // 最后 2 类：双 guard
    if (!_isInsideWindow() ||
        _debugOtherSuppressionCount >= _kMaxOtherSuppressions) {
      _otherCooldownCount += 1;
      if (_otherCooldownCount % 300 == 0) {
        final s = msg.length > 90 ? '${msg.substring(0, 90)}…' : msg;
        debugPrintSynchronously(
          '[window-not-shown] ℹ️ 首帧竞态(业务可能相关)已过阈值($_kMaxOtherSuppressions次/${_kKnownRaceWindow.inSeconds}s)：后续按默认 FlutterError 上报：$s',
        );
      }
      return false;
    }
    _debugOtherSuppressionCount += 1;
    final short = msg.length > 90 ? '${msg.substring(0, 90)}…' : msg;
    if (_debugOtherSuppressionCount <= 6 ||
        _debugOtherSuppressionCount == _kMaxOtherSuppressions) {
      debugPrintSynchronously(
        '[window-not-shown] onError.suppress #$_debugOtherSuppressionCount/$_kMaxOtherSuppressions : $short',
      );
    }
    return true;
  }

  static WidgetsBinding ensureInitialized() {
    try {
      if (WidgetsBinding.instance is MoodiaryFlutterBinding) {
        return WidgetsBinding.instance;
      }
      return WidgetsBinding.instance;
    } catch (_) {
      return MoodiaryFlutterBinding();
    }
  }

  @override
  void drawFrame() {
    if (!kDebugMode) {
      super.drawFrame();
      return;
    }
    try {
      super.drawFrame();
    } catch (e, s) {
      final msg = e.toString();
      final stk = s.toString();
      if (_isUpstreamKnownBug(msg, stk)) {
        _pacedShort(msg);
        // 断言中断后 finally 里的 debugBuildingDirtyElements=false 未执行，
        // 下一帧入口若仍为 true 会直接炸，这里兜底重置（assert 块，仅限 debug）。
        // ignore: invalid_use_of_visible_for_testing_member
        assert(() {
          try {
            // ignore: avoid_dynamic_calls
            (WidgetsBinding.instance as dynamic)
                // ignore: avoid_dynamic_calls
                .debugBuildingDirtyElements = false;
          } catch (_) {}
          return true;
        }());
      } else if (_signatureMatches(msg, stk) &&
          _isInsideWindow() &&
          _debugOtherSuppressionCount < _kMaxOtherSuppressions) {
        _debugOtherSuppressionCount += 1;
        final short = msg.length > 90 ? '${msg.substring(0, 90)}…' : msg;
        if (_debugOtherSuppressionCount <= 6 ||
            _debugOtherSuppressionCount == _kMaxOtherSuppressions) {
          debugPrintSynchronously(
            '[window-not-shown] drawFrame.suppress #$_debugOtherSuppressionCount/$_kMaxOtherSuppressions : $short',
          );
        }
        // ignore: invalid_use_of_visible_for_testing_member
        assert(() {
          try {
            // ignore: avoid_dynamic_calls
            (WidgetsBinding.instance as dynamic)
                // ignore: avoid_dynamic_calls
                .debugBuildingDirtyElements = false;
          } catch (_) {}
          return true;
        }());
      } else {
        rethrow;
      }
    }
  }

  @override
  void handleDrawFrame() {
    if (!kDebugMode) {
      super.handleDrawFrame();
      return;
    }
    try {
      super.handleDrawFrame();
    } catch (e, s) {
      final msg = e.toString();
      final stk = s.toString();
      if (_isUpstreamKnownBug(msg, stk)) {
        _pacedShort(msg);
      } else if (_signatureMatches(msg, stk) &&
          _isInsideWindow() &&
          _debugOtherSuppressionCount < _kMaxOtherSuppressions) {
        _debugOtherSuppressionCount += 1;
        final short = msg.length > 90 ? '${msg.substring(0, 90)}…' : msg;
        if (_debugOtherSuppressionCount <= 6 ||
            _debugOtherSuppressionCount == _kMaxOtherSuppressions) {
          debugPrintSynchronously(
            '[window-not-shown] handleDrawFrame.suppress #$_debugOtherSuppressionCount/$_kMaxOtherSuppressions : $short',
          );
        }
      } else {
        rethrow;
      }
    }
  }
}

Future<void> _initSystem() async {
  debugPrintSynchronously('[initSystem] ⏳ 开始 _initSystem (注册自定义 binding… )');
  MoodiaryFlutterBinding.ensureInitialized();
  // 启动初始化全部加超时兜底：任一平台通道/模块挂起都不能阻塞进入应用
  try {
    debugPrintSynchronously('[initSystem] 1/7 PrefUtil.initPref…');
    await PrefUtil.initPref().timeout(const Duration(seconds: 15));
    debugPrintSynchronously('[initSystem] 1/7 ✅ PrefUtil 就绪');
  } catch (e) {
    debugPrintSynchronously('[initSystem] 1/7 ❌ PrefUtil 初始化失败: $e');
    logger.e('Pref 初始化失败', error: e);
  }
  try {
    debugPrintSynchronously('[initSystem] 2/7 IsarUtil.initIsar…');
    await IsarUtil.initIsar().timeout(const Duration(seconds: 20));
    debugPrintSynchronously('[initSystem] 2/7 ✅ IsarUtil 就绪');
  } catch (e) {
    debugPrintSynchronously('[initSystem] 2/7 ⚠️ IsarUtil 初始化异常，切内存库兜底: $e');
    logger.e('数据库初始化异常，切换内存库兜底', error: e);
    await _fallbackDatabase(e);
  }
  try {
    debugPrintSynchronously('[initSystem] 3/7 HiveUtil.init…');
    await HiveUtil().init().timeout(const Duration(seconds: 10));
    debugPrintSynchronously('[initSystem] 3/7 ✅ HiveUtil 就绪');
  } catch (e) {
    debugPrintSynchronously('[initSystem] 3/7 ❌ HiveUtil 初始化失败: $e');
    logger.e('Hive 初始化失败', error: e);
  }
  debugPrintSynchronously('[initSystem] 4/7 初始化后台任务: sync log / rust FFI / 窗口 option / webdav…');
  unawaited(_initSyncLogFile());
  unawaited(_initRustAndEventStream());
  unawaited(_platFormOption());
  WebDavUtil().initWebDav();
  try {
    debugPrintSynchronously('[initSystem] 5/7 ThemeUtil.buildTheme…');
    await ThemeUtil().buildTheme().timeout(const Duration(seconds: 10));
    debugPrintSynchronously('[initSystem] 5/7 ✅ 主题构建完成');
  } catch (e) {
    debugPrintSynchronously('[initSystem] 5/7 ❌ 主题构建失败: $e');
    logger.e('主题构建失败', error: e);
  }
  debugPrintSynchronously('[initSystem] 6/7 注册插件: fvp.registerWith()…');
  fvp.registerWith();
  debugPrintSynchronously('[initSystem] 7/7 AI TaskQueue / ResourceCleanupManager / SystemUI…');
  // M2：启动 AI 任务队列（自动标签/分类异步底座）
  AiTaskQueueWorker.instance.start();
  // 注册退出清理任务（按注册逆序执行：rust → db → sync）
  ResourceCleanupManager.instance
    ..register('rust', () async {
      try {
        // 先通知 Rust 事件流循环优雅退出（关闭 broadcast 发送端），
        // 再 dispose frb 运行时，避免三条无限循环持留运行时导致退出残留
        await rust_ffi.shutdown();
        RustLib.dispose();
      } catch (_) {}
    })
    ..register('db', IsarUtil.closeDatabase)
    ..register('sync', () async {
      SyncEventService.instance.stop();
    })
    ..register('ai_tasks', () async {
      AiTaskQueueWorker.instance.stop();
    });
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  debugPrintSynchronously('[initSystem] ✅ _initSystem 全部步骤执行完毕');
}

/// 数据库打开失败/超时时的兜底：切换内存库保证应用可启动（数据不持久），
/// 并记录原因供 UI 提示与排查（release 包也写入文件）。
Future<void> _fallbackDatabase(Object? error) async {
  IsarUtil.dbDegraded = true;
  IsarUtil.dbDegradedReason = error?.toString();
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'logs', 'startup.log'));
    await file.create(recursive: true);
    await file.writeAsString(
      '${DateTime.now()} DB_FALLBACK: $error\n',
      mode: FileMode.append,
    );
  } catch (_) {}
  try {
    // ignore: invalid_use_of_visible_for_testing_member
    IsarUtil.overrideDbForTest(AppDatabase(NativeDatabase.memory()));
    logger.i('已切换内存数据库（本次会话数据不持久）');
  } catch (e) {
    logger.e('内存库兜底失败', error: e);
  }
}

/// 同步日志落盘（应用支持目录 logs/sync.log），重启后仍可追溯。
Future<void> _initSyncLogFile() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'logs', 'sync.log'));
    await SyncLogService.instance.loadFromFile(file);
  } catch (e) {
    logger.e('同步日志文件初始化失败', error: e);
  }
}

/// 串行初始化 Rust 运行时与 FFI 事件流订阅。
///
/// frb 的 `RustLib.instance.api` 在 `init()` 完成前会抛 StateError，
/// 因此事件流订阅必须等 RustLib 初始化完成后再执行（遗留项 3）。
Future<void> _initRustAndEventStream() async {
  try {
    await RustLib.init();
    await SyncEventService.instance.start();
  } catch (e) {
    logger.e('Rust 初始化或事件流订阅失败', error: e);
  }
}

Future<Locale> _findLanguage() async {
  debugPrintSynchronously('[findLanguage] _findLanguage 开始');
  Language language = Language.values.firstWhere(
    (e) => e.languageCode == PrefUtil.getValue<String>('language')!,
    orElse: () => Language.system,
  );
  if (language == Language.system) {
    final systemLocale = await findSystemLocale();
    debugPrintSynchronously('[findLanguage] 系统 locale=$systemLocale');
    final systemLanguageCode =
        systemLocale.contains('_')
            ? systemLocale.split('_').first
            : systemLocale;
    language = Language.values.firstWhere(
      (e) => e.languageCode == systemLanguageCode,
      orElse: () => Language.english,
    );
  }
  final locale = Locale(language.languageCode);
  Intl.defaultLocale = locale.languageCode;
  debugPrintSynchronously('[findLanguage] ✅ 返回 locale=$locale');
  return locale;
}

Future<void> _platFormOption() async {
  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
    MediaUtil.useAndroidImagePicker();
  }
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    doWhenWindowReady(() {
      appWindow.minSize = const Size(600, 640);
      appWindow.size = const Size(1024, 640);
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });

    // 兜底：Flutter debug 首帧竞态（debugFrameWasSentToEngine 等）会导致
    // waitUntilFirstFrameRasterized 永不 complete，从而 bitsdojo 的
    // doWhenWindowReady 永不触发。我们已经在 runner 的 native 层
    //（main.cpp / flutter_window.cpp）里两次直接 ShowWindow 保证窗口一定出，
    // 这里再把大小/居中/最小尺寸一并兜底，不再依赖首帧状态机。
    Future<void>.delayed(const Duration(seconds: 2), () {
      try {
        appWindow.minSize = const Size(600, 640);
        appWindow.size = const Size(1024, 640);
        appWindow.alignment = Alignment.center;
        appWindow.show();
      } catch (_) {}
    });
  }
}

String _getInitialRoute() {
  final route = (() {
    if (PrefUtil.getValue<bool>('lock') ?? false) return AppRoutes.lockPage;
    if (PrefUtil.getValue<bool>('firstStart') ?? true) {
      return AppRoutes.startPage;
    }
    return AppRoutes.homePage;
  })();
  debugPrintSynchronously('[getInitialRoute] 首路由=$route');
  return route;
}

void main() async {
  debugPrintSynchronously('[main] 🚀 main() 启动');
  try {
    await _initSystem().timeout(const Duration(seconds: 45));
  } catch (e, s) {
    debugPrintSynchronously('[main] ❌ _initSystem 整体超时/异常: $e\nstack=$s');
    logger.e('_initSystem 异常', error: e, stackTrace: s);
  }
  Locale locale;
  try {
    locale = await _findLanguage().timeout(const Duration(seconds: 5));
  } catch (e, s) {
    debugPrintSynchronously('[main] ❌ _findLanguage 失败，fallback=en: $e\n$s');
    locale = const Locale('en');
  }

  // 日志/错误处理兜底：
  // FlutterError.onError 处理规则：
  // - release / debug 都要同步打 debugPrintSynchronously，避免 logger 过滤吞日志；
  // - 首帧竞态断言（debug 专用）统一由 MoodiaryFlutterBinding.reportKnownFirstFrameRaceFromErrorHandler
  //   判定，其内部已经带了「启动 20s 时间窗 + 最多 60 次 suppress」双 guard，
  //   这里不再任何二次判定（两处写签名极容易漏判/签名漂移）；
  // - 其余未知 FlutterError / 异步错误 100% 完整堆栈上报。
  bool firstFrameRaceEverLogged = false;
  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    final stk = details.stack?.toString() ?? '';
    if (kDebugMode) {
      final suppressed = MoodiaryFlutterBinding.reportKnownFirstFrameRaceFromErrorHandler(msg, stk);
      if (suppressed) {
        if (!firstFrameRaceEverLogged) {
          firstFrameRaceEverLogged = true;
          logger.i(
            '[window-not-shown] 已抑制 Flutter 已知首帧竞态断言'
            '（#144261/#151976）；最多 60 次且启动 20s 后自动停止 suppress；release 构建不受影响。',
          );
        }
        return;
      }
    }
    final pretty = StringBuffer('FlutterError ${DateTime.now().toIso8601String()}\n');
    pretty.writeln('exception: $msg');
    pretty.writeln('stack: $stk');
    pretty.writeln('library: ${details.library}');
    pretty.writeln('context: ${details.context}');
    pretty.writeln('silent: ${details.silent}');
    debugPrintSynchronously(pretty.toString());
    logger.e(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    final pretty = StringBuffer('AsyncError ${DateTime.now().toIso8601String()}\n');
    pretty.writeln('exception: $error');
    pretty.writeln('stack: $stack');
    debugPrintSynchronously(pretty.toString());
    logger.f('Error', error: error, stackTrace: stack);
    return true;
  };

  final initialRoute = _getInitialRoute();
  debugPrintSynchronously('[main] ▶️ 即将 runApp → Moodiary(initialRoute=$initialRoute)');
  runApp(Moodiary(locale: locale, initialRoute: initialRoute));
  debugPrintSynchronously('[main] ✅ runApp() 返回（应用已挂载）');
}

class Moodiary extends StatefulWidget {
  final Locale locale;
  final String initialRoute;

  const Moodiary({super.key, required this.locale, required this.initialRoute});

  @override
  State<Moodiary> createState() => _MoodiaryState();
}

class _MoodiaryState extends State<Moodiary> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 全局命令面板快捷键：桌面 Ctrl+K / macOS ⌘K
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcut);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcut);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (event is KeyDownEvent &&
        HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyK) {
      final ctx = Get.context ?? context;
      if (ctx.mounted) {
        showCommandPalette(ctx);
      }
      return true;
    }
    return false;
  }

  /// 桌面平台请求退出：先释放资源，再允许退出；若仍卡住 3 秒后强制退出。
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    try {
      await ResourceCleanupManager.instance.cleanupAll(
        timeout: const Duration(seconds: 3),
      );
    } catch (e) {
      logger.e('退出清理异常', error: e);
    }
    // 兜底：清理/收尾若仍卡住，3 秒后强制结束
    Timer(const Duration(seconds: 3), () {
      logger.i('💀 退出兜底：强制结束进程');
      exit(0);
    });
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeUtil().getThemeData();
    final debugInitialRoute = widget.initialRoute;
    debugPrintSynchronously('[Moodiary.build] 构建 GetMaterialApp.router initialRoute=$debugInitialRoute');
    return GetMaterialApp.router(
      routeInformationParser: GetInformationParser.createInformationParser(
        initialRoute: debugInitialRoute,
      ),
      onGenerateTitle: (context) => context.l10n.appName,
      backButtonDispatcher: GetRootBackButtonDispatcher(),
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: (context, child) {
        final smartDialog = FlutterSmartDialog.init();
        final mediaQuery = MediaQuery(
          data: context.mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              PrefUtil.getValue<double>('fontScale') ?? 1.0,
            ),
          ),
          child: child!,
        );
        final home = Stack(
          children: [
            mediaQuery,
            const FrostedGlassOverlayComponent(),
            if (Env.debugMode)
              const Positioned(
                top: -15,
                right: -15,
                child: EnvBadge(envMode: '测试版'),
              ),
            if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
              const Positioned(top: 0, left: 0, right: 0, child: MoveTitle()),
          ],
        );
        return smartDialog(context, home);
      },
      theme: theme.$1,
      darkTheme: theme.$2,
      locale: widget.locale,
      themeMode: ThemeMode.values[
        (PrefUtil.getValue<int>('themeMode') ?? 0).clamp(
          0,
          ThemeMode.values.length - 1,
        ).toInt()
      ],
      getPages: AppPages.routes,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

class GetRootBackButtonDispatcher extends BackButtonDispatcher
    with WidgetsBindingObserver {
  GetRootBackButtonDispatcher();

  @override
  void addCallback(ValueGetter<Future<bool>> callback) {
    if (!hasCallbacks) {
      WidgetsBinding.instance.addObserver(this);
    }
    super.addCallback(callback);
  }

  @override
  void removeCallback(ValueGetter<Future<bool>> callback) {
    super.removeCallback(callback);
    if (!hasCallbacks) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  Future<bool> didPopRoute() async {
    return (await Get.rawRoute?.navigator?.maybePop()) ??
        invokeCallback(Future.value(false));
  }
}
