import 'package:json_annotation/json_annotation.dart';

part 'hitokoto.g.dart';

@JsonSerializable()
class HitokotoResponse {
  final int? id;
  final String? uuid;
  final String? hitokoto;
  final String? type;
  final String? from;
  @JsonKey(name: 'from_who')
  final String? fromWho;
  final String? creator;
  @JsonKey(name: 'creator_uid')
  final int? creatorUid;
  final int? reviewer;
  @JsonKey(name: 'commit_from')
  final String? commitFrom;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  final int? length;

  HitokotoResponse({
    this.id,
    this.uuid,
    this.hitokoto,
    this.type,
    this.from,
    this.fromWho,
    this.creator,
    this.creatorUid,
    this.reviewer,
    this.commitFrom,
    this.createdAt,
    this.length,
  });

  factory HitokotoResponse.fromJson(Map<String, dynamic> json) =>
      _$HitokotoResponseFromJson(json);

  Map<String, dynamic> toJson() => _$HitokotoResponseToJson(this);
}
