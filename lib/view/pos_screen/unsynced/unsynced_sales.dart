import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class UnsyncedSales extends StatefulWidget {
  const UnsyncedSales({super.key});

  @override
  State<UnsyncedSales> createState() => _UnsyncedSalesState();
}

class _UnsyncedSalesState extends State<UnsyncedSales>
    with TickerProviderStateMixin {
  late AnimationController _syncAnimationController;
  late Animation<double> _syncAnimation;
  bool _isSyncing = false;

  List<Map<String, dynamic>> unsyncedSales = [];

  @override
  void initState() {
    super.initState();
    _loadUnsyncedSales();
    _syncAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _syncAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _syncAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadUnsyncedSales() async {
    final box = await Hive.openBox('unsynced_sales');
    final salesData = box.values.toList();

    final sales = <Map<String, dynamic>>[];
    for (final saleData in salesData) {
      if (saleData is Map) {
        final sale = <String, dynamic>{};
        saleData.forEach((key, value) {
          sale[key.toString()] = value;
        });
        sales.add(sale);
      }
    }

    setState(() {
      unsyncedSales = sales;
    });
  }

  @override
  void dispose() {
    _syncAnimationController.dispose();
    super.dispose();
  }

  void _syncSales() async {
    print("🌐 Checking connectivity...");
    final connectivityResults = await Connectivity().checkConnectivity();

    if (connectivityResults.contains(ConnectivityResult.none)) {
      print("📱 OFFLINE: Can't sync sales. Aborting.");
      _showSyncSuccessToast(Colors.red , 'You are offline can\'t update the data');
      return;
    }

    final box = await Hive.openBox('unsynced_sales');
    if (box.isEmpty) {
      print("📦 No unsynced sales to sync. Exiting.");
      return;
    }

    setState(() => _isSyncing = true);
    _syncAnimationController.repeat();

    final salesToSync = box.values.toList();
    final keys = box.keys.toList();

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final WriteBatch batch = firestore.batch();

    for (int i = 0; i < salesToSync.length; i++) {
      try {
        final sale = Map<String, dynamic>.from(salesToSync[i] as Map);
        final DateTime createdAt = DateTime.parse(sale['createdAt']);
        final String dateKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

        final saleDocRef = firestore
            .collection('sales')
            .doc(dateKey)
            .collection('transactions')
            .doc(sale['id']);

        batch.set(saleDocRef, {
          ...sale,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': Timestamp.fromDate(createdAt),
        });

        double totalProfit = 0;
        final List itemsList = sale['items'] as List;
        for (final rawItem in itemsList) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          final double profit = (item['pricePerItem'] - item['costPrice']) * item['quantity'];
          totalProfit += profit;

          final productRef = firestore.collection('products').doc(item['productId']);
          batch.update(productRef, {
            'stock': FieldValue.increment(-item['quantity']),
          });
        }

        final summaryRef = firestore.collection('sales_summary').doc(dateKey);
        batch.set(summaryRef, {
          'date': dateKey,
          'totalSales': FieldValue.increment(sale['totalAmount']),
          'totalProfit': FieldValue.increment(totalProfit),
          'totalTransactions': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
          'year': createdAt.year,
          'month': createdAt.month,
          'day': createdAt.day,
        }, SetOptions(merge: true));

        await box.delete(keys[i]);

      } catch (e) {
        debugPrint("❌ Sync failed for sale ${salesToSync[i]?['id']}: $e");
      }
    }

    try {
      await batch.commit();
      print("✅ Batch committed successfully.");
    } catch (e) {
      debugPrint("❌ Batch commit failed: $e");
    }

    _syncAnimationController.stop();
    _syncAnimationController.reset();
    setState(() {
      _isSyncing = false;
    });

    await _loadUnsyncedSales();
    _showSyncSuccessToast(Colors.green , 'Sales synced successfully!');
  }

  void _showSyncSuccessToast(Color color, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  double get _totalAmount {
    return unsyncedSales.fold(0.0, (sum, sale) {
      if (sale['totalAmount'] != null) {
        return sum + (sale['totalAmount'] as num).toDouble();
      }
      return sum;
    });
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final DateTime dt = DateTime.parse(dateTimeStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Unsynced Sales'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pending_actions,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rs ${_totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      Text(
                        '${unsyncedSales.length} sales pending sync',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sales List
          Expanded(
            child: unsyncedSales.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All sales are synced!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: unsyncedSales.length,
              itemBuilder: (context, index) {
                final sale = unsyncedSales[index];
                final items = (sale['items'] as List?)?.map((item) => Map<String, dynamic>.from(item)).toList() ?? <Map<String, dynamic>>[];
                final total = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rs ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (sale['paymentMethod'] != null)
                                  Text(
                                    sale['paymentMethod'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'PENDING',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Products List
                        if (items.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Items (${items.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...items.map((item) {
                                  final productName = item['productName'] ?? 'Unknown Product';
                                  final quantity = item['quantity'] ?? 0;
                                  final price = (item['pricePerItem'] as num?)?.toDouble() ?? 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[400],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            productName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${quantity}x Rs${price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Footer Info
                        if (sale['createdAt'] != null)
                          Text(
                            _formatDateTime(sale['createdAt']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Sync Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _syncAnimation,
              builder: (context, child) {
                return ElevatedButton.icon(
                  onPressed: _isSyncing || unsyncedSales.isEmpty
                      ? null
                      : _syncSales,
                  icon: _isSyncing
                      ? Transform.rotate(
                    angle: _syncAnimation.value * 2 * 3.14159,
                    child: const Icon(Icons.sync, size: 20),
                  )
                      : const Icon(Icons.cloud_upload, size: 20),
                  label: Text(
                    _isSyncing
                        ? 'Syncing...'
                        : unsyncedSales.isEmpty
                        ? 'Nothing to Sync'
                        : 'Sync ${unsyncedSales.length} Sales',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: _isSyncing
                        ? Colors.grey[400]
                        : Colors.blue[600],
                    foregroundColor: Colors.white,
                    elevation: _isSyncing ? 0 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
}