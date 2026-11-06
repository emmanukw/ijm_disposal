import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/bid.dart';
import '../models/bid_status.dart';
import '../services/repository.dart';
import '../theme.dart';
import 'bids_dashboard.dart' show StatCard;
import 'item_card.dart' show money;

enum _Filter { all, unpaid, toCollect, collected }

final _when = DateFormat('d MMM, HH:mm');

/// Admin view of every booking with paid / collected tracking.
class AdminBidsView extends StatefulWidget {
  final List<Bid> bids;
  final Map<String, BidStatus> statuses;
  final void Function(Bid bid) onDelete;

  const AdminBidsView({
    super.key,
    required this.bids,
    required this.statuses,
    required this.onDelete,
  });

  @override
  State<AdminBidsView> createState() => _AdminBidsViewState();
}

class _AdminBidsViewState extends State<AdminBidsView> {
  _Filter _filter = _Filter.all;
  String _query = '';

  BidStatus _st(Bid b) => widget.statuses[b.id] ?? BidStatus.none;

  @override
  Widget build(BuildContext context) {
    final bids = widget.bids;
    final total = bids.fold<num>(0, (a, b) => a + b.total);
    final paid = bids.where((b) => _st(b).paid).fold<num>(0, (a, b) => a + b.total);
    final collected = bids.where((b) => _st(b).collected).length;

    final q = _query.trim().toLowerCase();
    final shown = bids.where((b) {
      final s = _st(b);
      final okFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.unpaid => !s.paid,
        _Filter.toCollect => !s.collected,
        _Filter.collected => s.collected,
      };
      return okFilter &&
          (q.isEmpty ||
              b.bidderName.toLowerCase().contains(q) ||
              b.email.toLowerCase().contains(q) ||
              b.itemName.toLowerCase().contains(q) ||
              s.note.toLowerCase().contains(q));
    }).toList();

    int count(_Filter f) => bids.where((b) {
          final s = _st(b);
          return switch (f) {
            _Filter.all => true,
            _Filter.unpaid => !s.paid,
            _Filter.toCollect => !s.collected,
            _Filter.collected => s.collected,
          };
        }).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        StatCard('Booked value', money.format(total), Icons.receipt_long_outlined,
            Brand.blue),
        StatCard('Paid', money.format(paid), Icons.payments_outlined, Brand.teal),
        StatCard('Outstanding', money.format(total - paid),
            Icons.hourglass_bottom_rounded, Brand.amber),
        StatCard('Collected', '$collected of ${bids.length}',
            Icons.inventory_outlined, const Color(0xFF7C5CDB)),
      ]),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search name, email, item or note…',
                prefixIcon: Icon(Icons.search),
                fillColor: Colors.white,
              ),
            ),
          ),
          for (final f in _Filter.values)
            ChoiceChip(
              label: Text('${switch (f) {
                _Filter.all => 'All',
                _Filter.unpaid => 'Unpaid',
                _Filter.toCollect => 'Not collected',
                _Filter.collected => 'Collected',
              }} (${count(f)})'),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Card(
        child: shown.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: Text('No bookings match.',
                        style: TextStyle(color: Color(0xFF8593A6)))),
              )
            : Column(children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Brand.border),
                  _BidRow(
                    bid: shown[i],
                    status: _st(shown[i]),
                    onDelete: () => widget.onDelete(shown[i]),
                  ),
                ],
              ]),
      ),
    ]);
  }
}

class _BidRow extends StatelessWidget {
  final Bid bid;
  final BidStatus status;
  final VoidCallback onDelete;
  const _BidRow({required this.bid, required this.status, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final repo = Repository.instance;
    final b = bid;
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [
        TextSpan(
            text: b.bidderName,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.navy)),
        if (b.email.isNotEmpty)
          TextSpan(
              text: '  ${b.email}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A90))),
      ])),
      const SizedBox(height: 3),
      Text('${b.quantity} × ${b.itemName}  ·  $currency ${money.format(b.total)}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Brand.blue)),
      const SizedBox(height: 2),
      Text(
        [
          'Booked ${b.createdAt == null ? 'just now' : _when.format(b.createdAt!)}',
          if (status.paidAt != null) 'paid ${_when.format(status.paidAt!)}',
          if (status.collectedAt != null)
            'collected ${_when.format(status.collectedAt!)}',
        ].join(' · '),
        style: const TextStyle(fontSize: 12, color: Color(0xFF8593A6)),
      ),
      if (status.note.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.sticky_note_2_outlined, size: 14, color: Brand.amber),
            const SizedBox(width: 4),
            Flexible(
              child: Text(status.note,
                  style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
            ),
          ]),
        ),
    ]);

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          avatar: Icon(status.paid ? Icons.check_circle : Icons.payments_outlined,
              size: 18, color: status.paid ? Colors.white : Brand.teal),
          label: Text(status.paid ? 'Paid' : 'Mark paid'),
          showCheckmark: false,
          selected: status.paid,
          selectedColor: Brand.teal,
          labelStyle: TextStyle(
              color: status.paid ? Colors.white : Brand.navy,
              fontWeight: FontWeight.w600),
          onSelected: (v) => repo.setPaid(b.id, v),
        ),
        FilterChip(
          avatar: Icon(
              status.collected ? Icons.check_circle : Icons.inventory_2_outlined,
              size: 18,
              color: status.collected ? Colors.white : const Color(0xFF7C5CDB)),
          label: Text(status.collected ? 'Collected' : 'Mark collected'),
          showCheckmark: false,
          selected: status.collected,
          selectedColor: const Color(0xFF7C5CDB),
          labelStyle: TextStyle(
              color: status.collected ? Colors.white : Brand.navy,
              fontWeight: FontWeight.w600),
          onSelected: (v) => repo.setCollected(b.id, v),
        ),
        IconButton(
          tooltip: 'Add note (e.g. M-Pesa ref)',
          icon: Icon(status.note.isEmpty
              ? Icons.note_add_outlined
              : Icons.sticky_note_2_outlined),
          onPressed: () => _editNote(context),
        ),
        IconButton(
          tooltip: 'Cancel bid (returns pieces to stock)',
          icon: const Icon(Icons.delete_outline, color: Brand.red),
          onPressed: onDelete,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(height: 8), actions],
          );
        }
        return Row(children: [Expanded(child: info), actions]);
      }),
    );
  }

  Future<void> _editNote(BuildContext context) async {
    final c = TextEditingController(text: status.note);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note'),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: c,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'e.g. M-Pesa ref QAB12XYZ9, collected by driver'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) await Repository.instance.setNote(bid.id, result);
  }
}
