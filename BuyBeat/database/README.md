# 🗄️ База данных для BuyBeat

## Быстрый старт с Supabase

### Шаг 1: Создайте проект в Supabase

1. Зайдите на [https://supabase.com](https://supabase.com)
2. Зарегистрируйтесь или войдите
3. Нажмите "New Project"
4. Заполните:
   - **Name**: `buybeat` (или любое другое)
   - **Database Password**: придумайте надежный пароль (сохраните его!)
   - **Region**: выберите ближайший регион
5. Нажмите "Create new project" (создание займет ~2 минуты)

### Шаг 2: Получите ключи API

#### 2.1. Найдите Project URL

**Project URL находится в одном из этих мест:**

**Вариант А (самый простой):**
1. В левом меню нажмите **Settings** (шестеренка)
2. Выберите **General** (первый пункт в "PROJECT SETTINGS")
3. В самом верху страницы вы увидите **Reference ID** и **Project URL**
4. Скопируйте **Project URL** (выглядит как `https://xxxxx.supabase.co`)

**Вариант Б:**
- Project URL также может быть виден в самом верху страницы проекта (рядом с названием проекта)

#### 2.2. Найдите Publishable Key (anon key)

1. В левом меню нажмите **Settings** → **API Keys** (вы уже там!)
2. Найдите секцию **"Publishable key"**
3. В таблице найдите строку с **NAME: `default`**
4. В колонке **API KEY** вы увидите ключ, начинающийся с `sb_publishable_...`
5. Нажмите на иконку **копирования** (📋) рядом с ключом, чтобы скопировать его

**Важно:** 
- **Publishable key** = это и есть **anon public key**
- Ключ начинается с `sb_publishable_` (в новых версиях Supabase)
- Или может начинаться с `eyJ...` (в старых версиях)

### Шаг 3: Настройте проект Flutter

1. Откройте `lib/config/supabase_config.dart`
2. Замените значения:
   ```dart
   static const String supabaseUrl = 'https://xxxxx.supabase.co';
   static const String supabaseAnonKey = 'ваш_anon_ключ';
   ```

3. Откройте `lib/main.dart` и раскомментируйте инициализацию:
   ```dart
   await SupabaseService.initialize(
     supabaseUrl: SupabaseConfig.supabaseUrl,
     supabaseAnonKey: SupabaseConfig.supabaseAnonKey,
   );
   ```

### Шаг 4: Создайте схему БД

1. В Supabase Dashboard перейдите в **SQL Editor**
2. Откройте файл `database/schema.sql` из этого проекта
3. Скопируйте весь SQL код
4. Вставьте в SQL Editor в Supabase
5. Нажмите **Run** (или F5)

✅ Готово! База данных создана.

### Шаг 5: Установите зависимости

```bash
flutter pub get
```

### Шаг 6: Сгенерируйте код для моделей

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Это создаст файлы `*.g.dart` для всех моделей.

---

## Структура базы данных

### Основные таблицы:

- **users** - пользователи (продюсеры, артисты)
- **beats** - биты/треки
- **genres** - жанры (Trap, Drill, Lo-fi и т.д.)
- **tags** - теги для битов
- **beat_files** - варианты файлов (MP3, WAV, STEMS и т.д.)
- **favorites** - избранное
- **follows** - подписки
- **plays** - статистика прослушиваний
- **chats** - чаты
- **messages** - сообщения
- **wallets** - кошельки
- **transactions** - транзакции
- **orders** - заказы

### Связи:

- `beats.producer_id` → `users.id`
- `beats.genre_id` → `genres.id`
- `beat_tags` (многие-ко-многим: beats ↔ tags)
- `beat_files.beat_id` → `beats.id`
- И другие...

---

## Использование в коде

### Пример: Получить все биты

```dart
import 'package:buybeat/services/beat_service.dart';

final beatService = BeatService();
final beats = await beatService.getBeats();
```

### Пример: Получить биты с фильтрами

```dart
final beats = await beatService.getBeats(
  genreId: 1, // Trap
  minBpm: 80,
  maxBpm: 140,
);
```

### Пример: Поиск битов

```dart
final results = await beatService.searchBeats('dark trap');
```

---

## Безопасность (RLS)

По умолчанию RLS (Row Level Security) отключен. Для продакшена:

1. В Supabase Dashboard → **Authentication** → **Policies**
2. Включите RLS для нужных таблиц
3. Создайте политики доступа

Пример политики (в SQL Editor):
```sql
ALTER TABLE beats ENABLE ROW LEVEL SECURITY;

-- Все могут читать биты
CREATE POLICY "Beats are viewable by everyone" ON beats
    FOR SELECT USING (true);

-- Только создатель может редактировать
CREATE POLICY "Users can update own beats" ON beats
    FOR UPDATE USING (auth.uid() = producer_id);
```

---

## Полезные ссылки

- [Документация Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)
- [Supabase Dashboard](https://app.supabase.com)
- [SQL Editor в Supabase](https://app.supabase.com/project/_/sql)

---

## Альтернативы

Если Supabase не подходит, можно использовать:

1. **Firebase Firestore** (уже подключен) - NoSQL
2. **Drift** - локальная SQLite с генерацией кода
3. **Свой backend** (Node.js, Python и т.д.) + PostgreSQL

