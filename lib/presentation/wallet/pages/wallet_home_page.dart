import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qnopy/data/wallet/models/wallet_model.dart' show WalletOrderModel;

import '../state/wallet_controller.dart';

class WalletHomePage extends StatelessWidget {
  const WalletHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WalletController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
      ),
      body: Obx(() {
        final wallet = controller.wallet.value;
        return RefreshIndicator(
          onRefresh: controller.refreshDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (controller.isLoading.value)
                const LinearProgressIndicator(),


              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available balance'),
                      const SizedBox(height: 8),
                      Text(
                        wallet == null
                            ? '—'
                            : _money(wallet.balancePaise),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text('Processing orders: ${wallet?.processingOrders ?? 0}'),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: (controller.isBusy.value || controller.isLoading.value)
                            ? null
                            : () => Get.toNamed('/wallet/top-up'),
                        icon: const Icon(Icons.add),
                        label: const Text('Top up wallet'),
                      ),
                    ],
                  ),
                ),
              ),

              if (controller.activeOrder.value != null) ...[
                const SizedBox(height: 12),
                _ActiveOrderCard(controller: controller),
              ],

              const SizedBox(height: 20),
              Text('Recent orders', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (controller.orders.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No top-up orders yet.'),
                  ),
                )
              else
                ...controller.orders.take(10).map(
                  (order) => _OrderTile(order: order),
                ),

            ],
          ),
        );
      }),
    );
  }

  static String _money(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final WalletOrderModel order;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      'paid' => Colors.green,
      'processing' => Colors.orange,
      'failed' => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Card(
      child: ListTile(
        leading: Icon(
          order.status == 'paid'
              ? Icons.check_circle
              : order.status == 'processing'
                  ? Icons.hourglass_top
                  : order.status == 'failed'
                      ? Icons.error
                      : Icons.receipt_long,
          color: color,
        ),
        title: Text('₹${order.amountRupees.toStringAsFixed(2)}'),
        subtitle: Text('${order.orderId}\n${order.status}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.controller});
  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final order = controller.activeOrder.value;
      if (order == null) return const SizedBox.shrink();
      final canRetry = order.status == 'created' &&
          !controller.paymentOutcomeUncertain.value &&
          (controller.paymentState.value == WalletPaymentState.readyToPay ||
              controller.paymentState.value == WalletPaymentState.declined);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Last top-up attempt',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Order: ${order.orderId}'),
              Text('Status: ${order.status}'),
              if (controller.infoMessage.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(controller.infoMessage.value),
                ),
              if (controller.errorMessage.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(controller.errorMessage.value),
                ),
              if (canRetry) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: controller.isBusy.value
                      ? null
                      : controller.retryPaymentForCreatedOrder,
                  child: const Text('Retry payment on this order'),
                ),
              ],
              if (controller.paymentOutcomeUncertain.value &&
                  (order.status == 'processing' || order.status == 'created')) ...[
                const SizedBox(height: 12),
                const Text('Payment outcome is uncertain. Do not retry or create another payment; refresh to check this order.'),
              ],
            ],
          ),
        ),
      );
    });
  }
}

