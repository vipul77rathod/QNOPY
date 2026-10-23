import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qnopy/presentation/kyc/pages/kyc_page.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(

      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          crossAxisAlignment: .center,
          children: [


            ElevatedButton(
                onPressed: (){
                  Get.to(KycPage());
                },
                child: Text("KYC")
            ),

            ElevatedButton(
                onPressed: (){
                  Get.to(KycPage());
                },
                child: Text("Wallet")
            ),

          ],
        ),
      ),

    );
  }
}
