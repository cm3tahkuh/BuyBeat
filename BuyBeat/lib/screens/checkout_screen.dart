import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../config/glass_theme.dart';
import '../services/cart_service.dart';
import '../services/purchase_service.dart';
import '../services/auth_service.dart';
import '../services/receipt_pdf_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _cart = CartService.instance;
  final _purchaseService = PurchaseService.instance;
  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _error;
  double? _walletBalance;
  bool _loadingWallet = true;
  List<CartItemSnapshot> _itemSnapshots = [];
  double _totalAtPurchase = 0;
  String _transactionId = '';

  @override
  void initState() { super.initState(); _loadWallet(); }

  Future<void> _loadWallet() async {
    try {
      final wallet = await _purchaseService.getMyWallet();
      if (mounted) setState(() { _walletBalance = wallet.balance; _loadingWallet = false; });
    } catch (e) { if (mounted) setState(() { _walletBalance = 0; _loadingWallet = false; }); }
  }

  Future<void> _processPurchase() async {
    setState(() { _isProcessing = true; _error = null; });
    _itemSnapshots = _cart.items.map((i) => CartItemSnapshot.fromCartItem(i)).toList();
    _totalAtPurchase = _cart.totalPrice;
    _transactionId = const Uuid().v4().substring(0, 8).toUpperCase();
    try {
      await Future.delayed(const Duration(seconds: 2));
      await _purchaseService.purchaseCart();
      if (mounted) setState(() { _isProcessing = false; _isSuccess = true; });
    } catch (e) {
      if (mounted) setState(() { _isProcessing = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _downloadReceipt() async {
    try {
      final user = await AuthService().getCurrentUser();
      final pdfBytes = await ReceiptPdfService.generateReceipt(
        items: _itemSnapshots, totalAmount: _totalAtPurchase,
        buyerName: user?.displayName ?? user?.username ?? 'User', buyerEmail: user?.email ?? '',
        purchaseDate: DateTime.now(), transactionId: _transactionId,
      );
      await Printing.sharePdf(bytes: pdfBytes, filename: 'BuyBeats_Receipt_$_transactionId.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка генерации PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(title: _isSuccess ? 'Покупка завершена' : 'Оплата', leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
        onPressed: () => Navigator.pop(context, _isSuccess),
      )),
      body: SafeArea(child: _isSuccess ? _buildSuccessView() : _buildCheckoutView()),
    );
  }

  Widget _buildCheckoutView() {
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 80, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Оформление заказа', style: LG.h1),
      const SizedBox(height: 20),
      ...List.generate(_cart.items.length, (i) {
        final item = _cart.items[i];
        return GlassPanel(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), borderRadius: 14,
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.beat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${item.formatLabel} · ${item.licenseLabel}', style: LG.font(color: LG.textMuted, size: 12)),
            ])),
            Text('\$${item.price.toStringAsFixed(2)}', style: LG.font(color: LG.green, weight: FontWeight.w700)),
          ]),
        );
      }),
      const SizedBox(height: 16),
      GlassPanel(padding: const EdgeInsets.all(18), borderRadius: 16, child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Товаров:', style: LG.font(color: LG.textMuted)),
          Text('${_cart.itemCount}', style: LG.font(color: Colors.white)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Итого:', style: LG.font(weight: FontWeight.w700, size: 18)),
          Text('\$${_cart.totalPrice.toStringAsFixed(2)}', style: LG.font(color: LG.green, weight: FontWeight.w800, size: 22)),
        ]),
      ])),
      const SizedBox(height: 20),
      GlassPanel(padding: const EdgeInsets.all(18), borderRadius: 16, borderColor: LG.accent.withValues(alpha: 0.3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: LG.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.account_balance_wallet, color: LG.accent, size: 22)),
          const SizedBox(width: 12),
          Text('Кошелёк BuyBeats', style: LG.font(weight: FontWeight.w700, size: 16)),
        ]),
        const SizedBox(height: 12),
        _loadingWallet
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: LG.accent))
          : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Баланс:', style: LG.font(color: LG.textMuted)),
              Text('\$${_walletBalance?.toStringAsFixed(2) ?? "0.00"}', style: LG.font(
                color: (_walletBalance ?? 0) >= _cart.totalPrice ? LG.green : LG.red, weight: FontWeight.w800, size: 18)),
            ]),
        if (!_loadingWallet && (_walletBalance ?? 0) < _cart.totalPrice) ...[
          const SizedBox(height: 8),
          Text('Недостаточно средств', style: LG.font(color: LG.red, size: 13)),
        ],
      ])),
      if (_error != null) ...[
        const SizedBox(height: 16),
        GlassPanel(padding: const EdgeInsets.all(14), borderRadius: 12, borderColor: LG.red.withValues(alpha: 0.3),
          child: Row(children: [
            Icon(Icons.error_outline, color: LG.red, size: 20), const SizedBox(width: 10),
            Expanded(child: Text(_error!, style: LG.font(color: LG.red, size: 13))),
          ])),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: GlassButton(
        text: 'Оплатить \$${_cart.totalPrice.toStringAsFixed(2)}',
        icon: Icons.payment,
        isLoading: _isProcessing,
        onTap: _isProcessing || _loadingWallet || ((_walletBalance ?? 0) < _cart.totalPrice) ? null : _processPurchase,
      )),
      const SizedBox(height: 12),
    ]));
  }

  Widget _buildSuccessView() {
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [LG.green, LG.green.withValues(alpha: 0.6)])),
        child: const Icon(Icons.check_rounded, color: Color(0xFF0A0A0F), size: 56)),
      const SizedBox(height: 24),
      Text('Покупка успешна!', style: LG.h1),
      const SizedBox(height: 8),
      Text('Ваш заказ обработан. Биты доступны для скачивания.', textAlign: TextAlign.center, style: LG.font(color: LG.textMuted, size: 14)),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: LG.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: LG.green.withValues(alpha: 0.3))),
        child: Text('Списано: \$${_totalAtPurchase.toStringAsFixed(2)}', style: LG.font(color: LG.green, weight: FontWeight.w800, size: 18))),
      const SizedBox(height: 8),
      Text('ID транзакции: $_transactionId', style: LG.font(color: LG.textMuted, size: 12)),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: GlassButton(text: 'Скачать PDF чек', icon: Icons.picture_as_pdf, onTap: _downloadReceipt)),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: GestureDetector(
        onTap: () => Navigator.pop(context, true),
        child: Container(height: 50, decoration: BoxDecoration(borderRadius: BorderRadius.circular(LG.radiusM), border: Border.all(color: LG.border)),
          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.library_music, color: LG.textSecondary, size: 20), const SizedBox(width: 8),
            Text('Вернуться в каталог', style: LG.font(weight: FontWeight.w600, size: 15)),
          ]))),
      )),
    ])));
  }
}
