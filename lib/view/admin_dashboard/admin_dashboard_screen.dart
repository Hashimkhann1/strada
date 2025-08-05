import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strada/view/admin_dashboard/add_product_screen/add_product_screen.dart';
import 'package:strada/view/admin_dashboard/update_product/update_product_screen.dart';
import 'package:strada/view/admin_dashboard/user_managment/user_managment_screen.dart';
import 'package:strada/view/auth/signin_screen/signin_screen.dart';
import 'package:strada/view_model/auth/auth_view_model.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const AdminDashboard({super.key, required this.userData});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
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

  @override
  Widget build(BuildContext context) {
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
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 10),

              // Quick Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Products',
                      '156',
                      Icons.inventory_2,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Users',
                      '24',
                      Icons.people,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Sales',
                      '1.2K',
                      Icons.trending_up,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

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
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddProductScreen(),
      ),
    );
  }

  void _navigateToUpdateProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UpdateProductScreen(),
      ),
    );
  }

  void _navigateToUserManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserManagementScreen(),
      ),
    );
  }

  void _navigateToRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordsScreen(),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                MaterialPageRoute(builder: (context) => const SigninScreen()),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
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