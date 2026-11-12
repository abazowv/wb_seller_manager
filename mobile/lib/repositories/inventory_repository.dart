import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../models/stock_movement.dart';

class InventoryRepository {
  InventoryRepository(this._api, this._bus);

  final ApiClient _api;
  final DataChangeBus _bus;

  Future<List<StockMovement>> fetchMovements({int? productId, MovementType? type}) async {
    final data = await _api.get(
      '/stock-movements',
      query: {'product_id': productId, 'type': type?.apiValue},
    ) as List;
    return data.map((e) => StockMovement.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StockMovement> create(MovementDraft draft) async {
    final m = StockMovement.fromJson(await _api.post('/stock-movements', data: draft.toJson()) as Map<String, dynamic>);
    _bus.notify(DataChange.stock);
    return m;
  }

  Future<StockMovement> update(int id, MovementDraft draft) async {
    final m = StockMovement.fromJson(
      await _api.put('/stock-movements/$id', data: draft.toJson()) as Map<String, dynamic>,
    );
    _bus.notify(DataChange.stock);
    return m;
  }

  Future<void> delete(int id) async {
    await _api.delete('/stock-movements/$id');
    _bus.notify(DataChange.stock);
  }
}
