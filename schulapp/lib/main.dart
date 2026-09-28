import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'screens/login_screen.dart';
import 'screens/school_setup_screen.dart';
import 'services/school_service.dart';
import 'theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupLogging();
  final isConfigured = await SchoolService.isConfigured();
  runApp(
    SchulApp(
      initialScreen: isConfigured ? const LoginScreen() : const SchoolSetupScreen(),
    ),
  );
}
void _setupLogging() {
  if (kReleaseMode) {
    Logger.root.level = Level.WARNING;
  } else {
    Logger.root.level = Level.ALL;
  }
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '${record.time.toIso8601String()} '
      '[${record.level.name}] '
      '${record.loggerName}: '
      '${record.message}'
      '${record.error != null ? '\nFehler: ${record.error}' : ''}',
    );
  });
}

class SchulApp extends StatelessWidget {
  final Widget initialScreen;
  const SchulApp({
    super.key,
    required this.initialScreen,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, child) {
        return MaterialApp(
          title: 'Schulapp',
          debugShowCheckedModeBanner: false,
          themeMode: themeManager.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            textTheme: const TextTheme(bodyLarge: TextStyle(fontSize: 18)),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color.fromARGB(255, 0, 0, 0),
            cardTheme: const CardThemeData(
              color: Color(0xFF1E1E1E),
              elevation: 4,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2C),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          home: initialScreen,
        );
      },
    );
  }
}