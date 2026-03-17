import 'package:json_annotation/json_annotation.dart';

part 'tag.g.dart';

/// Модель тега для работы со Strapi
@JsonSerializable()
class Tag {
  final int id;
  final String name;
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  Tag({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
  Map<String, dynamic> toJson() => _$TagToJson(this);
}

