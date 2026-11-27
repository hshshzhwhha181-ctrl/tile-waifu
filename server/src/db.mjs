// SQLite storage (node:sqlite, no native deps). WAL mode.
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  nick          TEXT    NOT NULL UNIQUE,
  nick_lc       TEXT    NOT NULL UNIQUE,         -- unicode lower-case key (SQLite NOCASE is ASCII-only)
  email         TEXT    NOT NULL DEFAULT '',
  password_hash TEXT,
  avatar        TEXT    NOT NULL DEFAULT 'mc',
  rp            INTEGER NOT NULL DEFAULT 0,
  pvp_elo       INTEGER NOT NULL DEFAULT 1000,
  wins          INTEGER NOT NULL DEFAULT 0,
  losses        INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS users_email_uq ON users(email) WHERE email <> '';  -- stored lower-cased
CREATE INDEX IF NOT EXISTS users_elo_idx ON users(pvp_elo DESC);

CREATE TABLE IF NOT EXISTS oauth_identities (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  provider     TEXT    NOT NULL CHECK (provider IN ('yandex','google','vk','telegram')),
  provider_uid TEXT    NOT NULL,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  profile_json TEXT    NOT NULL DEFAULT '{}',
  created_at   INTEGER NOT NULL,
  UNIQUE (provider, provider_uid)
);
CREATE INDEX IF NOT EXISTS oauth_user_idx ON oauth_identities(user_id);

CREATE TABLE IF NOT EXISTS sessions (
  token      TEXT    PRIMARY KEY,            -- sha256(token) hex; the raw token is never stored
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions(user_id);

CREATE TABLE IF NOT EXISTS player_saves (
  user_id    INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  save_json  TEXT    NOT NULL,
  version    INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS pvp_matches (
  id           INTEGER PRIMARY KEY,
  p1_id        INTEGER NOT NULL,
  p2_id        INTEGER,                      -- NULL for bot matches
  p2_bot_nick  TEXT,
  seed         INTEGER NOT NULL,
  winner_id    INTEGER,                      -- NULL: bot won or draw
  p1_score     INTEGER NOT NULL DEFAULT 0,
  p2_score     INTEGER NOT NULL DEFAULT 0,
  p1_elo_delta INTEGER NOT NULL DEFAULT 0,
  p2_elo_delta INTEGER NOT NULL DEFAULT 0,
  mode         TEXT    NOT NULL,
  reason       TEXT    NOT NULL,
  created_at   INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS pvp_p1_idx ON pvp_matches(p1_id);
CREATE INDEX IF NOT EXISTS pvp_p2_idx ON pvp_matches(p2_id);

CREATE TABLE IF NOT EXISTS leaderboard_raid (
  user_id    INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  stage_idx  INTEGER NOT NULL DEFAULT 0,
  damage     INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS raid_rank_idx ON leaderboard_raid(stage_idx DESC, damage DESC);
`;

export function openDb(path) {
  const full = resolve(path);
  mkdirSync(dirname(full), { recursive: true });
  const db = new DatabaseSync(full);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL; PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');
  db.exec(SCHEMA);
  db.exec(`DELETE FROM sessions WHERE expires_at < ${Math.floor(Date.now() / 1000)}`);
  return db;
}

/** Run fn inside BEGIN IMMEDIATE / COMMIT (rollback on throw). */
export function tx(db, fn) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const r = fn();
    db.exec('COMMIT');
    return r;
  } catch (e) {
    try { db.exec('ROLLBACK'); } catch { /* ignore */ }
    throw e;
  }
}
