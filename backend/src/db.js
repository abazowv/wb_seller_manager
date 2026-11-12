const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');
const config = require('./config');

fs.mkdirSync(path.dirname(config.dbPath), { recursive: true });

const db = new Database(config.dbPath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT    NOT NULL,
  email         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT    NOT NULL,
  created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS products (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name           TEXT    NOT NULL,
  description    TEXT    NOT NULL DEFAULT '',
  purchase_price REAL    NOT NULL DEFAULT 0 CHECK (purchase_price >= 0),
  selling_price  REAL    NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
  image_url      TEXT,
  stock          INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_products_user ON products(user_id);

CREATE TABLE IF NOT EXISTS daily_sales (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id   INTEGER REFERENCES products(id) ON DELETE SET NULL,
  date         TEXT    NOT NULL,
  orders_count INTEGER NOT NULL DEFAULT 0 CHECK (orders_count >= 0),
  items_sold   INTEGER NOT NULL DEFAULT 0 CHECK (items_sold >= 0),
  total_amount REAL    NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  unit_cost    REAL,   -- закупочная цена товара на момент продажи (для расчёта прибыли)
  note         TEXT    NOT NULL DEFAULT '',
  created_at   TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_sales_user_date ON daily_sales(user_id, date);

CREATE TABLE IF NOT EXISTS stock_movements (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id  INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sale_id     INTEGER REFERENCES daily_sales(id) ON DELETE SET NULL,
  type        TEXT    NOT NULL CHECK (type IN ('in', 'out')),
  quantity    INTEGER NOT NULL CHECK (quantity > 0),
  date        TEXT    NOT NULL,
  description TEXT    NOT NULL DEFAULT '',
  created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_moves_user_product ON stock_movements(user_id, product_id);
`);

// Миграция для баз, созданных до появления unit_cost.
const saleColumns = db.prepare('PRAGMA table_info(daily_sales)').all().map((c) => c.name);
if (!saleColumns.includes('unit_cost')) {
  db.exec('ALTER TABLE daily_sales ADD COLUMN unit_cost REAL');
  db.exec(`UPDATE daily_sales SET unit_cost = (SELECT purchase_price FROM products p WHERE p.id = daily_sales.product_id)
           WHERE product_id IS NOT NULL`);
}

module.exports = db;
