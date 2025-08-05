// auth_service.dart - Add this file to your services folder

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strada/view/initial/initial_screen.dart';

class AuthViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String userType,
    required BuildContext context
  }) async {
    try {
      // Create user account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Update display name
        // await user.updateDisplayName(name);

        // Save user data to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          // 'name': name,
          'userType': 'initial', // Set as initial as requested
          'joinDate': FieldValue.serverTimestamp(),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        }).then((onValue) {

          // Save to SharedPreferences
          _saveUserToPreferences({
            'uid': user.uid,
            'email': email,
            'userType': 'initial',
            'isActive': true,
          });

          // Navigate to initial screen
          Navigator.push(context, MaterialPageRoute(builder: (context) => InitialScreen()));
        });

        return {
          'success': true,
          'user': user,
          'userData': {
            'uid': user.uid,
            'email': email,
            'userType': 'initial',
            'isActive': true,
          }
        };
      } else {
        return {'success': false, 'error': 'Failed to create user'};
      }
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in user
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        // Get user data from Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          // Check if user is active
          if (userData['isActive'] != true) {
            await _auth.signOut();
            return {'success': false, 'error': 'Account is deactivated'};
          }

          // Save to SharedPreferences
          await _saveUserToPreferences(userData);

          return {
            'success': true,
            'user': user,
            'userData': userData
          };
        } else {
          // User document doesn't exist, sign out
          await _auth.signOut();
          return {'success': false, 'error': 'User data not found'};
        }
      } else {
        return {'success': false, 'error': 'Failed to sign in'};
      }
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _clearUserFromPreferences();
  }

  // Get user data from SharedPreferences (for offline access)
  Future<Map<String, dynamic>?> getUserFromPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? uid = prefs.getString('user_uid');
    String? email = prefs.getString('user_email');
    String? name = prefs.getString('user_name');
    String? userType = prefs.getString('user_type');
    bool? isActive = prefs.getBool('user_is_active');

    if (uid != null && email != null) {
      return {
        'uid': uid,
        'email': email,
        'name': name,
        'userType': userType,
        'isActive': isActive ?? true,
      };
    }
    return null;
  }

  // Check if user is logged in and get cached data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    User? user = currentUser;
    if (user != null) {
      // First try to get from SharedPreferences (faster)
      Map<String, dynamic>? cachedData = await getUserFromPreferences();
      if (cachedData != null && cachedData['uid'] == user.uid) {
        return cachedData;
      }

      // If not in cache or different user, get from Firestore
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          // Update cache
          await _saveUserToPreferences(userData);
          return userData;
        }
      } catch (e) {
        // If Firestore fails, return cached data if available
        return cachedData;
      }
    }
    return null;
  }

  // Update user type (for admin approval)
  Future<bool> updateUserType(String uid, String newUserType) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'userType': newUserType,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update cache if it's current user
      if (currentUser?.uid == uid) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_type', newUserType);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {'success': true, 'message': 'Password reset email sent'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _getErrorMessage(e.code)};
    }
  }

  // Save user data to SharedPreferences
  Future<void> _saveUserToPreferences(Map<String, dynamic> userData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_uid', userData['uid'] ?? '');
    await prefs.setString('user_email', userData['email'] ?? '');
    await prefs.setString('user_name', userData['name'] ?? '');
    await prefs.setString('user_type', userData['userType'] ?? 'initial');
    await prefs.setBool('user_is_active', userData['isActive'] ?? true);
    await prefs.setString('last_login', DateTime.now().toIso8601String());
  }

  // Clear user data from SharedPreferences
  Future<void> _clearUserFromPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove('user_uid');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_type');
    await prefs.remove('user_is_active');
    await prefs.remove('last_login');
  }

  // Update user data in SharedPreferences (called when role changes)
  Future<void> updateUserDataInPreferences(Map<String, dynamic> userData) async {
    await _saveUserToPreferences(userData);
  }

  // Get user-friendly error messages
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}