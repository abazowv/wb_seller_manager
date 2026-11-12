// Smoke-тест API на временной базе: `npm test`.
const os = require('os');
const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'wbsm-'));
process.env.DB_PATH = path.join(tmpDir, 'test.db');
process.env.JWT_SECRET = 'test-secret';

const app = require('../src/index');

async function main() {
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}/api`;
  let token = null;

  async function call(method, url, body, expected) {
    const res = await fetch(base + url, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = res.status === 204 ? null : await res.json();
    assert.equal(res.status, expected, `${method} ${url}: ожидался ${expected}, получен ${res.status} ${JSON.stringify(data)}`);
    console.log(`ok  ${method} ${url} → ${res.status}`);
    return data;
  }

  try {
    await call('GET', '/products', null, 401);
    const reg = await call('POST', '/auth/register', { name: 'Тест', email: 'a@test.ru', password: 'secret1' }, 201);
    await call('POST', '/auth/register', { name: 'Тест', email: 'A@test.ru', password: 'secret1' }, 409);
    await call('POST', '/auth/login', { email: 'a@test.ru', password: 'wrong' }, 401);
    const login = await call('POST', '/auth/login', { email: 'a@test.ru', password: 'secret1' }, 200);
    assert.equal(login.user.id, reg.user.id);
    token = login.token;
    await call('GET', '/auth/me', null, 200);

    const p = await call('POST', '/products', {
      name: 'Футболка', description: 'Хлопок', purchase_price: 300, selling_price: 900, stock: 10,
    }, 201);
    assert.equal(p.stock, 10);
    await call('POST', '/stock-movements', { product_id: p.id, type: 'out', quantity: 11 }, 400);
    const out = await call('POST', '/stock-movements', { product_id: p.id, type: 'out', quantity: 4, description: 'Отгрузка' }, 201);
    assert.equal(out.product_stock, 6);
    await call('PUT', `/stock-movements/${out.id}`, { quantity: 11 }, 400);
    const upd = await call('PUT', `/stock-movements/${out.id}`, { quantity: 7 }, 200);
    assert.equal(upd.id, out.id);
    assert.equal(upd.product_stock, 3);
    await call('DELETE', `/stock-movements/${out.id}`, null, 204);

    const today = new Date().toISOString().slice(0, 10);
    const sale = await call('POST', '/sales', {
      date: today, orders_count: 3, items_sold: 3, total_amount: 2700, product_id: p.id,
    }, 201);
    let prod = await call('GET', `/products/${p.id}`, null, 200);
    assert.equal(prod.stock, 7);
    assert.equal(prod.stats.profit, 1800);
    await call('PUT', `/sales/${sale.id}`, { date: today, orders_count: 2, items_sold: 20, total_amount: 1 , product_id: p.id }, 400);
    await call('PUT', `/sales/${sale.id}`, { date: today, orders_count: 2, items_sold: 2, total_amount: 1800, product_id: p.id }, 200);
    prod = await call('GET', `/products/${p.id}`, null, 200);
    assert.equal(prod.stock, 8);
    await call('POST', '/sales', { date: today, orders_count: 1, items_sold: 1, total_amount: 1000 }, 201);
    await call('GET', `/sales?from=${today}&to=${today}`, null, 200);

    const dash = await call('GET', `/dashboard?today=${today}`, null, 200);
    assert.equal(dash.today.revenue, 2800);
    assert.equal(dash.stock.total_units, 8);
    await call('GET', `/finance?from=${today}&to=${today}`, null, 200);
    for (const g of ['day', 'week', 'month']) await call('GET', `/analytics?group=${g}`, null, 200);
    const top = await call('GET', '/analytics/top-products', null, 200);
    assert.equal(top.items[0].id, p.id);

    // Второй пользователь не видит чужие данные.
    const other = await call('POST', '/auth/register', { name: 'Другой', email: 'b@test.ru', password: 'secret2' }, 201);
    token = other.token;
    assert.equal((await call('GET', '/products', null, 200)).length, 0);
    await call('GET', `/products/${p.id}`, null, 404);
    await call('DELETE', `/sales/${sale.id}`, null, 404);

    token = login.token;
    await call('DELETE', `/sales/${sale.id}`, null, 204);
    prod = await call('GET', `/products/${p.id}`, null, 200);
    assert.equal(prod.stock, 10);
    // Прибыль прошлых продаж не меняется при смене цены и удалении товара.
    await call('POST', '/sales', { date: today, orders_count: 1, items_sold: 2, total_amount: 1800, product_id: p.id }, 201);
    await call('PUT', `/products/${p.id}`, { purchase_price: 800 }, 200);
    await call('DELETE', `/products/${p.id}`, null, 204);
    const fin = await call('GET', `/finance?from=${today}&to=${today}`, null, 200);
    assert.equal(fin.cost, 600, 'себестоимость считается по цене на момент продажи');
    console.log('\nВсе проверки пройдены');
  } finally {
    server.close();
    require('../src/db').close();
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

main().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
