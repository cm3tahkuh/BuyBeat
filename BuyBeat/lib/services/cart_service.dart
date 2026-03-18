import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/beat.dart';
import '../models/beat_file.dart';

/// Элемент корзины
class CartItem {
  final Beat beat;
  final BeatFile beatFile;

  CartItem({required this.beat, required this.beatFile});

  double get price => beatFile.price;
  String get formatLabel => beatFile.fileType.name.toUpperCase();
  String get licenseLabel =>
      beatFile.licenseType == LicenseType.exclusive ? 'Exclusive' : 'Lease';

  Map<String, dynamic> toJson() => {
        'beatId': beat.id,
        'beatFileId': beatFile.id,
        'beatTitle': beat.title,
        'beatFileType': beatFile.fileType.name,
        'price': beatFile.price,
        'licenseType': beatFile.licenseType.name,
      };

  /// Уникальный ключ: beatId_beatFileId
  String get key => '${beat.id}_${beatFile.id}';
}

/// Сервис клиентской корзины (хранится в SharedPreferences).
/// Extends ChangeNotifier so UI widgets can listen and rebuild automatically.
class CartService extends ChangeNotifier {
  static const _storageKey = 'buybeat_cart';

  static CartService? _instance;
  static CartService get instance => _instance ??= CartService._();
  CartService._();

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.price);

  /// Добавить в корзину
  bool addItem(Beat beat, BeatFile beatFile) {
    final key = '${beat.id}_${beatFile.id}';
    if (_items.any((i) => i.key == key)) return false; // уже есть
    _items.add(CartItem(beat: beat, beatFile: beatFile));
    _persist();
    notifyListeners();
    return true;
  }

  /// Удалить из корзины
  void removeItem(String key) {
    _items.removeWhere((i) => i.key == key);
    _persist();
    notifyListeners();
  }

  /// Очистить корзину
  void clear() {
    _items.clear();
    _persist();
    notifyListeners();
  }

  /// Проверить, есть ли файл в корзине
  bool contains(int beatId, int beatFileId) {
    return _items.any((i) => i.beat.id == beatId && i.beatFile.id == beatFileId);
  }

  /// Сохранение в SharedPreferences (только метаданные)
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.map((i) => i.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }
}
