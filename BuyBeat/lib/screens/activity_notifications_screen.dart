import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/glass_theme.dart';
import '../models/user_activity.dart';
import '../services/activity_service.dart';
import '../widgets/global_player_bar.dart';
import 'user_profile_screen.dart';

class ActivityNotificationsScreen extends StatefulWidget {
  const ActivityNotificationsScreen({super.key});

  @override
  State<ActivityNotificationsScreen> createState() => _ActivityNotificationsScreenState();
}

class _ActivityNotificationsScreenState extends State<ActivityNotificationsScreen> {
  bool _isLoading = true;
  List<UserActivity> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await ActivityService.instance.getMyActivity();
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки уведомлений: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Уведомления'),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator(color: LG.accent))
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        'Пока нет активности',
                        style: LG.font(color: LG.textMuted, size: 15),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: LG.accent,
                      backgroundColor: LG.bgLight,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(14, topInset + 74, 14, 120),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _activityTile(_items[i]),
                      ),
                    ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GlobalPlayerBar(),
          ),
        ],
      ),
    );
  }

  Widget _activityTile(UserActivity item) {
    final isFavorite = item.type == UserActivityType.favorite;
    final isPurchase = item.type == UserActivityType.purchase;
    final isFollow = item.type == UserActivityType.follow;
    final icon = isFavorite
        ? Icons.favorite
        : (isPurchase ? Icons.shopping_bag : Icons.person_add_alt_1);
    final iconColor = isFavorite ? LG.pink : (isPurchase ? LG.green : LG.cyan);
    final actionText = isFavorite
        ? 'добавил(а) в избранное'
        : (isPurchase ? 'купил(а)' : 'подписался(ась) на вас');
    final description = isFollow
        ? '${item.actorName} $actionText'
        : '${item.actorName} $actionText бит «${item.beatTitle}»';

    return GestureDetector(
      onTap: item.actorUserId == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: item.actorUserId!),
                ),
              ),
      child: GlassPanel(
        borderRadius: 14,
        borderColor: LG.border,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: LG.font(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMMM, HH:mm', 'ru').format(item.createdAt.toLocal()),
                    style: LG.font(size: 12, color: LG.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
