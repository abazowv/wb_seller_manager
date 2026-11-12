import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, const Color(0xFFCB11AB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.storefront_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'WB Seller Manager',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Продажи, товары и склад под контролем',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
              ),
              const Spacer(),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
