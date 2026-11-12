const express = require('express');
const db = require('../db');
const { productOrThrow, createMovement, removeMovement } = require('../stock');
const {
  HttpError, requireDate, optionalDate, requireNumber, optionalString, parseId,
} = require('../utils');

const router = express.Router();

const SELECT_SALE = `
  SELECT s.*, p.name AS product_name
  FROM daily_sales s LEFT JOIN products p ON p.id = s.product_id
`;

function getOwned(userId, id) {
  const s = db.prepare(`${SELECT_SALE} WHERE s.id = ? AND s.user_id = ?`).get(id, userId);
  if (!s) throw new HttpError(404, 'Запись о продажах не найдена');
  return s;
}

function parseSaleBody(userId, body) {
  const productId = body.product_id === undefined || body.product_id === null || body.product_id === ''
    ? null
    : parseId(body.product_id, 'product_id');
  const unitCost = productId
    ? db.prepare('SELECT purchase_price FROM products WHERE id = ? AND user_id = ?').get(productId, userId)?.purchase_price
    : null;
  if (productId && unitCost === undefined) productOrThrow(userId, productId);
  const sale = {
    date: requireDate(body.date, 'Дата'),
    orders_count: requireNumber(body.orders_count ?? 0, 'Заказы', { integer: true }),
    items_sold: requireNumber(body.items_sold ?? 0, 'Продано штук', { integer: true }),
    total_amount: requireNumber(body.total_amount ?? 0, 'Сумма'),
    note: optionalString(body.note, 'Комментарий', { max: 500 }),
    product_id: productId,
    unit_cost: unitCost ?? null,
  };
  // По умолчанию продажа конкретного товара списывает его со склада.
  const writeOff = productId !== null && body.write_off_stock !== false && sale.items_sold > 0;
  return { sale, writeOff };
}

function linkedMovements(saleId) {
  return db.prepare('SELECT * FROM stock_movements WHERE sale_id = ?').all(saleId);
}

function writeOffForSale(userId, saleId, sale) {
  createMovement(userId, {
    product_id: sale.product_id,
    sale_id: saleId,
    type: 'out',
    quantity: sale.items_sold,
    date: sale.date,
    description: 'Продажа',
  });
}

router.get('/', (req, res) => {
  const from = optionalDate(req.query.from, 'from');
  const to = optionalDate(req.query.to, 'to');
  const where = ['s.user_id = ?'];
  const params = [req.user.id];
  if (from) { where.push('s.date >= ?'); params.push(from); }
  if (to) { where.push('s.date <= ?'); params.push(to); }
  if (req.query.product_id) { where.push('s.product_id = ?'); params.push(parseId(req.query.product_id)); }
  const limit = req.query.limit ? Math.min(requireNumber(req.query.limit, 'limit', { integer: true, min: 1 }), 1000) : 1000;
  const rows = db
    .prepare(`${SELECT_SALE} WHERE ${where.join(' AND ')} ORDER BY s.date DESC, s.id DESC LIMIT ${limit}`)
    .all(...params);
  res.json(rows);
});

router.get('/:id', (req, res) => {
  res.json(getOwned(req.user.id, parseId(req.params.id)));
});

router.post('/', (req, res) => {
  const { sale, writeOff } = parseSaleBody(req.user.id, req.body || {});
  const id = db.transaction(() => {
    const info = db.prepare(`
      INSERT INTO daily_sales (user_id, product_id, date, orders_count, items_sold, total_amount, unit_cost, note)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      req.user.id, sale.product_id, sale.date, sale.orders_count, sale.items_sold, sale.total_amount, sale.unit_cost, sale.note,
    );
    const saleId = Number(info.lastInsertRowid);
    if (writeOff) writeOffForSale(req.user.id, saleId, sale);
    return saleId;
  })();
  res.status(201).json(getOwned(req.user.id, id));
});

router.put('/:id', (req, res) => {
  const id = parseId(req.params.id);
  getOwned(req.user.id, id);
  const { sale, writeOff } = parseSaleBody(req.user.id, req.body || {});
  db.transaction(() => {
    // Возвращаем на склад то, что списала старая версия продажи, и списываем заново.
    for (const m of linkedMovements(id)) removeMovement(req.user.id, m);
    db.prepare(`
      UPDATE daily_sales
      SET product_id = ?, date = ?, orders_count = ?, items_sold = ?, total_amount = ?, unit_cost = ?, note = ?
      WHERE id = ?
    `).run(sale.product_id, sale.date, sale.orders_count, sale.items_sold, sale.total_amount, sale.unit_cost, sale.note, id);
    if (writeOff) writeOffForSale(req.user.id, id, sale);
  })();
  res.json(getOwned(req.user.id, id));
});

router.delete('/:id', (req, res) => {
  const id = parseId(req.params.id);
  getOwned(req.user.id, id);
  db.transaction(() => {
    for (const m of linkedMovements(id)) removeMovement(req.user.id, m);
    db.prepare('DELETE FROM daily_sales WHERE id = ?').run(id);
  })();
  res.status(204).end();
});

module.exports = router;
