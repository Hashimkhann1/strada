import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strada/model/product_model/product_model.dart';
import 'package:strada/view_model/pos/cart_view_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });
}


class CartWidget extends StatelessWidget {
  // The widget now only needs the ViewModel and two simple callbacks for UI events.
  final CartViewModel viewModel;
  final Function() onPaymentSuccess;
  final Function(String message, Color color) onShowSnackBar;

  const CartWidget({
    super.key,
    required this.viewModel,
    required this.onPaymentSuccess,
    required this.onShowSnackBar,
  });

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder will automatically rebuild the widget when the viewModel changes.
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              // Cart Header
              _buildCartHeader(),
              // Cart Items
              Expanded(
                child: viewModel.items.isEmpty
                    ? _buildEmptyCart()
                    : ListView.builder(
                  itemCount: viewModel.items.length,
                  itemBuilder: (context, index) {
                    return _buildCartItem(viewModel.items[index]);
                  },
                ),
              ),
              // Cart Total and Actions
              if (viewModel.items.isNotEmpty) _buildCartFooter(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartHeader() {
    return Container(
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
          if (viewModel.items.isNotEmpty)
            TextButton(
              // Call the ViewModel's method directly
              onPressed: viewModel.clearCart,
              child: Text(
                'Clear All',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
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
        title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${item.product.price.toStringAsFixed(2)} each'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decrease quantity
            _buildQuantityButton(
              icon: Icons.remove,
              color: Colors.red.shade300,
              // Call the ViewModel's method directly
              onPressed: () => viewModel.updateQuantity(item, item.quantity - 1),
            ),
            // Quantity Text
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            // Increase quantity
            _buildQuantityButton(
              icon: Icons.add,
              color: Colors.green.shade700,
              // Call the ViewModel's method directly
              onPressed: () => viewModel.updateQuantity(item, item.quantity + 1),
            ),
            const SizedBox(width: 8),
            // Total price for this item
            SizedBox(
              width: 60,
              child: Text(
                '${(item.product.price * item.quantity).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: color),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCartFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(
                '${viewModel.subtotal.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showPaymentDialog(context),
              icon: const Icon(Icons.payment, size: 24),
              label: const Text('PROCESS PAYMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Process Payment'),
          content: Text(
            'Total: ${viewModel.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close the confirmation dialog
                await _handlePaymentWithLoading(context, 'Cash');
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePaymentWithLoading(BuildContext context, String paymentMethod) async {
    // Step 1: Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Processing Payment...'),
          ],
        ),
      ),
    );

    // Step 2: Process sale
    final success = await viewModel.processSale(paymentMethod: paymentMethod, items: viewModel.items,subtotal: viewModel.subtotal);

    // Step 3: Close loading dialog
    Navigator.pop(context);

    // Step 4: Show success or error dialog
    if (success) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Payment Successful!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onPaymentSuccess(); // UI cleanup
                onShowSnackBar('Transaction completed successfully!', Colors.green);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      onShowSnackBar(viewModel.paymentError ?? 'An unknown error occurred.', Colors.red);
    }
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
        ],),);}}