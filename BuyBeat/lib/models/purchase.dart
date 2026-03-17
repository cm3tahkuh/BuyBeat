import 'package:json_annotation/json_annotation.dart';
import '../config/strapi_config.dart';

part 'purchase.g.dart';

/// Модель покупки для работы со Strapi
@JsonSerializable()
class Purchase {
  final int id;
  final double amount;
  @JsonKey(name: 'purchase_status')
  final PurchaseStatus purchaseStatus;
  @JsonKey(name: 'payment_provider')
  final String? paymentProvider;
  @JsonKey(name: 'license_pdf')
  final Map<String, dynamic>? licensePdf;
  
  // Relations
  @JsonKey(name: 'users_permissions_user')
  final Map<String, dynamic>? user;
  @JsonKey(name: 'beat_file')
  final Map<String, dynamic>? beatFile;
  
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  Purchase({
    required this.id,
    required this.amount,
    required this.purchaseStatus,
    this.paymentProvider,
    this.licensePdf,
    this.user,
    this.beatFile,
    this.createdAt,
    this.updatedAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) => _$PurchaseFromJson(json);
  Map<String, dynamic> toJson() => _$PurchaseToJson(this);
  
  /// URL лицензии PDF
  String? get licenseUrl {
    if (licensePdf == null) return null;
    final url = licensePdf!['url'] as String?;
    return StrapiConfig.getMediaUrl(url);
  }
  
  /// ID пользователя
  int? get userId => user?['id'] as int?;
  
  /// ID файла бита
  int? get beatFileId => beatFile?['id'] as int?;
}

enum PurchaseStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('refunded')
  refunded,
}

