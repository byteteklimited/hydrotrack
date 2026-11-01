import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/action_controller.dart';
import '../../../inventory/data/providers/inventory_providers.dart';
import '../../../locations/data/providers/location_providers.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../models/product.dart';
import '../repositories/products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final remote = SupabaseProductsRepository(
    ref.watch(dataScopeProvider).tenantId,
  );
  final offline = ref.watch(offlineContextProvider);
  return offline == null ? remote : OfflineProductsRepository(remote, offline);
});

/// Every product, retired ones included (history, the Products screen).
final productsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productsRepositoryProvider).fetchProducts();
});

/// Products that can be used in new sales, production and load-outs.
final activeProductsProvider = FutureProvider<List<Product>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  return products.where((product) => !product.isRetired).toList();
});

/// Adding, changing, retiring and deleting products.
class ProductActionController extends ActionController {
  ProductActionController(this._ref);

  final Ref _ref;

  ProductsRepository get _repository => _ref.read(productsRepositoryProvider);

  Future<Product?> save({
    String? productId,
    required String name,
    required String unit,
    required num walkInPrice,
    required num distributorPrice,
  }) {
    return guard(() async {
      final product = productId == null
          ? await _repository.createProduct(
              name: name,
              unit: unit,
              walkInPrice: walkInPrice,
              distributorPrice: distributorPrice,
            )
          : await _repository.updateProduct(
              productId: productId,
              name: name,
              unit: unit,
              walkInPrice: walkInPrice,
              distributorPrice: distributorPrice,
            );
      _refresh();
      return product;
    });
  }

  Future<Product?> setRetired(Product product, {required bool retired}) {
    return guard(() async {
      final updated = await _repository.setRetired(
        productId: product.id,
        retired: retired,
      );
      _refresh();
      return updated;
    });
  }

  Future<bool> delete(Product product) async {
    final done = await guard(() async {
      await _repository.deleteProduct(product.id);
      _refresh();
      return true;
    });
    return done ?? false;
  }

  void _refresh() {
    _ref.invalidate(productsProvider);
    _ref.invalidate(stockItemsProvider);
  }
}

final productActionControllerProvider =
    StateNotifierProvider.autoDispose<
      ProductActionController,
      AsyncValue<void>
    >((ref) => ProductActionController(ref));
