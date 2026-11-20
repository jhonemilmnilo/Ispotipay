import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'services/audio_handler.dart';
import 'ui/app_theme.dart';
import 'ui/home_screen.dart';

AudioPlayerHandler? audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optimization for Low-End Devices:
  // Restrict Flutter's in-memory image cache from default 100MB+ down to 30MB
  // and maximum 100 images to prevent Out-Of-Memory (OOM) crashes on 2GB RAM phones.
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      audioHandler = await AudioService.init(
        builder: () => AudioPlayerHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.ispotipay.channel.audio',
          androidNotificationChannelName: 'Ispotipay Music Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/launcher_icon',
          androidShowNotificationBadge: true,
        ),
      );
    } catch (e) {
      debugPrint('[AudioService] Init error: $e');
    }
  }

  runApp(const IspotipayApp());
}

class IspotipayApp extends StatefulWidget {
  const IspotipayApp({super.key});

  @override
  State<IspotipayApp> createState() => _IspotipayAppState();
}

class _IspotipayAppState extends State<IspotipayApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    // Low-end memory recovery: clear live image cache when OS reports memory pressure
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

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
