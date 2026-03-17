# Настройка Strapi для BuyBeat — Полное руководство

## Запуск

```bash
cd buy-beat-backend
npm run develop
```

Открой **http://localhost:1337/admin** и создай admin-аккаунт.

---

## Как работает Content-Type Builder

Слева в сайдбаре: **Content-Type Builder**

Каждый Content Type = таблица в базе данных.  
После сохранения Strapi **автоматически перезапускается** и применяет миграцию.

---

## Как создавать поля — шаги

1. Нажми **"Create new collection type"**
2. Введи имя (например `Beat`) — Strapi сам сделает его во множественном числе в URL (`/api/beats`)
3. Добавляй поля через **"Add another field"**
4. Нажми **"Save"** — Strapi перезапустится и создаст таблицу

---

## Типы полей которые будешь использовать

| Тип в UI | Когда использовать | Пример |
|---|---|---|
| **Short text** | Короткие строки до 255 символов | title, name, key |
| **Long text** | Длинный текст | bio, description |
| **Integer** | Целое число | bpm, duration_seconds |
| **Decimal** | Число с дробью | price, balance |
| **Boolean** | true/false | enabled, is_onboarded |
| **Enumeration** | Фиксированный список значений | role, status, visibility |
| **Media** | Файлы/изображения | cover, audio_file, avatar |
| **Relation** | Связь с другой таблицей | producer -> User |
| **Date** | Дата или время | — (created_at есть автоматически) |

> `created_at` и `updated_at` Strapi добавляет **автоматически** — не нужно создавать вручную.

---

## Как создавать Enumeration (список значений)

1. Add field → **Enumeration**
2. Имя поля: напр. `visibility`
3. В поле Values введи каждое значение на **новой строке**:
   ```
   PUBLIC
   SOLD_EXCLUSIVE
   ```
4. Можешь выбрать default value

---

## Как создавать Media поле

1. Add field → **Media**
2. Выбери тип:
   - **Single media** — один файл (обложка, аватар)
   - **Multiple media** — несколько файлов
3. Можно ограничить тип: only images / only videos / all

Strapi автоматически отдаёт полный URL к файлу в ответе API.

---

## Как делать связи (Relations) — самое важное

Открой вкладку **Relation** при добавлении поля.  
Слева — текущая таблица, справа — выбираешь с какой таблицей связать.

### Типы связей визуально:

```
Beat  ──────────  User (producer)
many beats принадлежат одному юзеру
→ это "Many-to-One"

Beat  ──────────  Tag
один бит имеет много тегов, один тег на многих битах
→ это "Many-to-Many"

User  ──────────  Wallet
у одного юзера один кошелёк
→ это "One-to-One"

Beat  ──────────  BeatFile
один бит имеет много файлов (MP3, WAV, STEMS...)
→ это "One-to-Many"
```

### Таблица типов связей:

| Тип | Означает | Пример |
|---|---|---|
| **One to One** | A имеет одного B | User и Wallet |
| **One to Many** | A имеет много B | Beat имеет много BeatFile |
| **Many to One** | Много A принадлежат одному B | BeatFile принадлежит одному Beat |
| **Many to Many** | A и B связаны многократно с обеих сторон | Beat и Tag |

---

## Создание всех таблиц по порядку

> **Важно:** создавай в этом порядке, потому что некоторые таблицы ссылаются на другие.

---

### 1. Genre

**Content-Type Builder → Create new collection type → `Genre`**

| Поле | Тип | Настройки |
|---|---|---|
| `name` | Short text | ✅ Required |
| `icon` | Short text | — |

---

### 2. Tag

**Create new collection type → `Tag`**

| Поле | Тип | Настройки |
|---|---|---|
| `name` | Short text | ✅ Required |

---

### 3. Расширить встроенный User

Strapi уже имеет Users. Тебе нужно добавить доп. поля.

**Content-Type Builder → нажми на `User` (он уже есть) → Add another field**

| Поле | Тип | Настройки |
|---|---|---|
| `display_name` | Short text | — |
| `bio` | Long text | — |
| `avatar` | Media | Single media, only images |
| `app_role` | Enumeration | `guest`, `artist`, `producer`, `admin` |
| `is_onboarded` | Boolean | Default: false |

> Называй именно `app_role` — поле `role` уже занято системой Strapi для прав доступа.

---

### 4. Beat

**Create new collection type → `Beat`**

| Поле | Тип | Настройки |
|---|---|---|
| `title` | Short text | ✅ Required |
| `bpm` | Integer | — |
| `key` | Short text | — |
| `mood` | Short text | — |
| `price_base` | Decimal | ✅ Required |
| `duration_seconds` | Integer | — |
| `visibility` | Enumeration | `PUBLIC`, `SOLD_EXCLUSIVE` |
| `cover` | Media | Single media, only images |
| `audio_preview` | Media | Single media |

**Связи для Beat:**

1. **Beat → User (producer)**
   - Add field → Relation
   - Слева: `Beat`, Справа: `User`
   - Тип: **Many to One** (много битов → один продюсер)
   - Имя поля: `producer`

2. **Beat → Genre**
   - Add field → Relation
   - Слева: `Beat`, Справа: `Genre`
   - Тип: **Many to One** (много битов → один жанр)
   - Имя поля: `genre`

