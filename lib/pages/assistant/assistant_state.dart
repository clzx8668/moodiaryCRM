import 'package:get/get.dart';
import 'package:moodiary/common/values/keyboard_state.dart';

import 'assistant_logic.dart';

class AssistantState {
  //对话上下文
  late Map<DateTime, Message> messages;

  /// 当前服务商/模型展示名（批次 116：模型由「模型管理」决定，
  /// 这里只用于标题栏显示，不再有手动档位切换）。
  late RxString modelLabel;

  late KeyboardState keyboardState;

  late int totalToken;

  AssistantState() {
    messages = {};

    modelLabel = ''.obs;
    keyboardState = KeyboardState.closed;

    ///Initialize variables
  }
}
