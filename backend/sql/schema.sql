CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_id TEXT NOT NULL,
    content TEXT NOT NULL,
    visible BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_answers_user_id ON answers(user_id);
CREATE INDEX IF NOT EXISTS idx_answers_visible ON answers(user_id, visible);

CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT friendships_no_self CHECK (user_a <> user_b),
    CONSTRAINT friendships_unique_pair UNIQUE (user_a, user_b)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user_a ON friendships(user_a);
CREATE INDEX IF NOT EXISTS idx_friendships_user_b ON friendships(user_b);
