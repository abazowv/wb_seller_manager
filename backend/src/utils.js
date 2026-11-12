class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function isValidDate(value) {
  if (typeof value !== 'string' || !DATE_RE.test(value)) return false;
  const d = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
}

function requireDate(value, field) {
  if (!isValidDate(value)) throw new HttpError(400, `Поле «${field}» должно быть датой в формате ГГГГ-ММ-ДД`);
  return value;
}

function optionalDate(value, field) {
  if (value === undefined || value === null || value === '') return null;
  return requireDate(value, field);
}

function requireString(value, field, { max = 500, allowEmpty = false } = {}) {
  if (typeof value !== 'string') throw new HttpError(400, `Поле «${field}» обязательно`);
  const v = value.trim();
  if (!allowEmpty && v.length === 0) throw new HttpError(400, `Поле «${field}» не может быть пустым`);
  if (v.length > max) throw new HttpError(400, `Поле «${field}» слишком длинное (макс. ${max})`);
  return v;
}

function optionalString(value, field, opts = {}) {
  if (value === undefined || value === null) return '';
  return requireString(String(value), field, { ...opts, allowEmpty: true });
}

function requireNumber(value, field, { min = 0, integer = false } = {}) {
  const n = typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
  if (typeof n !== 'number' || !Number.isFinite(n)) throw new HttpError(400, `Поле «${field}» должно быть числом`);
  if (integer && !Number.isInteger(n)) throw new HttpError(400, `Поле «${field}» должно быть целым числом`);
  if (n < min) throw new HttpError(400, `Поле «${field}» не может быть меньше ${min}`);
  return n;
}

function parseId(value, field = 'id') {
  const n = Number(value);
  if (!Number.isInteger(n) || n <= 0) throw new HttpError(400, `Некорректный ${field}`);
  return n;
}

/** Дата в формате ГГГГ-ММ-ДД, сдвинутая на days дней. */
function addDays(dateStr, days) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function daysBetween(from, to) {
  return Math.round((new Date(`${to}T00:00:00Z`) - new Date(`${from}T00:00:00Z`)) / 86400000);
}

function todayLocal() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** Понедельник недели, в которую попадает дата. */
function weekStart(dateStr) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  const dow = (d.getUTCDay() + 6) % 7; // 0 = понедельник
  return addDays(dateStr, -dow);
}

function monthStart(dateStr) {
  return `${dateStr.slice(0, 7)}-01`;
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

module.exports = {
  HttpError,
  isValidDate,
  requireDate,
  optionalDate,
  requireString,
  optionalString,
  requireNumber,
  parseId,
  addDays,
  daysBetween,
  todayLocal,
  weekStart,
  monthStart,
  round2,
};
