// Сводки: dashboard, финансы, аналитика по периодам, лучшие товары.
//
// Оценочная прибыль: если продажа привязана к товару, себестоимость =
// продано штук × закупочная цена. Если товар не указан, себестоимость
// оценивается по среднему отношению закупочной цены к цене продажи
// среди товаров пользователя.
const express = require('express');
const db = require('../db');
const {
  optionalDate, requireNumber, todayLocal, addDays, daysBetween, weekStart, monthStart, round2, HttpError,
} = require('../utils');

const router = express.Router();

function avgCostRatio(userId) {
  const r = db.prepare(`
    SELECT AVG(purchase_price / selling_price) AS ratio
    FROM products WHERE user_id = ? AND selling_price > 0
  `).get(userId);
  return r && r.ratio ? Math.min(r.ratio, 1) : 0;
}

function salesInRange(userId, from, to) {
  return db.prepare(`
    SELECT s.*, p.purchase_price, p.name AS product_name
    FROM daily_sales s LEFT JOIN products p ON p.id = s.product_id
    WHERE s.user_id = ? AND s.date >= ? AND s.date <= ?
    ORDER BY s.date ASC, s.id ASC
  `).all(userId, from, to);
}

function saleCost(row, ratio) {
  // Себестоимость фиксируется в продаже, поэтому переживает удаление товара и смену цены.
  if (row.unit_cost !== null && row.unit_cost !== undefined) return { cost: row.items_sold * row.unit_cost, estimated: false };
  return { cost: row.total_amount * ratio, estimated: true };
}

function totals(rows, ratio) {
  let revenue = 0; let orders = 0; let items = 0; let cost = 0; let estimatedCost = 0;
  for (const r of rows) {
    const c = saleCost(r, ratio);
    revenue += r.total_amount;
    orders += r.orders_count;
    items += r.items_sold;
    cost += c.cost;
    if (c.estimated) estimatedCost += c.cost;
  }
  const profit = revenue - cost;
  return {
    revenue: round2(revenue),
    orders,
    items_sold: items,
    cost: round2(cost),
    profit: round2(profit),
    margin_percent: revenue > 0 ? round2((profit / revenue) * 100) : 0,
    avg_check: orders > 0 ? round2(revenue / orders) : 0,
    sales_count: rows.length,
    estimated_cost: round2(estimatedCost),
  };
}

function periodTotals(userId, from, to, ratio) {
  return totals(salesInRange(userId, from, to), ratio);
}

function changePercent(current, previous) {
  if (previous === 0) return current === 0 ? 0 : null; // null = «нет данных для сравнения»
  return round2(((current - previous) / Math.abs(previous)) * 100);
}

function bucketKey(date, group) {
  if (group === 'week') return weekStart(date);
  if (group === 'month') return monthStart(date);
  return date;
}

function nextBucket(key, group) {
  if (group === 'week') return addDays(key, 7);
  if (group === 'month') {
    const [y, m] = key.split('-').map(Number);
    return m === 12 ? `${y + 1}-01-01` : `${y}-${String(m + 1).padStart(2, '0')}-01`;
  }
  return addDays(key, 1);
}

/** Точки графика с нулями для пустых дней/недель/месяцев. */
function seriesPoints(rows, from, to, group, ratio) {
  const map = new Map();
  for (let k = bucketKey(from, group); k <= to; k = nextBucket(k, group)) {
    map.set(k, { period: k, revenue: 0, cost: 0, profit: 0, orders: 0, items_sold: 0 });
  }
  for (const r of rows) {
    const p = map.get(bucketKey(r.date, group));
    if (!p) continue;
    const { cost } = saleCost(r, ratio);
    p.revenue += r.total_amount;
    p.cost += cost;
    p.orders += r.orders_count;
    p.items_sold += r.items_sold;
  }
  return [...map.values()].map((p) => ({
    ...p,
    revenue: round2(p.revenue),
    cost: round2(p.cost),
    profit: round2(p.revenue - p.cost),
  }));
}

function topProducts(userId, from, to, limit, by = 'revenue') {
  const order = { revenue: 'revenue', items: 'items_sold', profit: 'profit' }[by] || 'revenue';
  return db.prepare(`
    SELECT p.id, p.name, p.image_url, p.stock, p.selling_price, p.purchase_price,
           SUM(s.items_sold) AS items_sold,
           SUM(s.total_amount) AS revenue,
           SUM(s.total_amount) - SUM(s.items_sold * COALESCE(s.unit_cost, p.purchase_price)) AS profit
    FROM daily_sales s JOIN products p ON p.id = s.product_id
    WHERE s.user_id = ? AND s.date >= ? AND s.date <= ?
    GROUP BY p.id
    ORDER BY ${order} DESC
    LIMIT ?
  `).all(userId, from, to, limit).map((r) => ({ ...r, revenue: round2(r.revenue), profit: round2(r.profit) }));
}

function resolveRange(query, defaultFrom) {
  const to = optionalDate(query.to, 'to') || optionalDate(query.today, 'today') || todayLocal();
  const from = optionalDate(query.from, 'from') || defaultFrom(to);
  if (from > to) throw new HttpError(400, 'Дата начала периода позже даты окончания');
  return { from, to };
}

