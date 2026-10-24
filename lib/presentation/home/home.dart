
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qnopy/core/service/screenshot_protection.dart';

import '../../core/routes/app_routes.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qnopy'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: .start,
          children: [
            const Text(
              'Welcome to Qnopy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Get.toNamed(AppRoutes.kyc);
                },
                icon: const Icon(Icons.verified_user),
                label: const Text('KYC'),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Get.toNamed(AppRoutes.wallet);
                },
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Wallet'),
              ),
            ),

            // OutlinedButton(
            //     onPressed: () async {
            //       try {
            //         print("object1");
            //         final res = await ScreenshotProtection.disable();
            //         print("object ");
            //       }catch(e){
            //         print("error -${e.toString()}");
            //       }
            //     },
            //     child: Text("Test")
            // )

          ],
        ),
      ),
    );
  }
}
