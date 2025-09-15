import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/feed_provider.dart';
import 'screens/feed_screen.dart';
import 'screens/onboarding_screen.dart';

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
        ChangeNotifierProvider(create: (_) => AuthProvider()..load()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
      ],
      child: MaterialApp(
        title: 'AnonDiary',
        debugShowCheckedModeBanner: false,
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
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  String? _appliedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.watch<AuthProvider>().userId;
    if (id != null && id != _appliedUserId) {
      _appliedUserId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<FeedProvider>().setUserId(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = context.watch<AuthProvider>().userId;
    if (id == null) {
      return const OnboardingScreen();
    }
    return const FeedScreen();
  }
}
 
