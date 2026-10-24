import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../state/wallet_amount_validator.dart';
import '../state/wallet_controller.dart';

class WalletTopUpPage extends StatefulWidget {
  const WalletTopUpPage({super.key});

  @override
  State<WalletTopUpPage> createState() => _WalletTopUpPageState();
}

class _WalletTopUpPageState extends State<WalletTopUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WalletController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet top-up')),
      body: Obx(() {
        final activeOrder = controller.activeOrder.value;
        final paymentUncertain = controller.paymentOutcomeUncertain.value &&
            (activeOrder == null ||
                (activeOrder.status != 'paid' && activeOrder.status != 'failed'));
        final orderUnresolved = paymentUncertain ||
            (activeOrder != null &&
                (activeOrder.status == 'created' || activeOrder.status == 'processing'));
        final retrySameOrder = activeOrder?.status == 'created' &&
            !controller.paymentOutcomeUncertain.value;
        return RefreshIndicator(
          onRefresh: ()async {
            controller.refreshDashboard();
          },
          child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Add money', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Enter an amount from ₹1 to ₹50,000'),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        enabled: !orderUnresolved,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          prefixText: '₹ ',
                          hintText: 'e.g. 1000.00',
                        ),
                        validator: (value) {
                          if (rupeesToPaise(value ?? '') == null) {
                            return 'Enter an amount from ₹1 and ₹50,000 (up to 2 decimals).';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        enabled: !orderUnresolved,
                        controller: _noteController,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Payment method'),

                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'upi',
                        groupValue: controller.selectedMethod.value,
                        title: const Text('UPI'),
                        onChanged: (controller.isBusy.value || orderUnresolved) ? null : controller.setPaymentMethod,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'card',
                        groupValue: controller.selectedMethod.value,
                        title: const Text('Card'),
                        onChanged: (controller.isBusy.value || orderUnresolved) ? null : controller.setPaymentMethod,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                if (controller.errorMessage.value.isNotEmpty)
                  _FeedbackCard(
                    message: controller.errorMessage.value,
                    error: true,
                  ),
                if (controller.infoMessage.value.isNotEmpty)
                  _FeedbackCard(
                    message: controller.infoMessage.value,
                    error: false,
                  ),
                if (controller.activeOrder.value != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last Order Details}',style: TextStyle(fontSize: 14,fontWeight: FontWeight.bold),),
                          Text('Order status: ${controller.activeOrder.value!.status}'),
                          Text('Order ID: ${controller.activeOrder.value!.orderId}'),
                          Text('Payment state: ${controller.paymentState.value.name}'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (controller.isLoading.value || controller.isBusy.value || paymentUncertain ||
                          activeOrder?.status == 'processing')
                      ? null
                      : () {
                          if (retrySameOrder) {
                            controller.retryPaymentForCreatedOrder();
                            return;
                          }
                          if (!(_formKey.currentState?.validate() ?? false)) return;
                          final paise = rupeesToPaise(_amountController.text)!;
                          controller.topUp(
                            amountPaise: paise,
                            note: _noteController.text,
                          );
                        },
                  child: controller.isBusy.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(paymentUncertain
                          ? 'Payment outcome unknown — check status'
                          : activeOrder?.status == 'processing'
                              ? 'Payment processing'
                              : retrySameOrder
                                  ? 'Retry payment on existing order'
                                  : 'Create order and pay'),
                ),
                const SizedBox(height: 10),


                const Text(
                  'If a payment response is uncertain, do not immediately pay again. The app checks the existing order status first.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
        );
      }),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.message, required this.error});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message),
      ),
    );
  }
}
