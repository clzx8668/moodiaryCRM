#include "flutter_window.h"

#include <chrono>
#include <iostream>
#include <optional>
#include <thread>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // 全局快捷键（闪念速记）：Windows 主消息循环在本窗口线程，
  // 直接把 WM_HOTKEY 转成 Dart 侧的方法调用，避免 Dart 侧自建消息循环。
  shortcut_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "moodiary/shortcut",
          &flutter::StandardMethodCodec::GetInstance());
  shortcut_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setEnabled") {
          const bool* enabled = std::get_if<bool>(call.arguments());
          const bool value = enabled == nullptr ? true : *enabled;
          if (value) {
            RegisterShortcut();
          } else {
            UnregisterShortcut();
          }
          result->Success(flutter::EncodableValue(shortcut_registered_));
          return;
        }
        if (call.method_name() == "isRegistered") {
          result->Success(flutter::EncodableValue(shortcut_registered_));
          return;
        }
        result->NotImplemented();
      });

  // 自测钩子（仅显式设置环境变量时生效）：模拟一次热键命中，
  // 用于在无法合成系统按键的环境里验证「热键 → 置前 → 打开收集面板」链路。
  wchar_t selftest[8] = {0};
  if (::GetEnvironmentVariableW(L"MOODIARY_SHORTCUT_SELFTEST", selftest, 8) >
          0 &&
      selftest[0] == L'1') {
    std::thread([this]() {
      std::this_thread::sleep_for(std::chrono::seconds(15));
      // 用与真实热键完全相同的路径：向窗口投递 WM_HOTKEY，
      // 由平台线程的消息循环处理（避免跨线程调用平台通道）。
      std::cout << "[shortcut] selftest: 投递 WM_HOTKEY" << std::endl;
      ::PostMessage(GetHandle(), WM_HOTKEY, kShortcutId, 0);
    }).detach();
  }

  // 兜底：CreateWindow 阶段还没把窗口内容/尺寸刷进引擎时，先显示一个空壳窗口，
  // 避免首帧断言/插件初始化阻塞时用户看到"无窗口"。SetNextFrameCallback
  // 保留作冗余（等首帧后再 Show 一次也幂等）。
  Show();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  UnregisterShortcut();
  shortcut_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // 兜底：正常关闭应走 引擎收尾→PostQuitMessage 快速退出；
  // 若 8 秒仍未退出（引擎收尾被后台资源阻塞），强制结束进程，避免无限残留。
  // 放在 HandleTopLevelWindowProc 之前，避免被 Flutter 消费 WM_CLOSE 而漏掉。
  if (message == WM_CLOSE) {
    std::thread([]() {
      std::this_thread::sleep_for(std::chrono::seconds(8));
      ::ExitProcess(0);
    }).detach();
  }

  // 全局快捷键：把窗口提到前台并通知 Dart 打开快速收集。
  if (message == WM_HOTKEY) {
    std::cout << "[shortcut] WM_HOTKEY id=" << static_cast<int>(wparam)
              << std::endl;
    if (static_cast<int>(wparam) == kShortcutId) {
      ActivateWindow();
      if (shortcut_channel_) {
        shortcut_channel_->InvokeMethod("hotkeyPressed", nullptr);
      }
      return 0;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterShortcut() {
  if (shortcut_registered_) {
    return;
  }
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  // MOD_NOREPEAT：按住不放不重复触发。
  shortcut_registered_ =
      ::RegisterHotKey(hwnd, kShortcutId,
                       MOD_CONTROL | MOD_ALT | MOD_NOREPEAT,
                       0x4D /* 'M' */) != 0;
  std::cout << "[shortcut] RegisterHotKey(Ctrl+Alt+M) ok="
            << (shortcut_registered_ ? 1 : 0)
            << " err=" << ::GetLastError() << std::endl;
  if (!shortcut_registered_) {
    OutputDebugStringW(
        L"[shortcut] RegisterHotKey(Ctrl+Alt+M) 失败：可能已被其它程序占用\n");
  }
}

void FlutterWindow::UnregisterShortcut() {
  if (!shortcut_registered_) {
    return;
  }
  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    ::UnregisterHotKey(hwnd, kShortcutId);
  }
  shortcut_registered_ = false;
}

void FlutterWindow::ActivateWindow() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  } else {
    ::ShowWindow(hwnd, SW_SHOW);
  }
  HWND foreground = ::GetForegroundWindow();
  DWORD foreground_thread =
      foreground == nullptr ? 0 : ::GetWindowThreadProcessId(foreground, nullptr);
  DWORD current_thread = ::GetCurrentThreadId();
  const bool attached = foreground_thread != 0 &&
                        foreground_thread != current_thread &&
                        ::AttachThreadInput(current_thread, foreground_thread,
                                            TRUE);
  ::BringWindowToTop(hwnd);
  ::SetForegroundWindow(hwnd);
  if (attached) {
    ::AttachThreadInput(current_thread, foreground_thread, FALSE);
  }
}
