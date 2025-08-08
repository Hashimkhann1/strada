
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:strada/model/product_model/product_model.dart';
import 'package:strada/view/pos_screen/cart_widgte/cart_widgte.dart'; // Ensure path is correct



class CartViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;


  // --- PRIVATE STATE ---
  final List<CartItem> _items = [];
  bool _isProcessingPayment = false;
  String? _paymentError;

  // --- PUBLIC GETTERS ---
  List<CartItem> get items => _items;
  bool get isProcessingPayment => _isProcessingPayment;
  String? get paymentError => _paymentError;

  /// Calculates the total price of all items in the cart.
  double get subtotal => _items.fold(
      0.0, (sum, item) => sum + (item.product.price * item.quantity));

  /// Calculates the total number of individual items in the cart.
  int get totalItemCount => _items.fold(0, (sum, item) => sum + item.quantity);


  // --- CART MANAGEMENT METHODS ---

  /// Adds a product to the cart or increments its quantity if it already exists.
  void addToCart(Product product) {
    // Check if the product is out of stock
    if (product.stock <= 0) {
      debugPrint('${product.name} is out of stock.');
      // Optionally, you could set an error message to show in the UI
      return;
    }

    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // Product already in cart, just increase quantity
      _items[existingIndex].quantity++;
    } else {
      // Add new product to cart
      _items.add(CartItem(product: product, quantity: 1));
    }

    // This is a temporary local stock reduction for the UI.
    // The final reduction happens in Firestore upon successful payment.
    product.stock--;
    notifyListeners();
  }

  /// Updates the quantity of an item in the cart. Removes it if quantity is zero or less.
  void updateQuantity(CartItem cartItem, int newQuantity) {
    int itemIndex = _items.indexOf(cartItem);
    if (itemIndex == -1) return;

    final oldQuantity = _items[itemIndex].quantity;
    final stockDifference = oldQuantity - newQuantity;

    // Return stock to the local product model
    _items[itemIndex].product.stock += stockDifference;

    if (newQuantity <= 0) {
      _items.removeAt(itemIndex);
    } else {
      _items[itemIndex].quantity = newQuantity;
    }
    notifyListeners();
  }

  /// Clears all items from the cart and returns their stock to the local models.
  void clearCart() {
    // Return stock for all items being cleared
    for (final item in _items) {
      item.product.stock += item.quantity;
    }
    _items.clear();
    notifyListeners();
  }


  // --- SALE PROCESSING METHOD ---

  /// Processes the sale: saves it to Firestore and decrements stock.
  /// Returns `true` on success and `false` on failure.

  Future<bool> processSale({
    required String paymentMethod,
    required List<CartItem> items,
    required double subtotal,
  }) async {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final saleDocRef = _firestore
        .collection('sales')
        .doc(dateKey)
        .collection('transactions')
        .doc();

    try {
      // Check connectivity
      final connectivityResults = await Connectivity().checkConnectivity();

      if (connectivityResults.contains(ConnectivityResult.none)) {
        print("📱 OFFLINE: Saving sale to Hive...");
        await _saveOfflineSale(
          items: items,
          paymentMethod: paymentMethod,
          saleId: saleDocRef.id,
          now: now,
          subtotal: subtotal,
        );

        return true;
      }

      // Calculate total profit
      double totalProfit = 0;
      for (final item in items) {
        totalProfit += (item.product.price - item.product.costPrice) * item.quantity;
      }

      // Firestore batch write
      final WriteBatch batch = _firestore.batch();

      // 1. Add detailed sale transaction
      batch.set(saleDocRef, {
        'id': saleDocRef.id,
        'totalAmount': subtotal,
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': Timestamp.fromDate(now),
        'employeeId': FirebaseAuth.instance.currentUser?.uid,
        'items': items.map((item) => {
          'productId': item.product.id,
          'productName': item.product.name,
          'quantity': item.quantity,
          'pricePerItem': item.product.price,
          'costPrice': item.product.costPrice,
        }).toList(),
      });

      // 2. Update daily summary
      final dailySummaryRef = _firestore.collection('sales_summary').doc(dateKey);
      batch.set(dailySummaryRef, {
        'date': dateKey,
        'totalSales': FieldValue.increment(subtotal),
        'totalProfit': FieldValue.increment(totalProfit),
        'totalTransactions': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
        'year': now.year,
        'month': now.month,
        'day': now.day,
      }, SetOptions(merge: true));

      // 3. Decrease product stock
      for (final item in items) {
        final productRef = _firestore.collection('products').doc(item.product.id);
        batch.update(productRef, {'stock': FieldValue.increment(-item.quantity)});
      }

      await batch.commit();
      return true;
    } catch (e) {
      print("❌ Firestore failed: $e");
      await _saveOfflineSale(
        items: items,
        paymentMethod: paymentMethod,
        saleId: saleDocRef.id,
        now: now,
        subtotal: subtotal,
      );
      return false;
    } finally {
      _items.clear();
      _isProcessingPayment = false;
      notifyListeners();
    }
  }

  Future<void> _saveOfflineSale({
    required List<CartItem> items,
    required String paymentMethod,
    required String saleId,
    required DateTime now,
    required double subtotal,
  }) async {
    final unsyncedBox = await Hive.openBox('unsynced_sales');
    final productsBox = Hive.box<Product>('productsBox');

    final offlineSale = {
      'id': saleId,
      'totalAmount': subtotal,
      'paymentMethod': paymentMethod,
      'createdAt': now.toIso8601String(),
      'timestamp': now.millisecondsSinceEpoch,
      'employeeId': FirebaseAuth.instance.currentUser?.uid,
      'items': items.map((item) => {
        'productId': item.product.id,
        'productName': item.product.name,
        'quantity': item.quantity,
        'pricePerItem': item.product.price,
        'costPrice': item.product.costPrice,
      }).toList(),
    };

    await unsyncedBox.put(saleId, offlineSale);

    final allProducts = productsBox.values.toList();

    for (final item in items) {
      final index = allProducts.indexWhere((p) => p.id == item.product.id);
      if (index != -1) {
        final product = productsBox.getAt(index);
        if (product != null) {
          final updatedProduct = product.copyWith(
            stock: (product.stock - item.quantity).clamp(0, double.infinity).toInt(),
          );
          await productsBox.putAt(index, updatedProduct);
        }
      }
    }
  }





