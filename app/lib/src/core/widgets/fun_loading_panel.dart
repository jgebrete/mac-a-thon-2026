import 'dart:async';

import 'package:flutter/material.dart';

class FunLoadingPanel extends StatefulWidget {
  const FunLoadingPanel({
    super.key,
    required this.title,
    required this.messages,
  });

  final String title;
  final List<String> messages;

  @override
  State<FunLoadingPanel> createState() => _FunLoadingPanelState();
}

class _FunLoadingPanelState extends State<FunLoadingPanel> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.messages.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 1700), (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _index = (_index + 1) % widget.messages.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = widget.messages.isEmpty ? 'Loading...' : widget.messages[_index];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.95, end: 1.05),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              onEnd: () {
                if (mounted) {
                  setState(() {});
                }
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                message,
                key: ValueKey<String>(message),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
