import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SaleViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Private variables
  List<DocumentSnapshot> _todaySales = [];
  bool _isLoading = true;
  double _totalSalesToday = 0.0;
  int _totalTransactions = 0;
  double _totalProfit = 0.0;
  Map<String, dynamic> _dailySummary = {}; // Fixed spelling
  String? _errorMessage;

  // Getters
  List<DocumentSnapshot> get todaySales => _todaySales;
  bool get isLoading => _isLoading;
  double get totalSalesToday => _totalSalesToday;
  int get totalTransactions => _totalTransactions;
  double get totalProfit => _totalProfit;
  Map<String, dynamic> get dailySummary => _dailySummary; // Fixed spelling
  String? get errorMessage => _errorMessage;

  // Constructor
  SaleViewModel() {
    fetchTodaySales();
    fetchDailySummary(); // Added this line to fetch daily summary on initialization
  }

  /// Fetches today's sales from Firebase
  Future<void> fetchTodaySales() async {
    try {
      _setLoading(true);
      _clearError();

      DateTime now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      QuerySnapshot snapshot = await _firestore
          .collection('sales').doc(dateKey).collection('transactions')
          .orderBy('createdAt', descending: true)
          .get();

      _processSalesData(snapshot.docs);

    } catch (e) {
      _setError('Error fetching sales: ${e.toString()}');
      print('Error fetching sales: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetches sales for a specific date range
  Future<void> fetchSalesForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      _setLoading(true);
      _clearError();

      DateTime now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      QuerySnapshot snapshot = await _firestore
          .collection('sales').doc(dateKey).collection('transactions')
          .orderBy('createdAt', descending: true)
          .get();

      _processSalesData(snapshot.docs);

    } catch (e) {
      _setError('Error fetching sales for date range: ${e.toString()}');
      print('Error fetching sales for date range: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetches sales for a specific employee
  Future<void> fetchSalesForEmployee(String employeeId) async {
    try {
      _setLoading(true);
      _clearError();

      DateTime now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      QuerySnapshot snapshot = await _firestore
          .collection('sales').doc(dateKey).collection('transactions')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('createdAt', descending: true)
          .get();

      _processSalesData(snapshot.docs);

    } catch (e) {
      _setError('Error fetching employee sales: ${e.toString()}');
      print('Error fetching employee sales: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchDailySummary() async {
    try {
      _setLoading(true);
      _clearError();

      DateTime now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      DocumentSnapshot snapshot = await _firestore
          .collection('sales_summary')
          .doc(dateKey)
          .get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

        _dailySummary = {
          'date': data['date'] ?? dateKey,
          'day': data['day'] ?? now.day,
          'month': data['month'] ?? now.month,
          'year': data['year'] ?? now.year,
          'totalProfit': data['totalProfit']?.toDouble() ?? 0.0,
          'totalSales': data['totalSales']?.toDouble() ?? 0.0,
          'totalTransactions': data['totalTransactions'] ?? 0,
          'lastUpdated': data['lastUpdated'],
        };
      } else {
        // No sales data for today yet
        _dailySummary = {
          'date': dateKey,
          'day': now.day,
          'month': now.month,
          'year': now.year,
          'totalProfit': 0.0,
          'totalSales': 0.0,
          'totalTransactions': 0,
          'lastUpdated': null,
        };
      }

    } catch (e) {
      _setError('Error fetching daily sales summary: ${e.toString()}');
      print('Error fetching daily sales summary: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Get sales statistics
  Future<Map<String, dynamic>> getSalesStatistics() async {
    try {
      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day);
      DateTime todayEnd = todayStart.add(const Duration(days: 1));

      QuerySnapshot snapshot = await _firestore
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
          .get();

      Map<String, int> paymentMethodCount = {};
      Map<String, double> paymentMethodTotal = {};
      double totalSales = 0.0;
      int totalItems = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String paymentMethod = data['paymentMethod'] ?? 'Unknown';
        double amount = data['totalAmount']?.toDouble() ?? 0.0;
        List<dynamic> items = data['items'] ?? [];

        // Count payment methods
        paymentMethodCount[paymentMethod] = (paymentMethodCount[paymentMethod] ?? 0) + 1;
        paymentMethodTotal[paymentMethod] = (paymentMethodTotal[paymentMethod] ?? 0.0) + amount;

        totalSales += amount;
        totalItems += items.length;
      }

      return {
        'totalSales': totalSales,
        'totalTransactions': snapshot.docs.length,
        'totalItems': totalItems,
        'paymentMethodCount': paymentMethodCount,
        'paymentMethodTotal': paymentMethodTotal,
        'averageTransactionValue': snapshot.docs.isEmpty ? 0.0 : totalSales / snapshot.docs.length,
      };
    } catch (e) {
      print('Error getting sales statistics: $e');
      return {};
    }
  }

  /// Private method to process sales data
  void _processSalesData(List<DocumentSnapshot> docs) {
    double total = 0.0;
    double profit = 0.0;

    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      total += data['totalAmount']?.toDouble() ?? 0.0;

      // Calculate profit from items
      List<dynamic> items = data['items'] ?? [];
      for (var item in items) {
        double salePrice = item['pricePerItem']?.toDouble() ?? 0.0;
        double costPrice = item['costPrice']?.toDouble() ?? 0.0;
        int quantity = item['quantity']?.toInt() ?? 0;

        profit += (salePrice - costPrice) * quantity;
      }
    }

    _todaySales = docs;
    _totalSalesToday = total;
    _totalTransactions = docs.length;
    _totalProfit = profit;
  }

  /// Private method to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Private method to set error
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Private method to clear error
  void _clearError() {
    _errorMessage = null;
  }

  /// Refresh data
  Future<void> refresh() async {
    await fetchTodaySales();
    await fetchDailySummary(); // Added this line to refresh daily summary too
  }

  /// Clear all data
  void clearData() {
    _todaySales = [];
    _totalSalesToday = 0.0;
    _totalTransactions = 0;
    _totalProfit = 0.0;
    _dailySummary = {}; // Fixed spelling
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Helper method to format numbers for display
  String formatSalesAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}