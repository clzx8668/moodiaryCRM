import 'package:json_annotation/json_annotation.dart';

part 'image.g.dart';

@JsonSerializable()
class BingImage {
  final List<Images>? images;
  final Tooltips? tooltips;

  BingImage({this.images, this.tooltips});

  factory BingImage.fromJson(Map<String, dynamic> json) =>
      _$BingImageFromJson(json);

  Map<String, dynamic> toJson() => _$BingImageToJson(this);
}

@JsonSerializable()
class Tooltips {
  final String? loading;
  final String? previous;
  final String? next;
  final String? walle;
  final String? walls;

  Tooltips({this.loading, this.previous, this.next, this.walle, this.walls});

  factory Tooltips.fromJson(Map<String, dynamic> json) =>
      _$TooltipsFromJson(json);

  Map<String, dynamic> toJson() => _$TooltipsToJson(this);
}

@JsonSerializable()
class Images {
  final String? startdate;
  final String? fullstartdate;
  final String? enddate;
  final String? url;
  final String? urlbase;
  final String? copyright;
  final String? copyrightlink;
  final String? title;
  final String? quiz;
  final bool? wp;
  final String? hsh;
  final int? drk;
  final int? top;
  final int? bot;
  final List<dynamic>? hs;

  Images({
    this.startdate,
    this.fullstartdate,
    this.enddate,
    this.url,
    this.urlbase,
    this.copyright,
    this.copyrightlink,
    this.title,
    this.quiz,
    this.wp,
    this.hsh,
    this.drk,
    this.top,
    this.bot,
    this.hs,
  });

  factory Images.fromJson(Map<String, dynamic> json) => _$ImagesFromJson(json);

  Map<String, dynamic> toJson() => _$ImagesToJson(this);
}
