import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/feed_provider.dart';
import 'screens/feed_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryAccent = const Color(0xFF27B0A5); // Teal accent
    final Color appBackground = const Color(0xFF031D31); // Deep space navy
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FeedProvider()),
      ],
      child: MaterialApp(
        title: 'Global Anonymous Log',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: appBackground,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryAccent,
            brightness: Brightness.dark,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: appBackground,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: primaryAccent,
            foregroundColor: Colors.white,
          ),
          cardColor: const Color(0xFF0A2430),
        ),
        home: const FeedScreen(),
      ),
    );
  }
}
 
