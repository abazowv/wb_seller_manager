# WB Seller Manager

Мобильное приложение для продавцов Wildberries: учёт продаж за день, товаров, склада, финансов и аналитики.

```
Flutter UI → BLoC → Repository → REST API (dio) → Node.js / Express → SQLite
```

> По ТЗ предполагался PostgreSQL. По просьбе заказчика используется **SQLite** (`better-sqlite3`):
> база — один файл `backend/data/wb_seller.db`, отдельный сервер СУБД ставить не нужно.

## Структура

```
wb_seller_manager/
├── backend/                     Node.js + Express + SQLite
│   ├── src/
│   │   ├── index.js             запуск сервера, маршруты, обработка ошибок
│   │   ├── db.js                схема SQLite (создаётся автоматически)
│   │   ├── stock.js             пересчёт остатков, запрет ухода в минус
│   │   ├── middleware/auth.js   проверка JWT
│   │   └── routes/              auth, products, sales, stockMovements, reports
│   ├── test/smoke.js            автотест API (npm test)
│   └── uploads/                 загруженные фото товаров (раздаются статикой)
└── mobile/                      Flutter (Android + iOS)
    └── lib/
        ├── core/                ApiClient (dio + JWT), настройки, тема, форматирование, шина изменений
        ├── models/              User, Product, Sale, StockMovement, отчёты
        ├── repositories/        Auth, Product, Sales, Inventory, Reports
        ├── blocs/               Auth, Settings, Dashboard, Sales, Products, ProductDetails, Inventory, Finance, Analytics
        ├── screens/             все экраны
        └── widgets/             карточки, графики fl_chart, выбор периода, лист прихода/расхода
```

## Требования

- Node.js 18+ (проверено на 24)
- Flutter 3.38+ (проверено на 3.47), Android SDK, эмулятор Android (или iOS-симулятор на macOS)

## Запуск

### 1. Бэкенд

```bash
cd backend
npm install
cp .env.example .env     # и задайте свой JWT_SECRET
npm start                # http://localhost:3000/api
```

Таблицы создаются автоматически при первом запуске. Сервер слушает `0.0.0.0:3000`.
Проверка: `http://localhost:3000/api/health`. Автотест API: `npm test` (на временной базе).

### 2. Мобильное приложение

**Android Studio:** откройте папку `mobile/`, выберите эмулятор и нажмите **Run** с конфигурацией
**WB Seller Manager** (или `main.dart`).

**Командная строка:**

```bash
cd mobile
flutter pub get
flutter run
```

Адрес API по умолчанию:

| Где запущено | Адрес |
|---|---|
| Android-эмулятор | `http://10.0.2.2:3000/api` (это `localhost` компьютера) |
| iOS-симулятор | `http://localhost:3000/api` |

Для реального телефона в той же Wi-Fi сети укажите IP компьютера:

```bash
flutter run --dart-define=API_URL=http://192.168.1.10:3000/api
```

В Android Studio то же самое: *Edit Configurations → Additional run args*.
Для Android включён `usesCleartextTraffic`, для iOS — `NSAllowsLocalNetworking`, чтобы работал локальный HTTP.

### Если сборка Android падает с `Unable to establish loopback connection`

Это ошибка JDK (Gradle), а не проекта: на некоторых машинах антивирус или политика безопасности
запрещают служебные сокеты JDK в папке `%TEMP%`. Помогает указать другой каталог:

```powershell
mkdir $env:USERPROFILE\.jtmp
setx JAVA_TOOL_OPTIONS "-Djdk.net.unixdomain.tmpdir=$env:USERPROFILE\.jtmp"
```

После этого перезапустите Android Studio (и остановите старые демоны: `cd mobile/android; ./gradlew --stop`).

## Экраны

