import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/glass_theme.dart';
import '../models/purchase.dart';
import '../models/wallet.dart';
import '../models/wallet_entry.dart';
import '../services/purchase_service.dart';
import 'purchase_detail_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});
  @override State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _purchaseService = PurchaseService.instance;
  List<Purchase> _purchases = [];
  Wallet? _wallet;
  List<WalletEntry> _walletEntries = [];
  bool _loadingPurchases = true;
  bool _loadingWallet = true;
  String? _purchasesError;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); _loadData(); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }
  Future<void> _loadData() async { await Future.wait([_loadPurchases(), _loadWallet()]); }
  Future<void> _loadPurchases() async {
    setState(() { _purchasesError = null; });
    try { final p = await _purchaseService.getMyPurchases(); if (mounted) setState(() { _purchases = p; _loadingPurchases = false; }); }
    catch (e) { if (mounted) setState(() { _loadingPurchases = false; _purchasesError = e.toString(); }); }
  }
  Future<void> _loadWallet() async {
    try {
      final w = await _purchaseService.getMyWallet();
      final e = await _purchaseService.getWalletEntries(w.id);
      if (mounted) setState(() { _wallet = w; _walletEntries = e; _loadingWallet = false; });
    } catch (e) { if (mounted) setState(() => _loadingWallet = false); }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(title: 'Покупки и кошелёк', bottom: TabBar(
        controller: _tabController,
        indicatorColor: LG.accent, labelColor: LG.accent, unselectedLabelColor: LG.textMuted,
        labelStyle: LG.font(weight: FontWeight.w700),
        tabs: const [Tab(text: 'Покупки'), Tab(text: 'Кошелёк')],
      )),
      body: SafeArea(
        top: true,
        child: TabBarView(controller: _tabController, children: [_buildPurchasesTab(), _buildWalletTab()]),
      ),
    );
  }

  Widget _buildPurchasesTab() {
    if (_loadingPurchases) return Center(child: CircularProgressIndicator(color: LG.accent));
    if (_purchasesError != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, size: 48, color: LG.red), const SizedBox(height: 12),
      Text('Ошибка загрузки', style: LG.font(color: LG.red, size: 16, weight: FontWeight.w700)), const SizedBox(height: 8),
      Text(_purchasesError!, style: LG.font(color: LG.textMuted, size: 12), textAlign: TextAlign.center), const SizedBox(height: 16),
      GestureDetector(onTap: _loadPurchases, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: LG.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: LG.accent.withValues(alpha: 0.4))),
        child: Text('Повторить', style: LG.font(color: LG.accent, weight: FontWeight.w700)))),
    ])));
    if (_purchases.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.shopping_bag_outlined, size: 64, color: LG.textMuted), const SizedBox(height: 12),
      Text('Нет покупок', style: LG.font(color: LG.textMuted, size: 16)),
    ]));
    return RefreshIndicator(onRefresh: _loadPurchases, child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 112, 16, 16),
      itemCount: _purchases.length,
      itemBuilder: (_, i) => _buildPurchaseCard(_purchases[i]),
    ));
  }

  Widget _buildPurchaseCard(Purchase p) {
    final statusColor = _statusColor(p.purchaseStatus);
    final dateStr = p.createdAt != null ? DateFormat('dd.MM.yyyy HH:mm').format(p.createdAt!.toLocal()) : '';
    final fileTypeName = p.beatFile?['type'] as String? ?? '';
    final beatInfo = p.beatFile?['beat'];
    final beatTitle = beatInfo is Map ? (beatInfo['title'] as String? ?? 'Beat') : 'Beat #${p.beatFileId ?? "?"}';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseDetailScreen(purchase: p))),
      child: GlassPanel(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), borderRadius: 16,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(beatTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(weight: FontWeight.w700, size: 16))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(_statusLabel(p.purchaseStatus), style: LG.font(color: statusColor, weight: FontWeight.w700, size: 11))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            if (fileTypeName.isNotEmpty) ...[
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: LG.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(fileTypeName, style: LG.font(color: LG.accent, weight: FontWeight.w700, size: 11))),
              const SizedBox(width: 10),
            ],
            Text(dateStr, style: LG.font(color: LG.textMuted, size: 12)),
            const Spacer(),
            Text('\$${p.amount.toStringAsFixed(2)}', style: LG.font(color: LG.green, weight: FontWeight.w800, size: 16)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: LG.textMuted, size: 20),
          ]),
        ]),
      ),
    );
  }

  Color _statusColor(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.completed: return LG.green;
      case PurchaseStatus.pending: return LG.orange;
      case PurchaseStatus.cancelled: return LG.textMuted;
      case PurchaseStatus.refunded: return LG.red;
    }
  }
  String _statusLabel(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.completed: return 'Оплачено';
      case PurchaseStatus.pending: return 'В обработке';
      case PurchaseStatus.cancelled: return 'Отменено';
      case PurchaseStatus.refunded: return 'Возврат';
    }
  }

  Widget _buildWalletTab() {
    if (_loadingWallet) return Center(child: CircularProgressIndicator(color: LG.accent));
    return RefreshIndicator(onRefresh: _loadWallet, child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 112, 16, 16),
      child: Column(children: [
        GlassPanel(padding: const EdgeInsets.all(24), borderRadius: 20, borderColor: LG.accent.withValues(alpha: 0.3),
          child: Column(children: [
            Icon(Icons.account_balance_wallet, color: LG.accent, size: 40),
            const SizedBox(height: 12),
            Text('Баланс', style: LG.font(color: LG.textMuted, size: 14)),
            const SizedBox(height: 4),
            Text('\$${_wallet?.balance.toStringAsFixed(2) ?? "0.00"}', style: LG.font(size: 36, weight: FontWeight.w800, color: LG.green)),
            const SizedBox(height: 16),
            GlassButton(text: 'Пополнить', icon: Icons.add, onTap: _showTopUpDialog),
          ])),
        const SizedBox(height: 20),
        if (_walletEntries.isNotEmpty) ...[
          Align(alignment: Alignment.centerLeft, child: Text('История операций', style: LG.h3)),
          const SizedBox(height: 12),
          ..._walletEntries.map((e) => _buildWalletEntryCard(e)),
        ] else Padding(padding: const EdgeInsets.all(32), child: Text('Нет операций', style: LG.font(color: LG.textMuted))),
      ]),
    ));
  }

  Widget _buildWalletEntryCard(WalletEntry entry) {
    final isPositive = entry.amount >= 0;
    final dateStr = entry.createdAt != null ? DateFormat('dd.MM.yyyy HH:mm').format(entry.createdAt!.toLocal()) : '';
    IconData icon; Color color;
    switch (entry.entryType) {
      case WalletEntryType.topup: icon = Icons.arrow_downward; color = LG.green;
      case WalletEntryType.purchase: icon = Icons.shopping_bag; color = LG.accent;
      case WalletEntryType.payout: icon = Icons.arrow_upward; color = LG.orange;
    }
    return GlassPanel(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), borderRadius: 14,
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.description ?? _entryTypeLabel(entry.entryType), maxLines: 1, overflow: TextOverflow.ellipsis, style: LG.font(weight: FontWeight.w600, size: 13)),
          Text(dateStr, style: LG.font(color: LG.textMuted, size: 11)),
        ])),
        Text('${isPositive ? "+" : ""}\$${entry.amount.toStringAsFixed(2)}', style: LG.font(color: isPositive ? LG.green : LG.red, weight: FontWeight.w800, size: 15)),
      ]),
    );
  }

  String _entryTypeLabel(WalletEntryType type) {
    switch (type) { case WalletEntryType.topup: return 'Пополнение'; case WalletEntryType.purchase: return 'Покупка'; case WalletEntryType.payout: return 'Вывод'; }
  }

  void _showTopUpDialog() {
    final controller = TextEditingController(text: '100');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: LG.bgLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Пополнение кошелька', style: LG.font(weight: FontWeight.w700, size: 18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Введите сумму пополнения', style: LG.font(color: LG.textMuted, size: 13)),
        const SizedBox(height: 16),
        TextField(controller: controller, keyboardType: TextInputType.number,
          style: LG.font(), decoration: InputDecoration(
            prefixText: '\$ ', prefixStyle: LG.font(color: LG.green),
            filled: true, fillColor: LG.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LG.border)),
          )),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [50, 100, 500, 1000].map((amt) => ActionChip(
          label: Text('\$$amt', style: LG.font(size: 12, weight: FontWeight.w600)),
          backgroundColor: LG.bg, side: BorderSide(color: LG.border),
          onPressed: () => controller.text = amt.toString(),
        )).toList()),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: LG.font(color: LG.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: LG.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            final amt = double.tryParse(controller.text) ?? 0;
            if (amt <= 0) return;
            Navigator.pop(ctx);
            try {
              await _purchaseService.topUpWallet(amt);
              await _loadWallet();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Баланс пополнен на \$${amt.toStringAsFixed(2)}')));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
            }
          },
          child: Text('Пополнить', style: LG.font(weight: FontWeight.w700, color: const Color(0xFF0A0A0F))),
        ),
      ],
    ));
  }
}
