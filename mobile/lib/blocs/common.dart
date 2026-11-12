/// Статус загрузки данных экрана.
enum LoadStatus { initial, loading, success, failure }

/// Статус действия (сохранение, удаление).
enum ActionStatus { idle, inProgress, success, failure }

/// Какое действие выполнялось — чтобы форма реагировала только на сохранение,
/// а список — только на удаление.
enum ActionKind { save, delete }
