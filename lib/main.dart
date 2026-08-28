import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:drift/native.dart';
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

Future<void> _initSystem() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 启动初始化全部加超时兜底：任一平台通道/模块挂起都不能阻塞进入应用
  try {
    await PrefUtil.initPref().timeout(const Duration(seconds: 15));
  } catch (e) {
    logger.e('Pref 初始化失败', error: e);
  }
  try {
    await IsarUtil.initIsar().timeout(const Duration(seconds: 20));
  } catch (e) {
    logger.e('数据库初始化异常，切换内存库兜底', error: e);
    await _fallbackDatabase(e);
  }
  try {
    await HiveUtil().init().timeout(const Duration(seconds: 10));
  } catch (e) {
    logger.e('Hive 初始化失败', error: e);
  }
  unawaited(_initSyncLogFile());
  unawaited(_initRustAndEventStream());
  unawaited(_platFormOption());
  WebDavUtil().initWebDav();
  try {
    await ThemeUtil().buildTheme().timeout(const Duration(seconds: 10));
  } catch (e) {
    logger.e('主题构建失败', error: e);
  }
  fvp.registerWith();
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
    });
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
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
  Language language = Language.values.firstWhere(
    (e) => e.languageCode == PrefUtil.getValue<String>('language')!,
    orElse: () => Language.system,
  );
  if (language == Language.system) {
    final systemLocale = await findSystemLocale();
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
  }
}

String _getInitialRoute() {
  if (PrefUtil.getValue<bool>('lock') ?? false) return AppRoutes.lockPage;
  if (PrefUtil.getValue<bool>('firstStart') ?? true) {
    return AppRoutes.startPage;
  }
  return AppRoutes.homePage;
}

void main() async {
  await _initSystem();
  Locale locale;
  try {
    locale = await _findLanguage().timeout(const Duration(seconds: 5));
  } catch (_) {
    locale = const Locale('en');
  }
  FlutterError.onError = (details) {
    logger.e(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.f('Error', error: error, stackTrace: stack);
    return true;
  };

  runApp(Moodiary(locale: locale));
}

class Moodiary extends StatefulWidget {
  final Locale locale;

  const Moodiary({super.key, required this.locale});

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
    return GetMaterialApp.router(
      routeInformationParser: GetInformationParser.createInformationParser(
        initialRoute: _getInitialRoute(),
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
