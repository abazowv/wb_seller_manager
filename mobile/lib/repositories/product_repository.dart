import '../core/api_client.dart';
import '../core/data_change_bus.dart';
import '../models/product.dart';

class ProductRepository {
  ProductRepository(this._api, this._bus);

  final ApiClient _api;
  final DataChangeBus _bus;

  Future<List<Product>> fetchAll() async {
    final data = await _api.get('/products') as List;
    return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Товар со статистикой продаж и прибыли.
  Future<Product> fetchOne(int id) async {
    final data = await _api.get('/products/$id') as Map<String, dynamic>;
    return Product.fromJson(data);
  }

  Future<Product> create(ProductDraft draft) async {
    var product = Product.fromJson(await _api.post('/products', data: draft.toJson()) as Map<String, dynamic>);
    if (draft.imagePath != null) product = await _uploadImage(product.id, draft.imagePath!);
    _bus.notify(DataChange.products);
    return product;
  }

  Future<Product> update(int id, ProductDraft draft) async {
    var product = Product.fromJson(await _api.put('/products/$id', data: draft.toJson()) as Map<String, dynamic>);
    if (draft.imagePath != null) product = await _uploadImage(id, draft.imagePath!);
    _bus.notify(DataChange.products);
    return product;
  }

  Future<void> delete(int id) async {
    await _api.delete('/products/$id');
    _bus.notify(DataChange.products);
  }

  Future<Product> _uploadImage(int id, String path) async {
    final data = await _api.uploadFile('/products/$id/image', field: 'image', filePath: path);
    return Product.fromJson(data as Map<String, dynamic>);
  }
}
