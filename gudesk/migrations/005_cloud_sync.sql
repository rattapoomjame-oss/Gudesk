-- Migration 005: Cloud directory sync fields
ALTER TABLE devices ADD COLUMN password   TEXT NOT NULL DEFAULT '';
ALTER TABLE devices ADD COLUMN cloud_id   TEXT;
ALTER TABLE devices ADD COLUMN group_name TEXT NOT NULL DEFAULT '';
