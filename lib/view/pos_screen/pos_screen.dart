// lib/view/pos_screen/pos_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:shimmer/shimmer.dart';
import 'package:strada/model/product_model/product_model.dart';
import 'package:strada/view/auth/signin_screen/signin_screen.dart';
import 'package:strada/view/pos_screen/cart_widgte/cart_widgte.dart';
import 'package:strada/view/pos_screen/unsynced/unsynced_sales.dart';
import 'package:strada/view_model/auth/auth_view_model.dart';
import 'package:strada/view_model/pos/cart_view_model.dart';
import 'package:strada/view_model/pos/pos_view_model.dart';


class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with TickerProviderStateMixin {
  // Controllers for UI elements
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  // ViewModels to manage state and business logic
  late final PosViewModel _posViewModel;
  late final CartViewModel _cartViewModel;

  // Local UI state
  String searchQuery = '';
  String selectedCategory = 'All';
  bool isOffline = true;
  int _unsyncedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadUnsyncedCount();

    // Initialize the ViewModels. They will handle their own data fetching.
    _posViewModel = PosViewModel();
    _cartViewModel = CartViewModel();
  }

  Future<void> loadUnsyncedCount() async {
    try {
      final box = await Hive.openBox('unsynced_sales');
      final salesToSync = box.values.toList();
      print(salesToSync);
      setState(() {
        _unsyncedCount = salesToSync.length;
      });
    } catch (e) {
      setState(() {
        _unsyncedCount = 0; // fallback if error
      });
      print('Error loading unsynced sales: $e');
    }
  }

  /// Refreshes the product list by calling the method in the PosViewModel.
  Future<void> _refreshProducts() async {
    await _posViewModel.fetchProducts();
    if (mounted) {
      _showSnackBar('Products refreshed', Colors.blue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      // ListenableBuilder ensures the screen rebuilds when product data changes.
      child: ListenableBuilder(
        listenable: _posViewModel,
        builder: (context, child) {
          // A safety check to reset the category filter if it becomes invalid.
          if (!_posViewModel.categories.contains(selectedCategory)) {
            selectedCategory = 'All';
          }
          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: _buildAppBar(),
            body: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {


    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const SizedBox(width: 6),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => UnsyncedSales()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_problem, size: 14, color: Colors.red[700]),
                  const SizedBox(width: 4),
                  Text(
                    '$_unsyncedCount unsynced',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.blue),
          onPressed: _refreshProducts,
          tooltip: 'Refresh Products',
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        // Left side - Products (70%)
        Expanded(
          flex: 7,
          child: _buildProductsSection(),
        ),
        // Right side - Cart (30%)
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.grey[300]!)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: CartWidget(
            viewModel: _cartViewModel,
            onPaymentSuccess: _onPaymentCompleted,
            onShowSnackBar: _showSnackBar,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            // ListenableBuilder updates the cart badge when items are added/removed.
            child: ListenableBuilder(
              listenable: _cartViewModel,
              builder: (context, child) {
                return TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[700],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue[700],
                  tabs: [
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory),
                          SizedBox(width: 8),
                          Text('Products'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart,color: _cartViewModel.items.length > 0 ? Colors.pink : Colors.grey,),
                          const SizedBox(width: 8),
                          // The count now comes from the CartViewModel
                          Text('Cart (${_cartViewModel.items.length})',style: TextStyle(color: _cartViewModel.items.length > 0 ? Colors.pink : Colors.grey,fontSize: _cartViewModel.items.length > 0 ? 18 : 16,),),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsSection(),
                CartWidget(
                  viewModel: _cartViewModel,
                  onPaymentSuccess: _onPaymentCompleted,
                  onShowSnackBar: _showSnackBar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    // Categories are now fetched from the PosViewModel
    final categories = _posViewModel.categories;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.blue[100],
                    checkmarkColor: Colors.blue[700],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blue[700] : Colors.grey[700],
                      fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    // Shows the shimmer effect while loading
    if (_posViewModel.isLoading) {
      return _buildShimmerGrid();
    }

    // Shows an error message if fetching fails
    if (_posViewModel.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Error loading products', style: TextStyle(fontSize: 18, color: Colors.red[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(_posViewModel.errorMessage!, style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshProducts, child: const Text('Retry')),
          ],
        ),
      );
    }

    final products = _getFilteredProducts();

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No products found', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Try adjusting your search or filters', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshProducts, child: const Text('Refresh Products')),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[50],
      child: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return _buildProductCard(products[index]);
          },
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 8,
        itemBuilder: (context, index) => _buildShimmerProductCard(),
      ),
    );
  }

  Widget _buildShimmerProductCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)))),
          const SizedBox(height: 12),
          Container(height: 20, width: double.infinity, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 20, width: 100, color: Colors.white),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(height: 24, width: 80, color: Colors.white),
            Container(height: 16, width: 60, color: Colors.white),
          ]),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isOutOfStock = product.stock <= 0;

    return GestureDetector(
      onTap: isOutOfStock
          ? null
          : () {
        // Call the CartViewModel to add the product
        _cartViewModel.addToCart(product);
        HapticFeedback.lightImpact();
        _showSnackBar('${product.name} added to cart', Colors.green);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 60, height: 60, decoration: BoxDecoration(color: isOutOfStock ? Colors.grey[200] : Colors.blue[50], borderRadius: BorderRadius.circular(30)), child: Center(child: Text(product.image, style: TextStyle(fontSize: 30, color: isOutOfStock ? Colors.grey[400] : null))))),
                const SizedBox(height: 12),
                Text(product.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isOutOfStock ? Colors.grey[400] : Colors.grey[800]), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(product.category, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('₨${product.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isOutOfStock ? Colors.grey[400] : Colors.green[700])),
                  Text('Stock: ${product.stock}', style: TextStyle(fontSize: 12, color: product.stock <= 5 ? Colors.red[600] : Colors.grey[600], fontWeight: product.stock <= 5 ? FontWeight.w600 : FontWeight.normal)),
                ]),
              ],
            ),
          ),
          if (isOutOfStock)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Text('OUT OF STOCK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
              ),
            ),
          if (product.stock <= 5 && product.stock > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                child: const Text('LOW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }

  /// Filters products based on search query and selected category.
  List<Product> _getFilteredProducts() {
    return _posViewModel.allProducts.where((product) {
      final matchesSearch = searchQuery.isEmpty || product.name.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory = selectedCategory == 'All' || product.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  /// Handles UI changes after a payment is successfully processed by the ViewModel.
  void _onPaymentCompleted() {
    // The ViewModel handles clearing the data. This just handles UI.
    if (MediaQuery.of(context).size.width <= 600) {
      _tabController.animateTo(0);
    }
  }

  /// Shows a SnackBar with a given message and color.
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  // --- Other Methods ---


  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await AuthViewModel().signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SigninScreen()));
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _posViewModel.dispose();
    _cartViewModel.dispose();
    super.dispose();
  }
}