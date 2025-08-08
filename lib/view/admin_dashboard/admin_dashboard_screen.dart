import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strada/view/admin_dashboard/add_product_screen/add_product_screen.dart';
import 'package:strada/view/admin_dashboard/sale/sale_view.dart';
import 'package:strada/view/admin_dashboard/stock/stock_screen.dart';
import 'package:strada/view/admin_dashboard/update_product/update_product_screen.dart';
import 'package:strada/view/admin_dashboard/user_managment/user_managment_screen.dart';
import 'package:strada/view/auth/signin_screen/signin_screen.dart';
import 'package:strada/view_model/admin_view_model/product/product_view_model.dart';
import 'package:strada/view_model/admin_view_model/sale/sale_view_model.dart';
import 'package:strada/view_model/auth/auth_view_model.dart';

// Add this provider at the top of your file or in a separate providers file
final saleViewModelProvider = ChangeNotifierProvider<SaleViewModel>((ref) {
  return SaleViewModel();
});

class AdminDashboard extends ConsumerStatefulWidget {
  final Map<String, dynamic>? userData;
  const AdminDashboard({super.key, required this.userData});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  String _getUserDisplayName() {
    String name = widget.userData?['name'] ?? '';
    String email = widget.userData?['email'] ?? '';

    if (name.isNotEmpty) {
      return name;
    } else if (email.isNotEmpty) {
      return email.split('@')[0];
    } else {
      return 'Admin';
    }
  }

