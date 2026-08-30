#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME);

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 禁用 WebView2 GPU 加速（尽力而为）：WebView2 惰性创建环境时会读取该
  // 环境变量；降 GPU 能降低 inappwebview 插件静态 GraphicsContext 析构时
  // 在 D3D11 设备释放上的挂起风险（真正兜底见末尾 TerminateProcess）。
  ::SetEnvironmentVariableW(L"WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS",
                            L"--disable-gpu");

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Moodiary", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  // 彻底解耦"窗口显示"与"首帧渲染"。
  // 标准模板依赖 SetNextFrameCallback→Show()，但当首帧断言卡在 Flutter
  // 框架层（debugFrameWasSentToEngine）或渲染被 WebView2/D3D11 阻塞时，
  // NextFrameCallback 永不触发 → 窗口永远隐藏。这里直接 Show，显示与
  // 渲染解耦：即使内容白屏，至少能看到窗口、能抓控制台日志定位。
  window.Show();

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  // 主循环已退出（引擎收尾完成）。用 TerminateProcess 跳过 DLL 卸载
  // （ExitProcess 会触发 LdrShutdownProcess → 各 DLL 的 DLL_PROCESS_DETACH，
  // 其中 flutter_inappwebview_windows 插件的静态 GraphicsContext 析构会在
  // 部分 Intel/WebView2 环境卡在 igd10um64xe.dll 的 D3D11 设备释放上）。
  // TerminateProcess 直接终止、不跑 DLL 卸载，从而彻底避免该挂起。
  ::TerminateProcess(GetCurrentProcess(), 0);
  return EXIT_SUCCESS;
}
