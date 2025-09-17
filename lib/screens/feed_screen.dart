// ignore_for_file: unused_local_variable, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/feed_provider.dart';
import 'replies_screen.dart';
import 'chat_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _starsCtrl;

  @override
  void initState() {
    super.initState();
    _starsCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().fetchFeed();
    });
  }

  @override
  void dispose() {
    _starsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AnonDiary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.videogame_asset_outlined),
            tooltip: 'Game',
            onPressed: () => Navigator.of(context).pushNamed('/game'),
          ),
          IconButton(
            icon: const Icon(Icons.rocket_launch_outlined),
            tooltip: 'Space Arena',
            onPressed: () => Navigator.of(context).pushNamed('/space'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (m) {
              context.read<FeedProvider>().fetchFeed(mode: m);
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'random', child: Text('Random (global)')),
              PopupMenuItem(value: 'recommended', child: Text('Recommended (most reactions)')),
              PopupMenuItem(value: 'latest', child: Text('Latest')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FeedProvider>().fetchFeed(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _starsCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _StarFieldPainter(progress: _starsCtrl.value),
              );
            },
          ),
          const _FeedList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openComposer(context),
        child: const Icon(Icons.edit),
      ),
    );
  }

  void _openComposer(BuildContext context) {
    final controller = TextEditingController();
    String? selectedEmotion;
    final emotions = <String>['joy','sad','angry','lonely','love','anxious','calm'];
    DateTime? selectedDate;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E12),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Share your feelings (anonymous)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write something... (no limit)',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(builder: (context, setState) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: emotions.map((e) {
                    final selected = selectedEmotion == e;
                    return ChoiceChip(
                      label: Text(e),
                      selected: selected,
                      onSelected: (_) => setState(() => selectedEmotion = e),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 12),
              StatefulBuilder(builder: (context, setState) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(selectedDate == null
                          ? 'No diary date selected'
                          : 'Diary date: ${selectedDate!.toLocal()}'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(now.year - 50),
                          lastDate: DateTime(now.year + 50),
                          initialDate: selectedDate ?? now,
                        );
                        if (picked != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate ?? now),
                          );
                          setState(() {
                            selectedDate = DateTime(
                              picked.year, picked.month, picked.day,
                              time?.hour ?? 0, time?.minute ?? 0,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: const Text('Pick date & time'),
                    )
                  ],
                );
              }),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Post anonymously'),
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  final ok = await context.read<FeedProvider>().createEntry(text, emotion: selectedEmotion, diaryDate: selectedDate);
                  if (ok && mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList();

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        if (feed.loading && feed.entries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (feed.error != null) {
          return Center(child: Text('Error: ${feed.error}'));
        }
        if (feed.entries.isEmpty) {
          return const Center(child: Text('No posts yet. Be the first!'));
        }
        // Responsive center column on wide screens
        final list = ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: feed.entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final e = feed.entries[index];
            final card = _EntryCard(entry: e, buildReactionBar: () => _reactionBar(context, e), onOpenReplies: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RepliesScreen(entry: e)),
              );
            });
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: card,
              ),
            );
          },
        );
        return list;
      },
    );
  }

  Widget _reactionBar(BuildContext context, EntryModel e) {
    final feed = context.read<FeedProvider>();
    final Map<String, int> counts = e.reactionsCounts;
    final int total = (counts['heart'] ?? 0) + (counts['happy'] ?? 0) + (counts['sad'] ?? 0) + (counts['angry'] ?? 0);

    void showOverlayPicker(Offset globalPos) {
      final overlay = Overlay.of(context);
      late OverlayEntry entry;
      entry = OverlayEntry(builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        const margin = 12.0;
        const itemSize = 44.0;
        const gap = 8.0;
        const horizontalPad = 16.0; // container horizontal padding total
        // width = 4 items + 3 gaps + padding
        const pillWidth = (itemSize * 4) + (gap * 3) + horizontalPad;
        const pillHeight = 60.0;

        double desiredTop = globalPos.dy - 72;
        // Nếu không đủ chỗ phía trên, hiển thị phía dưới
        if (desiredTop < margin) {
          desiredTop = globalPos.dy + 16;
        }
        // Clamp theo chiều dọc
        double top = desiredTop.clamp(margin, size.height - pillHeight - margin);

        // Căn giữa quanh điểm nhấn nhưng không tràn trái/phải
        double left = (globalPos.dx - pillWidth / 2).clamp(margin, size.width - pillWidth - margin);
        return Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => entry.remove(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151B),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _reactionPickerItem(context, Icons.favorite_border, () {
                      entry.remove();
                      feed.reactToEntry(e.id, 'heart');
                    }),
                    const SizedBox(width: gap),
                    _reactionPickerItem(context, Icons.emoji_emotions_outlined, () {
                      entry.remove();
                      feed.reactToEntry(e.id, 'happy');
                    }),
                    const SizedBox(width: gap),
                    _reactionPickerItem(context, Icons.mood_bad_outlined, () {
                      entry.remove();
                      feed.reactToEntry(e.id, 'sad');
                    }),
                    const SizedBox(width: gap),
                    _reactionPickerItem(context, Icons.sentiment_very_dissatisfied_outlined, () {
                      entry.remove();
                      feed.reactToEntry(e.id, 'angry');
                    }),
                  ],
                ),
              ),
            ),
          ),
        ]);
      });
      overlay.insert(entry);
    }

    return GestureDetector(
      onTap: () => feed.reactToEntry(e.id, 'heart'),
      onLongPressStart: (d) => showOverlayPicker(d.globalPosition),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _ghostIconButton(context, Icons.favorite_border, () => feed.reactToEntry(e.id, 'heart')),
        const SizedBox(width: 4),
        Text('$total'),
      ]),
    );
  }

}

