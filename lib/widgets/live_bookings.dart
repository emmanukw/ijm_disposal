import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bid.dart';
import '../models/item.dart';
import '../theme.dart';
import 'item_image.dart';

final _when = DateFormat('d MMM yyyy · HH:mm:ss');

const _avatarColors = [
  Brand.blue,
  Brand.teal,
  Color(0xFF7C5CDB),
  Brand.amber,
  Color(0xFFE76F51),
  Color(0xFF2A9D8F),
];

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final s = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return s.isEmpty ? '?' : s;
}

String bookingTime(Bid b) =>
    b.createdAt == null ? 'just now…' : _when.format(b.createdAt!);

/// Read-only, scrollable list of every booking (newest first).
/// New bookings that arrive while the page is open are briefly highlighted.
class LiveBookingsPanel extends StatefulWidget {
  final List<Bid> bids; // newest first
  final double height;
  const LiveBookingsPanel({
    super.key,
    required this.bids,
    required this.height,
  });

  @override
  State<LiveBookingsPanel> createState() => _LiveBookingsPanelState();
}

class _LiveBookingsPanelState extends State<LiveBookingsPanel> {
  Set<String>? _seen;
  final _fresh = <String>{};
  final _timers = <Timer>[];

  @override
  void didUpdateWidget(LiveBookingsPanel old) {
    super.didUpdateWidget(old);
    _markFresh();
  }

  void _markFresh() {
    final ids = widget.bids.map((b) => b.id).toSet();
    final seen = _seen;
    if (seen == null) {
      _seen = ids; // first load: nothing is "new"
      return;
    }
    final added = ids.difference(seen);
    if (added.isEmpty) return;
    _seen = {...seen, ...added};
    _fresh.addAll(added);
    _timers.add(
      Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _fresh.removeAll(added));
      }),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) _markFresh();
    final bids = widget.bids;
    final pieces = bids.fold<int>(0, (a, b) => a + b.quantity);
    return SizedBox(
      height: widget.height,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 20, color: Brand.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live bookings',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Brand.navy,
                              ),
                        ),
                        Text(
                          '${bids.length} bookings · $pieces pieces',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7A90),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const StatusPill('LIVE', Brand.red, icon: Icons.circle),
                ],
              ),
            ),
            const Divider(height: 1, color: Brand.border),
            Expanded(
              child: bids.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No bookings yet. They will appear here live.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF8593A6)),
                        ),
                      ),
                    )
                  : Scrollbar(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: bids.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: 64,
                          color: Color(0xFFEDF1F6),
                        ),
                        itemBuilder: (context, i) => BookingRow(
                          bid: bids[i],
                          fresh: _fresh.contains(bids[i].id),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One read-only booking line: avatar, name, "booked N × item", exact time.
class BookingRow extends StatelessWidget {
  final Bid bid;
  final bool fresh;
  final bool showItem;
  const BookingRow({
    super.key,
    required this.bid,
    this.fresh = false,
    this.showItem = true,
  });

  @override
  Widget build(BuildContext context) {
    final b = bid;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      color: fresh ? Brand.teal.withValues(alpha: 0.12) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                _avatarColors[b.bidderName.hashCode.abs() %
                    _avatarColors.length],
            foregroundColor: Colors.white,
            child: Text(
              _initials(b.bidderName),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: b.bidderName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: ' booked ',
                        style: const TextStyle(color: Color(0xFF6B7A90)),
                      ),
                      TextSpan(
                        text: showItem
                            ? '${b.quantity} × ${b.itemName}'
                            : '${b.quantity} piece${b.quantity == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Brand.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 13,
                      color: Color(0xFF8593A6),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        bookingTime(b),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8593A6),
                        ),
                      ),
                    ),
                    if (fresh) ...[
                      const SizedBox(width: 8),
                      const StatusPill('NEW', Brand.teal),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only dialog listing every booking for one item.
Future<void> showItemBookings(
  BuildContext context,
  Item item,
  List<Bid> allBids,
) {
  return showDialog(
    context: context,
    builder: (ctx) {
      final bids = allBids.where((b) => b.itemId == item.id).toList();
      final pieces = bids.fold<int>(0, (a, b) => a + b.quantity);
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ItemImage(base64: item.imageBase64, width: 52, height: 52),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  Text(
                    '${bids.length} booking${bids.length == 1 ? '' : 's'} · '
                    '$pieces of ${item.quantity} pieces booked · '
                    '${item.remaining} left',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7A90),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          height: bids.isEmpty ? 100 : (bids.length * 64.0).clamp(100, 420),
          child: bids.isEmpty
              ? const Center(
                  child: Text(
                    'No bookings for this item yet.',
                    style: TextStyle(color: Color(0xFF8593A6)),
                  ),
                )
              : Scrollbar(
                  child: ListView.separated(
                    itemCount: bids.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 64,
                      color: Color(0xFFEDF1F6),
                    ),
                    itemBuilder: (_, i) =>
                        BookingRow(bid: bids[i], showItem: false),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
