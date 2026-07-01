-- Migration 004: Chat message history
CREATE TABLE IF NOT EXISTS chat_messages (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id  TEXT    NOT NULL,
  direction  TEXT    NOT NULL CHECK(direction IN ('outgoing', 'incoming')),
  sender     TEXT    NOT NULL DEFAULT '',
  text       TEXT    NOT NULL,
  created_at TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_chat_remote_id  ON chat_messages(remote_id);
CREATE INDEX IF NOT EXISTS idx_chat_created_at ON chat_messages(created_at);
