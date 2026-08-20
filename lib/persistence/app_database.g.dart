// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DiariesTable extends Diaries with TableInfo<$DiariesTable, DiaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentTextMeta = const VerificationMeta(
    'contentText',
  );
  @override
  late final GeneratedColumn<String> contentText = GeneratedColumn<String>(
    'content_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _yMMeta = const VerificationMeta('yM');
  @override
  late final GeneratedColumn<String> yM = GeneratedColumn<String>(
    'y_m',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _yMdMeta = const VerificationMeta('yMd');
  @override
  late final GeneratedColumn<String> yMd = GeneratedColumn<String>(
    'y_md',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _showMeta = const VerificationMeta('show');
  @override
  late final GeneratedColumn<bool> show = GeneratedColumn<bool>(
    'show',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<double> mood = GeneratedColumn<double>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> weather =
      GeneratedColumn<String>(
        'weather',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($DiariesTable.$converterweather);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> imageName =
      GeneratedColumn<String>(
        'image_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($DiariesTable.$converterimageName);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> audioName =
      GeneratedColumn<String>(
        'audio_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($DiariesTable.$converteraudioName);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> videoName =
      GeneratedColumn<String>(
        'video_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($DiariesTable.$convertervideoName);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($DiariesTable.$convertertags);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> position =
      GeneratedColumn<String>(
        'position',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($DiariesTable.$converterposition);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> keywords =
      GeneratedColumn<String>(
        'keywords',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($DiariesTable.$converterkeywords);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tokenizer =
      GeneratedColumn<String>(
        'tokenizer',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($DiariesTable.$convertertokenizer);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('markdown'),
  );
  static const VerificationMeta _imageColorMeta = const VerificationMeta(
    'imageColor',
  );
  @override
  late final GeneratedColumn<int> imageColor = GeneratedColumn<int>(
    'image_color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aspectMeta = const VerificationMeta('aspect');
  @override
  late final GeneratedColumn<double> aspect = GeneratedColumn<double>(
    'aspect',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    title,
    content,
    contentText,
    yM,
    yMd,
    time,
    lastModified,
    show,
    mood,
    weather,
    imageName,
    audioName,
    videoName,
    tags,
    position,
    keywords,
    tokenizer,
    type,
    imageColor,
    aspect,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('content_text')) {
      context.handle(
        _contentTextMeta,
        contentText.isAcceptableOrUnknown(
          data['content_text']!,
          _contentTextMeta,
        ),
      );
    }
    if (data.containsKey('y_m')) {
      context.handle(_yMMeta, yM.isAcceptableOrUnknown(data['y_m']!, _yMMeta));
    }
    if (data.containsKey('y_md')) {
      context.handle(
        _yMdMeta,
        yMd.isAcceptableOrUnknown(data['y_md']!, _yMdMeta),
      );
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedMeta);
    }
    if (data.containsKey('show')) {
      context.handle(
        _showMeta,
        show.isAcceptableOrUnknown(data['show']!, _showMeta),
      );
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('image_color')) {
      context.handle(
        _imageColorMeta,
        imageColor.isAcceptableOrUnknown(data['image_color']!, _imageColorMeta),
      );
    }
    if (data.containsKey('aspect')) {
      context.handle(
        _aspectMeta,
        aspect.isAcceptableOrUnknown(data['aspect']!, _aspectMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      contentText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_text'],
      )!,
      yM: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}y_m'],
      )!,
      yMd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}y_md'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}time'],
      )!,
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified'],
      )!,
      show: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mood'],
      )!,
      weather: $DiariesTable.$converterweather.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}weather'],
        )!,
      ),
      imageName: $DiariesTable.$converterimageName.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}image_name'],
        )!,
      ),
      audioName: $DiariesTable.$converteraudioName.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}audio_name'],
        )!,
      ),
      videoName: $DiariesTable.$convertervideoName.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}video_name'],
        )!,
      ),
      tags: $DiariesTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      position: $DiariesTable.$converterposition.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}position'],
        )!,
      ),
      keywords: $DiariesTable.$converterkeywords.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}keywords'],
        )!,
      ),
      tokenizer: $DiariesTable.$convertertokenizer.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tokenizer'],
        )!,
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      imageColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_color'],
      ),
      aspect: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aspect'],
      ),
    );
  }

  @override
  $DiariesTable createAlias(String alias) {
    return $DiariesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterweather =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterimageName =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converteraudioName =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertervideoName =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterposition =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterkeywords =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertertokenizer =
      const StringListConverter();
}

