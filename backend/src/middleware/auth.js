const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../db');

const findUser = db.prepare('SELECT id, name, email, created_at FROM users WHERE id = ?');

function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Требуется авторизация' });
  }
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    const user = findUser.get(payload.sub);
    if (!user) return res.status(401).json({ error: 'Пользователь не найден' });
    req.user = user;
    return next();
  } catch {
    return res.status(401).json({ error: 'Сессия истекла, войдите снова' });
  }
}

module.exports = auth;
