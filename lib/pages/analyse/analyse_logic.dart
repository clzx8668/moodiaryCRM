import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/features/ai/ai_provider.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:moodiary/utils/array_util.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'analyse_state.dart';

class AnalyseLogic extends GetxController {
  final AnalyseState state = AnalyseState();

  @override
  void onReady() async {
    await getMoodAndWeatherByRange(state.dateRange[0], state.dateRange[1]);
    super.onReady();
  }

  //选中两个日期后，查询指定范围内的日记
  Future<void> getMoodAndWeatherByRange(DateTime start, DateTime end) async {
    //清空原有数据
    clearResult();
    //获取数据开始
    state.finished = false;
    update();
    state.moodList = await IsarUtil.getMoodByDateRange(
      start,
      end.subtract(const Duration(days: -1)),
    );

    final weatherList = await IsarUtil.getWeatherByDateRange(
      start,
      end.subtract(const Duration(days: -1)),
    );
    for (final weather in weatherList) {
      if (weather.isNotEmpty) {
        state.weatherList.add(weather.first);
      }
    }
    state.moodMap = ArrayUtil.countList(state.moodList);
    state.weatherMap = ArrayUtil.countList(state.weatherList);
    state.finished = true;
    update();
  }

  void clearResult() {
    state.moodList.clear();
    state.weatherList.clear();
    state.moodMap.clear();
    state.weatherMap.clear();
  }

  //弹出日期选择框
  Future<void> openDatePicker(context) async {
    final result = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarViewMode: CalendarDatePicker2Mode.day,
        calendarType: CalendarDatePicker2Type.range,
        selectableDayPredicate: (date) => date.isBefore(DateTime.now()),
      ),
      dialogSize: const Size(325, 400),
      value: state.dateRange,
      borderRadius: BorderRadius.circular(20.0),
    );
    if (result != null) {
      state.dateRange[0] = result[0]!;
      state.dateRange[1] = result[1]!;
      update();
      getMoodAndWeatherByRange(result[0]!, result[1]!);
    }
  }

  Future<void> getAi() async {
    // 批次 116：从"腾讯云混元专有签名"切到**通用模型**——
    // 与旧版助手一致，统一走「模型管理」里配置的服务商（OpenAI 兼容），
    // 不再需要腾讯云 SecretId/SecretKey。
    final provider = await AiProviderFactory.load();
    if (!provider.isConfigured) {
      toast.info(message: '请先在「AI 设置 → 模型管理」配置一个服务商');
      return;
    }
    state.reply = '';
    update();
    await for (final chunk in provider.streamChat([
      const AiChatMessage(
        role: 'system',
        content:
            '我会给你一组来自一款日记APP的数据，其中包含了在某一段时间内，'
            '日记所记录的心情情况，根据这些数据，分析用户最近的心情状况，'
            '并给出合理的建议，心情的值是一个从0.0到1.0的浮点数，'
            '从小到大表示心情从坏到好，给你的值是一个Map，'
            '其中的Key是心情指数，Value是对应心情指数出现的次数。'
            '给出的输出应当是结论，不需要给出分析过程，不需要其他反馈。',
      ),
      AiChatMessage(role: 'user', content: '心情：${state.moodMap.toString()}'),
    ])) {
      if (chunk.error != null && chunk.error!.isNotEmpty) {
        state.reply = '（出错了）${chunk.error}';
        update();
        return;
      }
      if (chunk.text.isEmpty) continue;
      state.reply += chunk.text;
      update();
    }
  }
}
