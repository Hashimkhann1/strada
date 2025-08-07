import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strada/model/product_model/product_model.dart';
import 'package:strada/res/pop_up_message/pop_up_messages.dart';
import 'package:strada/res/provider/loading_provider/loading_provider.dart';


class ProductViewModel {
  final _firestore = FirebaseFirestore.instance.collection('products');

  Future<void> addProduct(BuildContext context, WidgetRef ref, String productName,
      category, image, sku, int stock, double costPrice, salePrice, int discount) async {
    try {
      ref.read(loadingProvider.notifier).setLoading(true);

      // Create a new document reference with auto-generated ID
      final docRef = _firestore.doc();
      final productId = docRef.id; // get the auto-generated ID

      // Now set the product data with the ID included
      await docRef.set({
        "id": productId,
        "name": productName,
        "costPrice": costPrice,
        'salePrice': salePrice,
        'discount': discount,
        "category": category,
        "stock": stock,
        "image": image,
        'ske': sku,
        "createdAt": Timestamp.now(),
      });

      PopUpMessages.showSnackBar(
        context,
        "Product '$productName' added successfully",
        Colors.blue,
      );

      ref.read(loadingProvider.notifier).setLoading(false);
      Navigator.pop(context);
    } catch (error) {
      ref.read(loadingProvider.notifier).setLoading(false);
      print("Error while adding product from AddProductViewModel >> $error");
      PopUpMessages.showSnackBar(
        context,
        "Failed to add product",
        Colors.red,
      );
    }
  }

  // Get all products from Firebase
  Stream<List<Product>> getAllProducts() {
    return _firestore
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
    });
  }

  // Get products stream for Riverpod
  Future<List<Product>> getProductsList() async {
    try {
      final querySnapshot = await _firestore
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
    } catch (error) {
      print("Error getting products: $error");
      return [];
    }
  }

  // Get total stock count
  Future<int> getTotalStockCount() async {
    try {
      final querySnapshot = await _firestore.get();
      int totalStock = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        totalStock += (data['stock'] ?? 0) as int;
      }

      return totalStock;
    } catch (error) {
      print("Error getting total stock: $error");
      return 0;
    }
  }

  // Get low stock products count (less than 3)
  Future<int> getLowStockCount() async {
    try {
      final querySnapshot = await _firestore
          .where('stock', isLessThan: 3)
          .get();

      return querySnapshot.docs.length;
    } catch (error) {
      print("Error getting low stock count: $error");
      return 0;
    }
  }

  // Get products with low stock
  Future<List<Product>> getLowStockProducts() async {
    try {
      final querySnapshot = await _firestore
          .where('stock', isLessThan: 3)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
    } catch (error) {
      print("Error getting low stock products: $error");
      return [];
    }
  }

  // Update product stock
  Future<void> updateProductStock(String productId, int newStock) async {
    try {
      await _firestore.doc(productId).update({'stock': newStock});
    } catch (error) {
      print("Error updating product stock: $error");
      rethrow;
    }
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.doc(productId).delete();
    } catch (error) {
      print("Error deleting product: $error");
      rethrow;
    }
  }
}

// Riverpod Providers
final productViewModelProvider = Provider((ref) => ProductViewModel());

// Stream provider for all products
final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final productViewModel = ref.read(productViewModelProvider);
  return productViewModel.getAllProducts();
});

// Future provider for products list
final productsListProvider = FutureProvider<List<Product>>((ref) {
  final productViewModel = ref.read(productViewModelProvider);
  return productViewModel.getProductsList();
});

// Future provider for total stock count
final totalStockProvider = FutureProvider<int>((ref) {
  final productViewModel = ref.read(productViewModelProvider);
  return productViewModel.getTotalStockCount();
});

// Future provider for low stock count
final lowStockCountProvider = FutureProvider<int>((ref) {
  final productViewModel = ref.read(productViewModelProvider);
  return productViewModel.getLowStockCount();
});