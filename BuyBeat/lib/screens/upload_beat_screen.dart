import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../config/glass_theme.dart';
import '../services/strapi_service.dart';
import '../services/beat_service.dart';
import '../models/genre.dart';
import '../models/tag.dart';
import '../config/strapi_config.dart';

class UploadBeatScreen extends StatefulWidget {
  const UploadBeatScreen({super.key});

  @override
  State<UploadBeatScreen> createState() => _UploadBeatScreenState();
}

class _UploadBeatScreenState extends State<UploadBeatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _strapi = StrapiService.instance;
  final _beatService = BeatService.instance;

  // Form controllers
  final _titleController = TextEditingController();
  final _bpmController = TextEditingController();
  final _keyController = TextEditingController();
  final _moodController = TextEditingController();
  final _priceController = TextEditingController(text: '29.99');

  // Files
  PlatformFile? _audioFile;
  PlatformFile? _coverFile;

  // Data
  List<Genre> _genres = [];
  List<Tag> _tags = [];
  Genre? _selectedGenre;
  List<Tag> _selectedTags = [];
  List<String> _customTagNames = [];
  final _newTagController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _isUploading = false;
  String _uploadStatus = '';
  double _uploadProgress = 0;

  // Musical keys
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
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bpmController.dispose();
    _keyController.dispose();
    _moodController.dispose();
    _priceController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final genres = await _beatService.getAllGenres();
      final tags = await _beatService.getAllTags();
      if (mounted) {
        setState(() {
          _genres = genres;
          _tags = tags;
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
    // If matches existing tag — select it instead
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

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true, // Needed for web
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _audioFile = result.files.first);
      }
    } catch (e) {
      _showError('Ошибка выбора файла: $e');
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // Needed for web
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _coverFile = result.files.first);
      }
    } catch (e) {
      _showError('Ошибка выбора изображения: $e');
    }
  }

  Future<void> _uploadBeat() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audioFile == null) {
      _showError('Выберите аудио файл');
      return;
    }
    if (_selectedGenre == null) {
      _showError('Выберите жанр');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadStatus = 'Загрузка аудио...';
    });

    try {
      // 1. Upload audio file
      int? audioFileId;
      if (_audioFile!.bytes != null) {
        final audioResult = await _strapi.uploadFileBytes(
          bytes: _audioFile!.bytes!,
          fileName: _audioFile!.name,
        );
        if (audioResult.isNotEmpty) {
          audioFileId = audioResult[0]['id'] as int;
        }
      }
      if (audioFileId == null) {
        throw Exception('Не удалось загрузить аудио файл');
      }

      setState(() {
        _uploadProgress = 0.4;
        _uploadStatus = 'Загрузка обложки...';
      });

      // 2. Upload cover image (optional)
      int? coverFileId;
      if (_coverFile != null && _coverFile!.bytes != null) {
        final coverResult = await _strapi.uploadFileBytes(
          bytes: _coverFile!.bytes!,
          fileName: _coverFile!.name,
        );
        if (coverResult.isNotEmpty) {
          coverFileId = coverResult[0]['id'] as int;
        }
      }

      setState(() {
        _uploadProgress = 0.7;
        _uploadStatus = 'Создание бита...';
      });

      // 3. Create beat entry
      final beatData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'users_permissions_user': _strapi.currentUserId,
        'genre': _selectedGenre!.id,
        'price_base': double.tryParse(_priceController.text) ?? 29.99,
        'visibility': 'PUBLIC',
        'audio_preview': audioFileId,
      };

      if (_bpmController.text.isNotEmpty) {
        beatData['bpm'] = int.tryParse(_bpmController.text);
      }
      if (_keyController.text.isNotEmpty) {
        beatData['key'] = _keyController.text;
      }
      if (_moodController.text.isNotEmpty) {
        beatData['mood'] = _moodController.text;
      }
      if (coverFileId != null) {
        beatData['cover'] = coverFileId;
      }
      final allTagIds = await _resolveTagIds();
      if (allTagIds.isNotEmpty) {
        beatData['tags'] = allTagIds;
      }

      final beatResponse = await _strapi.post(
        StrapiConfig.beats,
        body: {'data': beatData},
      );

      setState(() {
        _uploadProgress = 0.85;
        _uploadStatus = 'Создание файла бита...';
      });

      // 4. Create beat_file entry linking audio to the beat
      final beatItem = StrapiService.parseItem(beatResponse);
      if (beatItem != null) {
        final beatId = beatItem['id'];
        final fileExtension = _audioFile!.name.split('.').last.toUpperCase();
        final beatFileType = (fileExtension == 'WAV') ? 'WAV' : 'MP3';

        await _strapi.post(
          StrapiConfig.beatFiles,
          body: {
            'data': {
              'beat': beatId,
              'type': beatFileType,
              'price': double.tryParse(_priceController.text) ?? 29.99,
              'license_type': 'lease',
              'audio_file': audioFileId,
              'enabled': true,
            }
          },
        );
      }

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatus = 'Готово!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Бит "${_titleController.text}" успешно загружен!',
              style: LG.font(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true = beat was uploaded
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = '';
      });
      _showError('Ошибка загрузки: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: LG.font()),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LG.bg,
      appBar: AppBar(
        backgroundColor: LG.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.cloud_upload, color: LG.accent, size: 24),
            const SizedBox(width: 10),
            Text(
              'Загрузить бит',
              style: LG.font(size: 20, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: LG.accent))
          : _isUploading
              ? _buildUploadProgress()
              : _buildForm(),
    );
  }

  Widget _buildUploadProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _uploadProgress,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade800,
                      valueColor: AlwaysStoppedAnimation(LG.accent),
                    ),
                  ),
                  Text(
                    '${(_uploadProgress * 100).toInt()}%',
                    style: LG.font(size: 24, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _uploadStatus,
              style: LG.font(size: 16, weight: FontWeight.w600, color: LG.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Audio file picker ---
            _buildSectionTitle('Аудио файл', required: true),
            const SizedBox(height: 8),
            _buildFilePicker(
              file: _audioFile,
              icon: Icons.audiotrack,
              label: 'Выберите аудио файл',
              subtitle: 'MP3, WAV, FLAC',
              onPick: _pickAudioFile,
              accentColor: LG.accent,
            ),

            const SizedBox(height: 24),

            // --- Cover image picker ---
            _buildSectionTitle('Обложка', required: false),
            const SizedBox(height: 8),
            _buildFilePicker(
              file: _coverFile,
              icon: Icons.image,
              label: 'Выберите обложку',
              subtitle: 'JPG, PNG, WebP',
              onPick: _pickCoverImage,
              accentColor: LG.cyan,
            ),

            const SizedBox(height: 32),

            // --- Title ---
            _buildSectionTitle('Название бита', required: true),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: 'Например: Night Vibes',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),

            const SizedBox(height: 20),

            // --- Genre ---
            _buildSectionTitle('Жанр', required: true),
            const SizedBox(height: 8),
            _buildGenreSelector(),

            const SizedBox(height: 20),

            // --- BPM & Key row ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('BPM'),
                      const SizedBox(height: 8),
                      _buildTextField(
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
                      _buildSectionTitle('Тональность'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _keyController.text.isEmpty ? null : _keyController.text,
                        items: _musicalKeys,
                        hint: 'Выбрать',
                        onChanged: (v) => setState(() => _keyController.text = v ?? ''),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- Mood & Price row ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Настроение'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _moodController.text.isEmpty ? null : _moodController.text,
                        items: _moodRuMap.keys.toList(),
                        labelMap: _moodRuMap,
                        hint: 'Выбрать',
                        onChanged: (v) => setState(() => _moodController.text = v ?? ''),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Цена (\$)', required: true),
                      const SizedBox(height: 8),
                      _buildTextField(
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

            // --- Tags ---
            _buildSectionTitle('Теги'),
            const SizedBox(height: 8),
            _buildTagSelector(),
            const SizedBox(height: 20),

            const SizedBox(height: 16),

            // --- Upload button ---
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _uploadBeat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LG.accent,
                  foregroundColor: const Color(0xFF0A0A0F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Загрузить бит',
                      style: LG.font(size: 16, weight: FontWeight.w700, color: const Color(0xFF0A0A0F)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==================== UI Helpers ====================

  Widget _buildSectionTitle(String title, {bool required = false}) {
    return Row(
      children: [
        Text(
          title,
          style: LG.font(size: 14, weight: FontWeight.w600, color: LG.textSecondary),
        ),
        if (required)
          Text(
            ' *',
            style: LG.font(size: 14, weight: FontWeight.w700, color: LG.red),
          ),
      ],
    );
  }

  Widget _buildTextField({
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
        hintStyle: LG.font(color: LG.textMuted),
        filled: true,
        fillColor: LG.bgLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: LG.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: LG.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: LG.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: LG.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown({
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
          hint: Text(hint, style: LG.font(color: LG.textMuted)),
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A2E),
          style: LG.font(size: 15),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(labelMap?[item] ?? item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFilePicker({
    required PlatformFile? file,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onPick,
    required Color accentColor,
  }) {
    final hasFile = file != null;
    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasFile ? accentColor.withOpacity(0.08) : LG.bgLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile ? accentColor.withOpacity(0.5) : LG.border,
            width: hasFile ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasFile ? Icons.check_circle : icon,
                color: accentColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? file.name : label,
                    style: LG.font(
                      color: hasFile ? LG.textPrimary : LG.textMuted,
                      size: 15,
                      weight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFile
                        ? _formatFileSize(file.size)
                        : subtitle,
                    style: LG.font(color: LG.textMuted, size: 12),
                  ),
                ],
              ),
            ),
            Icon(
              hasFile ? Icons.swap_horiz : Icons.add,
              color: accentColor,
              size: 22,
            ),
          ],
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
              color: selected
                  ? LG.accent.withOpacity(0.15)
                  : LG.bgLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? LG.accent : LG.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              genre.icon != null ? '${genre.icon} ${genre.name}' : genre.name,
              style: LG.font(
                color: selected ? LG.accent : LG.textMuted,
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
                    color: selected ? LG.cyan.withValues(alpha: 0.15) : LG.bgLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? LG.cyan : LG.border),
                  ),
                  child: Text('#${tag.name}',
                    style: LG.font(color: selected ? LG.cyan : LG.textMuted, size: 13,
                        weight: selected ? FontWeight.w600 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        if (_customTagNames.isNotEmpty) ...[if (_tags.isNotEmpty) const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customTagNames.map((name) {
              return GestureDetector(
                onTap: () => setState(() => _customTagNames.remove(name)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: LG.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LG.accent),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('#$name', style: LG.font(color: LG.accent, size: 13, weight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.close, color: LG.accent, size: 13),
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
              style: LG.font(size: 14),
              decoration: InputDecoration(
                hintText: 'Новый тег...',
                hintStyle: LG.font(color: LG.textMuted, size: 13),
                filled: true, fillColor: LG.bgLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LG.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LG.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: LG.cyan)),
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
                color: LG.cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LG.cyan.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.add, color: LG.cyan, size: 22),
            ),
          ),
        ]),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
