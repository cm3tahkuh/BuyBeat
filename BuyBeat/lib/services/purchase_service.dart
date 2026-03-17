import '../models/purchase.dart';
import '../models/wallet.dart';
import '../models/wallet_entry.dart';
import '../config/strapi_config.dart';
import 'strapi_service.dart';
import 'auth_service.dart';
import 'cart_service.dart';

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
        queryParams: {'populate': '*'},
      );
      freshItem = StrapiService.parseItem(freshResponse);
    } catch (_) {}
    return Purchase.fromJson(freshItem ?? item);
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
        // Deep populate: beat_file → beat → cover, audio_preview, producer
        'populate[beat_file][populate][beat][populate][0]': 'cover',
        'populate[beat_file][populate][beat][populate][1]': 'audio_preview',
        'populate[beat_file][populate][beat][populate][2]': 'users_permissions_user',
        'populate[beat_file][populate][audio_file]': '*',
        'populate[license_pdf]': '*',
        'populate[users_permissions_user]': '*',
      },
    );

    final items = StrapiService.parseList(response);
    return items.map((json) => Purchase.fromJson(json)).toList();
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
        'populate[beat_file]': '*',
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
