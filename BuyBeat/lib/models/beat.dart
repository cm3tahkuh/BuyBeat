import 'package:json_annotation/json_annotation.dart';
import '../config/strapi_config.dart';
import 'tag.dart';

part 'beat.g.dart';

/// Модель бита для работы со Strapi
@JsonSerializable()
class Beat {
  final int id;
  @JsonKey(name: 'documentId')
  final String? documentId;
  final String title;
  final int? bpm;
  final String? key;
  final String? mood;
  @JsonKey(name: 'price_base')
  final double priceBase;
  @JsonKey(name: 'duration_seconds')
  final int? durationSeconds;
  final BeatVisibility visibility;
  
  // Media поля (Strapi возвращает объекты)
  final Map<String, dynamic>? cover;
  @JsonKey(name: 'audio_preview')
  final Map<String, dynamic>? audioPreview;
  
  // Relations (populated)
  @JsonKey(name: 'users_permissions_user')
  final Map<String, dynamic>? producer;
  final Map<String, dynamic>? genre;
  final List<dynamic>? tags;
  
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  Beat({
    required this.id,
    this.documentId,
    required this.title,
    this.bpm,
    this.key,
    this.mood,
    required this.priceBase,
    this.durationSeconds,
    this.visibility = BeatVisibility.public,
    this.cover,
    this.audioPreview,
    this.producer,
    this.genre,
    this.tags,
    this.createdAt,
    this.updatedAt,
  });

  factory Beat.fromJson(Map<String, dynamic> json) => _$BeatFromJson(json);
  Map<String, dynamic> toJson() => _$BeatToJson(this);
  
  /// URL обложки
  String get coverUrl {
    if (cover == null) return '';
    final url = cover!['url'] as String?;
    return StrapiConfig.getMediaUrl(url);
  }
  
  /// URL превью аудио
  String get audioPreviewUrl {
    if (audioPreview == null) return '';
    final url = audioPreview!['url'] as String?;
    return StrapiConfig.getMediaUrl(url);
  }
  
  /// Имя продюсера
  String? get producerName {
    if (producer == null) return null;
    return producer!['display_name'] as String? ?? 
           producer!['username'] as String?;
  }
  
  /// ID продюсера
  int? get producerId {
    if (producer == null) return null;
    return producer!['id'] as int?;
  }
  
  /// Название жанра
  String? get genreName {
    if (genre == null) return null;
    return genre!['name'] as String?;
  }
  
  /// ID жанра
  int? get genreId {
    if (genre == null) return null;
    return genre!['id'] as int?;
  }
  
  /// Список тегов как объекты Tag
  List<Tag> get tagsList {
    if (tags == null) return [];
    return tags!.map((t) {
      if (t is Map<String, dynamic>) {
        return Tag.fromJson(t);
      }
      return Tag(id: 0, name: t.toString());
    }).toList();
  }
  
  /// Названия тегов
  List<String> get tagNames => tagsList.map((t) => t.name).toList();
}

enum BeatVisibility {
  @JsonValue('PUBLIC')
  public,
  @JsonValue('SOLD_EXCLUSIVE')
  soldExclusive,
}

