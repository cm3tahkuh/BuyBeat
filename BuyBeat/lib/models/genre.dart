import 'package:json_annotation/json_annotation.dart';

part 'genre.g.dart';

/// Модель жанра для работы со Strapi
@JsonSerializable()
class Genre {
  final int id;
  final String name;
  final String? icon;
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  Genre({
    required this.id,
    required this.name,
    this.icon,
    this.createdAt,
    this.updatedAt,
  });

  factory Genre.fromJson(Map<String, dynamic> json) => _$GenreFromJson(json);
  Map<String, dynamic> toJson() => _$GenreToJson(this);
}

