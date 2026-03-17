import 'package:json_annotation/json_annotation.dart';

part 'wallet_entry.g.dart';

/// Модель записи кошелька для работы со Strapi
@JsonSerializable()
class WalletEntry {
  final int id;
  final double amount;
  @JsonKey(name: 'type')
  final WalletEntryType entryType;
  final String? description;
  
  // Relation к Wallet
  final Map<String, dynamic>? wallet;
  
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  WalletEntry({
    required this.id,
    required this.amount,
    required this.entryType,
    this.description,
    this.wallet,
    this.createdAt,
    this.updatedAt,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> json) => _$WalletEntryFromJson(json);
  Map<String, dynamic> toJson() => _$WalletEntryToJson(this);
  
  /// ID кошелька
  int? get walletId => wallet?['id'] as int?;
}

enum WalletEntryType {
  @JsonValue('topup')
  topup,
  @JsonValue('purchase')
  purchase,
  @JsonValue('payout')
  payout,
}

