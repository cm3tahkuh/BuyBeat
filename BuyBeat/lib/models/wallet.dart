import 'package:json_annotation/json_annotation.dart';

part 'wallet.g.dart';

/// Модель кошелька для работы со Strapi
@JsonSerializable()
class Wallet {
  final int id;
  final String? documentId;
  final double balance;
  
  // Relation к User
  final Map<String, dynamic>? user;
  
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  Wallet({
    required this.id,
    this.documentId,
    required this.balance,
    this.user,
    this.createdAt,
    this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
  Map<String, dynamic> toJson() => _$WalletToJson(this);
  
  /// ID для API запросов (Strapi v5 использует documentId)
  String get apiId => documentId ?? id.toString();
  
  /// ID пользователя
  int? get userId => user?['id'] as int?;
}