// Future<bool> processSale({
//   required String paymentMethod,
//   required List<CartItem> items,
//   required double subtotal,
// }) async {
//   final WriteBatch batch = _firestore.batch();
//   final now = DateTime.now();
//   final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
//   final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
//
//   // Store individual sale in date-specific subcollection
//   final saleDocRef = _firestore
//       .collection('sales')
//       .doc(dateKey)
//       .collection('transactions')
//       .doc();
//
//   try {
//     // Calculate total profit for this sale
//     double totalProfit = 0;
//     for (final item in items) {
//       double itemProfit = (item.product.price - item.product.costPrice) * item.quantity;
//       totalProfit += itemProfit;
//     }
//
//     // 1. Store the detailed sale
//     batch.set(saleDocRef, {
//       'id': saleDocRef.id,
//       'totalAmount': subtotal,
//       'paymentMethod': paymentMethod,
//       'createdAt': FieldValue.serverTimestamp(),
//       'timestamp': Timestamp.fromDate(now),
//       'employeeId': FirebaseAuth.instance.currentUser?.uid,
//       'items': items.map((item) => {
//         'productId': item.product.id,
//         'productName': item.product.name,
//         'quantity': item.quantity,
//         'pricePerItem': item.product.price,
//         'costPrice': item.product.costPrice,
//       }).toList(),
//     });
//
//     // 2. Update daily summary with profit
//     final dailySummaryRef = _firestore.collection('sales_summary').doc(dateKey);
//     batch.set(dailySummaryRef, {
//       'date': dateKey,
//       'totalSales': FieldValue.increment(subtotal),
//       'totalProfit': FieldValue.increment(totalProfit),
//       'totalTransactions': FieldValue.increment(1),
//       'lastUpdated': FieldValue.serverTimestamp(),
//       'year': now.year,
//       'month': now.month,
//       'day': now.day,
//     }, SetOptions(merge: true));
//
//     // 3. Update product stock
//     for (final item in items) {
//       final productRef = _firestore.collection('products').doc(item.product.id);
//       batch.update(productRef, {'stock': FieldValue.increment(-item.quantity)});
//     }
//
//     await batch.commit();
//
//     // 4. On success, clear the local cart (stock is already correct in Firestore)
//     _items.clear(); // Clear cart without returning stock this time
//     _isProcessingPayment = false;
//     notifyListeners();
//     return true;
//
//     return true;
//   } catch (e) {
//     debugPrint('Sale processing failed: ${e.toString()}');
//     return false;
//   }
// }


}