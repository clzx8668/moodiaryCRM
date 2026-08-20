import 'package:json_annotation/json_annotation.dart';

part 'github.g.dart';

@JsonSerializable()
class GithubRelease {
  final String? url;
  @JsonKey(name: 'assets_url')
  final String? assetsUrl;
  @JsonKey(name: 'upload_url')
  final String? uploadUrl;
  @JsonKey(name: 'html_url')
  final String? htmlUrl;
  final int? id;
  final Author? author;
  @JsonKey(name: 'node_id')
  final String? nodeId;
  @JsonKey(name: 'tag_name')
  final String? tagName;
  @JsonKey(name: 'target_commitish')
  final String? targetCommitish;
  final String? name;
  final bool? draft;
  final bool? prerelease;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'published_at')
  final String? publishedAt;
  final List<Assets>? assets;
  @JsonKey(name: 'tarball_url')
  final String? tarballUrl;
  @JsonKey(name: 'zipball_url')
  final String? zipballUrl;
  final String? body;

  GithubRelease({
    this.url,
    this.assetsUrl,
    this.uploadUrl,
    this.htmlUrl,
    this.id,
    this.author,
    this.nodeId,
    this.tagName,
    this.targetCommitish,
    this.name,
    this.draft,
    this.prerelease,
    this.createdAt,
    this.publishedAt,
    this.assets,
    this.tarballUrl,
    this.zipballUrl,
    this.body,
  });

  factory GithubRelease.fromJson(Map<String, dynamic> json) =>
      _$GithubReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$GithubReleaseToJson(this);
}

@JsonSerializable()
class Assets {
  final String? url;
  final int? id;
  @JsonKey(name: 'node_id')
  final String? nodeId;
  final String? name;
  final dynamic label;
  final Uploader? uploader;
  @JsonKey(name: 'content_type')
  final String? contentType;
  final String? state;
  final int? size;
  @JsonKey(name: 'download_count')
  final int? downloadCount;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;
  @JsonKey(name: 'browser_download_url')
  final String? browserDownloadUrl;

  Assets({
    this.url,
    this.id,
    this.nodeId,
    this.name,
    this.label,
    this.uploader,
    this.contentType,
    this.state,
    this.size,
    this.downloadCount,
    this.createdAt,
    this.updatedAt,
    this.browserDownloadUrl,
  });

  factory Assets.fromJson(Map<String, dynamic> json) =>
      _$AssetsFromJson(json);

  Map<String, dynamic> toJson() => _$AssetsToJson(this);
}

@JsonSerializable()
class Uploader {
  final String? login;
  final int? id;
  @JsonKey(name: 'node_id')
  final String? nodeId;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'gravatar_id')
  final String? gravatarId;
  final String? url;
  @JsonKey(name: 'html_url')
  final String? htmlUrl;
  @JsonKey(name: 'followers_url')
  final String? followersUrl;
  @JsonKey(name: 'following_url')
  final String? followingUrl;
  @JsonKey(name: 'gists_url')
  final String? gistsUrl;
  @JsonKey(name: 'starred_url')
  final String? starredUrl;
  @JsonKey(name: 'subscriptions_url')
  final String? subscriptionsUrl;
  @JsonKey(name: 'organizations_url')
  final String? organizationsUrl;
  @JsonKey(name: 'repos_url')
  final String? reposUrl;
  @JsonKey(name: 'events_url')
  final String? eventsUrl;
  @JsonKey(name: 'received_events_url')
  final String? receivedEventsUrl;
  final String? type;
  @JsonKey(name: 'user_view_type')
  final String? userViewType;
  @JsonKey(name: 'site_admin')
  final bool? siteAdmin;

  Uploader({
    this.login,
    this.id,
    this.nodeId,
    this.avatarUrl,
    this.gravatarId,
    this.url,
    this.htmlUrl,
    this.followersUrl,
    this.followingUrl,
    this.gistsUrl,
    this.starredUrl,
    this.subscriptionsUrl,
    this.organizationsUrl,
    this.reposUrl,
    this.eventsUrl,
    this.receivedEventsUrl,
    this.type,
    this.userViewType,
    this.siteAdmin,
  });

  factory Uploader.fromJson(Map<String, dynamic> json) =>
      _$UploaderFromJson(json);

  Map<String, dynamic> toJson() => _$UploaderToJson(this);
}

@JsonSerializable()
class Author {
  final String? login;
  final int? id;
  @JsonKey(name: 'node_id')
  final String? nodeId;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'gravatar_id')
  final String? gravatarId;
  final String? url;
  @JsonKey(name: 'html_url')
  final String? htmlUrl;
  @JsonKey(name: 'followers_url')
  final String? followersUrl;
  @JsonKey(name: 'following_url')
  final String? followingUrl;
  @JsonKey(name: 'gists_url')
  final String? gistsUrl;
  @JsonKey(name: 'starred_url')
  final String? starredUrl;
  @JsonKey(name: 'subscriptions_url')
  final String? subscriptionsUrl;
  @JsonKey(name: 'organizations_url')
  final String? organizationsUrl;
  @JsonKey(name: 'repos_url')
  final String? reposUrl;
  @JsonKey(name: 'events_url')
  final String? eventsUrl;
  @JsonKey(name: 'received_events_url')
  final String? receivedEventsUrl;
  final String? type;
  @JsonKey(name: 'user_view_type')
  final String? userViewType;
  @JsonKey(name: 'site_admin')
  final bool? siteAdmin;

  Author({
    this.login,
    this.id,
    this.nodeId,
    this.avatarUrl,
    this.gravatarId,
    this.url,
    this.htmlUrl,
    this.followersUrl,
    this.followingUrl,
    this.gistsUrl,
    this.starredUrl,
    this.subscriptionsUrl,
    this.organizationsUrl,
    this.reposUrl,
    this.eventsUrl,
    this.receivedEventsUrl,
    this.type,
    this.userViewType,
    this.siteAdmin,
  });

  factory Author.fromJson(Map<String, dynamic> json) => _$AuthorFromJson(json);

  Map<String, dynamic> toJson() => _$AuthorToJson(this);
}