3. **Beat → Tag**
   - Add field → Relation
   - Слева: `Beat`, Справа: `Tag`
   - Тип: **Many to Many**
   - Имя поля: `tags`

---

### 5. BeatFile

**Create new collection type → `BeatFile`**

| Поле | Тип | Настройки |
|---|---|---|
| `file_type` | Enumeration | `MP3`, `WAV`, `STEMS`, `PROJECT`, `MELODY`, `EXCLUSIVE` |
| `price` | Decimal | ✅ Required |
| `license_type` | Enumeration | `lease`, `exclusive` |
| `audio_file` | Media | Single media |
| `enabled` | Boolean | Default: true |

> ⚠️ Называй `file_type`, а не `type`.

**Связь BeatFile → Beat:**
- Add field → Relation
- Слева: `BeatFile`, Справа: `Beat`
- Тип: **Many to One**
- Имя поля: `beat`

---

### 6. Wallet

**Create new collection type → `Wallet`**

| Поле | Тип | Настройки |
|---|---|---|
| `balance` | Decimal | Default: 0 |

**Связь Wallet → User:**
- Add field → Relation
- Слева: `Wallet`, Справа: `User`
- Тип: **One to One**
- Имя поля: `user`

---

### 7. WalletEntry

**Create new collection type → `WalletEntry`**

| Поле | Тип | Настройки |
|---|---|---|
| `amount` | Decimal | ✅ Required |
| `entry_type` | Enumeration | `topup`, `purchase`, `payout` |
| `description` | Short text | — |

> ⚠️ Называй `entry_type`, а не `type` — Strapi резервирует это слово.

**Связь WalletEntry → Wallet:**
- Add field → Relation
- Слева: `WalletEntry`, Справа: `Wallet`
- Тип: **Many to One**
- Имя поля: `wallet`

---

### 8. Chat

**Create new collection type → `Chat`**

Поля не нужны, только связи.

**Связи:**

1. **Chat → User (participants)**
   - Add field → Relation
   - Слева: `Chat`, Справа: `User`
   - Тип: **Many to Many**
   - Имя поля: `participants`

---

### 9. Message

**Create new collection type → `Message`**

| Поле | Тип | Настройки |
|---|---|---|
| `message_type` | Enumeration | `TEXT`, `FILE` |
| `text` | Long text | — |
| `file_attachment` | Media | Single media |

> ⚠️ Называй `message_type`, а не `type`.

**Связи:**

1. **Message → Chat**
   - Add field → Relation
   - Слева: `Message`, Справа: `Chat`
   - Тип: **Many to One**
   - Имя поля: `chat`

2. **Message → User (sender)**
   - Add field → Relation
   - Слева: `Message`, Справа: `User`
   - Тип: **Many to One**
   - Имя поля: `sender`

---

### 10. Purchase

**Create new collection type → `Purchase`**

| Поле | Тип | Настройки |
|---|---|---|
| `amount` | Decimal | ✅ Required |
| `purchase_status` | Enumeration | `pending`, `completed`, `cancelled`, `refunded` |
| `payment_provider` | Short text | — |
| `license_pdf` | Media | Single media |

> ⚠️ Называй именно `purchase_status`, а не `status` — Strapi резервирует это слово и не даст сохранить поле с таким именем.

**Связи:**

1. **Purchase → User**
   - Тип: **Many to One**, имя: `user`

2. **Purchase → BeatFile**
   - Тип: **Many to One**, имя: `beat_file`

---

## Настройка прав доступа

**Settings → Users & Permissions Plugin → Roles**

### Public (неавторизованные пользователи)

| Content Type | Разрешить |
|---|---|
| Beat | `find`, `findOne` |
| Genre | `find` |
| Tag | `find` |

### Authenticated (залогиненные)

| Content Type | Разрешить |
|---|---|
| Beat | `find`, `findOne`, `create`, `update` |
| BeatFile | `find`, `findOne` |
| Chat | `find`, `findOne`, `create` |
| Message | `find`, `findOne`, `create` |
| Purchase | `find`, `findOne`, `create` |
| Wallet | `find`, `findOne` |
| WalletEntry | `find` |

---

## Примеры REST запросов после настройки

```
# Список битов с жанром, тегами и продюсером
GET /api/beats?populate=genre,tags,producer,beat_files

# Конкретный бит со всем
GET /api/beats/1?populate=*

# Регистрация
POST /api/auth/local/register
Body: { "username": "vasya", "email": "v@v.com", "password": "123456" }

# Логин
POST /api/auth/local
Body: { "identifier": "v@v.com", "password": "123456" }

# Чат сообщения
GET /api/messages?filters[chat][id][$eq]=1&populate=sender&sort=createdAt:asc

# Кошелёк текущего юзера
GET /api/wallets?filters[user][id][$eq]=5&populate=wallet_entries
```

---

## Итог — порядок создания

1. ✅ Genre
2. ✅ Tag  
3. ✅ User (расширить поля)
4. ✅ Beat + связи (producer, genre, tags)
5. ✅ BeatFile + связь (beat)
6. ✅ Wallet + связь (user)
7. ✅ WalletEntry + связь (wallet)
8. ✅ Chat + связь (participants)
9. ✅ Message + связи (chat, sender)
10. ✅ Purchase + связи (user, beat_file)

Когда всё создано — сообщи, и следующий шаг: **полное удаление Drift из Flutter и замена на HTTP-запросы к Strapi**.
