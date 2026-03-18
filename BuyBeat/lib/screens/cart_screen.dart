import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/glass_theme.dart';
import '../services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService.instance;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _cart.items;
    return GlassScaffold(
      appBar: GlassAppBar(title: 'Корзина', showBack: false, leading: const SizedBox.shrink(), actions: [
        if (items.isNotEmpty) IconButton(icon: Icon(Icons.delete_sweep, color: LG.red), onPressed: () => _cart.clear()),
      ]),
      body: SafeArea(child: items.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: LG.textMuted),
            const SizedBox(height: 16),
            Text('Корзина пуста', style: LG.h2.copyWith(color: LG.textMuted)),
            const SizedBox(height: 8),
            Text('Добавьте биты из каталога', style: LG.font(color: LG.textMuted, size: 14)),
          ]))
        : Column(children: [
            const SizedBox(height: 60),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return GlassPanel(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), borderRadius: 16,
                  child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 56, height: 56,
                      child: item.beat.coverUrl.isNotEmpty
                        ? Image.network(item.beat.coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: LG.bgLight, child: const Icon(Icons.music_note, color: Colors.white38)))
                        : Container(color: LG.bgLight, child: const Icon(Icons.music_note, color: Colors.white38)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.beat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${item.formatLabel} • ${item.licenseLabel}', style: LG.font(size: 12, color: LG.textSecondary)),
                    ])),
                    Text('\$${item.price.toStringAsFixed(2)}', style: LG.font(weight: FontWeight.w700, color: LG.green)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _cart.removeItem(item.key),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: LG.red.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: Icon(Icons.close, color: LG.red, size: 16),
                      ),
                    ),
                  ]),
                );
              },
            )),
            // Total bar — bottom padding учитывает плавающий нав-бар (~92px) и мини-плеер (~172px)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 180),
              child: ClipRRect(borderRadius: BorderRadius.circular(LG.radiusL), child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: LG.blurHeavy, sigmaY: LG.blurHeavy),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(color: LG.panelFillLight, borderRadius: BorderRadius.circular(LG.radiusL), border: Border.all(color: LG.border)),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Итого', style: LG.font(size: 13, color: LG.textMuted)),
                    Text('\$${_cart.totalPrice.toStringAsFixed(2)}', style: LG.font(size: 24, weight: FontWeight.w800, color: LG.green)),
                  ]),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: GlassButton(text: 'Оформить', icon: Icons.arrow_forward, onTap: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                      if (result == true) setState(() {});
                    }),
                  ),
                ]),
              ),
            ))),
          ]),
      ),
    );
  }
}
