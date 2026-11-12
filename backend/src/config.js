const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const ROOT = path.join(__dirname, '..');

const config = {
  port: Number(process.env.PORT) || 3000,
  host: process.env.HOST || '0.0.0.0',
  jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  dbPath: path.resolve(ROOT, process.env.DB_PATH || 'data/wb_seller.db'),
  uploadsDir: path.join(ROOT, 'uploads'),
};

if (!process.env.JWT_SECRET) {
  console.warn('[config] JWT_SECRET не задан в .env — используется небезопасный ключ для разработки');
}

module.exports = config;
