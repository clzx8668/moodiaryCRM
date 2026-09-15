#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // 全局快捷键（闪念速记）通道：Ctrl+Alt+M → Dart 侧打开快速收集。
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      shortcut_channel_;

  // 热键 id（窗口内唯一）与注册状态。
  static constexpr int kShortcutId = 0xB1;
  bool shortcut_registered_ = false;

  // 注册/注销 Ctrl+Alt+M。
  void RegisterShortcut();
  void UnregisterShortcut();

  // 把窗口提到前台（含最小化恢复）。Windows 对非前台进程抢焦点有限制，
  // 用 AttachThreadInput 兜底。
  void ActivateWindow();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
