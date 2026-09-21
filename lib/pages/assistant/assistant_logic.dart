import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/components/keyboard_listener/keyboard_listener.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'assistant_state.dart';

/// 对话消息（原笔记软件自带，批次 116 从 `common/models/hunyuan.dart` 搬过来）。
///
/// 只保留页面真正需要的最小字段——[role] 与 [content]，
/// 不再依赖 `hunyuan.dart`（那个文件是为了腾讯云签名的请求/响应报文存在的）。
class Message {
  final String role;
  final String content;

  const Message({required this.role, required this.content});

  Message copyWith({String? role, String? content}) =>
      Message(role: role ?? this.role, content: content ?? this.content);
}

class AssistantLogic extends GetxController {
  final AssistantState state = AssistantState();

  //输入框控制器
  late TextEditingController textEditingController = TextEditingController();

  //控制器
  late ScrollController scrollController = ScrollController();

  //聚焦对象
  late FocusNode focusNode = FocusNode();
  late final KeyboardObserver keyboardObserver;

  List<double> heightList = [];

  @override
  void onInit() {
    keyboardObserver = KeyboardObserver(
      onStateChanged: (state) {
        switch (state) {
          case KeyboardState.opening:
            break;
          case KeyboardState.closing:
            unFocus();
            break;
          case KeyboardState.closed:
            break;
          case KeyboardState.unknown:
            break;
        }
      },
    );
    keyboardObserver.start();
    super.onInit();
    // 标题栏显示当前生效的模型（由「模型管理」决定）
    unawaited(refreshModelLabel());
  }

  @override
  void onClose() {
    keyboardObserver.stop();
    textEditingController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  void handleBack() {
    if (focusNode.hasFocus) {
      unFocus();
      Future.delayed(const Duration(seconds: 1), () {
        Get.back();
      });
    } else {
      Get.back();
    }
  }

  void unFocus() {
    focusNode.unfocus();
  }

  void newChat() {
    state.messages = {};
    update();
  }

  void clearText() {
    textEditingController.clear();
  }

  //对话
  Future<void> getAi(String ask) async {
    // 批次 116：从"腾讯云混元专有签名"切到**通用模型**——
    // 统一走「模型管理」里配置的服务商（OpenAI 兼容），
    // 支持多服务商主备切换，不再需要腾讯云 SecretId/SecretKey。
    final provider = await AiProviderFactory.load();
    if (!provider.isConfigured) {
      toast.info(message: '请先在「AI 设置 → 模型管理」配置一个服务商');
      return;
    }

    //清空输入框
    clearText();
    //失去焦点
    unFocus();
    //拿到用户提问后，对话上下文中增加一项用户提问
    final askTime = DateTime.now();
    state.messages[askTime] = Message(role: 'user', content: ask);
    update();
    toBottom();

    //带上下文请求（多轮：把历史消息一起发过去）
    final history = state.messages.values
        .map((m) => AiChatMessage(role: m.role, content: m.content))
        .toList();

    //先占位，收到流式分片往里追加
    final replyTime = DateTime.now();
    state.messages[replyTime] = const Message(role: 'assistant', content: '');
    update();

    await for (final chunk in provider.streamChat(history)) {
      if (chunk.error != null && chunk.error!.isNotEmpty) {
        final current = state.messages[replyTime]!;
        state.messages[replyTime] = current.copyWith(
          content: current.content.isEmpty ? '（出错了）${chunk.error}' : current.content,
        );
        update();
        toBottom();
        return;
      }
      if (chunk.text.isEmpty) continue;
      final current = state.messages[replyTime]!;
      state.messages[replyTime] = current.copyWith(
        content: current.content + chunk.text,
      );
      HapticFeedback.vibrate();
      update();
      toBottom();
    }
  }

  void toBottom() {
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
  }

  String getText() {
    return textEditingController.text;
  }

  Future<void> checkGetAi() async {
    final text = getText();
    if (text != '') {
      await getAi(text);
    } else {
      toast.info(message: '还没有输入问题');
    }
  }

  /// 读取当前生效的服务商/模型名（仅用于标题栏显示）。
  ///
  /// 批次 116：模型不再由本页的档位切换决定，统一由「模型管理」配置；
  /// 这里把真实生效的 provider/model 显示出来，避免用户以为还能在这切。
  Future<void> refreshModelLabel() async {
    try {
      final provider = await AiProviderFactory.load();
      final label = describeProvider(provider);
      state.modelLabel.value = label.isEmpty ? '未配置' : label;
    } catch (_) {
      state.modelLabel.value = '未配置';
    }
    update();
  }
}
