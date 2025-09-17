import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class GameRoomScreen extends StatefulWidget {
  const GameRoomScreen({super.key});

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gp = context.read<GameProvider>();
      if (gp.currentCode != null) gp.startPolling();
    });
  }

  @override
  void dispose() {
    context.read<GameProvider>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<GameProvider>(builder: (_, gp, __) => Text('Room ${gp.currentCode ?? ''}')),
      ),
      body: Center(
        child: Consumer<GameProvider>(
          builder: (context, gp, _) {
            final total = (gp.votesA + gp.votesB).clamp(1, 1 << 30);
            final aPct = gp.votesA / total;
            final bPct = gp.votesB / total;
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(gp.question ?? '', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => gp.vote('A'),
                          child: Text(gp.optionA ?? 'A'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => gp.vote('B'),
                          child: Text(gp.optionB ?? 'B'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    Text('Results', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _bar(context, Colors.tealAccent, aPct, 'A: ${gp.votesA}'),
                    const SizedBox(height: 8),
                    _bar(context, Colors.pinkAccent, bPct, 'B: ${gp.votesB}'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, Color color, double pct, String label) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(children: [
        FractionallySizedBox(
          widthFactor: pct.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Center(child: Text(label)),
      ]),
    );
  }
}
