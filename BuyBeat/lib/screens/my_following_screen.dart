import 'package:flutter/material.dart';

import '../config/glass_theme.dart';
import '../services/follow_service.dart';
import 'user_profile_screen.dart';

class MyFollowingScreen extends StatefulWidget {
  const MyFollowingScreen({super.key});

  @override
  State<MyFollowingScreen> createState() => _MyFollowingScreenState();
}

class _MyFollowingScreenState extends State<MyFollowingScreen> {
  bool _isLoading = true;
  List<FollowingUser> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await FollowService.instance.getMyFollowing();
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки подписок: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Мои подписки'),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: LG.accent))
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'Вы пока ни на кого не подписаны',
                    style: LG.font(color: LG.textMuted, size: 15),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: LG.accent,
                  backgroundColor: LG.bgLight,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(14, topInset + 84, 14, 20),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final user = _items[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: user.userId),
                          ),
                        ),
                        child: GlassPanel(
                          borderRadius: 14,
                          borderColor: LG.border,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: LG.accent.withValues(alpha: 0.2),
                                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                    ? NetworkImage(user.avatarUrl!)
                                    : null,
                                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                                    ? Icon(Icons.person, color: LG.accent, size: 20)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName ?? user.username ?? 'Пользователь',
                                      style: LG.font(size: 15, weight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${user.username ?? 'user'}',
                                      style: LG.font(size: 12, color: LG.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: LG.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
