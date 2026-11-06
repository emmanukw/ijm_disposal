import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bid.dart';
import '../models/item.dart';
import '../theme.dart';
import 'item_image.dart';

final _when = DateFormat('d MMM yyyy · HH:mm:ss');

/// Live summary of all bids, visible to every bidder.
/// When [onDeleteBid] is provided (admin), each bid gets a cancel button.
class BidsDashboard extends StatelessWidget {
  final List<Item> items;
  final List<Bid> bids;
  final void Function(Bid bid)? onDeleteBid;

  const BidsDashboard({
    super.key,
    required this.items,
    required this.bids,
    this.onDeleteBid,
  });

  @override
  Widget build(BuildContext context) {
    final finished = items.where((i) => i.soldOut).length;
    final piecesBooked = bids.fold<int>(0, (a, b) => a + b.quantity);
    final bidders = bids.map((b) => b.bidderName.toLowerCase()).toSet().length;

    final stats = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        StatCard(
          'Items listed',
          '${items.length}',
          Icons.inventory_2_outlined,
          Brand.blue,
        ),
        StatCard(
          'Bids placed',
          '${bids.length}',
          Icons.gavel_rounded,
          Brand.teal,
        ),
        StatCard(
          'Pieces booked',
          '$piecesBooked',
          Icons.shopping_bag_outlined,
          const Color(0xFF7C5CDB),
        ),
        StatCard('Bidders', '$bidders', Icons.people_alt_outlined, Brand.amber),
        StatCard(
          'Finished items',
          '$finished',
          Icons.task_alt,
          Colors.blueGrey,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 900;
        final status = _ItemStatusCard(items: items, bids: bids);
        final feed = _ActivityCard(bids: bids, onDeleteBid: onDeleteBid);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stats,
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: status),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: feed),
                ],
              )
            else ...[
              status,
              const SizedBox(height: 16),
              feed,
            ],
          ],
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard(this.label, this.value, this.icon, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    // Two cards per row on phones, fixed width elsewhere.
    final screen = MediaQuery.sizeOf(context).width;
    final width = screen < 500 ? (screen - 60) / 2 : 190.0;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(screen < 500 ? 12 : 16),
          child: Row(
            children: [
              Container(
                width: screen < 500 ? 36 : 44,
                height: screen < 500 ? 36 : 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF6B7A90),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Brand.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: Brand.navy),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
        const Divider(height: 1, color: Brand.border),
        child,
      ],
    ),
  );
}

class _ItemStatusCard extends StatelessWidget {
  final List<Item> items;
  final List<Bid> bids;
  const _ItemStatusCard({required this.items, required this.bids});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Status per item',
      icon: Icons.inventory_outlined,
      child: items.isEmpty
          ? const _Empty('No items listed yet.')
          : Column(
              children: [
                for (final it in items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Opacity(
                      opacity: it.soldOut ? 0.55 : 1,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ItemImage(
                              base64: it.imageBase64,
                              width: 44,
                              height: 44,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        it.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    it.soldOut
                                        ? const StatusPill(
                                            'Finished',
                                            Colors.grey,
                                          )
                                        : Text(
                                            '${it.remaining} of ${it.quantity} left',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF6B7A90),
                                            ),
                                          ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: it.quantity == 0
                                        ? 0
                                        : it.booked / it.quantity,
                                    minHeight: 5,
                                    backgroundColor: const Color(0xFFEDF1F6),
                                    color: it.soldOut
                                        ? Colors.grey
                                        : Brand.teal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _biddersFor(it),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8593A6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: Brand.border,
                  ),
                ],
              ],
            ),
    );
  }

  String _biddersFor(Item it) {
    final names = bids
        .where((b) => b.itemId == it.id)
        .map((b) => '${b.bidderName} (${b.quantity})')
        .toList();
    return names.isEmpty ? 'No bids yet' : names.join(' · ');
  }
}

class _ActivityCard extends StatelessWidget {
  final List<Bid> bids;
  final void Function(Bid bid)? onDeleteBid;
  const _ActivityCard({required this.bids, this.onDeleteBid});

  static const _avatarColors = [
    Brand.blue,
    Brand.teal,
    Color(0xFF7C5CDB),
    Brand.amber,
    Color(0xFFE76F51),
    Color(0xFF2A9D8F),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Live bid activity',
      icon: Icons.bolt_rounded,
      trailing: const StatusPill('LIVE', Brand.red, icon: Icons.circle),
      child: bids.isEmpty
          ? const _Empty('No bids yet — be the first!')
          : Column(
              children: [
                for (final b in bids)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          _avatarColors[b.bidderName.hashCode.abs() %
                              _avatarColors.length],
                      foregroundColor: Colors.white,
                      child: Text(
                        _initials(b.bidderName),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: b.bidderName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' booked '),
                          TextSpan(
                            text: '${b.quantity} × ${b.itemName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Brand.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: Color(0xFF8593A6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          b.createdAt == null
                              ? 'just now…'
                              : _when.format(b.createdAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8593A6),
                          ),
                        ),
                      ],
                    ),
                    trailing: onDeleteBid == null
                        ? null
                        : IconButton(
                            tooltip: 'Cancel bid (returns pieces to stock)',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Brand.red,
                            ),
                            onPressed: () => onDeleteBid!(b),
                          ),
                  ),
              ],
            ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(text, style: const TextStyle(color: Color(0xFF8593A6))),
    ),
  );
}