router.get('/dashboard', (req, res) => {
  const userId = req.user.id;
  const today = optionalDate(req.query.today, 'today') || todayLocal();
  const threshold = req.query.low_stock_threshold
    ? requireNumber(req.query.low_stock_threshold, 'low_stock_threshold', { integer: true })
    : 5;
  const ratio = avgCostRatio(userId);

  const stock = db.prepare(`
    SELECT COUNT(*) AS products_count,
           COALESCE(SUM(stock), 0) AS total_units,
           COALESCE(SUM(stock * purchase_price), 0) AS stock_value,
           COALESCE(SUM(CASE WHEN stock > 0 THEN 1 ELSE 0 END), 0) AS in_stock_count
    FROM products WHERE user_id = ?
  `).get(userId);
  const lowStock = db.prepare(`
    SELECT id, name, stock, image_url FROM products
    WHERE user_id = ? AND stock <= ? ORDER BY stock ASC, name LIMIT 20
  `).all(userId, threshold);
  const recent = db.prepare(`
    SELECT s.*, p.name AS product_name FROM daily_sales s
    LEFT JOIN products p ON p.id = s.product_id
    WHERE s.user_id = ? ORDER BY s.date DESC, s.id DESC LIMIT 5
  `).all(userId);

  const chartFrom = addDays(today, -6);
  res.json({
    today: { date: today, ...periodTotals(userId, today, today, ratio) },
    week: { from: weekStart(today), to: today, ...periodTotals(userId, weekStart(today), today, ratio) },
    month: { from: monthStart(today), to: today, ...periodTotals(userId, monthStart(today), today, ratio) },
    stock: {
      products_count: stock.products_count,
      in_stock_count: stock.in_stock_count,
      total_units: stock.total_units,
      stock_value: round2(stock.stock_value),
      low_stock_threshold: threshold,
      low_stock_count: lowStock.length,
      low_stock: lowStock,
    },
    recent_sales: recent,
    chart: seriesPoints(salesInRange(userId, chartFrom, today), chartFrom, today, 'day', ratio),
  });
});

router.get('/finance', (req, res) => {
  const userId = req.user.id;
  const { from, to } = resolveRange(req.query, monthStart);
  const ratio = avgCostRatio(userId);
  const rows = salesInRange(userId, from, to);
  const length = daysBetween(from, to) + 1;
  const prevTo = addDays(from, -1);
  const prevFrom = addDays(prevTo, -(length - 1));
  const current = totals(rows, ratio);
  const previous = periodTotals(userId, prevFrom, prevTo, ratio);
  const stockValue = db.prepare(
    'SELECT COALESCE(SUM(stock * purchase_price), 0) AS v FROM products WHERE user_id = ?',
  ).get(userId).v;
  res.json({
    from,
    to,
    ...current,
    stock_value: round2(stockValue),
    avg_cost_ratio: round2(ratio),
    previous: { from: prevFrom, to: prevTo, ...previous },
    change: {
      revenue: changePercent(current.revenue, previous.revenue),
      profit: changePercent(current.profit, previous.profit),
    },
    by_day: seriesPoints(rows, from, to, 'day', ratio),
  });
});

router.get('/analytics', (req, res) => {
  const userId = req.user.id;
  const group = ['day', 'week', 'month'].includes(req.query.group) ? req.query.group : 'day';
  const defaults = {
    day: (to) => addDays(to, -29),
    week: (to) => addDays(weekStart(to), -7 * 11),
    month: (to) => {
      const d = new Date(`${monthStart(to)}T00:00:00Z`);
      d.setUTCMonth(d.getUTCMonth() - 11);
      return d.toISOString().slice(0, 10);
    },
  };
  const { from, to } = resolveRange(req.query, defaults[group]);
  const ratio = avgCostRatio(userId);
  const rows = salesInRange(userId, from, to);
  const length = daysBetween(from, to) + 1;
  const prevTo = addDays(from, -1);
  const prevFrom = addDays(prevTo, -(length - 1));
  const current = totals(rows, ratio);
  const previous = periodTotals(userId, prevFrom, prevTo, ratio);
  res.json({
    group,
    from,
    to,
    points: seriesPoints(rows, from, to, group, ratio),
    totals: current,
    previous: { from: prevFrom, to: prevTo, ...previous },
    change: {
      revenue: changePercent(current.revenue, previous.revenue),
      profit: changePercent(current.profit, previous.profit),
      orders: changePercent(current.orders, previous.orders),
      items_sold: changePercent(current.items_sold, previous.items_sold),
    },
    top_products: topProducts(userId, from, to, 5),
  });
});

router.get('/analytics/top-products', (req, res) => {
  const { from, to } = resolveRange(req.query, (t) => addDays(t, -29));
  const limit = req.query.limit ? Math.min(requireNumber(req.query.limit, 'limit', { integer: true, min: 1 }), 50) : 10;
  res.json({ from, to, items: topProducts(req.user.id, from, to, limit, req.query.by) });
});

module.exports = router;
