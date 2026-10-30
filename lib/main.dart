import 'package:flutter/material.dart';
import 'ui/app_theme.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Optimization for Low-End Devices:
  // Restrict Flutter's in-memory image cache from default 100MB+ down to 30MB
  // and maximum 100 images to prevent Out-Of-Memory (OOM) crashes on 2GB RAM phones.
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;

  runApp(const IspotipayApp());
}

class IspotipayApp extends StatelessWidget {
  const IspotipayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IsPoTiPay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        // Enforce safe text scaling across all devices to prevent accessibility overflow
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
      home: const HomeScreen(),
    );
  }
}
