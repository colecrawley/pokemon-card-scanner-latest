import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:test_scanner_app/screens/home_page.dart';
import 'package:test_scanner_app/services/database_helper.dart';
import 'package:test_scanner_app/services/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize both camera and database simultaneously
    final results = await Future.wait([
      availableCameras(),
      DatabaseHelper.instance.database,
    ]);

    final cameras = results[0] as List<CameraDescription>;
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MyApp(cameras: cameras),
      ),
    );
  } catch (e) {
    // Fallback if camera initialization fails
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(cameras: []),
      ),
    );
    debugPrint('Error initializing app: $e');
  }
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Pokémon Scanner App',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          home: HomePage(cameras: cameras),
        );
      },
    );
  }
}
