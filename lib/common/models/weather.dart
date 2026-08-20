import 'package:json_annotation/json_annotation.dart';

part 'weather.g.dart';

@JsonSerializable()
class WeatherResponse {
  final String? code;
  final String? updateTime;
  final String? fxLink;
  final Now? now;
  final Refer? refer;

  WeatherResponse({
    this.code,
    this.updateTime,
    this.fxLink,
    this.now,
    this.refer,
  });

  factory WeatherResponse.fromJson(Map<String, dynamic> json) =>
      _$WeatherResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WeatherResponseToJson(this);
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
class Now {
  final String? obsTime;
  final String? temp;
  final String? feelsLike;
  final String? icon;
  final String? text;
  final String? wind360;
  final String? windDir;
  final String? windScale;
  final String? windSpeed;
  final String? humidity;
  final String? precip;
  final String? pressure;
  final String? vis;
  final String? cloud;
  final String? dew;

  Now({
    this.obsTime,
    this.temp,
    this.feelsLike,
    this.icon,
    this.text,
    this.wind360,
    this.windDir,
    this.windScale,
    this.windSpeed,
    this.humidity,
    this.precip,
    this.pressure,
    this.vis,
    this.cloud,
    this.dew,
  });

  factory Now.fromJson(Map<String, dynamic> json) => _$NowFromJson(json);

  Map<String, dynamic> toJson() => _$NowToJson(this);
}
