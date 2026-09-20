-- +goose Up
ALTER TABLE profiles ADD COLUMN link_code text UNIQUE;

CREATE TABLE parent_sessions (
    token_hash text PRIMARY KEY,
    parent_id  uuid NOT NULL REFERENCES parents (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL
);

CREATE INDEX parent_sessions_parent_id_idx ON parent_sessions (parent_id);

-- +goose Down
DROP TABLE IF EXISTS parent_sessions;
ALTER TABLE profiles DROP COLUMN IF EXISTS link_code;
