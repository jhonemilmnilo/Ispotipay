import 'package:flutter/material.dart';
import 'ui/app_theme.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IspotipayApp());
}

class IspotipayApp extends StatelessWidget {
  const IspotipayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ispotipay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
