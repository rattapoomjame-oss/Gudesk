-- Phase 4: add unique index on recordings.filename so directory scans are idempotent.
-- Applied in GdDb._onUpgrade when upgrading from version 1 to 2.
CREATE UNIQUE INDEX IF NOT EXISTS idx_recordings_filename ON recordings(filename);
