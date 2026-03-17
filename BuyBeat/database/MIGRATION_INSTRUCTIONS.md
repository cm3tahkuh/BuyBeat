# 🔄 Инструкция по миграции БД: v1 → v2

## Проблема

Если вы получили ошибку:
```
ERROR: 42P07: relation "users" already exists
```

Это значит, что вы уже выполнили старую схему (`schema.sql`), и таблицы уже существуют.

## Решение

Используйте **скрипт миграции** вместо полной схемы.

---

## Шаги миграции

### 1. Откройте Supabase SQL Editor

1. Зайдите на [supabase.com](https://supabase.com)
2. Откройте ваш проект
3. Перейдите в **SQL Editor** (в левом меню)

### 2. Выполните скрипт миграции

1. Откройте файл `database/migration_v1_to_v2.sql` из проекта
2. Скопируйте **весь** SQL код
3. Вставьте в SQL Editor в Supabase
4. Нажмите **Run** (или F5)

### 3. Проверьте результат

После выполнения вы должны увидеть:
```
Success. No rows returned
```

---

## Что делает миграция

### ✅ Безопасно обновляет существующие таблицы:
- Добавляет новые колонки (`firebase_uid`, `display_name`, `is_onboarded` и т.д.)
- Обновляет ограничения (CHECK constraints)
- Делает некоторые поля nullable (для гостей)
- Удаляет устаревшие колонки (`password_hash`, `is_exclusive_available`)

### ✅ Создает новые таблицы:
- `user_genres_prefs` — предпочтения жанров
- `purchases` — покупки
- `wallet_entries` — история кошелька

### ✅ Обновляет существующие таблицы:
- `beats` — добавляет `stream_url`, `visibility`
- `beat_files` — добавляет `license_type`, `storage_path`, `enabled`, `MELODY`
- `messages` — добавляет `type`, `file_attachment`
- `plays` — добавляет `is_preview`

### ✅ Создает триггеры:
- Автоматическое скрытие бита при покупке EXCLUSIVE
- Автоматическое создание кошелька для продюсеров
- Автоматическое добавление записей в кошелёк при покупке

### ✅ Создает функции:
- `are_users_mutually_following()` — проверка взаимных подписок
- `is_allowed_file_format()` — проверка формата файла

---

## Важно!

- ✅ **Все существующие данные сохраняются**
- ✅ Миграция безопасна (использует `IF NOT EXISTS`, `IF EXISTS`)
- ✅ Можно выполнять несколько раз (идемпотентная)

---

## Если что-то пошло не так

### Откат изменений

Если нужно вернуться к старой схеме:

1. В Supabase Dashboard → **Database** → **Backups**
2. Восстановите последний бэкап

Или вручную удалите новые колонки/таблицы через SQL Editor.

---

## После миграции

1. ✅ Проверьте, что все таблицы обновлены
2. ✅ Проверьте, что триггеры созданы
3. ✅ Выполните `flutter pub run build_runner build` для генерации кода моделей

---

## Проверка миграции

Выполните этот запрос, чтобы проверить, что миграция прошла успешно:

```sql
-- Проверка новых колонок в users
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('firebase_uid', 'display_name', 'is_onboarded');

-- Проверка новых таблиц
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_genres_prefs', 'purchases', 'wallet_entries');

-- Проверка триггеров
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name IN (
    'hide_beat_on_exclusive', 
    'create_wallet_on_producer_role',
    'add_wallet_entry_on_purchase'
);
```

Если все запросы вернули результаты — миграция успешна! ✅

