-- +goose Up
CREATE TABLE profile_devices (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    profile_id        uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
    device_token_hash text NOT NULL UNIQUE,
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX profile_devices_profile_id_idx ON profile_devices (profile_id);

-- +goose Down
DROP TABLE IF EXISTS profile_devices;
