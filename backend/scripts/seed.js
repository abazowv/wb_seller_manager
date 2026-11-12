// Демо-данные для показа проекта: `npm run seed`.
//
// Создаёт (или пересоздаёт) пользователя demo@wb.ru / demo123 с товарами,
// фотографиями, продажами за 180 дней и историей склада. Остальных
// пользователей не трогает. Данные генерируются детерминированно и
// относительно сегодняшней даты, поэтому графики всегда «свежие».
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const bcrypt = require('bcryptjs');
const db = require('../src/db');
const config = require('../src/config');
const { createMovement } = require('../src/stock');
const { todayLocal, addDays } = require('../src/utils');

const DEMO = { name: 'Демо-магазин', email: 'demo@wb.ru', password: 'demo123' };
const SALES_DAYS = 180;
const HISTORY_DAYS = 210;

// ---------- Детерминированный генератор случайных чисел ----------
let seed = 20261112;
function rand() {
  seed = (seed * 1664525 + 1013904223) % 4294967296;
  return seed / 4294967296;
}
const randInt = (min, max) => Math.floor(min + rand() * (max - min + 1));

// ---------- Простые PNG-картинки товаров (градиент + круг) ----------
const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
function makePng(file, [r1, g1, b1], [r2, g2, b2]) {
  const size = 256;
  const raw = Buffer.alloc((size * 3 + 1) * size);
  for (let y = 0; y < size; y++) {
    raw[y * (size * 3 + 1)] = 0;
    for (let x = 0; x < size; x++) {
      const t = (x + y) / (2 * size);
      const dx = x - 128;
      const dy = y - 118;
      const inCircle = dx * dx + dy * dy < 62 * 62;
      const k = inCircle ? 0.35 : 0; // светлый круг по центру
      const o = y * (size * 3 + 1) + 1 + x * 3;
      raw[o] = Math.round((r1 + (r2 - r1) * t) * (1 - k) + 255 * k);
      raw[o + 1] = Math.round((g1 + (g2 - g1) * t) * (1 - k) + 255 * k);
      raw[o + 2] = Math.round((b1 + (b2 - b1) * t) * (1 - k) + 255 * k);
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // глубина цвета
  ihdr[9] = 2; // RGB
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

// ---------- Каталог ----------
// daily — среднее число проданных штук в день; restockStop — за сколько дней
// до сегодня прекращаются поставки (чтобы на складе был «низкий остаток»).
const PRODUCTS = [
  { name: 'Футболка оверсайз, хлопок', description: 'Плотный хлопок 220 г/м², унисекс, размеры S–XXL', purchase: 450, price: 1290, daily: 3.2, batch: 120, colors: [[139, 31, 169], [203, 17, 171]] },
  { name: 'Худи базовое с капюшоном', description: 'Футер трёхнитка с начёсом, карман-кенгуру', purchase: 1150, price: 2990, daily: 1.6, batch: 60, colors: [[40, 53, 147], [92, 107, 192]] },
  { name: 'Джинсы прямые классические', description: 'Деним 12 oz, высокая посадка', purchase: 1400, price: 3490, daily: 1.1, batch: 40, colors: [[21, 101, 192], [100, 181, 246]] },
  { name: 'Кепка бейсболка однотонная', description: 'Регулируемый ремешок, 100% хлопок', purchase: 220, price: 690, daily: 2.4, batch: 80, restockStop: 30, colors: [[46, 125, 50], [129, 199, 132]] },
  { name: 'Носки высокие, набор 5 пар', description: 'Хлопок с эластаном, размер 36–41', purchase: 180, price: 590, daily: 4.5, batch: 150, colors: [[245, 124, 0], [255, 202, 40]] },
  { name: 'Сумка-шоппер холщовая', description: 'Плотный канвас, внутренний карман', purchase: 260, price: 790, daily: 1.3, batch: 50, restockStop: 25, endStock: 3, colors: [[121, 85, 72], [188, 170, 164]] },
  { name: 'Платье летнее миди', description: 'Вискоза, свободный крой, поясок в комплекте', purchase: 980, price: 2590, daily: 0.9, batch: 30, colors: [[216, 27, 96], [244, 143, 177]] },
  { name: 'Свитшот оверсайз', description: 'Футер двухнитка, принт на груди', purchase: 890, price: 2290, daily: 1.2, batch: 45, colors: [[0, 121, 107], [77, 182, 172]] },
];

function main() {
  const today = todayLocal();
  fs.mkdirSync(config.uploadsDir, { recursive: true });

  const result = db.transaction(() => {
    db.prepare('DELETE FROM users WHERE email = ?').run(DEMO.email); // каскадно удалит старые демо-данные
    const userId = Number(db.prepare('INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)')
      .run(DEMO.name, DEMO.email, bcrypt.hashSync(DEMO.password, 10)).lastInsertRowid);

    const insertProduct = db.prepare(`
      INSERT INTO products (user_id, name, description, purchase_price, selling_price, image_url, stock, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 0, ?)
    `);
    const insertSale = db.prepare(`
      INSERT INTO daily_sales (user_id, product_id, date, orders_count, items_sold, total_amount, unit_cost, note)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);
    const stockOf = db.prepare('SELECT stock FROM products WHERE id = ?');

    const products = PRODUCTS.map((p, i) => {
      const file = `demo-${i + 1}.png`;
      makePng(path.join(config.uploadsDir, file), ...p.colors);
      const startDate = addDays(today, -HISTORY_DAYS + i * 2);
      const id = Number(insertProduct.run(
        userId, p.name, p.description, p.purchase, p.price, `/uploads/${file}`, `${startDate} 10:00:00`,
      ).lastInsertRowid);
      createMovement(userId, {
        product_id: id, type: 'in', quantity: p.batch, date: startDate, description: 'Начальный остаток',
      });
      return { ...p, id, startDate };
    });

    let salesCount = 0;
    for (let d = SALES_DAYS - 1; d >= 0; d--) {
      const date = addDays(today, -d);
      const dow = new Date(`${date}T00:00:00Z`).getUTCDay();
      const weekend = dow === 0 || dow === 6 ? 1.3 : 1;
      const trend = 0.7 + 0.6 * ((SALES_DAYS - d) / SALES_DAYS); // продажи растут

      for (const p of products) {
        // Поставка, если товар заканчивается (кроме «последних дней» для части товаров).
        const stock = stockOf.get(p.id).stock;
        const canRestock = !p.restockStop || d > p.restockStop;
        if (canRestock && stock < p.daily * 7) {
          createMovement(userId, {
            product_id: p.id, type: 'in', quantity: p.batch, date, description: 'Поставка от поставщика',
          });
        }

        let items = Math.round(p.daily * trend * weekend * (0.4 + rand() * 1.2));
        items = Math.min(items, stockOf.get(p.id).stock);
        if (items <= 0) continue;
        const orders = Math.max(1, items - randInt(0, Math.floor(items / 3)));
        const discount = 0.85 + rand() * 0.15; // скидки и акции WB
        const amount = Math.round(items * p.price * discount);
        const saleId = Number(insertSale.run(
          userId, p.id, date, orders, items, amount, p.purchase, '',
        ).lastInsertRowid);
        createMovement(userId, {
          product_id: p.id, sale_id: saleId, type: 'out', quantity: items, date, description: 'Продажа',
        });
        salesCount++;
      }

      // Изредка — списание брака.
      if (d % 23 === 11) {
        const p = products[randInt(0, products.length - 1)];
        if (stockOf.get(p.id).stock > 2) {
          createMovement(userId, {
            product_id: p.id, type: 'out', quantity: randInt(1, 2), date, description: 'Списание: брак',
          });
        }
      }
    }

    // Итоговый остаток по инвентаризации — чтобы был пример «мало на складе».
    for (const p of products.filter((x) => x.endStock !== undefined)) {
      const diff = p.endStock - stockOf.get(p.id).stock;
      if (diff !== 0) {
        createMovement(userId, {
          product_id: p.id, type: diff > 0 ? 'in' : 'out', quantity: Math.abs(diff), date: today,
          description: 'Корректировка по инвентаризации',
        });
      }
    }

    // Пара продаж без привязки к товару (например, комплекты), чтобы было видно оценку себестоимости.
    for (const d of [3, 17]) {
      insertSale.run(userId, null, addDays(today, -d), 2, 4, 6400, null, 'Комплекты (без привязки к товару)');
      salesCount++;
    }

    return { userId, salesCount, products: products.length };
  })();

  const stocks = db.prepare('SELECT name, stock FROM products WHERE user_id = ? ORDER BY stock').all(result.userId);
  console.log(`Демо-данные загружены: ${result.products} товаров, ${result.salesCount} записей о продажах за ${SALES_DAYS} дней.`);
  console.log('Остатки:', stocks.map((s) => `${s.name}: ${s.stock}`).join('; '));
  console.log(`\nВход в приложение: ${DEMO.email} / ${DEMO.password}`);
}

main();
