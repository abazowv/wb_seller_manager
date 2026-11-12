import 'dart:async';

/// Что изменилось в данных.
enum DataChange { products, sales, stock, settings }

/// Шина изменений: репозитории сообщают о сохранении/удалении,
/// а Dashboard, финансы и аналитика сами перезагружаются.
class DataChangeBus {
  final _controller = StreamController<DataChange>.broadcast();

  Stream<DataChange> get stream => _controller.stream;

  void notify(DataChange change) => _controller.add(change);

  Future<void> dispose() => _controller.close();
}
