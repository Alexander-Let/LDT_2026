-- +goose Up
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE profiles (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_token_hash text NOT NULL UNIQUE,
    display_name      text NOT NULL,
    created_at        timestamptz NOT NULL DEFAULT now(),
    state             jsonb NOT NULL DEFAULT '{}'::jsonb,
    state_version     integer NOT NULL DEFAULT 0,
    updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE content_bundles (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version      integer NOT NULL UNIQUE,
    payload      jsonb NOT NULL,
    published_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE parents (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email      citext NOT NULL UNIQUE,
    consent_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE parent_otp (
    email      citext PRIMARY KEY,
    code_hash  text NOT NULL,
    expires_at timestamptz NOT NULL
);

CREATE TABLE parent_profile_links (
    parent_id  uuid NOT NULL REFERENCES parents (id) ON DELETE CASCADE,
    profile_id uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (parent_id, profile_id)
);

CREATE TABLE parent_bonuses (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    profile_id uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
    amount     integer NOT NULL CHECK (amount > 0),
    reason     text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    applied_at timestamptz
);

-- +goose Down
DROP TABLE IF EXISTS parent_bonuses;
DROP TABLE IF EXISTS parent_profile_links;
DROP TABLE IF EXISTS parent_otp;
DROP TABLE IF EXISTS parents;
DROP TABLE IF EXISTS content_bundles;
DROP TABLE IF EXISTS profiles;
