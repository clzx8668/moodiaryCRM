#include "flutter_window.h"

#include <chrono>
#include <iostream>
#include <optional>
#include <thread>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

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
        if (call.method_name() == "setShortcut") {
          bool want_enabled = true;
          int modifiers = shortcut_modifiers_;
          int virtual_key = shortcut_virtual_key_;
          if (const auto* args =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto enabled_it = args->find(flutter::EncodableValue("enabled"));
            if (enabled_it != args->end()) {
              if (const auto* value =
                      std::get_if<bool>(&enabled_it->second)) {
                want_enabled = *value;
              }
            }
            const auto mods_it =
                args->find(flutter::EncodableValue("modifiers"));
            if (mods_it != args->end()) {
              if (const auto* value =
                      std::get_if<int32_t>(&mods_it->second)) {
                modifiers = *value;
              }
            }
            const auto vk_it =
                args->find(flutter::EncodableValue("virtualKey"));
            if (vk_it != args->end()) {
              if (const auto* value = std::get_if<int32_t>(&vk_it->second)) {
                virtual_key = *value;
              }
            }
          }

          // 组合键变化或开关状态变化都先注销，再按需重新注册，
          // 保证「同一时刻只占用一个组合键」。
          UnregisterShortcut();
          if (!want_enabled) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          shortcut_modifiers_ = modifiers;
          shortcut_virtual_key_ = virtual_key;
          RegisterShortcut();
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

  // 托盘常驻：关闭窗口隐藏到托盘；托盘菜单可打开主界面 / 快速收集 / 退出。
  tray_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "moodiary/tray",
          &flutter::StandardMethodCodec::GetInstance());
  tray_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setCloseToTray") {
          const bool* value = std::get_if<bool>(call.arguments());
          close_to_tray_ = value == nullptr ? true : *value;
          result->Success(flutter::EncodableValue(tray_installed_));
          return;
        }
        if (call.method_name() == "hideWindow") {
          ::ShowWindow(GetHandle(), SW_HIDE);
          result->Success();
          return;
        }
        if (call.method_name() == "quit") {
          quitting_ = true;
          ::PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  InstallTray();

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
  RemoveTray();
  shortcut_channel_.reset();
  tray_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // 托盘图标回调：双击左键打开主界面，右键弹菜单。
  if (message == kTrayCallbackMessage) {
    switch (LOWORD(lparam)) {
      case WM_LBUTTONDBLCLK:
      case WM_LBUTTONUP:
        ActivateWindow();
        return 0;
      case WM_RBUTTONUP:
        ShowTrayMenu();
        return 0;
      default:
        break;
    }
  }

  // 托盘菜单命令
  if (message == WM_COMMAND && HIWORD(wparam) == 0) {
    const int command_id = LOWORD(wparam);
    if (command_id == kTrayMenuOpen || command_id == kTrayMenuCapture ||
        command_id == kTrayMenuQuit) {
      HandleTrayCommand(command_id);
      return 0;
    }
  }

  // 自定义标题栏的关闭按钮走 WM_SYSCOMMAND/SC_CLOSE：同样按「最小化到托盘」处理，
  // 否则消息会先进 Flutter 的窗口过程，可能不再产生 WM_CLOSE。
  if (message == WM_SYSCOMMAND && (wparam & 0xFFF0) == SC_CLOSE &&
      close_to_tray_ && !quitting_) {
    ::ShowWindow(hwnd, SW_HIDE);
    if (tray_channel_) {
      tray_channel_->InvokeMethod("hiddenToTray", nullptr);
    }
    return 0;
  }

  // 关闭窗口：开启「最小化到托盘」时隐藏而非退出（托盘菜单「退出」除外）。
  if (message == WM_CLOSE && close_to_tray_ && !quitting_) {
    ::ShowWindow(hwnd, SW_HIDE);
    if (tray_channel_) {
      tray_channel_->InvokeMethod("hiddenToTray", nullptr);
    }
    return 0;
  }

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
                       static_cast<UINT>(shortcut_modifiers_) | MOD_NOREPEAT,
                       static_cast<UINT>(shortcut_virtual_key_)) != 0;
  std::cout << "[shortcut] RegisterHotKey mods=0x" << std::hex
            << shortcut_modifiers_ << std::dec
            << " vk=0x" << std::hex << shortcut_virtual_key_ << std::dec
            << " ok=" << (shortcut_registered_ ? 1 : 0)
            << " err=" << ::GetLastError() << std::endl;
  if (!shortcut_registered_) {
    OutputDebugStringW(
        L"[shortcut] RegisterHotKey 失败：可能已被其它程序占用\n");
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

void FlutterWindow::InstallTray() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr || tray_installed_) {
    return;
  }
  tray_icon_ = {};
  tray_icon_.cbSize = sizeof(NOTIFYICONDATAW);
  tray_icon_.hWnd = hwnd;
  tray_icon_.uID = kTrayId;
  tray_icon_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  tray_icon_.uCallbackMessage = kTrayCallbackMessage;
  tray_icon_.hIcon =
      ::LoadIcon(::GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(tray_icon_.szTip, L"Moodiary 私人助理（双击打开）");
  tray_installed_ = ::Shell_NotifyIconW(NIM_ADD, &tray_icon_) != FALSE;
  std::cout << "[tray] Shell_NotifyIcon(NIM_ADD) ok=" << (tray_installed_ ? 1 : 0)
            << std::endl;
}

void FlutterWindow::RemoveTray() {
  if (!tray_installed_) {
    return;
  }
  ::Shell_NotifyIconW(NIM_DELETE, &tray_icon_);
  tray_installed_ = false;
}

void FlutterWindow::ShowTrayMenu() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  POINT cursor;
  ::GetCursorPos(&cursor);
  HMENU menu = ::CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }
  ::AppendMenuW(menu, MF_STRING, kTrayMenuOpen, L"打开 Moodiary");
  ::AppendMenuW(menu, MF_STRING, kTrayMenuCapture, L"快速收集");
  ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(menu, MF_STRING, kTrayMenuQuit, L"退出");
  // 菜单消失前必须把窗口置前，否则点击别处不会关闭菜单（Win32 约定）
  ::SetForegroundWindow(hwnd);
  ::TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, cursor.x, cursor.y,
                   0, hwnd, nullptr);
  ::DestroyMenu(menu);
  ::PostMessage(hwnd, WM_NULL, 0, 0);
}

void FlutterWindow::HandleTrayCommand(int command_id) {
  switch (command_id) {
    case kTrayMenuOpen:
      ActivateWindow();
      break;
    case kTrayMenuCapture:
      ActivateWindow();
      if (shortcut_channel_) {
        // 与全局热键同一条链路：唤起快速收集面板
        shortcut_channel_->InvokeMethod("hotkeyPressed", nullptr);
      }
      break;
    case kTrayMenuQuit:
      quitting_ = true;
      ::PostMessage(GetHandle(), WM_CLOSE, 0, 0);
      break;
    default:
      break;
  }
}
