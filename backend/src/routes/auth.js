const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../db');
const config = require('../config');
const auth = require('../middleware/auth');
const { HttpError, requireString } = require('../utils');

const router = express.Router();
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function issueToken(user) {
  return jwt.sign({ sub: user.id }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
}

router.post('/register', (req, res) => {
  const body = req.body || {};
  const name = requireString(body.name, 'Имя', { max: 100 });
  const email = requireString(body.email, 'Email', { max: 200 }).toLowerCase();
  const password = typeof body.password === 'string' ? body.password : '';
  if (!EMAIL_RE.test(email)) throw new HttpError(400, 'Некорректный email');
  if (password.length < 6) throw new HttpError(400, 'Пароль должен быть не короче 6 символов');

  if (db.prepare('SELECT 1 FROM users WHERE email = ?').get(email)) {
    throw new HttpError(409, 'Пользователь с таким email уже зарегистрирован');
  }

  const hash = bcrypt.hashSync(password, 10);
  const info = db
    .prepare('INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)')
    .run(name, email, hash);
  const user = db.prepare('SELECT id, name, email, created_at FROM users WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json({ token: issueToken(user), user });
});

router.post('/login', (req, res) => {
  const body = req.body || {};
  const email = requireString(body.email, 'Email').toLowerCase();
  const password = typeof body.password === 'string' ? body.password : '';
  const row = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!row || !bcrypt.compareSync(password, row.password_hash)) {
    throw new HttpError(401, 'Неверный email или пароль');
  }
  const user = { id: row.id, name: row.name, email: row.email, created_at: row.created_at };
  res.json({ token: issueToken(user), user });
});

router.get('/me', auth, (req, res) => {
  res.json({ user: req.user });
});

module.exports = router;
