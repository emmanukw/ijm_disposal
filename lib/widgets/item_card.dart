import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/item.dart';
import '../theme.dart';
import 'item_image.dart';

final money = NumberFormat.decimalPattern();

/// One item tile on the public page. Greyed out when finished.
class ItemCard extends StatefulWidget {
  final Item item;
  final bool bookingOpen;
  final VoidCallback onBook;

  /// Number of bookings on this item, and how to show them (read-only).
  final int bookingCount;
  final VoidCallback? onViewBookings;

  const ItemCard({
    super.key,
    required this.item,
    required this.bookingOpen,
    required this.onBook,
    this.bookingCount = 0,
    this.onViewBookings,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final soldOut = item.soldOut;
    final low = !soldOut && item.remaining <= (item.quantity * 0.25).ceil();
    final canBook = !soldOut && widget.bookingOpen;

    final status = soldOut
        ? const StatusPill('Finished', Colors.grey, icon: Icons.block)
        : low
        ? StatusPill(
            'Only ${item.remaining} left',
            Brand.amber,
            icon: Icons.local_fire_department_outlined,
          )
        : StatusPill(
            '${item.remaining} available',
            Brand.teal,
            icon: Icons.check_circle_outline,
          );

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      transform: Matrix4.translationValues(0, _hover && canBook ? -4 : 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Brand.border),
        boxShadow: [
          BoxShadow(
            color: Brand.navy.withValues(
              alpha: _hover && canBook ? 0.12 : 0.04,
            ),
            blurRadius: _hover && canBook ? 24 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              // Fixed height so the card layout is the same at every width.
              SizedBox(
                height: 190,
                width: double.infinity,
                child: ItemImage(base64: item.imageBase64),
              ),
              // price tag
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8),
                    ],
                  ),
                  child: Text(
                    '$currency ${money.format(item.price)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Brand.navy,
                    ),
                  ),
                ),
              ),
              if (soldOut)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: Transform.rotate(
                      angle: -0.12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'FINISHED',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Brand.navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description.isEmpty ? ' ' : item.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7A90),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      status,
                      const Spacer(),
                      Text(
                        '${item.booked}/${item.quantity} booked',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7A90),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: item.quantity == 0
                          ? 0
                          : item.booked / item.quantity,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEDF1F6),
                      color: soldOut
                          ? Colors.grey
                          : low
                          ? Brand.amber
                          : Brand.teal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 32),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: widget.onViewBookings,
                      icon: const Icon(Icons.people_alt_outlined, size: 16),
                      label: Text(
                        widget.bookingCount == 0
                            ? 'No bookings yet'
                            : 'View ${widget.bookingCount} booking'
                                  '${widget.bookingCount == 1 ? '' : 's'}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canBook ? widget.onBook : null,
                      icon: Icon(
                        soldOut
                            ? Icons.block
                            : widget.bookingOpen
                            ? Icons.bookmark_add_outlined
                            : Icons.lock_clock_outlined,
                        size: 18,
                      ),
                      label: Text(
                        soldOut
                            ? 'No pieces left'
                            : widget.bookingOpen
                            ? 'Book now'
                            : 'Booking closed',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (soldOut) {
      card = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 0.7, 0,
        ]),
        child: card,
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: card,
    );
  }
}
