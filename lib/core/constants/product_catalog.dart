/// A product size this factory produces. Shared by Production, Sales, and
/// Inventory — one catalog, not a per-feature copy.
enum ProductType { sachet50cl, bottle75cl, bottle1_5l, bottle5l }

extension ProductTypeLabel on ProductType {
  String get label => switch (this) {
    ProductType.sachet50cl => '50cl Sachet',
    ProductType.bottle75cl => '75cl Bottle',
    ProductType.bottle1_5l => '1.5L Bottle',
    ProductType.bottle5l => '5L Bottle',
  };
}

/// Default per-unit selling price, used to prefill (not lock) the sales
/// line-entry form.
extension ProductTypePricing on ProductType {
  num get defaultUnitPrice => switch (this) {
    ProductType.sachet50cl => 400,
    ProductType.bottle75cl => 150,
    ProductType.bottle1_5l => 350,
    ProductType.bottle5l => 900,
  };
}
