import 'package:hydrotrack/features/products/data/models/product.dart';

/// Products as a new organization starts with them.
const sachet50cl = Product(
  id: 'product-sachet',
  name: '50cl Sachet',
  unit: 'bags',
  walkInPrice: 400,
  distributorPrice: 380,
  sortOrder: 1,
);

const bottle75cl = Product(
  id: 'product-75cl',
  name: '75cl Bottle',
  unit: 'packs',
  walkInPrice: 150,
  distributorPrice: 140,
  sortOrder: 2,
);

const starterProducts = [sachet50cl, bottle75cl];
