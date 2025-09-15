import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import 'feed_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            children: const [
              _Slide(
                title: 'Your feelings deserve space',
                subtitle: 'A quiet corner of the universe to breathe',
                body:
                    'Drop the weight you have been carrying. Here you do not need a name, a profile, or a perfect story. Just a few honest lines are enough. We hold space for your truth—gently and without judgment.',
              ),
              _Slide(
                title: 'Share without a name',
                subtitle: 'Write what your heart cannot say out loud',
                body:
                    'Post anonymously and your words flow into a random cosmic feed. They may land in front of someone who needed them today—someone who realizes they are not alone because of you.',
              ),
              _Slide(
                title: 'Be seen, be held',
                subtitle: 'Hearts and gentle replies from kind strangers',
                body:
                    'When a story resonates, people can send a heart or leave a soft reply. Tiny gestures, big warmth. Connection without pressure, comfort without exposure.',
              ),
              _Slide(
                title: 'Stay safe, stay kind',
                subtitle: 'Privacy first, compassion always',
                body:
                    'We lightly moderate to keep this space respectful. No public profiles. No pressure to reveal yourself. Share as much or as little as you like—and remember to be tender with yourself and others.',
              ),
            ],
          ),
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i == _index ? color : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final auth = context.read<AuthProvider>();
                      final id = await auth.signInAnonymous();
                      if (id != null && mounted) {
                        context.read<FeedProvider>().setUserId(id);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const FeedScreen()),
                        );
                      }
                    },
                    child: const Text('Continue anonymously'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final String title;
  final String subtitle;
  final String body;
  const _Slide({required this.title, required this.subtitle, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 120),
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, size: 72, color: Colors.white70),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}
