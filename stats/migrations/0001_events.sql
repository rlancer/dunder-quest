-- One row per gameplay event. Players are an anonymous install id, nothing else.
CREATE TABLE events (
  id INTEGER PRIMARY KEY,
  received_at INTEGER NOT NULL,
  install_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  platform TEXT NOT NULL,
  version TEXT NOT NULL,
  type TEXT NOT NULL,
  stage INTEGER,
  at INTEGER NOT NULL,
  data TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX events_type_stage ON events (type, stage);
CREATE INDEX events_received ON events (received_at);
CREATE INDEX events_install ON events (install_id);
