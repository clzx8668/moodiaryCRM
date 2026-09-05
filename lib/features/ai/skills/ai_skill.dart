/// AI 技能（对标得到大脑「四大能力」：点评 / 发芽 / 润色 / 拷问）。
enum AiSkillType {
  comment('点评', '💬', '旁观者视角，找亮点与盲区'),
  sprout('发芽', '🌱', '一条记录延伸出 3-5 个新想法'),
  interrogate('拷问', '🔥', '苏格拉底式追问，帮你想透'),
  polish('打磨成稿', '✨', '把粗糙记录打磨成可发布作品');

  final String label;
  final String icon;
  final String hint;

  const AiSkillType(this.label, this.icon, this.hint);
}

/// 技能 Prompt 构建（纯函数，便于单测与统一管理）。
class AiSkillPrompts {
  AiSkillPrompts._();

  static const String system =
      '你是一个知识教练，用中文回答。你只输出 JSON，不要输出任何多余说明。';

  static String build(AiSkillType type, String content) {
    final instruction = switch (type) {
      AiSkillType.comment => '''
以旁观者视角点评以下记录：
- 指出 2-3 个亮点；
- 指出 1-2 个盲区或可深挖的点；
- 语气克制、具体，不要空话套话。
返回 JSON：{"title":"点评","text":"..."}''',
      AiSkillType.sprout => '''
把这颗想法当作种子，延伸出 3-5 个新认知/新方向：
- 每个想法一句话概括 + 1-2 句展开；
- 优先给出跨领域联想，不要同义重复；
- 可直接继续行动。
返回 JSON：{"title":"发芽","items":["..."],"text":"..."}''',
      AiSkillType.interrogate => '''
像诤友一样，对以下记录的立场/逻辑提出 3 个尖锐追问：
- 每个追问要具体、可回答；
- 帮助用户把想法想透。
返回 JSON：{"title":"拷问","questions":["..."],"text":"..."}''',
      AiSkillType.polish => '''
把以下记录打磨成文从句顺、可直接发布的作品：
- 去掉口语冗余、理顺结构、补全逻辑；
- 不改变原意与事实；
- 输出成品正文。
返回 JSON：{"title":"打磨成稿","text":"..."}''',
    };
    return '''
$system

$instruction

记录内容：
"""$content"""
''';
  }
}
