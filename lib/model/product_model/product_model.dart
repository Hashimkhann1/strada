import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
part 'product_model.g.dart'; // required for generated adapter

@HiveType(typeId: 0)
class Product extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final String category;

  @HiveField(4)
  int stock;

  @HiveField(5)
  final String image;

  @HiveField(6)
  final double costPrice;

  @HiveField(7)
  final double discount;

  @HiveField(8)
  final String ske;

  @HiveField(9)
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.stock,
    required this.image,
    this.costPrice = 0.0,
    this.discount = 0.0,
    this.ske = '',
    this.createdAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Product(
      id: doc.id,
      name: data['name'] ?? 'Unknown Product',
      price: (data['salePrice'] ?? 0).toDouble(),
      category: data['category'] ?? 'Other',
      stock: data['stock'] ?? 0,
      image: data['image'] ?? '📦',
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      ske: data['ske'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'salePrice': price,
      'category': category,
      'stock': stock,
      'image': image,
      'costPrice': costPrice,
      'discount': discount,
      'ske': ske,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    int? stock,
    String? image,
    double? costPrice,
    double? discount,
    String? ske,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      image: image ?? this.image,
      costPrice: costPrice ?? this.costPrice,
      discount: discount ?? this.discount,
      ske: ske ?? this.ske,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, category: $category, stock: $stock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

