-- ============================================
-- МИГРАЦИЯ СХЕМЫ БД: v1 → v2
-- Обновление существующей БД под новые требования
-- ============================================
-- ВАЖНО: Выполняйте этот скрипт ПОСЛЕ того, как выполнили schema.sql
-- Этот скрипт безопасно обновит существующую БД

-- ============================================
-- 1. ОБНОВЛЕНИЕ ТАБЛИЦЫ users
-- ============================================

-- Добавляем новые колонки, если их нет
DO $$ 
BEGIN
    -- firebase_uid
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='firebase_uid') THEN
        ALTER TABLE users ADD COLUMN firebase_uid VARCHAR(255) UNIQUE;
    END IF;
    
    -- display_name
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='display_name') THEN
        ALTER TABLE users ADD COLUMN display_name VARCHAR(100);
    END IF;
    
    -- is_onboarded
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='is_onboarded') THEN
        ALTER TABLE users ADD COLUMN is_onboarded BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Обновляем role: добавляем 'guest' в CHECK, меняем DEFAULT
    -- Сначала удаляем старый CHECK
    ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
    -- Добавляем новый CHECK с 'guest'
    ALTER TABLE users ADD CONSTRAINT users_role_check 
        CHECK (role IN ('guest', 'artist', 'producer', 'admin'));
    -- Меняем DEFAULT
    ALTER TABLE users ALTER COLUMN role SET DEFAULT 'guest';
    
    -- Делаем username и email nullable (для гостей)
    ALTER TABLE users ALTER COLUMN username DROP NOT NULL;
    ALTER TABLE users ALTER COLUMN email DROP NOT NULL;
    
    -- Удаляем password_hash, если он есть (не нужен, используем Firebase)
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name='users' AND column_name='password_hash') THEN
        ALTER TABLE users DROP COLUMN password_hash;
    END IF;
END $$;

-- ============================================
-- 2. СОЗДАНИЕ НОВЫХ ТАБЛИЦ
-- ============================================

-- Связь пользователей и жанров (предпочтения)
CREATE TABLE IF NOT EXISTS user_genres_prefs (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    genre_id INTEGER NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, genre_id)
);

-- Покупки
CREATE TABLE IF NOT EXISTS purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    beat_file_id INTEGER NOT NULL REFERENCES beat_files(id) ON DELETE RESTRICT,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled', 'refunded')),
    payment_provider VARCHAR(50),
    payment_intent_id VARCHAR(255),
    license_url_pdf TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Записи кошелька
CREATE TABLE IF NOT EXISTS wallet_entries (
    id SERIAL PRIMARY KEY,
    producer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purchase_id UUID REFERENCES purchases(id) ON DELETE SET NULL,
    delta_amount DECIMAL(10, 2) NOT NULL,
    balance_after DECIMAL(10, 2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. ОБНОВЛЕНИЕ ТАБЛИЦЫ beats
-- ============================================

DO $$ 
BEGIN
    -- stream_url
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='beats' AND column_name='stream_url') THEN
        ALTER TABLE beats ADD COLUMN stream_url TEXT;
        -- Копируем audio_preview_url в stream_url для существующих записей
        UPDATE beats SET stream_url = audio_preview_url WHERE stream_url IS NULL;
        -- Делаем NOT NULL после заполнения
        ALTER TABLE beats ALTER COLUMN stream_url SET NOT NULL;
    END IF;
    
    -- visibility
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='beats' AND column_name='visibility') THEN
        ALTER TABLE beats ADD COLUMN visibility VARCHAR(20) NOT NULL DEFAULT 'PUBLIC';
        ALTER TABLE beats ADD CONSTRAINT beats_visibility_check 
            CHECK (visibility IN ('PUBLIC', 'SOLD_EXCLUSIVE'));
    END IF;
    
    -- Удаляем is_exclusive_available, если есть (заменено на visibility)
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name='beats' AND column_name='is_exclusive_available') THEN
        ALTER TABLE beats DROP COLUMN is_exclusive_available;
    END IF;
    
    -- Удаляем price_base, если есть (цены теперь в beat_files)
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name='beats' AND column_name='price_base') THEN
        ALTER TABLE beats DROP COLUMN price_base;
    END IF;
END $$;

-- ============================================
-- 4. ОБНОВЛЕНИЕ ТАБЛИЦЫ beat_files
-- ============================================