class DiaryRow extends DataClass implements Insertable<DiaryRow> {
  final String id;
  final String? categoryId;
  final String title;
  final String content;
  final String contentText;
  final String yM;
  final String yMd;
  final DateTime time;
  final DateTime lastModified;
  final bool show;
  final double mood;
  final List<String> weather;
  final List<String> imageName;
  final List<String> audioName;
  final List<String> videoName;
  final List<String> tags;
  final List<String> position;
  final List<String> keywords;
  final List<String> tokenizer;
  final String type;
  final int? imageColor;
  final double? aspect;
  const DiaryRow({
    required this.id,
    this.categoryId,
    required this.title,
    required this.content,
    required this.contentText,
    required this.yM,
    required this.yMd,
    required this.time,
    required this.lastModified,
    required this.show,
    required this.mood,
    required this.weather,
    required this.imageName,
    required this.audioName,
    required this.videoName,
    required this.tags,
    required this.position,
    required this.keywords,
    required this.tokenizer,
    required this.type,
    this.imageColor,
    this.aspect,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['content_text'] = Variable<String>(contentText);
    map['y_m'] = Variable<String>(yM);
    map['y_md'] = Variable<String>(yMd);
    map['time'] = Variable<DateTime>(time);
    map['last_modified'] = Variable<DateTime>(lastModified);
    map['show'] = Variable<bool>(show);
    map['mood'] = Variable<double>(mood);
    {
      map['weather'] = Variable<String>(
        $DiariesTable.$converterweather.toSql(weather),
      );
    }
    {
      map['image_name'] = Variable<String>(
        $DiariesTable.$converterimageName.toSql(imageName),
      );
    }
    {
      map['audio_name'] = Variable<String>(
        $DiariesTable.$converteraudioName.toSql(audioName),
      );
    }
    {
      map['video_name'] = Variable<String>(
        $DiariesTable.$convertervideoName.toSql(videoName),
      );
    }
    {
      map['tags'] = Variable<String>($DiariesTable.$convertertags.toSql(tags));
    }
    {
      map['position'] = Variable<String>(
        $DiariesTable.$converterposition.toSql(position),
      );
    }
    {
      map['keywords'] = Variable<String>(
        $DiariesTable.$converterkeywords.toSql(keywords),
      );
    }
    {
      map['tokenizer'] = Variable<String>(
        $DiariesTable.$convertertokenizer.toSql(tokenizer),
      );
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || imageColor != null) {
      map['image_color'] = Variable<int>(imageColor);
    }
    if (!nullToAbsent || aspect != null) {
      map['aspect'] = Variable<double>(aspect);
    }
    return map;
  }

  DiariesCompanion toCompanion(bool nullToAbsent) {
    return DiariesCompanion(
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      title: Value(title),
      content: Value(content),
      contentText: Value(contentText),
      yM: Value(yM),
      yMd: Value(yMd),
      time: Value(time),
      lastModified: Value(lastModified),
      show: Value(show),
      mood: Value(mood),
      weather: Value(weather),
      imageName: Value(imageName),
      audioName: Value(audioName),
      videoName: Value(videoName),
      tags: Value(tags),
      position: Value(position),
      keywords: Value(keywords),
      tokenizer: Value(tokenizer),
      type: Value(type),
      imageColor: imageColor == null && nullToAbsent
          ? const Value.absent()
          : Value(imageColor),
      aspect: aspect == null && nullToAbsent
          ? const Value.absent()
          : Value(aspect),
    );
  }

  factory DiaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryRow(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      contentText: serializer.fromJson<String>(json['contentText']),
      yM: serializer.fromJson<String>(json['yM']),
      yMd: serializer.fromJson<String>(json['yMd']),
      time: serializer.fromJson<DateTime>(json['time']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      show: serializer.fromJson<bool>(json['show']),
      mood: serializer.fromJson<double>(json['mood']),
      weather: serializer.fromJson<List<String>>(json['weather']),
      imageName: serializer.fromJson<List<String>>(json['imageName']),
      audioName: serializer.fromJson<List<String>>(json['audioName']),
      videoName: serializer.fromJson<List<String>>(json['videoName']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      position: serializer.fromJson<List<String>>(json['position']),
      keywords: serializer.fromJson<List<String>>(json['keywords']),
      tokenizer: serializer.fromJson<List<String>>(json['tokenizer']),
      type: serializer.fromJson<String>(json['type']),
      imageColor: serializer.fromJson<int?>(json['imageColor']),
      aspect: serializer.fromJson<double?>(json['aspect']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String?>(categoryId),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'contentText': serializer.toJson<String>(contentText),
      'yM': serializer.toJson<String>(yM),
      'yMd': serializer.toJson<String>(yMd),
      'time': serializer.toJson<DateTime>(time),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'show': serializer.toJson<bool>(show),
      'mood': serializer.toJson<double>(mood),
      'weather': serializer.toJson<List<String>>(weather),
      'imageName': serializer.toJson<List<String>>(imageName),
      'audioName': serializer.toJson<List<String>>(audioName),
      'videoName': serializer.toJson<List<String>>(videoName),
      'tags': serializer.toJson<List<String>>(tags),
      'position': serializer.toJson<List<String>>(position),
      'keywords': serializer.toJson<List<String>>(keywords),
      'tokenizer': serializer.toJson<List<String>>(tokenizer),
      'type': serializer.toJson<String>(type),
      'imageColor': serializer.toJson<int?>(imageColor),
      'aspect': serializer.toJson<double?>(aspect),
    };
  }

  DiaryRow copyWith({
    String? id,
    Value<String?> categoryId = const Value.absent(),
    String? title,
    String? content,
    String? contentText,
    String? yM,
    String? yMd,
    DateTime? time,
    DateTime? lastModified,
    bool? show,
    double? mood,
    List<String>? weather,
    List<String>? imageName,
    List<String>? audioName,
    List<String>? videoName,
    List<String>? tags,
    List<String>? position,
    List<String>? keywords,
    List<String>? tokenizer,
    String? type,
    Value<int?> imageColor = const Value.absent(),
    Value<double?> aspect = const Value.absent(),
  }) => DiaryRow(
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    title: title ?? this.title,
    content: content ?? this.content,
    contentText: contentText ?? this.contentText,
    yM: yM ?? this.yM,
    yMd: yMd ?? this.yMd,
    time: time ?? this.time,
    lastModified: lastModified ?? this.lastModified,
    show: show ?? this.show,
    mood: mood ?? this.mood,
    weather: weather ?? this.weather,
    imageName: imageName ?? this.imageName,
    audioName: audioName ?? this.audioName,
    videoName: videoName ?? this.videoName,
    tags: tags ?? this.tags,
    position: position ?? this.position,
    keywords: keywords ?? this.keywords,
    tokenizer: tokenizer ?? this.tokenizer,
    type: type ?? this.type,
    imageColor: imageColor.present ? imageColor.value : this.imageColor,
    aspect: aspect.present ? aspect.value : this.aspect,
  );
  DiaryRow copyWithCompanion(DiariesCompanion data) {
    return DiaryRow(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      contentText: data.contentText.present
          ? data.contentText.value
          : this.contentText,
      yM: data.yM.present ? data.yM.value : this.yM,
      yMd: data.yMd.present ? data.yMd.value : this.yMd,
      time: data.time.present ? data.time.value : this.time,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      show: data.show.present ? data.show.value : this.show,
      mood: data.mood.present ? data.mood.value : this.mood,
      weather: data.weather.present ? data.weather.value : this.weather,
      imageName: data.imageName.present ? data.imageName.value : this.imageName,
      audioName: data.audioName.present ? data.audioName.value : this.audioName,
      videoName: data.videoName.present ? data.videoName.value : this.videoName,
      tags: data.tags.present ? data.tags.value : this.tags,
      position: data.position.present ? data.position.value : this.position,
      keywords: data.keywords.present ? data.keywords.value : this.keywords,
      tokenizer: data.tokenizer.present ? data.tokenizer.value : this.tokenizer,
      type: data.type.present ? data.type.value : this.type,
      imageColor: data.imageColor.present
          ? data.imageColor.value
          : this.imageColor,
      aspect: data.aspect.present ? data.aspect.value : this.aspect,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryRow(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentText: $contentText, ')
          ..write('yM: $yM, ')
          ..write('yMd: $yMd, ')
          ..write('time: $time, ')
          ..write('lastModified: $lastModified, ')
          ..write('show: $show, ')
          ..write('mood: $mood, ')
          ..write('weather: $weather, ')
          ..write('imageName: $imageName, ')
          ..write('audioName: $audioName, ')
          ..write('videoName: $videoName, ')
          ..write('tags: $tags, ')
          ..write('position: $position, ')
          ..write('keywords: $keywords, ')
          ..write('tokenizer: $tokenizer, ')
          ..write('type: $type, ')
          ..write('imageColor: $imageColor, ')
          ..write('aspect: $aspect')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    categoryId,
    title,
    content,
    contentText,
    yM,
    yMd,
    time,
    lastModified,
    show,
    mood,
    weather,
    imageName,
    audioName,
    videoName,
    tags,
    position,
    keywords,
    tokenizer,
    type,
    imageColor,
    aspect,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryRow &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.title == this.title &&
          other.content == this.content &&
          other.contentText == this.contentText &&
          other.yM == this.yM &&
          other.yMd == this.yMd &&
          other.time == this.time &&
          other.lastModified == this.lastModified &&
          other.show == this.show &&
          other.mood == this.mood &&
          other.weather == this.weather &&
          other.imageName == this.imageName &&
          other.audioName == this.audioName &&
          other.videoName == this.videoName &&
          other.tags == this.tags &&
          other.position == this.position &&
          other.keywords == this.keywords &&
          other.tokenizer == this.tokenizer &&
          other.type == this.type &&
          other.imageColor == this.imageColor &&
          other.aspect == this.aspect);
}

class DiariesCompanion extends UpdateCompanion<DiaryRow> {
  final Value<String> id;
  final Value<String?> categoryId;
  final Value<String> title;
  final Value<String> content;
  final Value<String> contentText;
  final Value<String> yM;
  final Value<String> yMd;
  final Value<DateTime> time;
  final Value<DateTime> lastModified;
  final Value<bool> show;
  final Value<double> mood;
  final Value<List<String>> weather;
  final Value<List<String>> imageName;
  final Value<List<String>> audioName;
  final Value<List<String>> videoName;
  final Value<List<String>> tags;
  final Value<List<String>> position;
  final Value<List<String>> keywords;
  final Value<List<String>> tokenizer;
  final Value<String> type;
  final Value<int?> imageColor;
  final Value<double?> aspect;
  final Value<int> rowid;
  const DiariesCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.contentText = const Value.absent(),
    this.yM = const Value.absent(),
    this.yMd = const Value.absent(),
    this.time = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.show = const Value.absent(),
    this.mood = const Value.absent(),
    this.weather = const Value.absent(),
    this.imageName = const Value.absent(),
    this.audioName = const Value.absent(),
    this.videoName = const Value.absent(),
    this.tags = const Value.absent(),
    this.position = const Value.absent(),
    this.keywords = const Value.absent(),
    this.tokenizer = const Value.absent(),
    this.type = const Value.absent(),
    this.imageColor = const Value.absent(),
    this.aspect = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiariesCompanion.insert({
    required String id,
    this.categoryId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.contentText = const Value.absent(),
    this.yM = const Value.absent(),
    this.yMd = const Value.absent(),
    required DateTime time,
    required DateTime lastModified,
    this.show = const Value.absent(),
    this.mood = const Value.absent(),
    this.weather = const Value.absent(),
    this.imageName = const Value.absent(),
    this.audioName = const Value.absent(),
    this.videoName = const Value.absent(),
    this.tags = const Value.absent(),
    this.position = const Value.absent(),
    this.keywords = const Value.absent(),
    this.tokenizer = const Value.absent(),
    this.type = const Value.absent(),
    this.imageColor = const Value.absent(),
    this.aspect = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       time = Value(time),
       lastModified = Value(lastModified);
  static Insertable<DiaryRow> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? contentText,
    Expression<String>? yM,
    Expression<String>? yMd,
    Expression<DateTime>? time,
    Expression<DateTime>? lastModified,
    Expression<bool>? show,
    Expression<double>? mood,
    Expression<String>? weather,
    Expression<String>? imageName,
    Expression<String>? audioName,
    Expression<String>? videoName,
    Expression<String>? tags,
    Expression<String>? position,
    Expression<String>? keywords,
    Expression<String>? tokenizer,
    Expression<String>? type,
    Expression<int>? imageColor,
    Expression<double>? aspect,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (contentText != null) 'content_text': contentText,
      if (yM != null) 'y_m': yM,
      if (yMd != null) 'y_md': yMd,
      if (time != null) 'time': time,
      if (lastModified != null) 'last_modified': lastModified,
      if (show != null) 'show': show,
      if (mood != null) 'mood': mood,
      if (weather != null) 'weather': weather,
      if (imageName != null) 'image_name': imageName,
      if (audioName != null) 'audio_name': audioName,
      if (videoName != null) 'video_name': videoName,
      if (tags != null) 'tags': tags,
      if (position != null) 'position': position,
      if (keywords != null) 'keywords': keywords,
      if (tokenizer != null) 'tokenizer': tokenizer,
      if (type != null) 'type': type,
      if (imageColor != null) 'image_color': imageColor,
      if (aspect != null) 'aspect': aspect,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiariesCompanion copyWith({
    Value<String>? id,
    Value<String?>? categoryId,
    Value<String>? title,
    Value<String>? content,
    Value<String>? contentText,
    Value<String>? yM,
    Value<String>? yMd,
    Value<DateTime>? time,
    Value<DateTime>? lastModified,
    Value<bool>? show,
    Value<double>? mood,
    Value<List<String>>? weather,
    Value<List<String>>? imageName,
    Value<List<String>>? audioName,
    Value<List<String>>? videoName,
    Value<List<String>>? tags,
    Value<List<String>>? position,
    Value<List<String>>? keywords,
    Value<List<String>>? tokenizer,
    Value<String>? type,
    Value<int?>? imageColor,
    Value<double?>? aspect,
    Value<int>? rowid,
  }) {
    return DiariesCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      content: content ?? this.content,
      contentText: contentText ?? this.contentText,
      yM: yM ?? this.yM,
      yMd: yMd ?? this.yMd,
      time: time ?? this.time,
      lastModified: lastModified ?? this.lastModified,
      show: show ?? this.show,
      mood: mood ?? this.mood,
      weather: weather ?? this.weather,
      imageName: imageName ?? this.imageName,
      audioName: audioName ?? this.audioName,
      videoName: videoName ?? this.videoName,
      tags: tags ?? this.tags,
      position: position ?? this.position,
      keywords: keywords ?? this.keywords,
      tokenizer: tokenizer ?? this.tokenizer,
      type: type ?? this.type,
      imageColor: imageColor ?? this.imageColor,
      aspect: aspect ?? this.aspect,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (contentText.present) {
      map['content_text'] = Variable<String>(contentText.value);
    }
    if (yM.present) {
      map['y_m'] = Variable<String>(yM.value);
    }
    if (yMd.present) {
      map['y_md'] = Variable<String>(yMd.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (show.present) {
      map['show'] = Variable<bool>(show.value);
    }
    if (mood.present) {
      map['mood'] = Variable<double>(mood.value);
    }
    if (weather.present) {
      map['weather'] = Variable<String>(
        $DiariesTable.$converterweather.toSql(weather.value),
      );
    }
    if (imageName.present) {
      map['image_name'] = Variable<String>(
        $DiariesTable.$converterimageName.toSql(imageName.value),
      );
    }
    if (audioName.present) {
      map['audio_name'] = Variable<String>(
        $DiariesTable.$converteraudioName.toSql(audioName.value),
      );
    }
    if (videoName.present) {
      map['video_name'] = Variable<String>(
        $DiariesTable.$convertervideoName.toSql(videoName.value),
      );
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $DiariesTable.$convertertags.toSql(tags.value),
      );
    }
    if (position.present) {
      map['position'] = Variable<String>(
        $DiariesTable.$converterposition.toSql(position.value),
      );
    }
    if (keywords.present) {
      map['keywords'] = Variable<String>(
        $DiariesTable.$converterkeywords.toSql(keywords.value),
      );
    }
    if (tokenizer.present) {
      map['tokenizer'] = Variable<String>(
        $DiariesTable.$convertertokenizer.toSql(tokenizer.value),
      );
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (imageColor.present) {
      map['image_color'] = Variable<int>(imageColor.value);
    }
    if (aspect.present) {
      map['aspect'] = Variable<double>(aspect.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiariesCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentText: $contentText, ')
          ..write('yM: $yM, ')
          ..write('yMd: $yMd, ')
          ..write('time: $time, ')
          ..write('lastModified: $lastModified, ')
          ..write('show: $show, ')
          ..write('mood: $mood, ')
          ..write('weather: $weather, ')
          ..write('imageName: $imageName, ')
          ..write('audioName: $audioName, ')
          ..write('videoName: $videoName, ')
          ..write('tags: $tags, ')
          ..write('position: $position, ')
          ..write('keywords: $keywords, ')
          ..write('tokenizer: $tokenizer, ')
          ..write('type: $type, ')
          ..write('imageColor: $imageColor, ')
          ..write('aspect: $aspect, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryNameMeta = const VerificationMeta(
    'categoryName',
  );
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
    'category_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, categoryName, parentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_name')) {
      context.handle(
        _categoryNameMeta,
        categoryName.isAcceptableOrUnknown(
          data['category_name']!,
          _categoryNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryNameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String categoryName;
  final String? parentId;
  const CategoryRow({
    required this.id,
    required this.categoryName,
    this.parentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_name'] = Variable<String>(categoryName);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      categoryName: Value(categoryName),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      categoryName: serializer.fromJson<String>(json['categoryName']),
      parentId: serializer.fromJson<String?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryName': serializer.toJson<String>(categoryName),
      'parentId': serializer.toJson<String?>(parentId),
    };
  }

  CategoryRow copyWith({
    String? id,
    String? categoryName,
    Value<String?> parentId = const Value.absent(),
  }) => CategoryRow(
    id: id ?? this.id,
    categoryName: categoryName ?? this.categoryName,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      categoryName: data.categoryName.present
          ? data.categoryName.value
          : this.categoryName,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('categoryName: $categoryName, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoryName, parentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.categoryName == this.categoryName &&
          other.parentId == this.parentId);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> categoryName;
  final Value<String?> parentId;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.parentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String categoryName,
    this.parentId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryName = Value(categoryName);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? categoryName,
    Expression<String>? parentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryName != null) 'category_name': categoryName,
      if (parentId != null) 'parent_id': parentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryName,
    Value<String?>? parentId,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      parentId: parentId ?? this.parentId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('categoryName: $categoryName, ')
          ..write('parentId: $parentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FontsTable extends Fonts with TableInfo<$FontsTable, FontRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FontsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fontFileNameMeta = const VerificationMeta(
    'fontFileName',
  );
  @override
  late final GeneratedColumn<String> fontFileName = GeneratedColumn<String>(
    'font_file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  fontWghtAxisMap = GeneratedColumn<String>(
    'font_wght_axis_map',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  ).withConverter<Map<String, dynamic>>($FontsTable.$converterfontWghtAxisMap);
  @override
  List<GeneratedColumn> get $columns => [fontFileName, fontWghtAxisMap];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fonts';
  @override
  VerificationContext validateIntegrity(
    Insertable<FontRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('font_file_name')) {
      context.handle(
        _fontFileNameMeta,
        fontFileName.isAcceptableOrUnknown(
          data['font_file_name']!,
          _fontFileNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fontFileNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fontFileName};
  @override
  FontRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FontRow(
      fontFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}font_file_name'],
      )!,
      fontWghtAxisMap: $FontsTable.$converterfontWghtAxisMap.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}font_wght_axis_map'],
        )!,
      ),
    );
  }

  @override
  $FontsTable createAlias(String alias) {
    return $FontsTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, dynamic>, String> $converterfontWghtAxisMap =
      const MapConverter();
}

class FontRow extends DataClass implements Insertable<FontRow> {
  final String fontFileName;
  final Map<String, dynamic> fontWghtAxisMap;
  const FontRow({required this.fontFileName, required this.fontWghtAxisMap});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['font_file_name'] = Variable<String>(fontFileName);
    {
      map['font_wght_axis_map'] = Variable<String>(
        $FontsTable.$converterfontWghtAxisMap.toSql(fontWghtAxisMap),
      );
    }
    return map;
  }

  FontsCompanion toCompanion(bool nullToAbsent) {
    return FontsCompanion(
      fontFileName: Value(fontFileName),
      fontWghtAxisMap: Value(fontWghtAxisMap),
    );
  }

  factory FontRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FontRow(
      fontFileName: serializer.fromJson<String>(json['fontFileName']),
      fontWghtAxisMap: serializer.fromJson<Map<String, dynamic>>(
        json['fontWghtAxisMap'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fontFileName': serializer.toJson<String>(fontFileName),
      'fontWghtAxisMap': serializer.toJson<Map<String, dynamic>>(
        fontWghtAxisMap,
      ),
    };
  }

  FontRow copyWith({
    String? fontFileName,
    Map<String, dynamic>? fontWghtAxisMap,
  }) => FontRow(
    fontFileName: fontFileName ?? this.fontFileName,
    fontWghtAxisMap: fontWghtAxisMap ?? this.fontWghtAxisMap,
  );
  FontRow copyWithCompanion(FontsCompanion data) {
    return FontRow(
      fontFileName: data.fontFileName.present
          ? data.fontFileName.value
          : this.fontFileName,
      fontWghtAxisMap: data.fontWghtAxisMap.present
          ? data.fontWghtAxisMap.value
          : this.fontWghtAxisMap,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FontRow(')
          ..write('fontFileName: $fontFileName, ')
          ..write('fontWghtAxisMap: $fontWghtAxisMap')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fontFileName, fontWghtAxisMap);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FontRow &&
          other.fontFileName == this.fontFileName &&
          other.fontWghtAxisMap == this.fontWghtAxisMap);
}

class FontsCompanion extends UpdateCompanion<FontRow> {
  final Value<String> fontFileName;
  final Value<Map<String, dynamic>> fontWghtAxisMap;
  final Value<int> rowid;
  const FontsCompanion({
    this.fontFileName = const Value.absent(),
    this.fontWghtAxisMap = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FontsCompanion.insert({
    required String fontFileName,
    this.fontWghtAxisMap = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fontFileName = Value(fontFileName);
  static Insertable<FontRow> custom({
    Expression<String>? fontFileName,
    Expression<String>? fontWghtAxisMap,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fontFileName != null) 'font_file_name': fontFileName,
      if (fontWghtAxisMap != null) 'font_wght_axis_map': fontWghtAxisMap,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FontsCompanion copyWith({
    Value<String>? fontFileName,
    Value<Map<String, dynamic>>? fontWghtAxisMap,
    Value<int>? rowid,
  }) {
    return FontsCompanion(
      fontFileName: fontFileName ?? this.fontFileName,
      fontWghtAxisMap: fontWghtAxisMap ?? this.fontWghtAxisMap,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fontFileName.present) {
      map['font_file_name'] = Variable<String>(fontFileName.value);
    }
    if (fontWghtAxisMap.present) {
      map['font_wght_axis_map'] = Variable<String>(
        $FontsTable.$converterfontWghtAxisMap.toSql(fontWghtAxisMap.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FontsCompanion(')
          ..write('fontFileName: $fontFileName, ')
          ..write('fontWghtAxisMap: $fontWghtAxisMap, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlocksTable extends Blocks with TableInfo<$BlocksTable, BlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  @override
  late final GeneratedColumn<String> diaryId = GeneratedColumn<String>(
    'diary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockTypeMeta = const VerificationMeta(
    'blockType',
  );
  @override
  late final GeneratedColumn<int> blockType = GeneratedColumn<int>(
    'block_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _streamBufferMeta = const VerificationMeta(
    'streamBuffer',
  );
  @override
  late final GeneratedColumn<String> streamBuffer = GeneratedColumn<String>(
    'stream_buffer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _streamCompleteMeta = const VerificationMeta(
    'streamComplete',
  );
  @override
  late final GeneratedColumn<bool> streamComplete = GeneratedColumn<bool>(
    'stream_complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("stream_complete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    diaryId,
    blockType,
    content,
    sortOrder,
    isDeleted,
    streamBuffer,
    streamComplete,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryIdMeta);
    }
    if (data.containsKey('block_type')) {
      context.handle(
        _blockTypeMeta,
        blockType.isAcceptableOrUnknown(data['block_type']!, _blockTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_blockTypeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('stream_buffer')) {
      context.handle(
        _streamBufferMeta,
        streamBuffer.isAcceptableOrUnknown(
          data['stream_buffer']!,
          _streamBufferMeta,
        ),
      );
    }
    if (data.containsKey('stream_complete')) {
      context.handle(
        _streamCompleteMeta,
        streamComplete.isAcceptableOrUnknown(
          data['stream_complete']!,
          _streamCompleteMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_id'],
      )!,
      blockType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}block_type'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      streamBuffer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_buffer'],
      )!,
      streamComplete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}stream_complete'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BlocksTable createAlias(String alias) {
    return $BlocksTable(attachedDatabase, alias);
  }
}

class BlockRow extends DataClass implements Insertable<BlockRow> {
  final String id;
  final String diaryId;
  final int blockType;
  final String content;
  final int sortOrder;
  final bool isDeleted;
  final String streamBuffer;
  final bool streamComplete;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BlockRow({
    required this.id,
    required this.diaryId,
    required this.blockType,
    required this.content,
    required this.sortOrder,
    required this.isDeleted,
    required this.streamBuffer,
    required this.streamComplete,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['diary_id'] = Variable<String>(diaryId);
    map['block_type'] = Variable<int>(blockType);
    map['content'] = Variable<String>(content);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['stream_buffer'] = Variable<String>(streamBuffer);
    map['stream_complete'] = Variable<bool>(streamComplete);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BlocksCompanion toCompanion(bool nullToAbsent) {
    return BlocksCompanion(
      id: Value(id),
      diaryId: Value(diaryId),
      blockType: Value(blockType),
      content: Value(content),
      sortOrder: Value(sortOrder),
      isDeleted: Value(isDeleted),
      streamBuffer: Value(streamBuffer),
      streamComplete: Value(streamComplete),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockRow(
      id: serializer.fromJson<String>(json['id']),
      diaryId: serializer.fromJson<String>(json['diaryId']),
      blockType: serializer.fromJson<int>(json['blockType']),
      content: serializer.fromJson<String>(json['content']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      streamBuffer: serializer.fromJson<String>(json['streamBuffer']),
      streamComplete: serializer.fromJson<bool>(json['streamComplete']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'diaryId': serializer.toJson<String>(diaryId),
      'blockType': serializer.toJson<int>(blockType),
      'content': serializer.toJson<String>(content),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'streamBuffer': serializer.toJson<String>(streamBuffer),
      'streamComplete': serializer.toJson<bool>(streamComplete),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BlockRow copyWith({
    String? id,
    String? diaryId,
    int? blockType,
    String? content,
    int? sortOrder,
    bool? isDeleted,
    String? streamBuffer,
    bool? streamComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BlockRow(
    id: id ?? this.id,
    diaryId: diaryId ?? this.diaryId,
    blockType: blockType ?? this.blockType,
    content: content ?? this.content,
    sortOrder: sortOrder ?? this.sortOrder,
    isDeleted: isDeleted ?? this.isDeleted,
    streamBuffer: streamBuffer ?? this.streamBuffer,
    streamComplete: streamComplete ?? this.streamComplete,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BlockRow copyWithCompanion(BlocksCompanion data) {
    return BlockRow(
      id: data.id.present ? data.id.value : this.id,
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      blockType: data.blockType.present ? data.blockType.value : this.blockType,
      content: data.content.present ? data.content.value : this.content,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      streamBuffer: data.streamBuffer.present
          ? data.streamBuffer.value
          : this.streamBuffer,
      streamComplete: data.streamComplete.present
          ? data.streamComplete.value
          : this.streamComplete,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockRow(')
          ..write('id: $id, ')
          ..write('diaryId: $diaryId, ')
          ..write('blockType: $blockType, ')
          ..write('content: $content, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('streamBuffer: $streamBuffer, ')
          ..write('streamComplete: $streamComplete, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    diaryId,
    blockType,
    content,
    sortOrder,
    isDeleted,
    streamBuffer,
    streamComplete,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockRow &&
          other.id == this.id &&
          other.diaryId == this.diaryId &&
          other.blockType == this.blockType &&
          other.content == this.content &&
          other.sortOrder == this.sortOrder &&
          other.isDeleted == this.isDeleted &&
          other.streamBuffer == this.streamBuffer &&
          other.streamComplete == this.streamComplete &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BlocksCompanion extends UpdateCompanion<BlockRow> {
  final Value<String> id;
  final Value<String> diaryId;
  final Value<int> blockType;
  final Value<String> content;
  final Value<int> sortOrder;
  final Value<bool> isDeleted;
  final Value<String> streamBuffer;
  final Value<bool> streamComplete;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BlocksCompanion({
    this.id = const Value.absent(),
    this.diaryId = const Value.absent(),
    this.blockType = const Value.absent(),
    this.content = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.streamBuffer = const Value.absent(),
    this.streamComplete = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlocksCompanion.insert({
    required String id,
    required String diaryId,
    required int blockType,
    this.content = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.streamBuffer = const Value.absent(),
    this.streamComplete = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       diaryId = Value(diaryId),
       blockType = Value(blockType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BlockRow> custom({
    Expression<String>? id,
    Expression<String>? diaryId,
    Expression<int>? blockType,
    Expression<String>? content,
    Expression<int>? sortOrder,
    Expression<bool>? isDeleted,
    Expression<String>? streamBuffer,
    Expression<bool>? streamComplete,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (diaryId != null) 'diary_id': diaryId,
      if (blockType != null) 'block_type': blockType,
      if (content != null) 'content': content,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (streamBuffer != null) 'stream_buffer': streamBuffer,
      if (streamComplete != null) 'stream_complete': streamComplete,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? diaryId,
    Value<int>? blockType,
    Value<String>? content,
    Value<int>? sortOrder,
    Value<bool>? isDeleted,
    Value<String>? streamBuffer,
    Value<bool>? streamComplete,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BlocksCompanion(
      id: id ?? this.id,
      diaryId: diaryId ?? this.diaryId,
      blockType: blockType ?? this.blockType,
      content: content ?? this.content,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      streamBuffer: streamBuffer ?? this.streamBuffer,
      streamComplete: streamComplete ?? this.streamComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (diaryId.present) {
      map['diary_id'] = Variable<String>(diaryId.value);
    }
    if (blockType.present) {
      map['block_type'] = Variable<int>(blockType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (streamBuffer.present) {
      map['stream_buffer'] = Variable<String>(streamBuffer.value);
    }
    if (streamComplete.present) {
      map['stream_complete'] = Variable<bool>(streamComplete.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocksCompanion(')
          ..write('id: $id, ')
          ..write('diaryId: $diaryId, ')
          ..write('blockType: $blockType, ')
          ..write('content: $content, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('streamBuffer: $streamBuffer, ')
          ..write('streamComplete: $streamComplete, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppMetadataTable extends AppMetadata
    with TableInfo<$AppMetadataTable, AppMetadataRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetadataRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetadataRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetadataRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetadataTable createAlias(String alias) {
    return $AppMetadataTable(attachedDatabase, alias);
  }
}

class AppMetadataRow extends DataClass implements Insertable<AppMetadataRow> {
  final String key;
  final String value;
  const AppMetadataRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetadataCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetadataRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetadataRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetadataRow copyWith({String? key, String? value}) =>
      AppMetadataRow(key: key ?? this.key, value: value ?? this.value);
  AppMetadataRow copyWithCompanion(AppMetadataCompanion data) {
    return AppMetadataRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetadataRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetadataCompanion extends UpdateCompanion<AppMetadataRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetadataRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CrmEntityCachesTable extends CrmEntityCaches
    with TableInfo<$CrmEntityCachesTable, CrmEntityCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrmEntityCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _twentyIdMeta = const VerificationMeta(
    'twentyId',
  );
  @override
  late final GeneratedColumn<String> twentyId = GeneratedColumn<String>(
    'twenty_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    twentyId,
    entityType,
    name,
    dataJson,
    isDeleted,
    localVersion,
    lastSyncedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'crm_entity_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrmEntityCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('twenty_id')) {
      context.handle(
        _twentyIdMeta,
        twentyId.isAcceptableOrUnknown(data['twenty_id']!, _twentyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_twentyIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CrmEntityCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrmEntityCacheRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      twentyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}twenty_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CrmEntityCachesTable createAlias(String alias) {
    return $CrmEntityCachesTable(attachedDatabase, alias);
  }
}

class CrmEntityCacheRow extends DataClass
    implements Insertable<CrmEntityCacheRow> {
  final String id;
  final String twentyId;
  final String entityType;
  final String name;
  final String dataJson;
  final bool isDeleted;
  final int localVersion;
  final DateTime lastSyncedAt;
  final DateTime updatedAt;
  const CrmEntityCacheRow({
    required this.id,
    required this.twentyId,
    required this.entityType,
    required this.name,
    required this.dataJson,
    required this.isDeleted,
    required this.localVersion,
    required this.lastSyncedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['twenty_id'] = Variable<String>(twentyId);
    map['entity_type'] = Variable<String>(entityType);
    map['name'] = Variable<String>(name);
    map['data_json'] = Variable<String>(dataJson);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['local_version'] = Variable<int>(localVersion);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CrmEntityCachesCompanion toCompanion(bool nullToAbsent) {
    return CrmEntityCachesCompanion(
      id: Value(id),
      twentyId: Value(twentyId),
      entityType: Value(entityType),
      name: Value(name),
      dataJson: Value(dataJson),
      isDeleted: Value(isDeleted),
      localVersion: Value(localVersion),
      lastSyncedAt: Value(lastSyncedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CrmEntityCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrmEntityCacheRow(
      id: serializer.fromJson<String>(json['id']),
      twentyId: serializer.fromJson<String>(json['twentyId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      name: serializer.fromJson<String>(json['name']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'twentyId': serializer.toJson<String>(twentyId),
      'entityType': serializer.toJson<String>(entityType),
      'name': serializer.toJson<String>(name),
      'dataJson': serializer.toJson<String>(dataJson),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'localVersion': serializer.toJson<int>(localVersion),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CrmEntityCacheRow copyWith({
    String? id,
    String? twentyId,
    String? entityType,
    String? name,
    String? dataJson,
    bool? isDeleted,
    int? localVersion,
    DateTime? lastSyncedAt,
    DateTime? updatedAt,
  }) => CrmEntityCacheRow(
    id: id ?? this.id,
    twentyId: twentyId ?? this.twentyId,
    entityType: entityType ?? this.entityType,
    name: name ?? this.name,
    dataJson: dataJson ?? this.dataJson,
    isDeleted: isDeleted ?? this.isDeleted,
    localVersion: localVersion ?? this.localVersion,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CrmEntityCacheRow copyWithCompanion(CrmEntityCachesCompanion data) {
    return CrmEntityCacheRow(
      id: data.id.present ? data.id.value : this.id,
      twentyId: data.twentyId.present ? data.twentyId.value : this.twentyId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      name: data.name.present ? data.name.value : this.name,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrmEntityCacheRow(')
          ..write('id: $id, ')
          ..write('twentyId: $twentyId, ')
          ..write('entityType: $entityType, ')
          ..write('name: $name, ')
          ..write('dataJson: $dataJson, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('localVersion: $localVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    twentyId,
    entityType,
    name,
    dataJson,
    isDeleted,
    localVersion,
    lastSyncedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrmEntityCacheRow &&
          other.id == this.id &&
          other.twentyId == this.twentyId &&
          other.entityType == this.entityType &&
          other.name == this.name &&
          other.dataJson == this.dataJson &&
          other.isDeleted == this.isDeleted &&
          other.localVersion == this.localVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.updatedAt == this.updatedAt);
}

class CrmEntityCachesCompanion extends UpdateCompanion<CrmEntityCacheRow> {
  final Value<String> id;
  final Value<String> twentyId;
  final Value<String> entityType;
  final Value<String> name;
  final Value<String> dataJson;
  final Value<bool> isDeleted;
  final Value<int> localVersion;
  final Value<DateTime> lastSyncedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CrmEntityCachesCompanion({
    this.id = const Value.absent(),
    this.twentyId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.name = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CrmEntityCachesCompanion.insert({
    required String id,
    required String twentyId,
    required String entityType,
    this.name = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.localVersion = const Value.absent(),
    required DateTime lastSyncedAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       twentyId = Value(twentyId),
       entityType = Value(entityType),
       lastSyncedAt = Value(lastSyncedAt),
       updatedAt = Value(updatedAt);
  static Insertable<CrmEntityCacheRow> custom({
    Expression<String>? id,
    Expression<String>? twentyId,
    Expression<String>? entityType,
    Expression<String>? name,
    Expression<String>? dataJson,
    Expression<bool>? isDeleted,
    Expression<int>? localVersion,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (twentyId != null) 'twenty_id': twentyId,
      if (entityType != null) 'entity_type': entityType,
      if (name != null) 'name': name,
      if (dataJson != null) 'data_json': dataJson,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (localVersion != null) 'local_version': localVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CrmEntityCachesCompanion copyWith({
    Value<String>? id,
    Value<String>? twentyId,
    Value<String>? entityType,
    Value<String>? name,
    Value<String>? dataJson,
    Value<bool>? isDeleted,
    Value<int>? localVersion,
    Value<DateTime>? lastSyncedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CrmEntityCachesCompanion(
      id: id ?? this.id,
      twentyId: twentyId ?? this.twentyId,
      entityType: entityType ?? this.entityType,
      name: name ?? this.name,
      dataJson: dataJson ?? this.dataJson,
      isDeleted: isDeleted ?? this.isDeleted,
      localVersion: localVersion ?? this.localVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (twentyId.present) {
      map['twenty_id'] = Variable<String>(twentyId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrmEntityCachesCompanion(')
          ..write('id: $id, ')
          ..write('twentyId: $twentyId, ')
          ..write('entityType: $entityType, ')
          ..write('name: $name, ')
          ..write('dataJson: $dataJson, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('localVersion: $localVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRecordsTable extends SyncRecords
    with TableInfo<$SyncRecordsTable, SyncRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  @override
  late final GeneratedColumn<String> diaryId = GeneratedColumn<String>(
    'diary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diaryJsonMeta = const VerificationMeta(
    'diaryJson',
  );
  @override
  late final GeneratedColumn<String> diaryJson = GeneratedColumn<String>(
    'diary_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncTypeMeta = const VerificationMeta(
    'syncType',
  );
  @override
  late final GeneratedColumn<int> syncType = GeneratedColumn<int>(
    'sync_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    syncId,
    diaryId,
    diaryJson,
    time,
    syncType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryIdMeta);
    }
    if (data.containsKey('diary_json')) {
      context.handle(
        _diaryJsonMeta,
        diaryJson.isAcceptableOrUnknown(data['diary_json']!, _diaryJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryJsonMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('sync_type')) {
      context.handle(
        _syncTypeMeta,
        syncType.isAcceptableOrUnknown(data['sync_type']!, _syncTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_syncTypeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncId};
  @override
  SyncRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecordRow(
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      )!,
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_id'],
      )!,
      diaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_json'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}time'],
      )!,
      syncType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_type'],
      )!,
    );
  }

  @override
  $SyncRecordsTable createAlias(String alias) {
    return $SyncRecordsTable(attachedDatabase, alias);
  }
}

class SyncRecordRow extends DataClass implements Insertable<SyncRecordRow> {
  final String syncId;
  final String diaryId;
  final String diaryJson;
  final DateTime time;
  final int syncType;
  const SyncRecordRow({
    required this.syncId,
    required this.diaryId,
    required this.diaryJson,
    required this.time,
    required this.syncType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_id'] = Variable<String>(syncId);
    map['diary_id'] = Variable<String>(diaryId);
    map['diary_json'] = Variable<String>(diaryJson);
    map['time'] = Variable<DateTime>(time);
    map['sync_type'] = Variable<int>(syncType);
    return map;
  }

  SyncRecordsCompanion toCompanion(bool nullToAbsent) {
    return SyncRecordsCompanion(
      syncId: Value(syncId),
      diaryId: Value(diaryId),
      diaryJson: Value(diaryJson),
      time: Value(time),
      syncType: Value(syncType),
    );
  }

  factory SyncRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRecordRow(
      syncId: serializer.fromJson<String>(json['syncId']),
      diaryId: serializer.fromJson<String>(json['diaryId']),
      diaryJson: serializer.fromJson<String>(json['diaryJson']),
      time: serializer.fromJson<DateTime>(json['time']),
      syncType: serializer.fromJson<int>(json['syncType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncId': serializer.toJson<String>(syncId),
      'diaryId': serializer.toJson<String>(diaryId),
      'diaryJson': serializer.toJson<String>(diaryJson),
      'time': serializer.toJson<DateTime>(time),
      'syncType': serializer.toJson<int>(syncType),
    };
  }

  SyncRecordRow copyWith({
    String? syncId,
    String? diaryId,
    String? diaryJson,
    DateTime? time,
    int? syncType,
  }) => SyncRecordRow(
    syncId: syncId ?? this.syncId,
    diaryId: diaryId ?? this.diaryId,
    diaryJson: diaryJson ?? this.diaryJson,
    time: time ?? this.time,
    syncType: syncType ?? this.syncType,
  );
  SyncRecordRow copyWithCompanion(SyncRecordsCompanion data) {
    return SyncRecordRow(
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      diaryJson: data.diaryJson.present ? data.diaryJson.value : this.diaryJson,
      time: data.time.present ? data.time.value : this.time,
      syncType: data.syncType.present ? data.syncType.value : this.syncType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordRow(')
          ..write('syncId: $syncId, ')
          ..write('diaryId: $diaryId, ')
          ..write('diaryJson: $diaryJson, ')
          ..write('time: $time, ')
          ..write('syncType: $syncType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncId, diaryId, diaryJson, time, syncType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRecordRow &&
          other.syncId == this.syncId &&
          other.diaryId == this.diaryId &&
          other.diaryJson == this.diaryJson &&
          other.time == this.time &&
          other.syncType == this.syncType);
}

class SyncRecordsCompanion extends UpdateCompanion<SyncRecordRow> {
  final Value<String> syncId;
  final Value<String> diaryId;
  final Value<String> diaryJson;
  final Value<DateTime> time;
  final Value<int> syncType;
  final Value<int> rowid;
  const SyncRecordsCompanion({
    this.syncId = const Value.absent(),
    this.diaryId = const Value.absent(),
    this.diaryJson = const Value.absent(),
    this.time = const Value.absent(),
    this.syncType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRecordsCompanion.insert({
    required String syncId,
    required String diaryId,
    required String diaryJson,
    required DateTime time,
    required int syncType,
    this.rowid = const Value.absent(),
  }) : syncId = Value(syncId),
       diaryId = Value(diaryId),
       diaryJson = Value(diaryJson),
       time = Value(time),
       syncType = Value(syncType);
  static Insertable<SyncRecordRow> custom({
    Expression<String>? syncId,
    Expression<String>? diaryId,
    Expression<String>? diaryJson,
    Expression<DateTime>? time,
    Expression<int>? syncType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncId != null) 'sync_id': syncId,
      if (diaryId != null) 'diary_id': diaryId,
      if (diaryJson != null) 'diary_json': diaryJson,
      if (time != null) 'time': time,
      if (syncType != null) 'sync_type': syncType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRecordsCompanion copyWith({
    Value<String>? syncId,
    Value<String>? diaryId,
    Value<String>? diaryJson,
    Value<DateTime>? time,
    Value<int>? syncType,
    Value<int>? rowid,
  }) {
    return SyncRecordsCompanion(
      syncId: syncId ?? this.syncId,
      diaryId: diaryId ?? this.diaryId,
      diaryJson: diaryJson ?? this.diaryJson,
      time: time ?? this.time,
      syncType: syncType ?? this.syncType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (diaryId.present) {
      map['diary_id'] = Variable<String>(diaryId.value);
    }
    if (diaryJson.present) {
      map['diary_json'] = Variable<String>(diaryJson.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (syncType.present) {
      map['sync_type'] = Variable<int>(syncType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordsCompanion(')
          ..write('syncId: $syncId, ')
          ..write('diaryId: $diaryId, ')
          ..write('diaryJson: $diaryJson, ')
          ..write('time: $time, ')
          ..write('syncType: $syncType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DiariesTable diaries = $DiariesTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $FontsTable fonts = $FontsTable(this);
  late final $BlocksTable blocks = $BlocksTable(this);
  late final $AppMetadataTable appMetadata = $AppMetadataTable(this);
  late final $CrmEntityCachesTable crmEntityCaches = $CrmEntityCachesTable(
    this,
  );
  late final $SyncRecordsTable syncRecords = $SyncRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    diaries,
    categories,
    fonts,
    blocks,
    appMetadata,
    crmEntityCaches,
    syncRecords,
  ];
}

typedef $$DiariesTableCreateCompanionBuilder =
    DiariesCompanion Function({
      required String id,
      Value<String?> categoryId,
      Value<String> title,
      Value<String> content,
      Value<String> contentText,
      Value<String> yM,
      Value<String> yMd,
      required DateTime time,
      required DateTime lastModified,
      Value<bool> show,
      Value<double> mood,
      Value<List<String>> weather,
      Value<List<String>> imageName,
      Value<List<String>> audioName,
      Value<List<String>> videoName,
      Value<List<String>> tags,
      Value<List<String>> position,
      Value<List<String>> keywords,
      Value<List<String>> tokenizer,
      Value<String> type,
      Value<int?> imageColor,
      Value<double?> aspect,
      Value<int> rowid,
    });
typedef $$DiariesTableUpdateCompanionBuilder =
    DiariesCompanion Function({
      Value<String> id,
      Value<String?> categoryId,
      Value<String> title,
      Value<String> content,
      Value<String> contentText,
      Value<String> yM,
      Value<String> yMd,
      Value<DateTime> time,
      Value<DateTime> lastModified,
      Value<bool> show,
      Value<double> mood,
      Value<List<String>> weather,
      Value<List<String>> imageName,
      Value<List<String>> audioName,
      Value<List<String>> videoName,
      Value<List<String>> tags,
      Value<List<String>> position,
      Value<List<String>> keywords,
      Value<List<String>> tokenizer,
      Value<String> type,
      Value<int?> imageColor,
      Value<double?> aspect,
      Value<int> rowid,
    });

class $$DiariesTableFilterComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get yM => $composableBuilder(
    column: $table.yM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get yMd => $composableBuilder(
    column: $table.yMd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get show => $composableBuilder(
    column: $table.show,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get imageName => $composableBuilder(
    column: $table.imageName,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get audioName => $composableBuilder(
    column: $table.audioName,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get videoName => $composableBuilder(
    column: $table.videoName,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
        column: $table.tags,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get tokenizer => $composableBuilder(
    column: $table.tokenizer,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageColor => $composableBuilder(
    column: $table.imageColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aspect => $composableBuilder(
    column: $table.aspect,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiariesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get yM => $composableBuilder(
    column: $table.yM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get yMd => $composableBuilder(
    column: $table.yMd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get show => $composableBuilder(
    column: $table.show,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageName => $composableBuilder(
    column: $table.imageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioName => $composableBuilder(
    column: $table.audioName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoName => $composableBuilder(
    column: $table.videoName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenizer => $composableBuilder(
    column: $table.tokenizer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageColor => $composableBuilder(
    column: $table.imageColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aspect => $composableBuilder(
    column: $table.aspect,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get yM =>
      $composableBuilder(column: $table.yM, builder: (column) => column);

  GeneratedColumn<String> get yMd =>
      $composableBuilder(column: $table.yMd, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get show =>
      $composableBuilder(column: $table.show, builder: (column) => column);

  GeneratedColumn<double> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get weather =>
      $composableBuilder(column: $table.weather, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get imageName =>
      $composableBuilder(column: $table.imageName, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get audioName =>
      $composableBuilder(column: $table.audioName, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get videoName =>
      $composableBuilder(column: $table.videoName, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get keywords =>
      $composableBuilder(column: $table.keywords, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tokenizer =>
      $composableBuilder(column: $table.tokenizer, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get imageColor => $composableBuilder(
    column: $table.imageColor,
    builder: (column) => column,
  );

  GeneratedColumn<double> get aspect =>
      $composableBuilder(column: $table.aspect, builder: (column) => column);
}

class $$DiariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiariesTable,
          DiaryRow,
          $$DiariesTableFilterComposer,
          $$DiariesTableOrderingComposer,
          $$DiariesTableAnnotationComposer,
          $$DiariesTableCreateCompanionBuilder,
          $$DiariesTableUpdateCompanionBuilder,
          (DiaryRow, BaseReferences<_$AppDatabase, $DiariesTable, DiaryRow>),
          DiaryRow,
          PrefetchHooks Function()
        > {
  $$DiariesTableTableManager(_$AppDatabase db, $DiariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> contentText = const Value.absent(),
                Value<String> yM = const Value.absent(),
                Value<String> yMd = const Value.absent(),
                Value<DateTime> time = const Value.absent(),
                Value<DateTime> lastModified = const Value.absent(),
                Value<bool> show = const Value.absent(),
                Value<double> mood = const Value.absent(),
                Value<List<String>> weather = const Value.absent(),
                Value<List<String>> imageName = const Value.absent(),
                Value<List<String>> audioName = const Value.absent(),
                Value<List<String>> videoName = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<List<String>> position = const Value.absent(),
                Value<List<String>> keywords = const Value.absent(),
                Value<List<String>> tokenizer = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> imageColor = const Value.absent(),
                Value<double?> aspect = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiariesCompanion(
                id: id,
                categoryId: categoryId,
                title: title,
                content: content,
                contentText: contentText,
                yM: yM,
                yMd: yMd,
                time: time,
                lastModified: lastModified,
                show: show,
                mood: mood,
                weather: weather,
                imageName: imageName,
                audioName: audioName,
                videoName: videoName,
                tags: tags,
                position: position,
                keywords: keywords,
                tokenizer: tokenizer,
                type: type,
                imageColor: imageColor,
                aspect: aspect,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> categoryId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> contentText = const Value.absent(),
                Value<String> yM = const Value.absent(),
                Value<String> yMd = const Value.absent(),
                required DateTime time,
                required DateTime lastModified,
                Value<bool> show = const Value.absent(),
                Value<double> mood = const Value.absent(),
                Value<List<String>> weather = const Value.absent(),
                Value<List<String>> imageName = const Value.absent(),
                Value<List<String>> audioName = const Value.absent(),
                Value<List<String>> videoName = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<List<String>> position = const Value.absent(),
                Value<List<String>> keywords = const Value.absent(),
                Value<List<String>> tokenizer = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int?> imageColor = const Value.absent(),
                Value<double?> aspect = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiariesCompanion.insert(
                id: id,
                categoryId: categoryId,
                title: title,
                content: content,
                contentText: contentText,
                yM: yM,
                yMd: yMd,
                time: time,
                lastModified: lastModified,
                show: show,
                mood: mood,
                weather: weather,
                imageName: imageName,
                audioName: audioName,
                videoName: videoName,
                tags: tags,
                position: position,
                keywords: keywords,
                tokenizer: tokenizer,
                type: type,
                imageColor: imageColor,
                aspect: aspect,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiariesTable,
      DiaryRow,
      $$DiariesTableFilterComposer,
      $$DiariesTableOrderingComposer,
      $$DiariesTableAnnotationComposer,
      $$DiariesTableCreateCompanionBuilder,
      $$DiariesTableUpdateCompanionBuilder,
      (DiaryRow, BaseReferences<_$AppDatabase, $DiariesTable, DiaryRow>),
      DiaryRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      required String categoryName,
      Value<String?> parentId,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> categoryName,
      Value<String?> parentId,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryName = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                categoryName: categoryName,
                parentId: parentId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryName,
                Value<String?> parentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                categoryName: categoryName,
                parentId: parentId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $$FontsTableCreateCompanionBuilder =
    FontsCompanion Function({
      required String fontFileName,
      Value<Map<String, dynamic>> fontWghtAxisMap,
      Value<int> rowid,
    });
typedef $$FontsTableUpdateCompanionBuilder =
    FontsCompanion Function({
      Value<String> fontFileName,
      Value<Map<String, dynamic>> fontWghtAxisMap,
      Value<int> rowid,
    });

class $$FontsTableFilterComposer extends Composer<_$AppDatabase, $FontsTable> {
  $$FontsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fontFileName => $composableBuilder(
    column: $table.fontFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, dynamic>,
    Map<String, dynamic>,
    String
  >
  get fontWghtAxisMap => $composableBuilder(
    column: $table.fontWghtAxisMap,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$FontsTableOrderingComposer
    extends Composer<_$AppDatabase, $FontsTable> {
  $$FontsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fontFileName => $composableBuilder(
    column: $table.fontFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fontWghtAxisMap => $composableBuilder(
    column: $table.fontWghtAxisMap,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FontsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FontsTable> {
  $$FontsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fontFileName => $composableBuilder(
    column: $table.fontFileName,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  get fontWghtAxisMap => $composableBuilder(
    column: $table.fontWghtAxisMap,
    builder: (column) => column,
  );
}

class $$FontsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FontsTable,
          FontRow,
          $$FontsTableFilterComposer,
          $$FontsTableOrderingComposer,
          $$FontsTableAnnotationComposer,
          $$FontsTableCreateCompanionBuilder,
          $$FontsTableUpdateCompanionBuilder,
          (FontRow, BaseReferences<_$AppDatabase, $FontsTable, FontRow>),
          FontRow,
          PrefetchHooks Function()
        > {
  $$FontsTableTableManager(_$AppDatabase db, $FontsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FontsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FontsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FontsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fontFileName = const Value.absent(),
                Value<Map<String, dynamic>> fontWghtAxisMap =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FontsCompanion(
                fontFileName: fontFileName,
                fontWghtAxisMap: fontWghtAxisMap,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fontFileName,
                Value<Map<String, dynamic>> fontWghtAxisMap =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FontsCompanion.insert(
                fontFileName: fontFileName,
                fontWghtAxisMap: fontWghtAxisMap,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FontsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FontsTable,
      FontRow,
      $$FontsTableFilterComposer,
      $$FontsTableOrderingComposer,
      $$FontsTableAnnotationComposer,
      $$FontsTableCreateCompanionBuilder,
      $$FontsTableUpdateCompanionBuilder,
      (FontRow, BaseReferences<_$AppDatabase, $FontsTable, FontRow>),
      FontRow,
      PrefetchHooks Function()
    >;
typedef $$BlocksTableCreateCompanionBuilder =
    BlocksCompanion Function({
      required String id,
      required String diaryId,
      required int blockType,
      Value<String> content,
      Value<int> sortOrder,
      Value<bool> isDeleted,
      Value<String> streamBuffer,
      Value<bool> streamComplete,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BlocksTableUpdateCompanionBuilder =
    BlocksCompanion Function({
      Value<String> id,
      Value<String> diaryId,
      Value<int> blockType,
      Value<String> content,
      Value<int> sortOrder,
      Value<bool> isDeleted,
      Value<String> streamBuffer,
      Value<bool> streamComplete,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BlocksTableFilterComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blockType => $composableBuilder(
    column: $table.blockType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamBuffer => $composableBuilder(
    column: $table.streamBuffer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get streamComplete => $composableBuilder(
    column: $table.streamComplete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blockType => $composableBuilder(
    column: $table.blockType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamBuffer => $composableBuilder(
    column: $table.streamBuffer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get streamComplete => $composableBuilder(
    column: $table.streamComplete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get diaryId =>
      $composableBuilder(column: $table.diaryId, builder: (column) => column);

  GeneratedColumn<int> get blockType =>
      $composableBuilder(column: $table.blockType, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get streamBuffer => $composableBuilder(
    column: $table.streamBuffer,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get streamComplete => $composableBuilder(
    column: $table.streamComplete,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlocksTable,
          BlockRow,
          $$BlocksTableFilterComposer,
          $$BlocksTableOrderingComposer,
          $$BlocksTableAnnotationComposer,
          $$BlocksTableCreateCompanionBuilder,
          $$BlocksTableUpdateCompanionBuilder,
          (BlockRow, BaseReferences<_$AppDatabase, $BlocksTable, BlockRow>),
          BlockRow,
          PrefetchHooks Function()
        > {
  $$BlocksTableTableManager(_$AppDatabase db, $BlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> diaryId = const Value.absent(),
                Value<int> blockType = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> streamBuffer = const Value.absent(),
                Value<bool> streamComplete = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion(
                id: id,
                diaryId: diaryId,
                blockType: blockType,
                content: content,
                sortOrder: sortOrder,
                isDeleted: isDeleted,
                streamBuffer: streamBuffer,
                streamComplete: streamComplete,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String diaryId,
                required int blockType,
                Value<String> content = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> streamBuffer = const Value.absent(),
                Value<bool> streamComplete = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion.insert(
                id: id,
                diaryId: diaryId,
                blockType: blockType,
                content: content,
                sortOrder: sortOrder,
                isDeleted: isDeleted,
                streamBuffer: streamBuffer,
                streamComplete: streamComplete,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlocksTable,
      BlockRow,
      $$BlocksTableFilterComposer,
      $$BlocksTableOrderingComposer,
      $$BlocksTableAnnotationComposer,
      $$BlocksTableCreateCompanionBuilder,
      $$BlocksTableUpdateCompanionBuilder,
      (BlockRow, BaseReferences<_$AppDatabase, $BlocksTable, BlockRow>),
      BlockRow,
      PrefetchHooks Function()
    >;
typedef $$AppMetadataTableCreateCompanionBuilder =
    AppMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppMetadataTableUpdateCompanionBuilder =
    AppMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetadataTable> {
  $$AppMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetadataTable,
          AppMetadataRow,
          $$AppMetadataTableFilterComposer,
          $$AppMetadataTableOrderingComposer,
          $$AppMetadataTableAnnotationComposer,
          $$AppMetadataTableCreateCompanionBuilder,
          $$AppMetadataTableUpdateCompanionBuilder,
          (
            AppMetadataRow,
            BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataRow>,
          ),
          AppMetadataRow,
          PrefetchHooks Function()
        > {
  $$AppMetadataTableTableManager(_$AppDatabase db, $AppMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetadataTable,
      AppMetadataRow,
      $$AppMetadataTableFilterComposer,
      $$AppMetadataTableOrderingComposer,
      $$AppMetadataTableAnnotationComposer,
      $$AppMetadataTableCreateCompanionBuilder,
      $$AppMetadataTableUpdateCompanionBuilder,
      (
        AppMetadataRow,
        BaseReferences<_$AppDatabase, $AppMetadataTable, AppMetadataRow>,
      ),
      AppMetadataRow,
      PrefetchHooks Function()
    >;
typedef $$CrmEntityCachesTableCreateCompanionBuilder =
    CrmEntityCachesCompanion Function({
      required String id,
      required String twentyId,
      required String entityType,
      Value<String> name,
      Value<String> dataJson,
      Value<bool> isDeleted,
      Value<int> localVersion,
      required DateTime lastSyncedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CrmEntityCachesTableUpdateCompanionBuilder =
    CrmEntityCachesCompanion Function({
      Value<String> id,
      Value<String> twentyId,
      Value<String> entityType,
      Value<String> name,
      Value<String> dataJson,
      Value<bool> isDeleted,
      Value<int> localVersion,
      Value<DateTime> lastSyncedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CrmEntityCachesTableFilterComposer
    extends Composer<_$AppDatabase, $CrmEntityCachesTable> {
  $$CrmEntityCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get twentyId => $composableBuilder(
    column: $table.twentyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CrmEntityCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $CrmEntityCachesTable> {
  $$CrmEntityCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get twentyId => $composableBuilder(
    column: $table.twentyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CrmEntityCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CrmEntityCachesTable> {
  $$CrmEntityCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get twentyId =>
      $composableBuilder(column: $table.twentyId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CrmEntityCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CrmEntityCachesTable,
          CrmEntityCacheRow,
          $$CrmEntityCachesTableFilterComposer,
          $$CrmEntityCachesTableOrderingComposer,
          $$CrmEntityCachesTableAnnotationComposer,
          $$CrmEntityCachesTableCreateCompanionBuilder,
          $$CrmEntityCachesTableUpdateCompanionBuilder,
          (
            CrmEntityCacheRow,
            BaseReferences<
              _$AppDatabase,
              $CrmEntityCachesTable,
              CrmEntityCacheRow
            >,
          ),
          CrmEntityCacheRow,
          PrefetchHooks Function()
        > {
  $$CrmEntityCachesTableTableManager(
    _$AppDatabase db,
    $CrmEntityCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrmEntityCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrmEntityCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrmEntityCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> twentyId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CrmEntityCachesCompanion(
                id: id,
                twentyId: twentyId,
                entityType: entityType,
                name: name,
                dataJson: dataJson,
                isDeleted: isDeleted,
                localVersion: localVersion,
                lastSyncedAt: lastSyncedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String twentyId,
                required String entityType,
                Value<String> name = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                required DateTime lastSyncedAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CrmEntityCachesCompanion.insert(
                id: id,
                twentyId: twentyId,
                entityType: entityType,
                name: name,
                dataJson: dataJson,
                isDeleted: isDeleted,
                localVersion: localVersion,
                lastSyncedAt: lastSyncedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CrmEntityCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CrmEntityCachesTable,
      CrmEntityCacheRow,
      $$CrmEntityCachesTableFilterComposer,
      $$CrmEntityCachesTableOrderingComposer,
      $$CrmEntityCachesTableAnnotationComposer,
      $$CrmEntityCachesTableCreateCompanionBuilder,
      $$CrmEntityCachesTableUpdateCompanionBuilder,
      (
        CrmEntityCacheRow,
        BaseReferences<_$AppDatabase, $CrmEntityCachesTable, CrmEntityCacheRow>,
      ),
      CrmEntityCacheRow,
      PrefetchHooks Function()
    >;
typedef $$SyncRecordsTableCreateCompanionBuilder =
    SyncRecordsCompanion Function({
      required String syncId,
      required String diaryId,
      required String diaryJson,
      required DateTime time,
      required int syncType,
      Value<int> rowid,
    });
typedef $$SyncRecordsTableUpdateCompanionBuilder =
    SyncRecordsCompanion Function({
      Value<String> syncId,
      Value<String> diaryId,
      Value<String> diaryJson,
      Value<DateTime> time,
      Value<int> syncType,
      Value<int> rowid,
    });

class $$SyncRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diaryJson => $composableBuilder(
    column: $table.diaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncType => $composableBuilder(
    column: $table.syncType,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaryId => $composableBuilder(
    column: $table.diaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diaryJson => $composableBuilder(
    column: $table.diaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncType => $composableBuilder(
    column: $table.syncType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get diaryId =>
      $composableBuilder(column: $table.diaryId, builder: (column) => column);

  GeneratedColumn<String> get diaryJson =>
      $composableBuilder(column: $table.diaryJson, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get syncType =>
      $composableBuilder(column: $table.syncType, builder: (column) => column);
}

class $$SyncRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRecordsTable,
          SyncRecordRow,
          $$SyncRecordsTableFilterComposer,
          $$SyncRecordsTableOrderingComposer,
          $$SyncRecordsTableAnnotationComposer,
          $$SyncRecordsTableCreateCompanionBuilder,
          $$SyncRecordsTableUpdateCompanionBuilder,
          (
            SyncRecordRow,
            BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecordRow>,
          ),
          SyncRecordRow,
          PrefetchHooks Function()
        > {
  $$SyncRecordsTableTableManager(_$AppDatabase db, $SyncRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> syncId = const Value.absent(),
                Value<String> diaryId = const Value.absent(),
                Value<String> diaryJson = const Value.absent(),
                Value<DateTime> time = const Value.absent(),
                Value<int> syncType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion(
                syncId: syncId,
                diaryId: diaryId,
                diaryJson: diaryJson,
                time: time,
                syncType: syncType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncId,
                required String diaryId,
                required String diaryJson,
                required DateTime time,
                required int syncType,
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion.insert(
                syncId: syncId,
                diaryId: diaryId,
                diaryJson: diaryJson,
                time: time,
                syncType: syncType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRecordsTable,
      SyncRecordRow,
      $$SyncRecordsTableFilterComposer,
      $$SyncRecordsTableOrderingComposer,
      $$SyncRecordsTableAnnotationComposer,
      $$SyncRecordsTableCreateCompanionBuilder,
      $$SyncRecordsTableUpdateCompanionBuilder,
      (
        SyncRecordRow,
        BaseReferences<_$AppDatabase, $SyncRecordsTable, SyncRecordRow>,
      ),
      SyncRecordRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DiariesTableTableManager get diaries =>
      $$DiariesTableTableManager(_db, _db.diaries);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$FontsTableTableManager get fonts =>
      $$FontsTableTableManager(_db, _db.fonts);
  $$BlocksTableTableManager get blocks =>
      $$BlocksTableTableManager(_db, _db.blocks);
  $$AppMetadataTableTableManager get appMetadata =>
      $$AppMetadataTableTableManager(_db, _db.appMetadata);
  $$CrmEntityCachesTableTableManager get crmEntityCaches =>
      $$CrmEntityCachesTableTableManager(_db, _db.crmEntityCaches);
  $$SyncRecordsTableTableManager get syncRecords =>
      $$SyncRecordsTableTableManager(_db, _db.syncRecords);
}
