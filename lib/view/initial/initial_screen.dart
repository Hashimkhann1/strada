import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strada/view_model/auth/auth_view_model.dart';
import 'package:strada/view/auth/signin_screen/signin_screen.dart';
import 'package:strada/view/pos_screen/pos_screen.dart';
import 'package:strada/view/admin_dashboard/admin_dashboard_screen.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({Key? key}) : super(key: key);

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  late AuthViewModel _authViewModel;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _authViewModel = AuthViewModel();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    final userData = await _authViewModel.getCurrentUserData();
    if (userData != null) {
      setState(() {
        currentUserId = userData['uid'];
      });
    }
  }

  void _handleRoleChange(Map<String, dynamic> userData) async {
    // Update SharedPreferences with new data
    await _authViewModel.updateUserDataInPreferences(userData);

    if (!mounted) return;

    String userType = userData['userType'] ?? 'initial';
    bool isActive = userData['isActive'] ?? false;

    // Check if account is still active
    if (!isActive) {
      _showDeactivatedDialog();
      return;
    }

    // Navigate based on new role
    switch (userType) {
      case 'admin':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboard(userData: userData),
          ),
        );
        break;
      case 'employee':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => POSScreen(),
          ),
        );
        break;
      case 'initial':
      // Stay on current screen, no navigation needed
        break;
      default:
      // Unknown role, stay on initial screen
        break;
    }
  }

  void _showDeactivatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text('Account Deactivated'),
          ],
        ),
        content: const Text('Your account has been deactivated by an administrator.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authViewModel.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SigninScreen()),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        appBar: AppBar(
          title: const Text('Initial'),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            // Add logout button
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _authViewModel.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SigninScreen()),
                );
              },
            ),
          ],
        ),
        body: currentUserId == null
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .snapshots(),
          builder: (context, snapshot) {
            // Handle stream states
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading data',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => setState(() {}), // Rebuild to retry
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Checking for updates...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // Document exists and has data
            if (snapshot.hasData && snapshot.data!.exists) {
              Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
              String userType = userData['userType'] ?? 'initial';
              bool isActive = userData['isActive'] ?? false;

              // If role changed from 'initial', navigate to appropriate screen
              if (userType != 'initial' && isActive) {
                // Use post frame callback to avoid calling setState during build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handleRoleChange(userData);
                });
              }

              // If account was deactivated
              if (!isActive) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showDeactivatedDialog();
                });
              }

              // Show initial screen UI with status indicator
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: userType == 'initial' ? Colors.orange[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: userType == 'initial' ? Colors.orange[300]! : Colors.green[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              userType == 'initial' ? Icons.hourglass_empty : Icons.check_circle,
                              size: 16,
                              color: userType == 'initial' ? Colors.orange[700] : Colors.green[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              userType == 'initial' ? 'Pending Approval' : 'Approved - Redirecting...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: userType == 'initial' ? Colors.orange[700] : Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Icon(
                        Icons.admin_panel_settings,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 24),

                      Text(
                        userType == 'initial'
                            ? 'Contact the admin to give you access'
                            : 'Access granted! Redirecting...',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      if (userType == 'initial') ...[
                        const SizedBox(height: 16),
                        Text(
                          'Your account is being reviewed by an administrator.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You will be automatically redirected once approved.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            // Document doesn't exist
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'User data not found',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await _authViewModel.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SigninScreen()),
                      );
                    },
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}