import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'game_room_screen.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final _q = TextEditingController();
  final _a = TextEditingController(text: 'Option A');
  final _b = TextEditingController(text: 'Option B');
  final _code = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Would You Rather')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Create a room', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextField(controller: _q, decoration: const InputDecoration(hintText: 'Your question')),
              const SizedBox(height: 8),
              TextField(controller: _a, decoration: const InputDecoration(hintText: 'Option A')), 
              const SizedBox(height: 8),
              TextField(controller: _b, decoration: const InputDecoration(hintText: 'Option B')),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : () async {
                  setState(() => _loading = true);
                  final code = await context.read<GameProvider>().createRoom(_q.text.trim(), _a.text.trim(), _b.text.trim());
                  setState(() => _loading = false);
                  if (code != null && mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameRoomScreen()));
                  }
                },
                child: const Text('Create room'),
              ),
              const Divider(height: 32),
              Text('Join a room', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextField(controller: _code, decoration: const InputDecoration(hintText: 'Enter room code')), 
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : () async {
                  setState(() => _loading = true);
                  final ok = await context.read<GameProvider>().joinRoom(_code.text.trim().toUpperCase());
                  setState(() => _loading = false);
                  if (ok && mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameRoomScreen()));
                  }
                },
                child: const Text('Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
