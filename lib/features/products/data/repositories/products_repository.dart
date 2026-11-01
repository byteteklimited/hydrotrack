import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/rpc_params.dart';
import '../../../offline/data/services/offline_context.dart';
import '../models/product.dart';

/// The organization's products and prices. Changing them is Owner/Admin
/// only (enforced by the server) and needs internet.
abstract class ProductsRepository {
  /// All products, retired ones included, in the organization's order.
  Future<List<Product>> fetchProducts();

  Future<Product> createProduct({
    required String name,
    required String unit,
    required num walkInPrice,
    required num distributorPrice,
  });

  Future<Product> updateProduct({
    required String productId,
    required String name,
    required String unit,
    required num walkInPrice,
    required num distributorPrice,
  });

  /// Retire (hide from new records) or bring back.
  Future<Product> setRetired({
    required String productId,
    required bool retired,
  });

  /// Only for a product never sold, produced, loaded or stocked.
  Future<void> deleteProduct(String productId);
}

class SupabaseProductsRepository implements ProductsRepository {
  SupabaseProductsRepository(this._tenantId);

  final String _tenantId;

  SupabaseClient get _client => Supabase.instance.client;

  Future<Product> _product(String function, Map<String, dynamic> params) async {
    final row = await _client.rpc(
      function,
      params: rpcParams(_tenantId, params),
    );
    return Product.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<List<Product>> fetchProducts() async {
    final rows = await _client
        .from('products')
        .select()
        .eq('tenant_id', _tenantId);
    return sortProducts([
      for (final row in rows as List)
        Product.fromJson(row as Map<String, dynamic>),
    ]);
  }

  @override
  Future<Product> createProduct({
    required String name,
    required String unit,
    required num walkInPrice,
    required num distributorPrice,
  }) {
    return _product('create_product', {
      'name': name,
      'unit': unit,
      'walk_in_price': walkInPrice,
      'distributor_price': distributorPrice,
    });
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required String name,
    required String unit,
    required num walkInPrice,
    required num distributorPrice,
  }) {
    return _product('update_product', {
      'product_id': productId,
      'name': name,
      'unit': unit,
      'walk_in_price': walkInPrice,
      'distributor_price': distributorPrice,
    });
  }

  @override
  Future<Product> setRetired({
    required String productId,
    required bool retired,
  }) {
    return _product('set_product_retired', {
      'product_id': productId,
      'retired': retired,
    });
  }

  @override
  Future<void> deleteProduct(String productId) {
    return _client.rpc(
      'delete_product',
      params: rpcParams(_tenantId, {'product_id': productId}),
    );
  }
}

/// Products on a device set up for offline use: readable offline (to
/// record sales and production); changing them needs internet.
class OfflineProductsRepository implements ProductsRepository {
  OfflineProductsRepository(this._remote, this._offline);

  final ProductsRepository _remote;
  final OfflineContext _offline;

  @override
  Future<List<Product>> fetchProducts() {
    return _offline.read(
      remote: _remote.fetchProducts,
      local: (snapshot) =>
          sortProducts(snapshot.rows('products').map(Product.fromJson)),
    );
  }

  @override
  Future<Product> createProduct({
    required String name,
    required String unit,
    required num walkInPrice,
    required num distributorPrice,
  }) {
    return _offline.online(
      () => _remote.createProduct(
        name: name,
        unit: unit,
        walkInPrice: walkInPrice,
        distributorPrice: distributorPrice,
      ),
    );
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required String name,
    required String unit,
    required num walkInPrice,
    required num distributorPrice,
  }) {
    return _offline.online(
      () => _remote.updateProduct(
        productId: productId,
        name: name,
        unit: unit,
        walkInPrice: walkInPrice,
        distributorPrice: distributorPrice,
      ),
    );
  }

  @override
  Future<Product> setRetired({
    required String productId,
    required bool retired,
  }) {
    return _offline.online(
      () => _remote.setRetired(productId: productId, retired: retired),
    );
  }

  @override
  Future<void> deleteProduct(String productId) {
    return _offline.online(() => _remote.deleteProduct(productId));
  }
}
