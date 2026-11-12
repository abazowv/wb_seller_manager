const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const multer = require('multer');
const db = require('../db');
const config = require('../config');
const { createMovement } = require('../stock');
const {
  HttpError, requireString, optionalString, requireNumber, parseId, todayLocal, round2,
} = require('../utils');

const router = express.Router();

fs.mkdirSync(config.uploadsDir, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: config.uploadsDir,
    filename: (req, file, cb) => {
      const ext = (path.extname(file.originalname) || '.jpg').toLowerCase();
      cb(null, `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`);
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const okExt = /\.(jpe?g|png|webp|gif|heic)$/i.test(file.originalname);
    if (file.mimetype.startsWith('image/') || okExt) cb(null, true);
    else cb(new HttpError(400, 'Можно загружать только изображения'));
  },
});

function getOwned(userId, id) {
  const p = db.prepare('SELECT * FROM products WHERE id = ? AND user_id = ?').get(id, userId);
  if (!p) throw new HttpError(404, 'Товар не найден');
  return p;
}

function removeImageFile(imageUrl) {
  if (!imageUrl || !imageUrl.startsWith('/uploads/')) return;
  const file = path.join(config.uploadsDir, path.basename(imageUrl));
  fs.unlink(file, () => {});
}

function parseProductBody(body, existing) {
  const src = { ...(existing || {}), ...body };
  return {
    name: requireString(src.name, 'Название', { max: 200 }),
    description: optionalString(src.description, 'Описание', { max: 2000 }),
    purchase_price: requireNumber(src.purchase_price ?? 0, 'Закупочная цена'),
    selling_price: requireNumber(src.selling_price ?? 0, 'Цена продажи'),
  };
}

router.get('/', (req, res) => {
  const { search, low_stock, sort } = req.query;
  const where = ['user_id = ?'];
  const params = [req.user.id];
  if (search) {
    where.push('(name LIKE ? OR description LIKE ?)');
    params.push(`%${search}%`, `%${search}%`);
  }
  if (low_stock !== undefined && low_stock !== '') {
    where.push('stock <= ?');
    params.push(requireNumber(low_stock, 'low_stock', { integer: true }));
  }
  const order = {
    name: 'name COLLATE NOCASE ASC',
    stock: 'stock ASC',
    price: 'selling_price DESC',
    newest: 'id DESC',
  }[sort] || 'id DESC';
  const rows = db
    .prepare(`SELECT * FROM products WHERE ${where.join(' AND ')} ORDER BY ${order}`)
    .all(...params);
  res.json(rows);
});

router.get('/:id', (req, res) => {
  const id = parseId(req.params.id);
  const product = getOwned(req.user.id, id);
  const sales = db.prepare(`
    SELECT COALESCE(SUM(items_sold), 0) AS items_sold,
           COALESCE(SUM(total_amount), 0) AS revenue,
           COALESCE(SUM(items_sold * COALESCE(unit_cost, ?)), 0) AS cost,
           COUNT(*) AS sales_count
    FROM daily_sales WHERE user_id = ? AND product_id = ?
  `).get(product.purchase_price, req.user.id, id);
  const moves = db.prepare(`
    SELECT COALESCE(SUM(CASE WHEN type = 'in' THEN quantity END), 0) AS total_in,
           COALESCE(SUM(CASE WHEN type = 'out' THEN quantity END), 0) AS total_out
    FROM stock_movements WHERE user_id = ? AND product_id = ?
  `).get(req.user.id, id);
  const { cost } = sales;
  res.json({
    ...product,
    stats: {
      unit_profit: round2(product.selling_price - product.purchase_price),
      margin_percent: product.selling_price > 0
        ? round2(((product.selling_price - product.purchase_price) / product.selling_price) * 100)
        : 0,
      items_sold: sales.items_sold,
      sales_count: sales.sales_count,
      revenue: round2(sales.revenue),
      cost: round2(cost),
      profit: round2(sales.revenue - cost),
      stock_value: round2(product.stock * product.purchase_price),
      total_in: moves.total_in,
      total_out: moves.total_out,
    },
  });
});

router.post('/', (req, res) => {
  const body = req.body || {};
  const data = parseProductBody(body);
  const stock = requireNumber(body.stock ?? 0, 'Остаток', { integer: true });
  const imageUrl = typeof body.image_url === 'string' && body.image_url ? body.image_url : null;

  const id = db.transaction(() => {
    const info = db.prepare(`
      INSERT INTO products (user_id, name, description, purchase_price, selling_price, image_url, stock)
      VALUES (?, ?, ?, ?, ?, ?, 0)
    `).run(req.user.id, data.name, data.description, data.purchase_price, data.selling_price, imageUrl);
    const productId = Number(info.lastInsertRowid);
    if (stock > 0) {
      createMovement(req.user.id, {
        product_id: productId, type: 'in', quantity: stock, date: todayLocal(), description: 'Начальный остаток',
      });
    }
    return productId;
  })();

  res.status(201).json(getOwned(req.user.id, id));
});

router.put('/:id', (req, res) => {
  const id = parseId(req.params.id);
  const existing = getOwned(req.user.id, id);
  const body = req.body || {};
  const data = parseProductBody(body, existing);
  const newStock = body.stock === undefined
    ? existing.stock
    : requireNumber(body.stock, 'Остаток', { integer: true });
  const imageUrl = body.image_url === undefined ? existing.image_url : (body.image_url || null);

  db.transaction(() => {
    db.prepare(`
      UPDATE products
      SET name = ?, description = ?, purchase_price = ?, selling_price = ?, image_url = ?, updated_at = datetime('now')
      WHERE id = ?
    `).run(data.name, data.description, data.purchase_price, data.selling_price, imageUrl, id);
    const diff = newStock - existing.stock;
    if (diff !== 0) {
      createMovement(req.user.id, {
        product_id: id,
        type: diff > 0 ? 'in' : 'out',
        quantity: Math.abs(diff),
        date: todayLocal(),
        description: 'Корректировка остатка',
      });
    }
  })();

  if (existing.image_url && existing.image_url !== imageUrl) removeImageFile(existing.image_url);
  res.json(getOwned(req.user.id, id));
});

router.delete('/:id', (req, res) => {
  const id = parseId(req.params.id);
  const existing = getOwned(req.user.id, id);
  db.prepare('DELETE FROM products WHERE id = ?').run(id);
  removeImageFile(existing.image_url);
  res.status(204).end();
});

router.post('/:id/image', (req, res, next) => {
  const id = parseId(req.params.id);
  const existing = getOwned(req.user.id, id);
  upload.single('image')(req, res, (err) => {
    if (err) {
      if (err instanceof multer.MulterError) return next(new HttpError(400, `Ошибка загрузки: ${err.message}`));
      return next(err);
    }
    if (!req.file) return next(new HttpError(400, 'Файл изображения не передан (поле «image»)'));
    const url = `/uploads/${req.file.filename}`;
    db.prepare("UPDATE products SET image_url = ?, updated_at = datetime('now') WHERE id = ?").run(url, id);
    removeImageFile(existing.image_url);
    return res.json(getOwned(req.user.id, id));
  });
});

module.exports = router;
