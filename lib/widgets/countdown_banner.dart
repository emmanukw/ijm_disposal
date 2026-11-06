import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/auction_settings.dart';
import '../theme.dart';

/// Live countdown to the end (or start) of the disposal exercise.
/// Designed to sit on the dark hero gradient.
class CountdownBanner extends StatefulWidget {
  final AuctionSettings settings;
  const CountdownBanner({super.key, required this.settings});

  @override
  State<CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<CountdownBanner> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final fmt = DateFormat('EEE d MMM yyyy · h:mm a');

    String label;
    Duration? left;
    Color dot;
    String? footer;
    if (s.endsAt == null) {
      label = 'Schedule not set yet';
      dot = Colors.white54;
    } else if (s.notStarted(_now)) {
      label = 'Booking opens in';
      left = s.startsAt!.difference(_now);
      dot = Brand.amber;
      footer = 'Opens ${fmt.format(s.startsAt!)}';
    } else if (s.isOpen(_now)) {
      left = s.endsAt!.difference(_now);
      final urgent = left.inMinutes < 30;
      label = urgent ? 'Hurry — closing soon' : 'Booking closes in';
      dot = urgent ? Brand.red : const Color(0xFF4ADE80);
      footer = 'Closes ${fmt.format(s.endsAt!)}';
    } else {
      label = 'Booking has closed';
      dot = Brand.red;
      footer = 'Closed ${fmt.format(s.endsAt!)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          _PulseDot(color: dot, pulse: left != null),
          const SizedBox(width: 8),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 1.4,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        if (left != null)
          Wrap(spacing: 8, runSpacing: 8, children: [
            _unit(left.inDays, 'days'),
            _unit(left.inHours % 24, 'hours'),
            _unit(left.inMinutes % 60, 'mins'),
            _unit(left.inSeconds % 60, 'secs'),
          ]),
        if (footer != null) ...[
          const SizedBox(height: 12),
          Text(footer,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _unit(int v, String name) => Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(children: [
          Text(v.toString().padLeft(2, '0'),
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          Text(name,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _PulseDot({required this.color, required this.pulse});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: widget.pulse
            ? Tween(begin: 0.35, end: 1.0).animate(_c)
            : const AlwaysStoppedAnimation(1),
        child: Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}
