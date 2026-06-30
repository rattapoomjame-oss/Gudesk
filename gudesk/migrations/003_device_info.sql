-- Phase 7: Device information fields captured from peer connections
ALTER TABLE devices ADD COLUMN hostname   TEXT NOT NULL DEFAULT '';
ALTER TABLE devices ADD COLUMN os_detail  TEXT NOT NULL DEFAULT '';
ALTER TABLE devices ADD COLUMN ip_last    TEXT NOT NULL DEFAULT '';