DO $$ 
BEGIN
    -- license_type
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='beat_files' AND column_name='license_type') THEN
        ALTER TABLE beat_files ADD COLUMN license_type VARCHAR(20) NOT NULL DEFAULT 'LEASE';
        ALTER TABLE beat_files ADD CONSTRAINT beat_files_license_type_check 
            CHECK (license_type IN ('LEASE', 'BUYOUT', 'EXCLUSIVE'));
    END IF;
    
    -- storage_path
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='beat_files' AND column_name='storage_path') THEN
        ALTER TABLE beat_files ADD COLUMN storage_path TEXT;
        -- Для существующих записей используем download_url как storage_path
        UPDATE beat_files SET storage_path = COALESCE(download_url, '') WHERE storage_path IS NULL;
        ALTER TABLE beat_files ALTER COLUMN storage_path SET NOT NULL;
    END IF;
    
    -- enabled
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='beat_files' AND column_name='enabled') THEN
        ALTER TABLE beat_files ADD COLUMN enabled BOOLEAN DEFAULT TRUE;
    END IF;
    
    -- Обновляем CHECK для type: добавляем MELODY
    ALTER TABLE beat_files DROP CONSTRAINT IF EXISTS beat_files_type_check;
    ALTER TABLE beat_files ADD CONSTRAINT beat_files_type_check 
        CHECK (type IN ('MP3', 'WAV', 'STEMS', 'PROJECT', 'MELODY', 'EXCLUSIVE'));
    
    -- Удаляем license_terms, если есть (заменено на license_type)
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name='beat_files' AND column_name='license_terms') THEN
        ALTER TABLE beat_files DROP COLUMN license_terms;
    END IF;
END $$;

-- ============================================
-- 5. ОБНОВЛЕНИЕ ТАБЛИЦЫ plays
-- ============================================

DO $$ 
BEGIN
    -- is_preview
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='plays' AND column_name='is_preview') THEN
        ALTER TABLE plays ADD COLUMN is_preview BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- ============================================
-- 6. ОБНОВЛЕНИЕ ТАБЛИЦЫ messages
-- ============================================

DO $$ 
BEGIN
    -- type
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='messages' AND column_name='type') THEN
        ALTER TABLE messages ADD COLUMN type VARCHAR(20) NOT NULL DEFAULT 'TEXT';
        ALTER TABLE messages ADD CONSTRAINT messages_type_check 
            CHECK (type IN ('TEXT', 'FILE'));
    END IF;
    
    -- file_attachment
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='messages' AND column_name='file_attachment') THEN
        ALTER TABLE messages ADD COLUMN file_attachment JSONB;
    END IF;
    
    -- Делаем text nullable (для FILE сообщений)
    ALTER TABLE messages ALTER COLUMN text DROP NOT NULL;
END $$;

-- ============================================
-- 7. ОБНОВЛЕНИЕ ТАБЛИЦЫ order_items
-- ============================================

