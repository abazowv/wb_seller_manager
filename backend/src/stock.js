// Общая логика складских движений: пересчёт остатка товара с проверкой,
// что он не уходит в минус. Вызывать только внутри db.transaction().
const db = require('./db');
const { HttpError } = require('./utils');

const getProduct = db.prepare('SELECT id, name, stock FROM products WHERE id = ? AND user_id = ?');
const setStock = db.prepare("UPDATE products SET stock = ?, updated_at = datetime('now') WHERE id = ?");
const insertMove = db.prepare(`
  INSERT INTO stock_movements (user_id, product_id, sale_id, type, quantity, date, description)
  VALUES (@user_id, @product_id, @sale_id, @type, @quantity, @date, @description)
`);
const deleteMove = db.prepare('DELETE FROM stock_movements WHERE id = ?');

function productOrThrow(userId, productId) {
  const p = getProduct.get(productId, userId);
  if (!p) throw new HttpError(404, 'Товар не найден');
  return p;
}

/** Меняет остаток на delta. Ошибка 400, если остаток станет отрицательным. */
function changeStock(userId, productId, delta, errorMessage) {
  const p = productOrThrow(userId, productId);
  const next = p.stock + delta;
  if (next < 0) {
    throw new HttpError(
      400,
      errorMessage || `Недостаточно товара «${p.name}» на складе: остаток ${p.stock} шт., требуется ${-delta} шт.`,
    );
  }
  setStock.run(next, productId);
  return next;
}

/** Применяет движение к остатку товара (без записи в историю). */
function applyEffect(userId, { product_id, type, quantity }) {
  changeStock(userId, product_id, type === 'in' ? quantity : -quantity);
}

/** Откатывает влияние движения на остаток (без удаления записи). */
function revertEffect(userId, move) {
  if (move.type === 'in') {
    changeStock(
      userId,
      move.product_id,
      -move.quantity,
      'Нельзя отменить приход: часть товара уже списана, остаток станет отрицательным',
    );
  } else {
    changeStock(userId, move.product_id, move.quantity);
  }
}

/** Создаёт движение и применяет его к остатку. */
function createMovement(userId, { product_id, sale_id = null, type, quantity, date, description = '' }) {
  applyEffect(userId, { product_id, type, quantity });
  const info = insertMove.run({ user_id: userId, product_id, sale_id, type, quantity, date, description });
  return info.lastInsertRowid;
}

/** Откатывает влияние движения на остаток и удаляет его. */
function removeMovement(userId, move) {
  revertEffect(userId, move);
  deleteMove.run(move.id);
}

module.exports = {
  productOrThrow, applyEffect, revertEffect, createMovement, removeMovement,
};
