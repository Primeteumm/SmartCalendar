import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/storage_service.dart';
import 'services/gemini_service.dart';
import 'providers/event_provider.dart';
import 'providers/note_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('.env file loaded successfully');
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    debugPrint('GEMINI_API_KEY exists: ${apiKey != null}');
    if (apiKey != null) {
      debugPrint('GEMINI_API_KEY length: ${apiKey.length}');
      debugPrint('GEMINI_API_KEY first 10 chars: ${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}...');
    } else {
      debugPrint('WARNING: GEMINI_API_KEY is null!');
      debugPrint('Available env keys: ${dotenv.env.keys.toList()}');
    }
  } catch (e, stackTrace) {
    debugPrint('ERROR: Failed to load .env file: $e');
    debugPrint('Stack trace: $stackTrace');
    // Try alternative loading method
    try {
      await dotenv.load();
      debugPrint('Alternative .env loading method succeeded');
    } catch (e2) {
      debugPrint('Alternative .env loading also failed: $e2');
    }
  }
  
  // Initialize date formatting for English locale
  await initializeDateFormatting('en_US', null);
  
  // Initialize Hive storage
  try {
  await StorageService.init();
  } catch (e, stackTrace) {
    debugPrint('Error initializing storage: $e');
    debugPrint('Stack trace: $stackTrace');
    // Continue anyway - app might work with limited functionality
  }
  
  // Initialize Gemini AI
  try {
    await GeminiService.initialize();
  } catch (e) {
    debugPrint('Error initializing Gemini AI: $e');
    // Continue anyway - AI features might not work
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
        title: 'Smart Calendar',
            theme: themeProvider.getTheme(),
            darkTheme: themeProvider.getTheme(),
            themeMode: themeProvider.themeMode,
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
