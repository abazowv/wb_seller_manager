const express = require('express');
const db = require('../db');
const {
  applyEffect, revertEffect, createMovement, removeMovement,
} = require('../stock');
const {
  HttpError, requireDate, optionalDate, requireNumber, optionalString, parseId, todayLocal,
} = require('../utils');

const router = express.Router();

const SELECT_MOVE = `
  SELECT m.*, p.name AS product_name, p.stock AS product_stock
  FROM stock_movements m JOIN products p ON p.id = m.product_id
`;

function getOwned(userId, id) {
  const m = db.prepare(`${SELECT_MOVE} WHERE m.id = ? AND m.user_id = ?`).get(id, userId);
  if (!m) throw new HttpError(404, 'Движение не найдено');
  return m;
}

function parseBody(body) {
  if (body.type !== 'in' && body.type !== 'out') {
    throw new HttpError(400, 'Тип движения должен быть «in» (приход) или «out» (расход)');
  }
  return {
    product_id: parseId(body.product_id, 'product_id'),
    type: body.type,
    quantity: requireNumber(body.quantity, 'Количество', { integer: true, min: 1 }),
    date: body.date ? requireDate(body.date, 'Дата') : todayLocal(),
    description: optionalString(body.description, 'Описание', { max: 500 }),
  };
}

router.get('/', (req, res) => {
  const where = ['m.user_id = ?'];
  const params = [req.user.id];
  if (req.query.product_id) { where.push('m.product_id = ?'); params.push(parseId(req.query.product_id)); }
  if (req.query.type === 'in' || req.query.type === 'out') { where.push('m.type = ?'); params.push(req.query.type); }
  const from = optionalDate(req.query.from, 'from');
  const to = optionalDate(req.query.to, 'to');
  if (from) { where.push('m.date >= ?'); params.push(from); }
  if (to) { where.push('m.date <= ?'); params.push(to); }
  const rows = db
    .prepare(`${SELECT_MOVE} WHERE ${where.join(' AND ')} ORDER BY m.date DESC, m.id DESC LIMIT 1000`)
    .all(...params);
  res.json(rows);
});

router.get('/:id', (req, res) => {
  res.json(getOwned(req.user.id, parseId(req.params.id)));
});

router.post('/', (req, res) => {
  const data = parseBody(req.body || {});
  const id = db.transaction(() => createMovement(req.user.id, data))();
  res.status(201).json(getOwned(req.user.id, Number(id)));
});

router.put('/:id', (req, res) => {
  const id = parseId(req.params.id);
  const existing = getOwned(req.user.id, id);
  if (existing.sale_id) {
    throw new HttpError(400, 'Это списание создано продажей — измените саму запись о продаже');
  }
  const data = parseBody({ ...existing, ...(req.body || {}) });
  db.transaction(() => {
    revertEffect(req.user.id, existing);
    applyEffect(req.user.id, data);
    db.prepare(`
      UPDATE stock_movements SET product_id = ?, type = ?, quantity = ?, date = ?, description = ?
      WHERE id = ?
    `).run(data.product_id, data.type, data.quantity, data.date, data.description, id);
  })();
  res.json(getOwned(req.user.id, id));
});

router.delete('/:id', (req, res) => {
  const id = parseId(req.params.id);
  const existing = getOwned(req.user.id, id);
  if (existing.sale_id) {
    throw new HttpError(400, 'Это списание создано продажей — удалите саму запись о продаже');
  }
  db.transaction(() => removeMovement(req.user.id, existing))();
  res.status(204).end();
});

module.exports = router;
