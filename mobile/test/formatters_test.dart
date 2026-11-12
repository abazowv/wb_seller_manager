import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wb_seller_manager/blocs/products_bloc.dart';
import 'package:wb_seller_manager/core/formatters.dart';
import 'package:wb_seller_manager/models/product.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  test('parseDecimal понимает запятую и пробелы', () {
    expect(parseDecimal('1 234,5'), 1234.5);
    expect(parseDecimal(''), isNull);
  });

  test('toIsoDate', () {
    expect(toIsoDate(DateTime(2026, 3, 7)), '2026-03-07');
  });

  test('фильтр «Мало» в списке товаров учитывает порог', () {
    const products = [
      Product(id: 1, name: 'Футболка', stock: 0),
      Product(id: 2, name: 'Кепка', stock: 3),
      Product(id: 3, name: 'Худи', stock: 50),
    ];
    const state = ProductsState(products: products, filter: StockFilter.low, lowStockThreshold: 5);
    expect(state.visible.map((p) => p.id), [2]);
    expect(state.copyWith(filter: StockFilter.outOfStock).visible.map((p) => p.id), [1]);
    expect(state.copyWith(filter: StockFilter.all, query: 'худ').visible.map((p) => p.id), [3]);
  });
}
