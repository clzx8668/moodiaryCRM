// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hunyuan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicHeader _$PublicHeaderFromJson(Map<String, dynamic> json) => PublicHeader(
  action: json['X-TC-Action'] as String?,
  timestamp: (json['X-TC-Timestamp'] as num?)?.toInt(),
  version: json['X-TC-Version'] as String?,
  authorization: json['Authorization'] as String?,
);

Map<String, dynamic> _$PublicHeaderToJson(PublicHeader instance) =>
    <String, dynamic>{
      'X-TC-Action': ?instance.action,
      'X-TC-Timestamp': ?instance.timestamp,
      'X-TC-Version': ?instance.version,
      'Authorization': ?instance.authorization,
    };

Message _$MessageFromJson(Map<String, dynamic> json) =>
    Message(role: json['Role'] as String, content: json['Content'] as String);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'Role': instance.role,
  'Content': instance.content,
};

HunyuanResponse _$HunyuanResponseFromJson(Map<String, dynamic> json) =>
    HunyuanResponse(
      note: json['Note'] as String?,
      choices: (json['Choices'] as List<dynamic>?)
          ?.map((e) => Choices.fromJson(e as Map<String, dynamic>))
          .toList(),
      created: (json['Created'] as num?)?.toInt(),
      id: json['Id'] as String?,
      usage: json['Usage'] == null
          ? null
          : Usage.fromJson(json['Usage'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HunyuanResponseToJson(HunyuanResponse instance) =>
    <String, dynamic>{
      'Note': ?instance.note,
      'Choices': ?instance.choices,
      'Created': ?instance.created,
      'Id': ?instance.id,
      'Usage': ?instance.usage,
    };

Usage _$UsageFromJson(Map<String, dynamic> json) => Usage(
  promptTokens: (json['PromptTokens'] as num?)?.toInt(),
  completionTokens: (json['CompletionTokens'] as num?)?.toInt(),
  totalTokens: (json['TotalTokens'] as num?)?.toInt(),
);

Map<String, dynamic> _$UsageToJson(Usage instance) => <String, dynamic>{
  'PromptTokens': ?instance.promptTokens,
  'CompletionTokens': ?instance.completionTokens,
  'TotalTokens': ?instance.totalTokens,
};

Choices _$ChoicesFromJson(Map<String, dynamic> json) => Choices(
  finishReason: json['FinishReason'] as String?,
  delta: json['Delta'] == null
      ? null
      : Delta.fromJson(json['Delta'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ChoicesToJson(Choices instance) => <String, dynamic>{
  'FinishReason': ?instance.finishReason,
  'Delta': ?instance.delta,
};

Delta _$DeltaFromJson(Map<String, dynamic> json) =>
    Delta(role: json['Role'] as String?, content: json['Content'] as String?);

Map<String, dynamic> _$DeltaToJson(Delta instance) => <String, dynamic>{
  'Role': ?instance.role,
  'Content': ?instance.content,
};
