import 'package:json_annotation/json_annotation.dart';

part 'hunyuan.g.dart';

@JsonSerializable()
class PublicHeader {
  @JsonKey(name: 'X-TC-Action')
  final String? action;
  @JsonKey(name: 'X-TC-Timestamp')
  final int? timestamp;
  @JsonKey(name: 'X-TC-Version')
  final String? version;
  @JsonKey(name: 'Authorization')
  final String? authorization;

  PublicHeader({this.action, this.timestamp, this.version, this.authorization});

  factory PublicHeader.fromJson(Map<String, dynamic> json) =>
      _$PublicHeaderFromJson(json);

  Map<String, dynamic> toJson() => _$PublicHeaderToJson(this);
}

@JsonSerializable()
class Message {
  @JsonKey(name: 'Role')
  final String role;
  @JsonKey(name: 'Content')
  final String content;

  const Message({required this.role, required this.content});

  Message copyWith({String? role, String? content}) {
    return Message(role: role ?? this.role, content: content ?? this.content);
  }

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

@JsonSerializable()
class HunyuanResponse {
  @JsonKey(name: 'Note')
  final String? note;
  @JsonKey(name: 'Choices')
  final List<Choices>? choices;
  @JsonKey(name: 'Created')
  final int? created;
  @JsonKey(name: 'Id')
  final String? id;
  @JsonKey(name: 'Usage')
  final Usage? usage;

  HunyuanResponse({this.note, this.choices, this.created, this.id, this.usage});

  factory HunyuanResponse.fromJson(Map<String, dynamic> json) =>
      _$HunyuanResponseFromJson(json);

  Map<String, dynamic> toJson() => _$HunyuanResponseToJson(this);
}

@JsonSerializable()
class Usage {
  @JsonKey(name: 'PromptTokens')
  final int? promptTokens;
  @JsonKey(name: 'CompletionTokens')
  final int? completionTokens;
  @JsonKey(name: 'TotalTokens')
  final int? totalTokens;

  Usage({this.promptTokens, this.completionTokens, this.totalTokens});

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);

  Map<String, dynamic> toJson() => _$UsageToJson(this);
}

@JsonSerializable()
class Choices {
  @JsonKey(name: 'FinishReason')
  final String? finishReason;
  @JsonKey(name: 'Delta')
  final Delta? delta;

  Choices({this.finishReason, this.delta});

  factory Choices.fromJson(Map<String, dynamic> json) =>
      _$ChoicesFromJson(json);

  Map<String, dynamic> toJson() => _$ChoicesToJson(this);
}

@JsonSerializable()
class Delta {
  @JsonKey(name: 'Role')
  final String? role;
  @JsonKey(name: 'Content')
  final String? content;

  Delta({this.role, this.content});

  factory Delta.fromJson(Map<String, dynamic> json) => _$DeltaFromJson(json);

  Map<String, dynamic> toJson() => _$DeltaToJson(this);
}
