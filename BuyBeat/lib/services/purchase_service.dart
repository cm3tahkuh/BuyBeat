import '../models/purchase.dart';
import '../models/wallet.dart';
import '../models/wallet_entry.dart';
import '../config/strapi_config.dart';
import 'strapi_service.dart';
import 'auth_service.dart';
import 'cart_service.dart';
import 'pdf_receipt_service.dart';

/// Сервис покупок и кошелька
class PurchaseService {
  final _strapi = StrapiService.instance;

  static PurchaseService? _instance;
  static PurchaseService get instance => _instance ??= PurchaseService._();
  PurchaseService._();

  // ============ КОШЕЛЁК ============

  /// Получить кошелёк текущего пользователя (или создать)
  Future<Wallet> getMyWallet() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    final response = await _strapi.get(
      StrapiConfig.wallets,
      queryParams: {
        'populate': '*',
        'filters[users_permissions_user][id][\$eq]': user.id.toString(),
      },
    );

    final items = StrapiService.parseList(response);
    if (items.isNotEmpty) {
      return Wallet.fromJson(items.first);
    }

    // Создать новый кошелёк
    final createResponse = await _strapi.post(
      StrapiConfig.wallets,
      body: {
        'data': {
          'users_permissions_user': user.id,
          'balance': 0,
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
    final item = StrapiService.parseItem(createResponse);
    if (item == null) throw Exception('Ошибка создания кошелька');

    // Перечитываем с populate
    Map<String, dynamic>? freshItem;
    try {
      final docId = item['documentId'] as String?;
      final freshResponse = await _strapi.get(
        '${StrapiConfig.wallets}/${docId ?? item['id']}',
        queryParams: {'populate': '*'},
      );
      freshItem = StrapiService.parseItem(freshResponse);
    } catch (_) {}
    return Wallet.fromJson(freshItem ?? item);
  }

  /// Обновить баланс кошелька
  Future<Wallet> _updateWalletBalance(Wallet wallet, double newBalance) async {
    final response = await _strapi.put(
      '${StrapiConfig.wallets}/${wallet.apiId}',
      body: {
        'data': {
          'balance': newBalance,
        },
      },
    );
    final item = StrapiService.parseItem(response);
    return Wallet.fromJson(item!);
  }

  /// Пополнить кошелёк (фиктивное)
  Future<Wallet> topUpWallet(double amount) async {
    final wallet = await getMyWallet();
    final newBalance = wallet.balance + amount;

    // Создать запись
    await _createWalletEntry(
      wallet: wallet,
      amount: amount,
      type: 'topup',
      description: 'Пополнение кошелька на \$${amount.toStringAsFixed(2)}',
    );

    return await _updateWalletBalance(wallet, newBalance);
  }

  /// Создать запись в кошельке
  Future<void> _createWalletEntry({
    required Wallet wallet,
    required double amount,
    required String type,
    required String description,
  }) async {
    await _strapi.post(
      StrapiConfig.walletEntries,
      body: {
        'data': {
          'wallet': wallet.documentId ?? wallet.id,
          'decimal': amount,
          'type': type,
          'description': description,
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
  }

  // ============ ПОКУПКИ ============

  /// Оформить покупку корзины (все элементы)
  Future<List<Purchase>> purchaseCart() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    final cart = CartService.instance;
    if (cart.isEmpty) throw Exception('Корзина пуста');

    // Получаем кошелёк
    final wallet = await getMyWallet();
    final total = cart.totalPrice;

    if (wallet.balance < total) {
      throw Exception('Недостаточно средств. Баланс: \$${wallet.balance.toStringAsFixed(2)}, нужно: \$${total.toStringAsFixed(2)}');
    }

    // Проверяем, не куплены ли уже какие-то файлы
    final purchasedIds = await getMyPurchasedBeatFileIds();
    final duplicates = cart.items.where((item) => purchasedIds.contains(item.beatFile.id)).toList();
    if (duplicates.isNotEmpty) {
      final names = duplicates.map((d) => '${d.beat.title} (${d.formatLabel})').join(', ');
      throw Exception('Вы уже купили: $names');
    }

    final purchases = <Purchase>[];

    // Создаём покупку для каждого элемента
    for (final item in cart.items) {
      final purchase = await _createPurchase(
        userId: user.id,
        beatFileId: item.beatFile.id,
        amount: item.price,
        buyerUsername: user.displayName ?? user.username ?? user.email ?? 'Покупатель',
      );
      purchases.add(purchase);
    }

    // Списываем средства
    await _updateWalletBalance(wallet, wallet.balance - total);

    // Создаём запись в кошельке
    await _createWalletEntry(
      wallet: wallet,
      amount: -total,
      type: 'purchase',
      description: 'Покупка ${cart.itemCount} бит(ов) на \$${total.toStringAsFixed(2)}',
    );

    // Очищаем корзину
    cart.clear();

    return purchases;
  }

  /// Создать одну покупку
  Future<Purchase> _createPurchase({
    required int userId,
    required int beatFileId,
    required double amount,
    required String buyerUsername,
  }) async {
    final response = await _strapi.post(
      StrapiConfig.purchases,
      body: {
        'data': {
          'users_permissions_user': userId,
          'beat_file': beatFileId,
          'amount': amount,
          'purchase_status': 'completed',
          'payment_provider': 'demo_wallet',
          'publishedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
    final item = StrapiService.parseItem(response);
    if (item == null) throw Exception('Ошибка создания покупки');

    // Перечитываем с populate
    Map<String, dynamic>? freshItem;
    try {
      final docId = item['documentId'] as String?;
      final freshResponse = await _strapi.get(
        '${StrapiConfig.purchases}/${docId ?? item['id']}',
        queryParams: {
          'populate[beat_file][populate][beat][populate][cover][fields][0]': 'url',
          'populate[beat_file][populate][beat][populate][cover][fields][1]': 'name',
          'populate[beat_file][populate][beat][populate][audio_preview][fields][0]': 'url',
          'populate[beat_file][populate][beat][populate][audio_preview][fields][1]': 'name',
          'populate[beat_file][populate][beat][populate][users_permissions_user][fields][0]': 'id',
          'populate[beat_file][populate][beat][populate][users_permissions_user][fields][1]': 'username',
          'populate[beat_file][populate][audio_file][fields][0]': 'url',
          'populate[beat_file][populate][audio_file][fields][1]': 'name',
          'populate[license_pdf][fields][0]': 'url',
          'populate[license_pdf][fields][1]': 'name',
          'populate[license_pdf][fields][2]': 'mime',
        },
      );
      freshItem = StrapiService.parseItem(freshResponse);
    } catch (_) {}

    final purchase = Purchase.fromJson(freshItem ?? item);

    // Генерируем PDF-чек и прикрепляем к покупке
    try {
      final bf = freshItem?['beat_file'];
      final beat = bf is Map ? bf['beat'] : null;
      final producer = beat is Map ? beat['users_permissions_user'] : null;

      final beatTitle = beat is Map ? (beat['title'] as String? ?? 'Бит') : 'Бит';
      final producerName = producer is Map
          ? (producer['display_name'] as String? ?? producer['username'] as String? ?? 'Продюсер')
          : 'Продюсер';
      final fileType = bf is Map ? (bf['type'] as String? ?? '') : '';
      final licenseType = bf is Map
          ? ((bf['license_type'] as String?) == 'exclusive' ? 'Эксклюзив' : 'Лицензия')
          : 'Лицензия';

      final pdfBytes = await PdfReceiptService.generateReceipt(
        purchase: purchase,
        beatTitle: beatTitle,
        producerName: producerName,
        fileType: fileType,
        licenseType: licenseType,
        buyerUsername: buyerUsername,
      );

      final uploaded = await _strapi.uploadFileBytes(
        bytes: pdfBytes,
        fileName: 'receipt_${purchase.id}.pdf',
        mimeType: 'application/pdf',
      );

      if (uploaded.isNotEmpty) {
        final fileId = uploaded.first['id'];
        final docId = (freshItem ?? item)['documentId'] as String?;
        final purchaseApiId = docId ?? '${purchase.id}';
        await _strapi.put(
          '${StrapiConfig.purchases}/$purchaseApiId',
          body: {'data': {'license_pdf': fileId}},
        );
        // Re-fetch with the PDF now attached
        try {
          final withPdfResponse = await _strapi.get(
            '${StrapiConfig.purchases}/$purchaseApiId',
            queryParams: {
              'populate[beat_file][populate][beat][populate][cover][fields][0]': 'url',
              'populate[beat_file][populate][beat][populate][cover][fields][1]': 'name',
              'populate[beat_file][populate][beat][populate][audio_preview][fields][0]': 'url',
              'populate[beat_file][populate][beat][populate][audio_preview][fields][1]': 'name',
              'populate[beat_file][populate][beat][populate][users_permissions_user][fields][0]': 'id',
              'populate[beat_file][populate][beat][populate][users_permissions_user][fields][1]': 'username',
              'populate[beat_file][populate][audio_file][fields][0]': 'url',
              'populate[beat_file][populate][audio_file][fields][1]': 'name',
              'populate[license_pdf][fields][0]': 'url',
              'populate[license_pdf][fields][1]': 'name',
              'populate[license_pdf][fields][2]': 'mime',
            },
          );
          final withPdfItem = StrapiService.parseItem(withPdfResponse);
          if (withPdfItem != null) return Purchase.fromJson(withPdfItem);
        } catch (_) {}
      }
    } catch (_) {
      // PDF generation/upload failed — return purchase without PDF
    }

    return purchase;
  }

  /// Получить покупки текущего пользователя (с глубокой популяцией)
  Future<List<Purchase>> getMyPurchases() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) throw Exception('Не авторизован');

    final response = await _strapi.get(
      StrapiConfig.purchases,
      queryParams: {
        'filters[users_permissions_user][id][\$eq]': user.id.toString(),
        'sort': 'createdAt:desc',
        'pagination[pageSize]': '100',
        // Nested media: use [fields] to avoid .related 400
        // Do NOT mix [fields] and [populate] on the same key — use only [populate]
        'populate[beat_file][populate][beat][populate][cover][fields][0]': 'url',
        'populate[beat_file][populate][beat][populate][cover][fields][1]': 'name',
        'populate[beat_file][populate][beat][populate][audio_preview][fields][0]': 'url',
        'populate[beat_file][populate][beat][populate][audio_preview][fields][1]': 'name',
        'populate[beat_file][populate][beat][populate][users_permissions_user][fields][0]': 'id',
        'populate[beat_file][populate][beat][populate][users_permissions_user][fields][1]': 'username',
        'populate[beat_file][populate][audio_file][fields][0]': 'url',
        'populate[beat_file][populate][audio_file][fields][1]': 'name',
        // license_pdf: explicit fields to avoid UploadFile.related 400
        'populate[license_pdf][fields][0]': 'url',
        'populate[license_pdf][fields][1]': 'name',
        'populate[license_pdf][fields][2]': 'mime',
        'populate[users_permissions_user][fields][0]': 'id',
        'populate[users_permissions_user][fields][1]': 'username',
      },
    );

    final items = StrapiService.parseList(response);
    final result = <Purchase>[];
    for (final json in items) {
      try {
        result.add(Purchase.fromJson(json));
      } catch (e) {
        // skip items that fail to parse but don't crash the whole list
      }
    }
    return result;
  }

  /// Проверить, куплен ли бит-файл текущим пользователем
  Future<bool> hasUserPurchasedBeatFile(int beatFileId) async {
    final user = await AuthService().getCurrentUser();
    if (user == null) return false;

    final response = await _strapi.get(
      StrapiConfig.purchases,
      queryParams: {
        'filters[users_permissions_user][id][\$eq]': user.id.toString(),
        'filters[beat_file][id][\$eq]': beatFileId.toString(),
        'filters[purchase_status][\$eq]': 'completed',
        'pagination[pageSize]': '1',
      },
    );

    final items = StrapiService.parseList(response);
    return items.isNotEmpty;
  }

  /// Получить все ID бит-файлов, купленных текущим пользователем
  Future<Set<int>> getMyPurchasedBeatFileIds() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) return {};

    final response = await _strapi.get(
      StrapiConfig.purchases,
      queryParams: {
        'filters[users_permissions_user][id][\$eq]': user.id.toString(),
        'filters[purchase_status][\$eq]': 'completed',
        'populate[beat_file][fields][0]': 'id',
        'pagination[pageSize]': '500',
      },
    );

    final items = StrapiService.parseList(response);
    final ids = <int>{};
    for (final item in items) {
      final bf = item['beat_file'];
      if (bf is Map && bf['id'] != null) {
        ids.add(bf['id'] as int);
      }
    }
    return ids;
  }

  /// Получить записи кошелька
  Future<List<WalletEntry>> getWalletEntries(int walletId) async {
    final response = await _strapi.get(
      StrapiConfig.walletEntries,
      queryParams: {
        'populate': '*',
        'filters[wallet][id][\$eq]': walletId.toString(),
        'sort': 'createdAt:desc',
        'pagination[pageSize]': '100',
      },
    );

    final items = StrapiService.parseList(response);
    return items.map((json) => WalletEntry.fromJson(json)).toList();
  }
}
