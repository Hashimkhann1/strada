
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:strada/model/product_model/product_model.dart'; // Ensure this path is correct

class PosViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  // Private state variables
  List<Product> _allProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _categories = ['All'];

  // Public getters for the UI to access the state
  List<Product> get allProducts => _allProducts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get categories => _categories;

  // The constructor is called when the ViewModel is created,
  // so we can fetch products immediately.
  PosViewModel() {
    fetchProducts();
  }

  /// Fetches products from the 'products' collection in Firestore.

  Future<void> fetchProducts() async {
    print("🚀 fetchProducts() started");

    // Get Hive box
    late Box<Product> productBox;
    try {
      productBox = Hive.box<Product>('productsBox');
      print("📦 Hive box accessed: ${productBox.length} cached products");
    } catch (e) {
      print("📦 Opening Hive box...");
      productBox = await Hive.openBox<Product>('productsBox');
    }

    // Check connectivity
    print("🌐 Checking connectivity...");
    final connectivityResults = await Connectivity().checkConnectivity();
    print("🌐 Connectivity results: $connectivityResults");

    // If completely offline, use Hive
    if (connectivityResults.contains(ConnectivityResult.none)) {
      print("📱 OFFLINE: Using cached products");
      _loadFromHive(productBox);
      return;
    }

    // Try to fetch from Firestore (online)
    print("🌐 ONLINE: Attempting Firestore fetch...");
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Set a timeout for the Firestore request
      final snapshot = await _firestore
          .collection('products')
          .orderBy('createdAt', descending: false)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Firestore request timeout');
        },
      );

      print("🔥 Firestore success: ${snapshot.docs.length} documents");

      final List<Product> fetchedProducts = [];
      final Set<String> categorySet = {'All'};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final product = Product(
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

          fetchedProducts.add(product);
          categorySet.add(product.category);
        } catch (e) {
          debugPrint('Error parsing product ${doc.id}: $e');
        }
      }

      // Update Hive cache with fresh data
      if (fetchedProducts.isNotEmpty) {
        await productBox.clear();
        await productBox.addAll(fetchedProducts);
        print("💾 Updated Hive cache with ${fetchedProducts.length} products");
      }

      // Update UI state
      _allProducts = fetchedProducts;
      _categories = categorySet.toList();
      _isLoading = false;
      _errorMessage = null;

      print("✅ Online fetch completed: ${_allProducts.length} products loaded");

    } catch (e) {
      // Firestore failed - fallback to Hive
      print("❌ Firestore failed: $e");
      print("🔄 Falling back to cached products...");

      _isLoading = false;

      // Check if we have cached data
      if (productBox.isNotEmpty) {
        _loadFromHive(productBox);
        _errorMessage = "Using cached products (network error)";
        print("🔄 Loaded ${_allProducts.length} cached products");
      } else {
        // No cached data and no network
        _allProducts = [];
        _categories = ['All'];
        _errorMessage = 'No internet connection and no cached products available';
        print("❌ No cached products available");
      }
    } finally {
      print("🏁 fetchProducts completed - Products: ${_allProducts.length}, Loading: $_isLoading");
      notifyListeners();
    }
  }

  /// Helper method to load products from Hive
  void _loadFromHive(Box<Product> productBox) {
    _allProducts = productBox.values.toList();
    _categories = {'All', ..._allProducts.map((p) => p.category)}.toList();
    _isLoading = false;
    // _errorMessage = productBox.isEmpty ? null : "Showing cached products";

    print("📱 Loaded from Hive: ${_allProducts.length} products, ${_categories.length} categories");
  }

  // Future<void> fetchProducts() async {
  //   // Ensure the Hive box is opened
  //   late Box<Product> productBox;
  //   try {
  //     productBox = Hive.box<Product>('productsBox');
  //   } catch (e) {
  //     // If box is not opened, open it
  //     productBox = await Hive.openBox<Product>('productsBox');
  //   }
  //
  //   print(">>>>>>>>>>>>>>>>>>");
  //   print("Fetched Products");
  //
  //   final connectivityResult = await Connectivity().checkConnectivity();
  //   if (connectivityResult == ConnectivityResult.none) {
  //     _errorMessage = "You're offline. Showing cached products.";
  //     _allProducts = productBox.values.toList();
  //     _categories = {'All', ..._allProducts.map((p) => p.category)}.toList();
  //     _isLoading = false; // Add this line!
  //
  //     print("=====================");
  //     print(_allProducts);
  //     print(_allProducts.length);
  //     print("From Connection statement");
  //     notifyListeners();
  //     return;
  //   }
  //
  //   try {
  //     _isLoading = true;
  //     _errorMessage = null;
  //     notifyListeners();
  //
  //     final snapshot = await _firestore
  //         .collection('products')
  //         .orderBy('createdAt', descending: false)
  //         .get();
  //
  //     final List<Product> fetchedProducts = [];
  //     final Set<String> categorySet = {'All'};
  //
  //     for (var doc in snapshot.docs) {
  //       try {
  //         final data = doc.data() as Map<String, dynamic>;
  //         final product = Product(
  //           id: doc.id,
  //           name: data['name'] ?? 'Unknown Product',
  //           price: (data['salePrice'] ?? 0).toDouble(),
  //           category: data['category'] ?? 'Other',
  //           stock: data['stock'] ?? 0,
  //           image: data['image'] ?? '📦',
  //           costPrice: (data['costPrice'] ?? 0).toDouble(),
  //           discount: (data['discount'] ?? 0).toDouble(),
  //           ske: data['ske'] ?? '',
  //           createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
  //         );
  //
  //         fetchedProducts.add(product);
  //         categorySet.add(product.category);
  //       } catch (e) {
  //         debugPrint('Error parsing product ${doc.id}: $e');
  //       }
  //     }
  //
  //     if(fetchedProducts.isNotEmpty) {
  //       // Save to Hive
  //       await productBox.clear(); // Clear old data
  //       await productBox.addAll(fetchedProducts);
  //     }
  //
  //     _allProducts = fetchedProducts;
  //     _categories = categorySet.toList();
  //     _isLoading = false;
  //   } catch (e) {
  //     debugPrint('Error fetching products: $e');
  //     _errorMessage = 'Failed to load products: $e';
  //     _isLoading = false;
  //
  //     // Load from Hive as fallback
  //     if (productBox.isNotEmpty) {
  //       _allProducts = productBox.values.toList();
  //       _categories = {'All', ..._allProducts.map((p) => p.category)}.toList();
  //     }
  //
  //     print(">>>>>>>>>>>>");
  //     print(_allProducts);
  //   } finally {
  //     notifyListeners();
  //   }
  // }

  // Future<void> fetchProducts() async {
  //   final productBox = Hive.box<Product>('productsBox');
  //
  //   print(">>>>>>>>>>>>>>>>>>");
  //   print("Feteched Products");
  //   print(productBox.values);
  //
  //
  //   final connectivityResult = await Connectivity().checkConnectivity();
  //   if (connectivityResult == ConnectivityResult.none) {
  //     _errorMessage = "You're offline. Showing cached products.";
  //     _allProducts = productBox.values.toList();
  //     _categories = {'All', ..._allProducts.map((p) => p.category)}.toList();
  //
  //     print("From Connection statement");
  //     notifyListeners();
  //     return;
  //   }
  //
  //   try {
  //     _isLoading = true;
  //     _errorMessage = null;
  //     notifyListeners();
  //
  //     final snapshot = await _firestore
  //         .collection('products')
  //         .orderBy('createdAt', descending: false)
  //         .get();
  //
  //     final List<Product> fetchedProducts = [];
  //     final Set<String> categorySet = {'All'};
  //
  //     for (var doc in snapshot.docs) {
  //       try {
  //         final data = doc.data() as Map<String, dynamic>;
  //         final product = Product(
  //           id: doc.id,
  //           name: data['name'] ?? 'Unknown Product',
  //           price: (data['salePrice'] ?? 0).toDouble(),
  //           category: data['category'] ?? 'Other',
  //           stock: data['stock'] ?? 0,
  //           image: data['image'] ?? '📦',
  //           costPrice: (data['costPrice'] ?? 0).toDouble(),
  //           discount: (data['discount'] ?? 0).toDouble(),
  //           ske: data['ske'] ?? '',
  //           createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
  //         );
  //
  //         fetchedProducts.add(product);
  //         categorySet.add(product.category);
  //       } catch (e) {
  //         debugPrint('Error parsing product ${doc.id}: $e');
  //       }
  //     }
  //
  //     if(fetchedProducts.isNotEmpty) {
  //       // Save to Hive
  //       await productBox.clear(); // Clear old data
  //       await productBox.addAll(fetchedProducts);
  //     }
  //
  //     _allProducts = fetchedProducts;
  //     _categories = categorySet.toList();
  //     _isLoading = false;
  //   } catch (e) {
  //     debugPrint('Error fetching products: $e');
  //     _errorMessage = 'Failed to load products: $e';
  //     _isLoading = false;
  //
  //     // Load from Hive as fallback
  //     if (productBox.isNotEmpty) {
  //       _allProducts = productBox.values.toList();
  //       _categories = {'All', ..._allProducts.map((p) => p.category)}.toList();
  //     }
  //
  //     print(">>>>>>>>>>>>");
  //     print(_allProducts);
  //   } finally {
  //     notifyListeners();
  //   }
  // }



}