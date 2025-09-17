import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/feed_provider.dart';
import 'screens/feed_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'providers/game_provider.dart';
import 'screens/game_lobby_screen.dart';
import 'screens/space_arena_screen.dart';
import 'providers/space_provider.dart';

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
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => SpaceProvider()),
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
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(bodyColor: Colors.white, displayColor: Colors.white),
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
        routes: {
          '/profile': (_) => const ProfileScreen(),
          '/game': (_) => const GameLobbyScreen(),
          '/space': (_) => const SpaceArenaScreen(),
        },
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
        context.read<GameProvider>().setUserId(id);
        context.read<SpaceProvider>().setUserId(id);
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
 
