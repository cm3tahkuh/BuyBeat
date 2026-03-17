import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../config/glass_theme.dart';
import '../config/strapi_config.dart';
import '../models/purchase.dart';
import '../services/audio_player_service.dart';
import '../models/beat.dart';

/// Экран деталей покупки — PDF-лицензия + воспроизведение бита
class PurchaseDetailScreen extends StatefulWidget {
  final Purchase purchase;
  const PurchaseDetailScreen({super.key, required this.purchase});

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  final _audio = AudioPlayerService.instance;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  Purchase get purchase => widget.purchase;

  // Извлекаем данные бита из глубокой популяции
  Map<String, dynamic>? get _beatFileMap => purchase.beatFile;
  Map<String, dynamic>? get _beatMap {
    final bf = _beatFileMap;
    if (bf == null) return null;
    final b = bf['beat'];
    return b is Map<String, dynamic> ? b : null;
  }

  String get _beatTitle {
    final b = _beatMap;
    if (b != null) return b['title'] as String? ?? 'Бит';
    return 'Бит #${purchase.beatFileId ?? "?"}';
  }

  String get _producerName {
    final b = _beatMap;
    if (b == null) return 'Неизвестно';
    final producer = b['users_permissions_user'];
    if (producer is Map) {
      return producer['display_name'] as String? ??
          producer['username'] as String? ??
          'Неизвестно';
    }
    return 'Неизвестно';
  }

  String? get _coverUrl {
    final b = _beatMap;
    if (b == null) return null;
    final cover = b['cover'];
    if (cover is Map) {
      return StrapiConfig.getMediaUrl(cover['url'] as String?);
    }
    return null;
  }

  String? get _audioUrl {
    final b = _beatMap;
    if (b == null) return null;
    final ap = b['audio_preview'];
    if (ap is Map) {
      return StrapiConfig.getMediaUrl(ap['url'] as String?);
    }
    return null;
  }

  String? get _downloadUrl {
    final bf = _beatFileMap;
    if (bf == null) return null;
    final af = bf['audio_file'];
    if (af is Map) {
      return StrapiConfig.getMediaUrl(af['url'] as String?);
    }
    return null;
  }

  String get _fileType => (_beatFileMap?['type'] as String?) ?? '';
  String get _licenseType {
    final lt = _beatFileMap?['license_type'] as String? ?? '';
    return lt == 'exclusive' ? 'Эксклюзив' : 'Лицензия';
  }

  String? get _licenseUrl => purchase.licenseUrl;

  Beat? _constructedBeat;