class _EntryCard extends StatefulWidget {
  final EntryModel entry;
  final Widget Function() buildReactionBar;
  final VoidCallback onOpenReplies;
  const _EntryCard({required this.entry, required this.buildReactionBar, required this.onOpenReplies});

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  static const int _trimLength = 180;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final text = e.content;
    final bool shouldTrim = text.length > _trimLength;
    final String shown = _expanded || !shouldTrim ? text : text.substring(0, _trimLength) + '…';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E12).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.authorId != null ? 'anon:${e.authorId!.substring(0, 6)}' : 'anon',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _OwnerOrActions(entry: e),
            ],
          ),
          const SizedBox(height: 8),
          if (e.emotion != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
              ),
              child: Text('#${e.emotion}', style: const TextStyle(color: Colors.tealAccent)),
            ),
            const SizedBox(height: 8),
          ],
          if (e.repostOf != null) ...[
            Row(children: [
              const Icon(Icons.repeat, size: 16, color: Colors.tealAccent),
              const SizedBox(width: 6),
              Text('Reposted', style: TextStyle(color: Colors.tealAccent.withOpacity(0.9))),
            ]),
            const SizedBox(height: 8),
          ],
          Text(shown, style: const TextStyle(fontSize: 16, height: 1.5)),
          if (shouldTrim && !_expanded) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = true),
              child: Text('See more', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: widget.buildReactionBar()),
              const SizedBox(width: 12),
              _ghostIconButton(context, Icons.reply, widget.onOpenReplies),
              Text('${e.repliesCount}'),
              const SizedBox(width: 12),
              _ghostIconButton(context, Icons.repeat, () async {
                final ok = await context.read<FeedProvider>().repostEntry(e.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Reposted' : 'Repost failed')));
              }),
              const Spacer(),
              Text(
                formatDateTime(e.diaryDate ?? e.createdAt),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _OwnerOrActions extends StatelessWidget {
  final EntryModel entry;
  const _OwnerOrActions({required this.entry});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final isOwner = entry.authorId != null && entry.authorId == feed.userId;
    if (isOwner) {
      return Row(children: [
        TextButton(
          onPressed: () => _showEditDialog(context, entry),
          child: const Text('Edit'),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () async {
            final ok = await _confirmDelete(context);
            if (!ok) return;
            final success = await context.read<FeedProvider>().deleteEntry(entry.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Deleted' : 'Delete failed')));
          },
          child: const Text('Delete'),
        ),
      ]);
    }
    return Row(children: [
      TextButton(
        onPressed: entry.authorId == null ? null : () async {
          final ok = await context.read<FeedProvider>().followUser(entry.authorId!);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Following anon user' : 'Failed to follow')));
        },
        child: const Text('Follow'),
      ),
      const SizedBox(width: 4),
      OutlinedButton(
        onPressed: entry.authorId == null ? null : () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(peerId: entry.authorId!, title: 'Chat with ${entry.authorId!.substring(0,6)}'),
            ),
          );
        },
        child: const Text('Message'),
      )
    ]);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete entry?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        ) ?? false;
  }
}

void _showEditDialog(BuildContext context, EntryModel entry) {
  final controller = TextEditingController(text: entry.content);
  String? emotion = entry.emotion;
  DateTime? diaryDate = entry.diaryDate;
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0E0E12),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: StatefulBuilder(builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Edit entry', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 6,
                minLines: 3,
                decoration: const InputDecoration(hintText: 'Update your text'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(diaryDate == null ? 'No diary date' : 'Diary: ${diaryDate!.toLocal()}')),
                TextButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 50), lastDate: DateTime(now.year + 50), initialDate: diaryDate ?? now);
                    if (d != null) {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(diaryDate ?? now));
                      setState(() { diaryDate = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0); });
                    }
                  },
                  icon: const Icon(Icons.event),
                  label: const Text('Pick date & time'),
                )
              ]),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  final ok = await context.read<FeedProvider>().updateEntry(entry.id, content: text, emotion: emotion, diaryDate: diaryDate);
                  if (!context.mounted) return;
                  if (ok) Navigator.pop(ctx);
                },
              )
            ],
          );
        }),
      );
    },
  );
}
class _StarFieldPainter extends CustomPainter {
  final double progress;
  _StarFieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.25);
    final numStars = 200;
    for (int i = 0; i < numStars; i++) {
      // pseudo random positions using i
      final dx = ((i * 37) % size.width);
      double dy = ((i * 91) % size.height);
      dy = (dy + progress * size.height) % size.height;
      final radius = 0.5 + (i % 3) * 0.4;
      canvas.drawCircle(Offset(dx.toDouble(), dy.toDouble()), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ---- Helpers (top-level) ----
Widget _ghostIconButton(BuildContext context, IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(icon, size: 18),
    ),
  );
}

Widget _reactionPickerItem(BuildContext context, IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, size: 22),
    ),
  );
}

String formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  return '${diff.inDays} d';
}

String formatDateTime(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}/${p(dt.month)}/${dt.year} ${p(dt.hour)}:${p(dt.minute)}';
}
