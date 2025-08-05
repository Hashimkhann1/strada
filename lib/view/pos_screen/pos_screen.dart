import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strada/view/auth/signin_screen/signin_screen.dart';
import 'package:strada/view_model/auth/auth_view_model.dart';

class POSScreen extends StatefulWidget {

  const POSScreen({
    super.key,
  });

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  // Sample data - replace with real data later
  List<Product> allProducts = [
    Product(id: '1', name: 'Type C', price: 170, category: 'Mobile Accessories', stock: 50, image: '🔌'),
    Product(id: '2', name: 'Type A', price: 150, category: 'Mobile Accessories', stock: 30, image: '🔌'),
    Product(id: '3', name: 'Adapter', price: 500, category: 'Mobile Accessories', stock: 100, image: '🔌'),
    Product(id: '4', name: 'Hands Free', price: 120, category: 'Mobile Accessories', stock: 75, image: '🎧'),
    Product(id: '5', name: 'Finger Gloves', price: 30, category: 'Mobile Accessories', stock: 60, image: '🧤'),
    Product(id: '6', name: 'Caps', price: 320, category: 'Caps', stock: 40, image: '🧢'),
    Product(id: '7', name: 'Glasses', price: 160, category: 'Glasses', stock: 25, image: '👓'),
    Product(id: '8', name: 'Masks', price: 20, category: 'other', stock: 20, image: '😷'),
  ];

  List<CartItem> cartItems = [];
  String searchQuery = '';
  String selectedCategory = 'All';
  bool isOffline = true;
  int unsyncedCount = 2;