DO $$ 
BEGIN
    -- purchase_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='order_items' AND column_name='purchase_id') THEN
        ALTER TABLE order_items ADD COLUMN purchase_id UUID REFERENCES purchases(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ============================================
-- 8. СОЗДАНИЕ ИНДЕКСОВ
-- ============================================

CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

CREATE INDEX IF NOT EXISTS idx_user_genres_prefs_user_id ON user_genres_prefs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_genres_prefs_genre_id ON user_genres_prefs(genre_id);

CREATE INDEX IF NOT EXISTS idx_beats_visibility ON beats(visibility);
CREATE INDEX IF NOT EXISTS idx_beats_stream_url ON beats(stream_url);

CREATE INDEX IF NOT EXISTS idx_beat_files_type ON beat_files(type);
CREATE INDEX IF NOT EXISTS idx_beat_files_enabled ON beat_files(enabled);
CREATE INDEX IF NOT EXISTS idx_beat_files_storage_path ON beat_files(storage_path);

CREATE INDEX IF NOT EXISTS idx_plays_is_preview ON plays(is_preview);

CREATE INDEX IF NOT EXISTS idx_purchases_user_id ON purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_purchases_beat_file_id ON purchases(beat_file_id);
CREATE INDEX IF NOT EXISTS idx_purchases_status ON purchases(status);

CREATE INDEX IF NOT EXISTS idx_wallet_entries_producer_id ON wallet_entries(producer_id);
CREATE INDEX IF NOT EXISTS idx_wallet_entries_created_at ON wallet_entries(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(type);

-- ============================================
-- 9. ОБНОВЛЕНИЕ ТРИГГЕРОВ
-- ============================================

-- Триггер для purchases.updated_at
DROP TRIGGER IF EXISTS update_purchases_updated_at ON purchases;
CREATE TRIGGER update_purchases_updated_at BEFORE UPDATE ON purchases
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Триггер для скрытия бита при покупке EXCLUSIVE
DROP FUNCTION IF EXISTS hide_beat_on_exclusive_purchase() CASCADE;
CREATE OR REPLACE FUNCTION hide_beat_on_exclusive_purchase()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND EXISTS (
        SELECT 1 FROM beat_files 
        WHERE id = NEW.beat_file_id AND type = 'EXCLUSIVE'
    ) THEN
        UPDATE beats 
        SET visibility = 'SOLD_EXCLUSIVE'
        WHERE id = (SELECT beat_id FROM beat_files WHERE id = NEW.beat_file_id);
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS hide_beat_on_exclusive ON purchases;
CREATE TRIGGER hide_beat_on_exclusive AFTER UPDATE OF status ON purchases
    FOR EACH ROW
    WHEN (NEW.status = 'completed' AND OLD.status != 'completed')
    EXECUTE FUNCTION hide_beat_on_exclusive_purchase();

-- Триггер для создания кошелька продюсера
DROP FUNCTION IF EXISTS create_wallet_for_producer() CASCADE;
CREATE OR REPLACE FUNCTION create_wallet_for_producer()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.role = 'producer' THEN
        INSERT INTO wallets (user_id, balance)
        VALUES (NEW.id, 0)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS create_wallet_on_producer_role ON users;
CREATE TRIGGER create_wallet_on_producer_role AFTER INSERT OR UPDATE OF role ON users
    FOR EACH ROW
    WHEN (NEW.role = 'producer')
    EXECUTE FUNCTION create_wallet_for_producer();

-- Триггер для добавления записи в кошелёк при покупке
DROP FUNCTION IF EXISTS add_wallet_entry_on_purchase() CASCADE;
CREATE OR REPLACE FUNCTION add_wallet_entry_on_purchase()
RETURNS TRIGGER AS $$
DECLARE
    v_producer_id UUID;
    v_beat_file_id INTEGER;
    v_amount DECIMAL(10, 2);
    v_new_balance DECIMAL(10, 2);
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        SELECT b.producer_id, NEW.beat_file_id, NEW.amount
        INTO v_producer_id, v_beat_file_id, v_amount
        FROM beat_files bf
        JOIN beats b ON b.id = bf.beat_id
        WHERE bf.id = NEW.beat_file_id;
        
        UPDATE wallets
        SET balance = balance + v_amount,
            updated_at = NOW()
        WHERE user_id = v_producer_id
        RETURNING balance INTO v_new_balance;
        
        INSERT INTO wallet_entries (producer_id, purchase_id, delta_amount, balance_after, description)
        VALUES (
            v_producer_id,
            NEW.id,
            v_amount,
            v_new_balance,
            'Продажа бита: ' || (SELECT title FROM beats WHERE id = (SELECT beat_id FROM beat_files WHERE id = v_beat_file_id))
        );
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS add_wallet_entry_on_purchase ON purchases;
CREATE TRIGGER add_wallet_entry_on_purchase AFTER UPDATE OF status ON purchases
    FOR EACH ROW
    WHEN (NEW.status = 'completed' AND OLD.status != 'completed')
    EXECUTE FUNCTION add_wallet_entry_on_purchase();

-- ============================================
-- 10. СОЗДАНИЕ ФУНКЦИЙ
-- ============================================

-- Проверка взаимной подписки
DROP FUNCTION IF EXISTS are_users_mutually_following(UUID, UUID);
CREATE OR REPLACE FUNCTION are_users_mutually_following(
    user1_id UUID,
    user2_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM follows
        WHERE (follower_id = user1_id AND followed_id = user2_id)
           OR (follower_id = user2_id AND followed_id = user1_id)
        HAVING COUNT(*) = 2
    );
END;
$$ language 'plpgsql';

-- Проверка формата файла
DROP FUNCTION IF EXISTS is_allowed_file_format(TEXT);
CREATE OR REPLACE FUNCTION is_allowed_file_format(
    file_name TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    file_ext TEXT;
BEGIN
    file_ext := LOWER(SUBSTRING(file_name FROM '\.([^.]+)$'));
    RETURN file_ext IN ('wav', 'flac', 'mp3', 'flp', 'als', 'alp', 'logicx', 'caf', 'patch', 'zip');
END;
$$ language 'plpgsql';

-- ============================================
-- ГОТОВО! ✅
-- ============================================
-- Миграция завершена. Ваша БД обновлена до версии v2.
-- Все существующие данные сохранены.