| Экран | Файл |
|---|---|
| Splash | `splash_screen.dart` |
| Вход / Регистрация | `login_screen.dart`, `register_screen.dart` |
| Главная (Dashboard): продажи за сегодня/неделю/месяц, заказы, штуки, прибыль, склад, низкий остаток, график, последние продажи | `dashboard_screen.dart` |
| Продажи: список, фильтр по периоду и датам, удаление свайпом | `sales_screen.dart` |
| Добавить / изменить продажу | `sale_form_screen.dart` |
| Товары: поиск, фильтр по наличию, сортировка | `products_screen.dart` |
| Добавить / изменить товар (фото из галереи или камеры) | `product_form_screen.dart` |
| Карточка товара: прибыль по товару, движения | `product_details_screen.dart` |
| Склад: остатки, приход/расход, предупреждение о низком остатке | `inventory_screen.dart` |
| История склада | `inventory_history_screen.dart` |
| Финансы: выручка, себестоимость, оценочная прибыль за период | `finance_screen.dart` |
| Аналитика: графики по дням/неделям/месяцам, сравнение периодов, лучшие товары | `analytics_screen.dart` |
| Профиль и настройки: порог низкого остатка (shared_preferences), выход | `profile_screen.dart` |

Нижняя навигация: Главная · Продажи · Товары · Склад · Отчёты (Финансы + Аналитика). Профиль — иконка на главной.
После любого изменения (продажа, товар, движение склада, порог остатка) Dashboard, финансы, аналитика и склад
обновляются сами через `DataChangeBus`.

## Как считается

- **Остаток** меняется только через движения склада (`stock_movements`). Начальный остаток товара и ручная
  корректировка записываются как приход/расход. Расход больше остатка → **ошибка 400**.
- **Продажа**, привязанная к товару, по умолчанию списывает проданные штуки со склада (движение «Продажа»).
  При изменении или удалении продажи списание пересчитывается или возвращается на склад.
- **Оценочная прибыль** = выручка − себестоимость. Себестоимость = продано штук × закупочная цена товара.
  Если продажа не привязана к товару, себестоимость оценивается по средней доле закупки в цене ваших товаров.
  Комиссии и логистика WB не учитываются.

## REST API

Все маршруты, кроме `/api/auth/register`, `/api/auth/login` и `/api/health`, требуют
`Authorization: Bearer <token>`. Пользователь видит и меняет только свои данные (чужие → 404).
Ошибки возвращаются как `{ "error": "текст" }`.

| Метод | Путь | Описание |
|---|---|---|
| POST | `/api/auth/register` | `{name, email, password}` → `{token, user}` (пароль — bcrypt) |
| POST | `/api/auth/login` | `{email, password}` → `{token, user}` (JWT, 7 дней) |
| GET | `/api/auth/me` | текущий пользователь |
| GET | `/api/products?search=&low_stock=&sort=` | список товаров |
| GET | `/api/products/:id` | товар + статистика (продано, выручка, себестоимость, прибыль) |
| POST / PUT / DELETE | `/api/products[/:id]` | `{name, description, purchase_price, selling_price, stock}` |
| POST | `/api/products/:id/image` | multipart, поле `image` → фото в `/uploads/...` |
| GET | `/api/sales?from=&to=&product_id=` | записи о продажах |
| POST / PUT / DELETE | `/api/sales[/:id]` | `{date, orders_count, items_sold, total_amount, product_id?, note?, write_off_stock?}` |
| GET | `/api/stock-movements?product_id=&type=&from=&to=` | история склада |
| POST / PUT / DELETE | `/api/stock-movements[/:id]` | `{product_id, type: in\|out, quantity, date?, description?}` |
| GET | `/api/dashboard?today=&low_stock_threshold=` | сводка для главного экрана |
| GET | `/api/finance?from=&to=` | выручка, себестоимость, прибыль, сравнение с прошлым периодом, по дням |
| GET | `/api/analytics?group=day\|week\|month` | точки графика, итоги, сравнение периодов, топ-5 товаров |
| GET | `/api/analytics/top-products?from=&to=&limit=&by=revenue\|items\|profit` | лучшие товары |

## Схема БД (SQLite)

- `users` (id, name, email, password_hash, created_at)
- `products` (id, **user_id → users**, name, description, purchase_price, selling_price, image_url, stock ≥ 0)
- `daily_sales` (id, **user_id → users**, product_id → products (необязательно), date, orders_count, items_sold, total_amount, note)
- `stock_movements` (id, **user_id → users**, **product_id → products**, sale_id → daily_sales, type in/out, quantity > 0, date, description)

Внешние ключи включены (`PRAGMA foreign_keys = ON`), удаление пользователя/товара каскадно удаляет связанные данные.