  List<String> categories = ['All', 'Mobile Accessories', 'Caps', 'Others'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(),
        body: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
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
          if (isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 14, color: Colors.orange[700]),
                ],
              ),
            ),
          if (unsyncedCount > 0) ...[
            const SizedBox(width: 8),
            Container(
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
                    '$unsyncedCount unsynced',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (unsyncedCount > 0)
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.blue),
            onPressed: _syncData,
            tooltip: 'Sync Data',
          ),
        // IconButton(
        //   icon: const Icon(Icons.history, color: Colors.blue),
        //   onPressed: _showTransactionHistory,
        //   tooltip: 'Transaction History',
        // ),
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
          child: _buildCartSection(),
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
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[700],
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory),
                      const SizedBox(width: 8),
                      const Text('Products'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart),
                      const SizedBox(width: 8),
                      Text('Cart (${cartItems.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsSection(),
                _buildCartSection(),
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              // const SizedBox(width: 12),
              // Container(
              //   decoration: BoxDecoration(
              //     color: Colors.blue,
              //     borderRadius: BorderRadius.circular(12),
              //   ),
              //   child: IconButton(
              //     icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              //     onPressed: _scanBarcode,
              //     tooltip: 'Scan Barcode',
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 16),

          // Category Filter
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
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    final products = _getFilteredProducts();

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[50],
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
    );
  }

  Widget _buildProductCard(Product product) {
    final isOutOfStock = product.stock <= 0;

    return GestureDetector(
      onTap: isOutOfStock ? null : () => _addToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image/Icon
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.grey[200] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          product.image,
                          style: TextStyle(
                            fontSize: 30,
                            color: isOutOfStock ? Colors.grey[400] : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Product Name
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isOutOfStock ? Colors.grey[400] : Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Category
                  Text(
                    product.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),

                  // Price and Stock
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock ? Colors.grey[400] : Colors.green[700],
                        ),
                      ),
                      Text(
                        'Stock: ${product.stock}',
                        style: TextStyle(
                          fontSize: 12,
                          color: product.stock <= 5 ? Colors.red[600] : Colors.grey[600],
                          fontWeight: product.stock <= 5 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Out of Stock Overlay
            if (isOutOfStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'OUT OF STOCK',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

            // Low Stock Indicator
            if (product.stock <= 5 && product.stock > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Cart Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Current Sale',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (cartItems.isNotEmpty)
                  TextButton(
                    onPressed: _clearCart,
                    child: Text(
                      'Clear All',
                      style: TextStyle(color: Colors.red[600]),
                    ),
                  ),
              ],
            ),
          ),

          // Cart Items
          Expanded(
            child: cartItems.isEmpty
                ? _buildEmptyCart()
                : ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                return _buildCartItem(cartItems[index], index);
              },
            ),
          ),

          // Cart Total and Actions
          if (cartItems.isNotEmpty) _buildCartFooter(),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products to start selling',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              item.product.image,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        title: Text(
          item.product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${item.product.price.toStringAsFixed(2)} each'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decrease quantity
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.remove, size: 16, color: Colors.red[700]),
                onPressed: () => _updateCartItemQuantity(index, item.quantity - 1),
              ),
            ),

            // Quantity
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Increase quantity
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.add, size: 16, color: Colors.green[700]),
                onPressed: () => _updateCartItemQuantity(index, item.quantity + 1),
              ),
            ),

            const SizedBox(width: 8),

            // Total price for this item
            SizedBox(
              width: 60,
              child: Text(
                '${(item.product.price * item.quantity).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartFooter() {
    final subtotal = _calculateSubtotal();
    final total = subtotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Totals
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payment, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'PROCESS PAYMENT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  List<Product> _getFilteredProducts() {
    return allProducts.where((product) {
      final matchesSearch = searchQuery.isEmpty ||
          product.name.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory = selectedCategory == 'All' ||
          product.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  double _calculateSubtotal() {
    return cartItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
  }

  void _addToCart(Product product) {
    HapticFeedback.lightImpact();

    if (product.stock <= 0) {
      _showSnackBar('${product.name} is out of stock', Colors.red);
      return;
    }

    setState(() {
      final existingIndex = cartItems.indexWhere((item) => item.product.id == product.id);

      if (existingIndex >= 0) {
        // Update existing item
        cartItems[existingIndex] = CartItem(
          product: product,
          quantity: cartItems[existingIndex].quantity + 1,
        );
      } else {
        // Add new item
        cartItems.add(CartItem(product: product, quantity: 1));
      }

      // Update product stock (for demo purposes)
      product.stock--;

      // Switch to cart tab on mobile
      if (MediaQuery.of(context).size.width <= 600) {
        // _tabController.animateTo(1);
      }
    });

    _showSnackBar('${product.name} added to cart', Colors.green);
  }

  void _updateCartItemQuantity(int index, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        // Return stock when removing item
        cartItems[index].product.stock += cartItems[index].quantity;
        cartItems.removeAt(index);
      } else {
        final oldQuantity = cartItems[index].quantity;
        final difference = newQuantity - oldQuantity;

        // Update stock
        cartItems[index].product.stock -= difference;

        // Update quantity
        cartItems[index] = CartItem(
          product: cartItems[index].product,
          quantity: newQuantity,
        );
      }
    });
  }

  void _clearCart() {
    setState(() {
      // Return all stock
      for (final item in cartItems) {
        item.product.stock += item.quantity;
      }
      cartItems.clear();
    });
    _showSnackBar('Cart cleared', Colors.orange);
  }

  void _scanBarcode() {
    // Simulate barcode scanning
    _showSnackBar('Barcode scanner opened (simulation)', Colors.blue);
  }

  void _processPayment() {
    showDialog(
      context: context,
      builder: (context) => _buildPaymentDialog(),
    );
  }

  Widget _buildPaymentDialog() {
    final total = _calculateSubtotal() * 1.08; // Include tax

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Process Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total: ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _completePayment('Card'),
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  void _completePayment(String paymentMethod) {
    Navigator.pop(context); // Close dialog

    // Simulate payment processing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing payment...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Simulate processing delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close processing dialog

      // Show success
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              const Text('Payment Successful!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearCart();
                _tabController.animateTo(0);
                _showSnackBar('Transaction completed successfully!', Colors.green);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void _syncData() {
    _showSnackBar('Syncing data...', Colors.blue);
    // Simulate sync
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        unsyncedCount = 0;
      });
      _showSnackBar('Data synced successfully!', Colors.green);
    });
  }

  void _showTransactionHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction History'),
        content: const Text('Transaction history feature will be implemented next.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await AuthViewModel().signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SigninScreen()),
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1000), // 1.5 seconds
      ),
    );
  }


  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

// Data Models
class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  int stock;
  final String image;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.stock,
    required this.image,
  });
}

class CartItem {
  final Product product;
  final int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });
}