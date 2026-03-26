import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/glass_theme.dart';
import 'screens/catalog_landing_page.dart';
import 'screens/chat_screen_real.dart';
import 'screens/profile_screen.dart';
import 'screens/cart_screen.dart';
import 'services/strapi_service.dart';
import 'services/websocket_service.dart';
import 'services/in_app_notification_service.dart';
import 'services/native_notification_service.dart';
import 'widgets/global_player_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  
  // Инициализация Strapi API сервиса
  print('🎵 Инициализация Strapi API...');
  try {
    // Инициализируем нативные уведомления
    await NativeNotificationService.instance.init();

    await StrapiService.instance.init();
    print('✅ Strapi API сервис инициализирован');
    
    // Подключаем WebSocket если есть токен
    if (StrapiService.instance.isAuthenticated) {
      WebSocketService.instance.connect();
      InAppNotificationService.instance.start();
      print('🔌 WebSocket подключение запущено');
    }
  } catch (e) {
    print('❌ Ошибка инициализации Strapi: $e');
  }
  
  runApp(const BeatMarketplaceApp());
}

class BeatMarketplaceApp extends StatefulWidget {
  const BeatMarketplaceApp({super.key});

  @override
  State<BeatMarketplaceApp> createState() => _BeatMarketplaceAppState();
}

class _BeatMarketplaceAppState extends State<BeatMarketplaceApp> {
  int _selectedIndex = 0;

  /// Табы, которые уже были открыты хоть раз (ленивая инициализация)
  final Set<int> _loadedTabs = {0};

  // Для «Написать продюсеру» — переключаемся на Chat tab с нужным userId
  int? _openChatWithUserId;
  String? _openChatWithUserName;
  Key _chatScreenKey = UniqueKey();

  @override
  void initState() {
    super.initState();
  }

  /// Открыть чат с конкретным пользователем (вызывается из BeatDetailScreen)
  void _openChatWith(int userId, String userName) {
    setState(() {
      _openChatWithUserId = userId;
      _openChatWithUserName = userName;
      _chatScreenKey = UniqueKey(); // пересоздаём ChatScreen
      _loadedTabs.add(1); // обязательно инициализируем чат
      _selectedIndex = 1; // переключаемся на вкладку Chat
    });
  }


  void _onItemTapped(int index) {
    // Если переключились на Chat вручную — сбрасываем openChat
    if (index == 1) {
      _openChatWithUserId = null;
      _openChatWithUserName = null;
      _chatScreenKey = UniqueKey();
    }
    setState(() {
      _loadedTabs.add(index); // помечаем таб как загруженный
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuyBeats',
      debugShowCheckedModeBanner: false,
      navigatorKey: InAppNotificationService.instance.navigatorKey,
      theme: LG.themeData(),
      routes: {
        '/home': (context) => _buildMainScreen(),
      },
      home: _buildMainScreen(),
    );
  }

  Widget _buildMainScreen() {
    final screens = [
      CatalogLandingPage(
        onMessageProducer: _openChatWith,
      ),
      ChatScreen(
        key: _chatScreenKey,
        openChatWithUserId: _openChatWithUserId,
        openChatWithUserName: _openChatWithUserName,
      ),
      const CartScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: LG.bg,
      body: Stack(
        children: [
          // Gradient background
          Container(decoration: const BoxDecoration(gradient: LG.bgGradient)),
          // Ленивый стек: табы инициализируются только при первом открытии
          Stack(
            children: List.generate(screens.length, (i) {
              final loaded = _loadedTabs.contains(i);
              if (!loaded) return const SizedBox.shrink();
              return Offstage(
                offstage: _selectedIndex != i,
                child: TickerMode(
                  enabled: _selectedIndex == i,
                  child: RepaintBoundary(child: screens[i]),
                ),
              );
            }),
          ),
          // Global mini-player — above nav bar
          const Positioned(
            left: 16,
            right: 16,
            bottom: 108,
            child: GlobalPlayerBar(),
          ),
          // Floating nav bar — поверх контента, фон прозрачный
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101015).withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(Icons.home_rounded, 0),
                      _buildNavItem(Icons.chat_bubble_rounded, 1),
                      _buildNavItem(Icons.shopping_bag_rounded, 2),
                      _buildNavItem(Icons.person_rounded, 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: isActive ? 56 : 48,
        height: isActive ? 56 : 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? LG.accent : Colors.transparent,
          boxShadow: isActive
              ? [BoxShadow(color: LG.accent.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 1)]
              : null,
        ),
        child: Icon(
          icon,
          size: isActive ? 26 : 24,
          color: isActive ? const Color(0xFF0A0A0F) : const Color(0xFF5B5F6B),
        ),
      ),
    );
  }
}