  // Helper method to determine if we're on web/desktop
  bool _isWebOrDesktop(double screenWidth) {
    return screenWidth > 800;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebOrDesktop = _isWebOrDesktop(screenWidth);

    // Watch the providers for real-time data
    final totalStockAsync = ref.watch(totalStockProvider);
    final lowStockCountAsync = ref.watch(lowStockCountProvider);
    final saleViewModel = ref.watch(saleViewModelProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.blue[600],
          automaticallyImplyLeading: false,
          elevation: 0,
          title: const Text(
            'Admin Panel',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.account_circle_rounded,
                color: Colors.white,
              ),
              onPressed: _logout,
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            // Refresh the data
            ref.invalidate(totalStockProvider);
            ref.invalidate(lowStockCountProvider);
            await saleViewModel.refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isWebOrDesktop ? 32 : 16),
            child: isWebOrDesktop
                ? _buildWebLayout(totalStockAsync, lowStockCountAsync, saleViewModel)
                : _buildMobileLayout(totalStockAsync, lowStockCountAsync, saleViewModel),
          ),
        ),
      ),
    );
  }

  // Mobile layout (original layout)
  Widget _buildMobileLayout(
      AsyncValue<int> totalStockAsync,
      AsyncValue<int> lowStockCountAsync,
      SaleViewModel saleViewModel,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        // Quick Stats
        Row(
          children: [
            Expanded(
              child: totalStockAsync.when(
                data: (totalStock) => _buildStatCard(
                  'Current Stock',
                  totalStock.toString(),
                  Icons.inventory_2,
                  Colors.blue,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StockScreen(),
                      ),
                    );
                  },
                ),
                loading: () => _buildLoadingStatCard(
                  'Current Stock',
                  Icons.inventory_2,
                  Colors.blue,
                ),
                error: (error, stack) => _buildErrorStatCard(
                  'Current Stock',
                  Icons.inventory_2,
                  Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: lowStockCountAsync.when(
                data: (lowStockCount) => _buildStatCard(
                  'Low Stock',
                  lowStockCount.toString(),
                  Icons.warning,
                  lowStockCount > 0 ? Colors.red : Colors.green,
                      () {},
                ),
                loading: () => _buildLoadingStatCard(
                  'Low Stock',
                  Icons.warning,
                  Colors.orange,
                ),
                error: (error, stack) => _buildErrorStatCard(
                  'Low Stock',
                  Icons.warning,
                  Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Fixed Sales Card
            Expanded(
              child: saleViewModel.isLoading
                  ? _buildLoadingStatCard(
                'Sales',
                Icons.trending_up,
                Colors.orange,
              )
                  : _buildStatCard(
                'Sales',
                saleViewModel.formatSalesAmount(
                    saleViewModel.dailySummary['totalSales']?.toDouble() ?? 0.0
                ),
                Icons.trending_up,
                Colors.orange,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SaleView()),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Low Stock Alert
        _buildLowStockAlert(lowStockCountAsync),

        // Main Actions
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons
        _buildActionButton(
          'Add New Product',
          'Add products to your store',
          Icons.add_box,
          Colors.blue,
              () => _navigateToAddProduct(),
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          'Update Products',
          'Edit existing product details',
          Icons.edit,
          Colors.green,
              () => _navigateToUpdateProduct(),
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          'Manage Users',
          'Add or remove employees',
          Icons.people_alt,
          Colors.purple,
              () => _navigateToUserManagement(),
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          'View Records',
          'Check sales and transactions',
          Icons.receipt_long,
          Colors.orange,
              () => _navigateToRecords(),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // Web layout (responsive design)
  Widget _buildWebLayout(
      AsyncValue<int> totalStockAsync,
      AsyncValue<int> lowStockCountAsync,
      SaleViewModel saleViewModel,
      ) {
    return Center(
      child: SizedBox(
        width: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Welcome Section for Web
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${_getUserDisplayName()}!',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage your store efficiently from the admin dashboard',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dashboard,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Quick Stats Grid for Web (4 columns)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1.2,
              children: [
                totalStockAsync.when(
                  data: (totalStock) => _buildWebStatCard(
                    'Current Stock',
                    totalStock.toString(),
                    Icons.inventory_2,
                    Colors.blue,
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StockScreen(),
                        ),
                      );
                    },
                  ),
                  loading: () => _buildWebLoadingStatCard(
                    'Current Stock',
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                  error: (error, stack) => _buildWebErrorStatCard(
                    'Current Stock',
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                ),
                lowStockCountAsync.when(
                  data: (lowStockCount) => _buildWebStatCard(
                    'Low Stock',
                    lowStockCount.toString(),
                    Icons.warning,
                    lowStockCount > 0 ? Colors.red : Colors.green,
                        () {},
                  ),
                  loading: () => _buildWebLoadingStatCard(
                    'Low Stock',
                    Icons.warning,
                    Colors.orange,
                  ),
                  error: (error, stack) => _buildWebErrorStatCard(
                    'Low Stock',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                saleViewModel.isLoading
                    ? _buildWebLoadingStatCard(
                  'Sales',
                  Icons.trending_up,
                  Colors.orange,
                )
                    : _buildWebStatCard(
                  'Sales',
                  saleViewModel.formatSalesAmount(
                      saleViewModel.dailySummary['totalSales']?.toDouble() ?? 0.0
                  ),
                  Icons.trending_up,
                  Colors.orange,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SaleView()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Low Stock Alert for Web
            _buildLowStockAlert(lowStockCountAsync),

            // Main Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons Grid for Web (2 columns)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 3.5,
              children: [
                _buildWebActionButton(
                  'Add New Product',
                  'Add products to your store',
                  Icons.add_box,
                  Colors.blue,
                      () => _navigateToAddProduct(),
                ),
                _buildWebActionButton(
                  'Update Products',
                  'Edit existing product details',
                  Icons.edit,
                  Colors.green,
                      () => _navigateToUpdateProduct(),
                ),
                _buildWebActionButton(
                  'Manage Users',
                  'Add or remove employees',
                  Icons.people_alt,
                  Colors.purple,
                      () => _navigateToUserManagement(),
                ),
                _buildWebActionButton(
                  'View Records',
                  'Check sales and transactions',
                  Icons.receipt_long,
                  Colors.orange,
                      () => _navigateToRecords(),
                ),
              ],
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // Mobile Stat Card (original)
  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      void Function()? onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Web Stat Card (enhanced)
  Widget _buildWebStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      void Function()? onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Web Action Button
  Widget _buildWebActionButton(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  // Loading and Error cards for web
  Widget _buildWebLoadingStatCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebErrorStatCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            '--',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Mobile Loading and Error cards (original)
  Widget _buildLoadingStatCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStatCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            '--',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Mobile Action Button (original)
  Widget _buildActionButton(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  // Low Stock Alert (shared)
  Widget _buildLowStockAlert(AsyncValue<int> lowStockCountAsync) {
    return lowStockCountAsync.when(
      data: (lowStockCount) {
        if (lowStockCount > 0) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red[600],
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$lowStockCount product(s) running low on stock',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StockScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'View',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  // Navigation methods
  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProductScreen()),
    );
  }

  void _navigateToUpdateProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UpdateProductScreen()),
    );
  }

  void _navigateToUserManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserManagementScreen()),
    );
  }

  void _navigateToRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecordsScreen()),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Create an instance of AuthViewModel
              AuthViewModel authViewModel = AuthViewModel();
              await authViewModel.signOut();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const SigninScreen(),
                ),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Records'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 80, color: Colors.orange),
              SizedBox(height: 20),
              Text(
                'Sales Records',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'View your sales and transactions here',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}