import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:strada/view_model/admin_view_model/sale/sale_view_model.dart';

class SaleView extends StatefulWidget {
  const SaleView({super.key});

  @override
  State<SaleView> createState() => _SaleViewState();
}

class _SaleViewState extends State<SaleView> with TickerProviderStateMixin {
  late SaleViewModel _viewModel;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _viewModel = SaleViewModel();
    _viewModel.addListener(_onViewModelChanged);

    // Initialize shimmer animation
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    if (_viewModel.isLoading) {
      _shimmerController.repeat();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {
        if (_viewModel.isLoading) {
          _shimmerController.repeat();
        } else {
          _shimmerController.stop();
        }
      });
    }
  }

  // Helper method to determine if we're on web/desktop
  bool _isWebOrDesktop(double screenWidth) {
    return screenWidth > 800;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _viewModel.fetchSalesForSpecificDate(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebOrDesktop = _isWebOrDesktop(screenWidth);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isWebOrDesktop),
      body: _viewModel.isLoading
          ? _buildShimmerLoading(isWebOrDesktop)
          : RefreshIndicator(
        onRefresh: () => _viewModel.fetchSalesForSpecificDate(_selectedDate),
        color: const Color(0xFF6366F1),
        backgroundColor: Colors.white,
        child: isWebOrDesktop
            ? _buildWebLayout()
            : _buildMobileLayout(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isWebOrDesktop) {
    String title = _isToday(_selectedDate) ? 'Today\'s Sales' : 'Sales';

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: isWebOrDesktop ? 28 : 22,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.1),
      surfaceTintColor: Colors.transparent,
      centerTitle: isWebOrDesktop,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: const Color(0xFF6366F1),
                size: isWebOrDesktop ? 24 : 20,
              ),
            ),
            onPressed: () => _viewModel.fetchSalesForSpecificDate(_selectedDate),
          ),
        ),
      ],
    );
  }

  // Mobile Layout (Original)
  Widget _buildMobileLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSummarySection(false)),
        SliverToBoxAdapter(child: _buildDateHeader(false)),
        _buildSalesList(false),
      ],
    );
  }

  // Web Layout (Enhanced)
  Widget _buildWebLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Web Summary Section
              _buildSummarySection(true),
              const SizedBox(height: 32),

              // Date Header for Web
              _buildDateHeader(true),
              const SizedBox(height: 24),

              // Sales List for Web
              if (_viewModel.todaySales.isEmpty)
                SizedBox(
                  height: 400,
                  child: _buildEmptyState(true),
                )
              else
                _buildWebSalesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(bool isWeb) {
    if (isWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Web Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
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
                        _isToday(_selectedDate) ? 'Today\'s Performance' : 'Sales Performance',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your sales and profit margins',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Web Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildWebSummaryCard(
                  'Total Sales',
                  'PKR ${NumberFormat('#,###').format(_viewModel.totalSalesToday)}',
                  Icons.trending_up_rounded,
                  const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildWebSummaryCard(
                  'Total Profit',
                  'PKR ${NumberFormat('#,###').format(_viewModel.totalProfit)}',
                  Icons.receipt_long_rounded,
                  const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildWebSummaryCard(
                  'Transactions',
                  '${_viewModel.todaySales.length}',
                  Icons.receipt_rounded,
                  const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Mobile Summary (Original)
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Sales',
              'PKR ${NumberFormat('#,###').format(_viewModel.totalSalesToday)}',
              Icons.trending_up_rounded,
              const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              false,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Profit',
              'PKR ${NumberFormat('#,###').format(_viewModel.totalProfit)}',
              Icons.receipt_long_rounded,
              const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, LinearGradient gradient, bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: isWeb ? 20 : 12,
            offset: Offset(0, isWeb ? 8 : 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isWeb ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                ),
                child: Icon(icon, color: Colors.white, size: isWeb ? 28 : 20),
              ),
              SizedBox(width: isWeb ? 16 : 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isWeb ? 18 : 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isWeb ? 24 : 16),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isWeb ? 32 : 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSummaryCard(String title, String value, IconData icon, LinearGradient gradient) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(bool isWeb) {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        margin: isWeb ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 32 : 20,
          vertical: isWeb ? 24 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: isWeb ? 12 : 8,
              offset: Offset(0, isWeb ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isWeb ? 16 : 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: const Color(0xFF6366F1),
                size: isWeb ? 28 : 20,
              ),
            ),
            SizedBox(width: isWeb ? 24 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(_selectedDate),
                    style: TextStyle(
                      fontSize: isWeb ? 16 : 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    DateFormat('MMMM d, yyyy').format(_selectedDate),
                    style: TextStyle(
                      fontSize: isWeb ? 24 : 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(isWeb ? 12 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(isWeb ? 12 : 8),
              ),
              child: Icon(
                Icons.expand_more_rounded,
                color: const Color(0xFF6366F1),
                size: isWeb ? 20 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList(bool isWeb) {
    if (_viewModel.todaySales.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState(false));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return Container(
            margin: EdgeInsets.fromLTRB(
              16,
              index == 0 ? 0 : 8,
              16,
              index == _viewModel.todaySales.length - 1 ? 16 : 0,
            ),
            child: _buildSaleCard(_viewModel.todaySales[index], false),
          );
        },
        childCount: _viewModel.todaySales.length,
      ),
    );
  }

  Widget _buildWebSalesList() {
    // Create rows with 2 cards each
    List<Widget> rows = [];
    for (int i = 0; i < _viewModel.todaySales.length; i += 2) {
      List<Widget> rowCards = [];

      // First card in the row
      rowCards.add(
        Expanded(
          child: _buildSaleCard(_viewModel.todaySales[i], true),
        ),
      );

      // Second card in the row (if it exists)
      if (i + 1 < _viewModel.todaySales.length) {
        rowCards.add(const SizedBox(width: 24));
        rowCards.add(
          Expanded(
            child: _buildSaleCard(_viewModel.todaySales[i + 1], true),
          ),
        );
      } else {
        // If odd number of cards, add spacer
        rowCards.add(const SizedBox(width: 24));
        rowCards.add(const Expanded(child: SizedBox()));
      }

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // This is key - align cards to top
          children: rowCards,
        ),
      );

      // Add spacing between rows (except for the last row)
      if (i + 2 < _viewModel.todaySales.length) {
        rows.add(const SizedBox(height: 24));
      }
    }

    return Column(
      children: rows,
    );
  }

  Widget _buildSaleCard(DocumentSnapshot sale, bool isWeb) {
    Map<String, dynamic> data = sale.data() as Map<String, dynamic>;
    List<dynamic> items = data['items'] ?? [];
    Timestamp createdAt = data['createdAt'];
    String paymentMethod = data['paymentMethod'] ?? 'Unknown';
    double totalAmount = data['totalAmount']?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 20 : 16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: isWeb ? 12 : 8,
            offset: Offset(0, isWeb ? 4 : 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 28 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isWeb ? 12 : 8),
                      decoration: BoxDecoration(
                        color: _getPaymentColor(paymentMethod).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                      ),
                      child: Icon(
                        _getPaymentIcon(paymentMethod),
                        color: _getPaymentColor(paymentMethod),
                        size: isWeb ? 24 : 18,
                      ),
                    ),
                    SizedBox(width: isWeb ? 16 : 12),
                    Text(
                      paymentMethod,
                      style: TextStyle(
                        color: _getPaymentColor(paymentMethod),
                        fontSize: isWeb ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWeb ? 16 : 12,
                    vertical: isWeb ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('h:mm a').format(createdAt.toDate()),
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: isWeb ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isWeb ? 20 : 16),

            // Items List
            Container(
              padding: EdgeInsets.all(isWeb ? 20 : 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: items.take(isWeb ? 3 : items.length).map<Widget>((item) => Padding(
                  padding: EdgeInsets.only(
                    bottom: items.indexOf(item) == (isWeb ? 2 : items.length - 1) ? 0 : 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: isWeb ? 8 : 6,
                              height: isWeb ? 8 : 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: isWeb ? 16 : 12),
                            Expanded(
                              child: Text(
                                '${item['quantity']}x ${item['productName']}',
                                style: TextStyle(
                                  fontSize: isWeb ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                  letterSpacing: -0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'PKR ${NumberFormat('#,###').format(item['pricePerItem'] * item['quantity'])}',
                        style: TextStyle(
                          fontSize: isWeb ? 16 : 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),

            if (isWeb && items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${items.length - 3} more items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            SizedBox(height: isWeb ? 20 : 16),

            // Total Row
            Container(
              padding: EdgeInsets.all(isWeb ? 20 : 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: isWeb ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'PKR ${NumberFormat('#,###').format(totalAmount)}',
                    style: TextStyle(
                      fontSize: isWeb ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isWeb) {
    String dateText = _isToday(_selectedDate)
        ? 'No sales today'
        : 'No sales found';
    String subtitleText = _isToday(_selectedDate)
        ? 'Sales will appear here once\ntransactions are made'
        : 'No transactions were made\non ${DateFormat('MMM d, yyyy').format(_selectedDate)}';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isWeb ? 32 : 24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: isWeb ? 64 : 48,
              color: const Color(0xFF6366F1).withOpacity(0.7),
            ),
          ),
          SizedBox(height: isWeb ? 32 : 24),
          Text(
            dateText,
            style: TextStyle(
              fontSize: isWeb ? 28 : 22,
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: isWeb ? 12 : 8),
          Text(
            subtitleText,
            style: TextStyle(
              fontSize: isWeb ? 18 : 16,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              height: 1.4,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isWeb ? 40 : 32),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isWeb ? 32 : 24,
              vertical: isWeb ? 16 : 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
            ),
            child: Text(
              'Pull to refresh',
              style: TextStyle(
                fontSize: isWeb ? 16 : 14,
                color: const Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isWeb) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        if (isWeb) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    // Web Shimmer Header
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[300]!,
                            Colors.grey[100]!,
                            Colors.grey[300]!,
                          ],
                          begin: Alignment(_shimmerAnimation.value - 1, 0),
                          end: Alignment(_shimmerAnimation.value, 0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Web Shimmer Summary Cards
                    Row(
                      children: [
                        Expanded(child: _buildWebShimmerCard()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildWebShimmerCard()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildWebShimmerCard()),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Web Shimmer Date Header
                    _buildWebShimmerDateHeader(),
                    const SizedBox(height: 24),

                    // Web Shimmer Sale Cards
                    Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildWebShimmerSaleCard()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildWebShimmerSaleCard()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildWebShimmerSaleCard()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildWebShimmerSaleCard()),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Mobile Shimmer (Original)
        return SingleChildScrollView(
          child: Column(
            children: [
              // Shimmer Summary Cards
              Container(
                margin: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: _buildShimmerCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildShimmerCard()),
                  ],
                ),
              ),

              // Shimmer Date Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildShimmerDateHeader(),
              ),

              // Shimmer Sale Cards
              ...List.generate(3, (index) => Container(
                margin: EdgeInsets.fromLTRB(16, index == 0 ? 0 : 8, 16, 0),
                child: _buildShimmerSaleCard(),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          begin: Alignment(_shimmerAnimation.value - 1, 0),
          end: Alignment(_shimmerAnimation.value, 0),
        ),
      ),
    );
  }

  Widget _buildWebShimmerCard() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          begin: Alignment(_shimmerAnimation.value - 1, 0),
          end: Alignment(_shimmerAnimation.value, 0),
        ),
      ),
    );
  }

  Widget _buildShimmerDateHeader() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          begin: Alignment(_shimmerAnimation.value - 1, 0),
          end: Alignment(_shimmerAnimation.value, 0),
        ),
      ),
    );
  }

  Widget _buildWebShimmerDateHeader() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          begin: Alignment(_shimmerAnimation.value - 1, 0),
          end: Alignment(_shimmerAnimation.value, 0),
        ),
      ),
    );
  }

  Widget _buildShimmerSaleCard() {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          begin: Alignment(_shimmerAnimation.value - 1, 0),
          end: Alignment(_shimmerAnimation.value, 0),
        ),
      ),
    );
  }

  Widget _buildWebShimmerSaleCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          begin: Alignment(_shimmerAnimation.value - 1, 0),
          end: Alignment(_shimmerAnimation.value, 0),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Color _getPaymentColor(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return const Color(0xFF10B981);
      case 'card':
        return const Color(0xFF3B82F6);
      case 'bank':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6366F1);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}