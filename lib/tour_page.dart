import 'package:flutter/material.dart';

class TourPage extends StatelessWidget {
  const TourPage({super.key});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour Page'),
      ),
      body: const Center(
        child: Text('Tour Page Content'),
      ),
    );
  }
}
