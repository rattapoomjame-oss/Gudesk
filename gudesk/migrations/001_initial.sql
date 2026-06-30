-- Phase 2: GuDesk local database schema

CREATE TABLE IF NOT EXISTS directories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL,
    parent_id   INTEGER REFERENCES directories(id) ON DELETE CASCADE,
    created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS devices (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    remote_id    TEXT    NOT NULL UNIQUE,
    alias        TEXT,
    directory_id INTEGER REFERENCES directories(id) ON DELETE SET NULL,
    tags         TEXT    NOT NULL DEFAULT '[]',
    notes        TEXT,
    last_seen    TEXT,
    status       TEXT    NOT NULL DEFAULT 'UNKNOWN',
    platform     TEXT,
    version      TEXT,
    color_label  TEXT,
    is_favorite  INTEGER NOT NULL DEFAULT 0,
    is_pinned    INTEGER NOT NULL DEFAULT 0,
    created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    remote_id   TEXT    NOT NULL,
    start_time  TEXT    NOT NULL DEFAULT (datetime('now')),
    end_time    TEXT,
    mode        TEXT    NOT NULL DEFAULT 'full_access',
    recorded    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS recordings (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    remote_id  TEXT    NOT NULL,
    filename   TEXT    NOT NULL,
    duration   INTEGER,
    created_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_devices_remote_id   ON devices(remote_id);
CREATE INDEX IF NOT EXISTS idx_devices_directory   ON devices(directory_id);
CREATE INDEX IF NOT EXISTS idx_sessions_remote_id  ON sessions(remote_id);
CREATE INDEX IF NOT EXISTS idx_recordings_session  ON recordings(session_id);