  @override
  void initState() {
    super.initState();
    _tryConstructBeat();
    _stateSub = _audio.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing && _audio.currentBeat?.id == _constructedBeat?.id;
      if (playing != _isPlaying) setState(() => _isPlaying = playing);
    });
    _posSub = _audio.positionStream.listen((pos) {
      if (mounted && _audio.currentBeat?.id == _constructedBeat?.id) {
        setState(() => _position = pos);
      }
    });
    _durSub = _audio.durationStream.listen((dur) {
      if (mounted && _audio.currentBeat?.id == _constructedBeat?.id) {
        setState(() => _duration = dur);
      }
    });
  }

  void _tryConstructBeat() {
    final b = _beatMap;
    if (b != null) {
      try {
        _constructedBeat = Beat.fromJson(b);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _playPause() async {
    if (_constructedBeat == null) return;
    await _audio.playPause(beat: _constructedBeat!);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: const GlassAppBar(title: 'Детали покупки'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 112, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Cover + Play ───
              _buildCoverPlayer(),
              const SizedBox(height: 20),

              // ─── Beat Info ───
              Text(_beatTitle, style: LG.h1),
              const SizedBox(height: 4),
              Text(_producerName, style: LG.font(color: LG.textSecondary, size: 14)),
              const SizedBox(height: 20),

              // ─── Purchase Info ───
              _buildInfoSection(),
              const SizedBox(height: 20),

              // ─── License PDF ───
              _buildLicenseSection(),
              const SizedBox(height: 20),

              // ─── Download File ───
              _buildDownloadSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlayer() {
    return GlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(
        children: [
          // Cover image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _coverUrl != null && _coverUrl!.isNotEmpty
                  ? Image.network(_coverUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultCover())
                  : _defaultCover(),
            ),
          ),
          // Player controls
          if (_constructedBeat != null && _audioUrl != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Progress bar
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: LG.accent,
                      inactiveTrackColor: LG.border,
                      thumbColor: LG.accent,
                      overlayColor: LG.accent.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _duration != null && _duration!.inMilliseconds > 0
                          ? _position.inMilliseconds.toDouble().clamp(0, _duration!.inMilliseconds.toDouble())
                          : 0,
                      max: _duration?.inMilliseconds.toDouble() ?? 1,
                      onChanged: (v) => _audio.seek(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                  // Time labels + play button
                  Row(
                    children: [
                      Text(_formatDuration(_position), style: LG.font(size: 11, color: LG.textMuted)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _playPause,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LG.accentGradient,
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: const Color(0xFF0A0A0F),
                            size: 32,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _duration != null ? _formatDuration(_duration!) : '--:--',
                        style: LG.font(size: 11, color: LG.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, color: LG.textMuted, size: 20),
                  const SizedBox(width: 8),
                  Text('Аудио недоступно', style: LG.font(color: LG.textMuted, size: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      color: LG.bgLight,
      child: Center(child: Icon(Icons.music_note, size: 48, color: LG.textMuted)),
    );
  }

  Widget _buildInfoSection() {
    final dateStr = purchase.createdAt != null
        ? DateFormat('dd MMMM yyyy, HH:mm', 'ru').format(purchase.createdAt!)
        : '—';
    final statusColor = _statusColor(purchase.purchaseStatus);

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Информация о покупке', style: LG.font(weight: FontWeight.w700, size: 15)),
          const SizedBox(height: 14),
          _infoRow('Статус', _statusLabel(purchase.purchaseStatus), statusColor),
          _infoRow('Сумма', '\$${purchase.amount.toStringAsFixed(2)}', LG.green),
          if (_fileType.isNotEmpty) _infoRow('Формат', _fileType, LG.accent),
          _infoRow('Тип лицензии', _licenseType, LG.textSecondary),
          _infoRow('Дата', dateStr, LG.textSecondary),
          if (purchase.paymentProvider != null)
            _infoRow('Способ оплаты', purchase.paymentProvider == 'demo_wallet' ? 'Кошелёк' : purchase.paymentProvider!, LG.textSecondary),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: LG.font(color: LG.textMuted, size: 13)),
          Flexible(
            child: Text(value, style: LG.font(color: valueColor, weight: FontWeight.w600, size: 13), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseSection() {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LG.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.picture_as_pdf, color: LG.red, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Лицензия PDF', style: LG.font(weight: FontWeight.w700, size: 15)),
                    const SizedBox(height: 2),
                    Text(
                      _licenseUrl != null && _licenseUrl!.isNotEmpty
                          ? 'Документ доступен'
                          : 'Документ не прикреплён',
                      style: LG.font(color: LG.textMuted, size: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_licenseUrl != null && _licenseUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassButton(
              text: 'Открыть лицензию',
              icon: Icons.open_in_new,
              onTap: _openLicensePdf,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadSection() {
    final url = _downloadUrl;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LG.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.audio_file, color: LG.cyan, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Файл бита', style: LG.font(weight: FontWeight.w700, size: 15)),
                    const SizedBox(height: 2),
                    Text(
                      url != null && url.isNotEmpty
                          ? '$_fileType · $_licenseType'
                          : 'Файл недоступен',
                      style: LG.font(color: LG.textMuted, size: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (url != null && url.isNotEmpty) ...[
            const SizedBox(height: 14),
            GlassButton(
              text: 'Скачать файл',
              icon: Icons.download,
              onTap: _downloadFile,
            ),
          ],
        ],
      ),
    );
  }

  void _openLicensePdf() {
    final url = _licenseUrl;
    if (url == null || url.isEmpty) return;
    // Открываем PDF в браузере
    _openUrl(url);
  }

  void _downloadFile() {
    final url = _downloadUrl;
    if (url == null || url.isEmpty) return;
    _openUrl(url);
  }

  void _openUrl(String url) async {
    try {
      // Используем url_launcher если доступен, или показываем URL
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ссылка: $url', style: const TextStyle(fontSize: 12)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
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
}
