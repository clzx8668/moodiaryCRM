import 'package:json_annotation/json_annotation.dart';

part 'geo.g.dart';

@JsonSerializable()
class GeoResponse {
  final String? code;
  final List<Location>? location;
  final Refer? refer;

  GeoResponse({this.code, this.location, this.refer});

  factory GeoResponse.fromJson(Map<String, dynamic> json) =>
      _$GeoResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GeoResponseToJson(this);
}

@JsonSerializable()
class Refer {
  final List<String>? sources;
  final List<String>? license;

  Refer({this.sources, this.license});

  factory Refer.fromJson(Map<String, dynamic> json) => _$ReferFromJson(json);

  Map<String, dynamic> toJson() => _$ReferToJson(this);
}

@JsonSerializable()
class Location {
  final String? name;
  final String? id;
  final String? lat;
  final String? lon;
  final String? adm2;
  final String? adm1;
  final String? country;
  final String? tz;
  final String? utcOffset;
  final String? isDst;
  final String? type;
  final String? rank;
  final String? fxLink;

  Location({
    this.name,
    this.id,
    this.lat,
    this.lon,
    this.adm2,
    this.adm1,
    this.country,
    this.tz,
    this.utcOffset,
    this.isDst,
    this.type,
    this.rank,
    this.fxLink,
  });

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  Map<String, dynamic> toJson() => _$LocationToJson(this);
}
