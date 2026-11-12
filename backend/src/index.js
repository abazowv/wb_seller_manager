const express = require('express');
const cors = require('cors');
const config = require('./config');
require('./db');
const auth = require('./middleware/auth');
const { HttpError } = require('./utils');

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use('/uploads', express.static(config.uploadsDir, { maxAge: '7d' }));

app.get('/api/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/products', auth, require('./routes/products'));
app.use('/api/sales', auth, require('./routes/sales'));
app.use('/api/stock-movements', auth, require('./routes/stockMovements'));
app.use('/api', auth, require('./routes/reports'));

app.use((req, res) => res.status(404).json({ error: 'Маршрут не найден' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err instanceof HttpError) return res.status(err.status).json({ error: err.message });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'Некорректный JSON' });
  if (err.code === 'SQLITE_CONSTRAINT_CHECK') return res.status(400).json({ error: 'Данные нарушают ограничения базы' });
  console.error(err);
  return res.status(500).json({ error: 'Внутренняя ошибка сервера' });
});

if (require.main === module) {
  const server = app.listen(config.port, config.host, () => {
    console.log(`WB Seller Manager API: http://localhost:${config.port}/api`);
    console.log(`Из Android-эмулятора: http://10.0.2.2:${config.port}/api`);
    console.log(`База данных SQLite: ${config.dbPath}`);
  });
  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`Порт ${config.port} уже занят (возможно, сервер уже запущен). Укажите другой PORT в .env.`);
    } else {
      console.error(err);
    }
    process.exit(1);
  });
}

module.exports = app;
