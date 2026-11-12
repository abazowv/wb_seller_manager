import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../models/sale.dart';

class SalesRepository {
  SalesRepository(this._api, this._bus);

  final ApiClient _api;
  final DataChangeBus _bus;

  Future<List<Sale>> fetch({String? from, String? to, int? productId}) async {
    final data = await _api.get('/sales', query: {'from': from, 'to': to, 'product_id': productId}) as List;
    return data.map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Sale> create(SaleDraft draft) async {
    final sale = Sale.fromJson(await _api.post('/sales', data: draft.toJson()) as Map<String, dynamic>);
    _notify(draft);
    return sale;
  }

  Future<Sale> update(int id, SaleDraft draft) async {
    final sale = Sale.fromJson(await _api.put('/sales/$id', data: draft.toJson()) as Map<String, dynamic>);
    _notify(draft);
    return sale;
  }

  Future<void> delete(int id) async {
    await _api.delete('/sales/$id');
    _bus
      ..notify(DataChange.sales)
      ..notify(DataChange.stock);
  }

  void _notify(SaleDraft draft) {
    _bus.notify(DataChange.sales);
    // Продажа товара может списать его со склада.
    if (draft.productId != null) _bus.notify(DataChange.stock);
  }
}
