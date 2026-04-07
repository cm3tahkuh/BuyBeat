import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/glass_theme.dart';
import '../models/beat.dart';
import '../models/genre.dart';
import '../models/tag.dart';
import '../services/beat_service.dart';

/// Экран редактирования бита — используется и админом и продюсером
class EditBeatScreen extends StatefulWidget {
  final Beat beat;
  const EditBeatScreen({super.key, required this.beat});

  @override
  State<EditBeatScreen> createState() => _EditBeatScreenState();
}

class _EditBeatScreenState extends State<EditBeatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _beatService = BeatService.instance;

  late TextEditingController _titleController;
  late TextEditingController _bpmController;
  late TextEditingController _priceController;

  String? _selectedKey;
  String? _selectedMood;
  Genre? _selectedGenre;
  List<Tag> _selectedTags = [];
  List<String> _customTagNames = [];
  final _newTagController = TextEditingController();

  List<Genre> _genres = [];
  List<Tag> _tags = [];
  bool _isLoading = true;
  bool _isSaving = false;
  BeatVisibility _visibility = BeatVisibility.public;

  static const List<String> _musicalKeys = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    'Cm', 'C#m', 'Dm', 'D#m', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'A#m', 'Bm',
  ];

  static const Map<String, String> _moodRuMap = {
    'Aggressive': 'Агрессивный',
    'Calm': 'Спокойный',
    'Dark': 'Тёмный',
    'Energetic': 'Энергичный',
    'Happy': 'Весёлый',
    'Melancholic': 'Меланхоличный',
    'Romantic': 'Романтичный',
    'Sad': 'Грустный',
    'Uplifting': 'Воодушевляющий',
    'Chill': 'Чилл',
  };

  @override
  void initState() {
    super.initState();
    final b = widget.beat;
    _titleController = TextEditingController(text: b.title);
    _bpmController = TextEditingController(text: b.bpm?.toString() ?? '');
    _priceController = TextEditingController(text: b.priceBase.toStringAsFixed(2));
    _selectedKey = b.key;
    _selectedMood = b.mood;
    _visibility = b.visibility;
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bpmController.dispose();
    _priceController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final genres = await _beatService.getAllGenres();
      final tags = await _beatService.getAllTags();
      if (mounted) {
        setState(() {
          _genres = genres;
          _tags = tags;
          // Подставляем текущие значения
          if (widget.beat.genreId != null) {
            _selectedGenre = genres.where((g) => g.id == widget.beat.genreId).firstOrNull;
          }
          _selectedTags = widget.beat.tagsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ошибка загрузки данных: $e');
      }
    }
  }

  void _addCustomTag() {
    final raw = _newTagController.text.trim().toLowerCase().replaceAll(' ', '_');
    if (raw.isEmpty) return;
    final existing = _tags.where((t) => t.name.toLowerCase() == raw).firstOrNull;
    if (existing != null) {
      if (!_selectedTags.any((t) => t.id == existing.id)) {
        setState(() => _selectedTags.add(existing));
      }
      _newTagController.clear();
      return;
    }
    if (!_customTagNames.contains(raw)) {
      setState(() => _customTagNames.add(raw));
    }
    _newTagController.clear();
  }

  Future<List<int>> _resolveTagIds() async {
    final ids = _selectedTags.map((t) => t.id).toList();
    for (final name in _customTagNames) {
      try {
        final existing = _tags.where((t) => t.name.toLowerCase() == name.toLowerCase()).firstOrNull;
        if (existing != null) {
          if (!ids.contains(existing.id)) ids.add(existing.id);
        } else {
          final newTag = await _beatService.createTag(name);
          ids.add(newTag.id);
        }
      } catch (_) {}
    }
    return ids;
  }

  Future<void> _saveBeat() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final resolvedTagIds = await _resolveTagIds();
      final tagIdsArg = resolvedTagIds.isEmpty ? null : resolvedTagIds;
      final docId = widget.beat.documentId;
      await (docId != null
          ? _beatService.updateBeatByDocId(
              docId,
              title: _titleController.text.trim(),
              genreId: _selectedGenre?.id,
              priceBase: double.tryParse(_priceController.text),
              bpm: int.tryParse(_bpmController.text),
              key: _selectedKey,
              mood: _selectedMood,
              visibility: _visibility,
              tagIds: tagIdsArg,
            )
          : _beatService.updateBeat(
              widget.beat.id,
              title: _titleController.text.trim(),
              genreId: _selectedGenre?.id,
              priceBase: double.tryParse(_priceController.text),
              bpm: int.tryParse(_bpmController.text),
              key: _selectedKey,
              mood: _selectedMood,
              visibility: _visibility,
              tagIds: tagIdsArg,
            ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Бит обновлён', style: TextStyle(color: const Color(0xFF0A0A0F))), backgroundColor: const Color(0xFF22C55E)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Ошибка сохранения: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Редактировать бит',
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: LG.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Title ---
                    _sectionTitle('Название', required: true),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _titleController,
                      hint: 'Night Vibes',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                    ),

                    const SizedBox(height: 20),

                    // --- Genre ---
                    _sectionTitle('Жанр'),
                    const SizedBox(height: 8),
                    _buildGenreSelector(),

                    const SizedBox(height: 20),

                    // --- BPM & Key ---
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('BPM'),
                              const SizedBox(height: 8),
                              _textField(
                                controller: _bpmController,
                                hint: '140',
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Тональность'),
                              const SizedBox(height: 8),
                              _dropdown(
                                value: (_selectedKey?.isNotEmpty == true) ? _selectedKey : null,
                                items: _musicalKeys,
                                hint: 'Выбрать',
                                onChanged: (v) => setState(() => _selectedKey = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- Mood & Price ---
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Настроение'),
                              const SizedBox(height: 8),
                              _dropdown(
                                value: (_selectedMood?.isNotEmpty == true) ? _selectedMood : null,
                                items: _moodRuMap.keys.toList(),
                                labelMap: _moodRuMap,
                                hint: 'Выбрать',
                                onChanged: (v) => setState(() => _selectedMood = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Цена (\$)', required: true),
                              const SizedBox(height: 8),
                              _textField(
                                controller: _priceController,
                                hint: '29.99',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Укажите цену';
                                  if (double.tryParse(v) == null) return 'Некорректная цена';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- Visibility ---
                    _sectionTitle('Видимость'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _visibilityChip('Публичный', BeatVisibility.public),
                        const SizedBox(width: 10),
                        _visibilityChip('Эксклюзив', BeatVisibility.soldExclusive),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- Tags ---
                    _sectionTitle('Теги'),
                    const SizedBox(height: 8),
                    _buildTagSelector(),
                    const SizedBox(height: 20),

                    const SizedBox(height: 16),

                    // --- Save button ---
                    GlassButton(
                      text: 'Сохранить изменения',
                      icon: Icons.save,
                      isLoading: _isSaving,
                      onTap: _isSaving ? null : _saveBeat,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // ==================== UI Helpers ====================

  Widget _sectionTitle(String title, {bool required = false}) {
    return Row(
      children: [
        Text(
          title,
          style: LG.font(color: LG.textSecondary, size: 14, weight: FontWeight.w600),
        ),
        if (required)
          Text(' *', style: LG.font(color: LG.red, size: 14, weight: FontWeight.w700)),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: LG.font(size: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: LG.font(color: LG.textMuted, size: 15),
        filled: true,
        fillColor: LG.bgLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LG.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LG.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LG.accent)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LG.red)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<String> items,
    Map<String, String>? labelMap,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: LG.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LG.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: LG.font(color: LG.textMuted, size: 15)),
          isExpanded: true,
          dropdownColor: LG.bgLight,
          style: LG.font(size: 15),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(labelMap?[i] ?? i))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _visibilityChip(String label, BeatVisibility val) {
    final selected = _visibility == val;
    return GestureDetector(
      onTap: () => setState(() => _visibility = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? LG.accent.withValues(alpha: 0.15) : LG.bgLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? LG.accent : LG.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: LG.font(
            color: selected ? LG.accent : LG.textSecondary,
            size: 14,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _genres.map((genre) {
        final selected = _selectedGenre?.id == genre.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedGenre = genre),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? LG.cyan.withValues(alpha: 0.15) : LG.bgLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? LG.cyan : LG.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              genre.name,
              style: LG.font(
                color: selected ? LG.cyan : LG.textSecondary,
                size: 14,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTagSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              final selected = _selectedTags.any((t) => t.id == tag.id);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedTags.removeWhere((t) => t.id == tag.id);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF06B6D4).withOpacity(0.2) : const Color(0xFF16161F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? const Color(0xFF06B6D4) : Colors.grey.shade800),
                  ),
                  child: Text('#${tag.name}',
                    style: GoogleFonts.manrope(
                      color: selected ? const Color(0xFF06B6D4) : Colors.grey.shade500,
                      fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        if (_customTagNames.isNotEmpty) ...[if (_tags.isNotEmpty) const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _customTagNames.map((name) {
              return GestureDetector(
                onTap: () => setState(() => _customTagNames.remove(name)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDFF00).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCDFF00)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('#$name', style: GoogleFonts.manrope(color: const Color(0xFFCDFF00), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.close, color: Color(0xFFCDFF00), size: 13),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _newTagController,
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Новый тег...',
                hintStyle: GoogleFonts.manrope(color: Colors.grey.shade600, fontSize: 13),
                filled: true, fillColor: const Color(0xFF16161F),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade800)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade800)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
              ),
              onFieldSubmitted: (_) => _addCustomTag(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _addCustomTag,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.5)),
              ),
              child: const Icon(Icons.add, color: Color(0xFF06B6D4), size: 22),
            ),
          ),
        ]),
      ],
    );
  }
}
