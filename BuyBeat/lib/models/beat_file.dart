import 'package:json_annotation/json_annotation.dart';
import '../config/strapi_config.dart';

part 'beat_file.g.dart';

/// Модель файла бита для работы со Strapi
@JsonSerializable()
class BeatFile {
  final int id;
  @JsonKey(name: 'type')
  final BeatFileType fileType;
  final double price;
  @JsonKey(name: 'license_type')
  final LicenseType licenseType;
  @JsonKey(name: 'audio_file')
  final Map<String, dynamic>? audioFile;
  final bool enabled;
  
  // Relation к Beat
  final Map<String, dynamic>? beat;
  
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  BeatFile({
    required this.id,
    required this.fileType,
    required this.price,
    this.licenseType = LicenseType.lease,
    this.audioFile,
    this.enabled = true,
    this.beat,
    this.createdAt,
    this.updatedAt,
  });

  factory BeatFile.fromJson(Map<String, dynamic> json) => _$BeatFileFromJson(json);
  Map<String, dynamic> toJson() => _$BeatFileToJson(this);
  
  /// URL для скачивания файла
  String get downloadUrl {
    if (audioFile == null) return '';
    final url = audioFile!['url'] as String?;
    return StrapiConfig.getMediaUrl(url);
  }
  
  /// ID связанного бита
  int? get beatId {
    if (beat == null) return null;
    return beat!['id'] as int?;
  }
}

enum BeatFileType {
  @JsonValue('MP3')
  mp3,
  @JsonValue('WAV')
  wav,
  @JsonValue('STEMS')
  stems,
  @JsonValue('PROJECT')
  project,
  @JsonValue('MELODY')
  melody,
  @JsonValue('EXCLUSIVE')
  exclusive,
}

enum LicenseType {
  @JsonValue('lease')
  lease,
  @JsonValue('exclusive')
  exclusive,
}

