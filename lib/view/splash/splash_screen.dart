import 'package:flutter/material.dart';
import 'package:strada/view/admin_dashboard/admin_dashboard_screen.dart';
import 'package:strada/view/auth/signin_screen/signin_screen.dart';
import 'package:strada/view/pos_screen/pos_screen.dart';
import 'package:strada/view/initial/initial_screen.dart';
import 'package:strada/view_model/auth/auth_view_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Add a small delay for splash effect
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Check if user is logged in and get cached data
      Map<String, dynamic>? userData = await AuthViewModel().getCurrentUserData();

      if (!mounted) return;

      if (userData != null) {
        // User is logged in, check their type and navigate accordingly
        String userType = userData['userType'] ?? 'initial';
        bool isActive = userData['isActive'] ?? false;

        if (!isActive) {
          // Account deactivated, go to signin
          _navigateToSignin();
          return;
        }

        switch (userType) {
          case 'admin':
          // Navigate to Admin Dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDashboard(userData: userData),
              ),
            );
            break;
          case 'employee':
          // Navigate to POS Screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => POSScreen(),
              ),
            );
            break;
          case 'initial':
          // Navigate to Initial Screen (waiting for admin approval)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const InitialScreen(),
              ),
            );
            break;
          default:
          // Unknown user type, go to signin
            _navigateToSignin();
            break;
        }
      } else {
        // No user logged in, go to signin
        _navigateToSignin();
      }
    } catch (e) {
      // Error occurred, go to signin
      _navigateToSignin();
    }
  }

  void _navigateToSignin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SigninScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.store,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            Text(
              'POS System',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Point of Sale Management',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),

            // Loading indicator
            const CircularProgressIndicator(),
            const SizedBox(height: 16),

            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}