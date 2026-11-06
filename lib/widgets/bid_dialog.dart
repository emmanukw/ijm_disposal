import 'package:flutter/material.dart';

import '../config.dart';
import '../models/item.dart';
import '../services/repository.dart';
import '../theme.dart';
import 'item_image.dart';
import 'item_card.dart' show money;

/// Asks the bidder for their name and quantity, then books the item.
/// Returns true when the booking succeeded.
Future<bool?> showBidDialog(BuildContext context, Item item) =>
    showDialog<bool>(context: context, builder: (_) => _BidDialog(item: item));

class _BidDialog extends StatefulWidget {
  final Item item;
  const _BidDialog({required this.item});

  @override
  State<_BidDialog> createState() => _BidDialogState();
}

class _BidDialogState extends State<_BidDialog> {
  // Remember the bidder's name for the rest of the browser session.
  static String _lastName = '';

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _lastName);
  int _qty = 1;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Repository.instance.placeBid(
        itemId: widget.item.id,
        bidderName: _name.text,
        quantity: _qty,
      );
      _lastName = _name.text.trim();
      if (mounted) Navigator.pop(context, true);
    } on BookingException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not place booking. Please try again.\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final max = item.remaining;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ItemImage(base64: item.imageBase64, width: 64, height: 64),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Book item',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7A90))),
            Text(item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            StatusPill('$currency ${money.format(item.price)} per piece', Brand.blue),
          ]),
        ),
      ]),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Please enter your name'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Text('Quantity'),
                const Spacer(),
                IconButton.outlined(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 44,
                  child: Text('$_qty',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton.outlined(
                  onPressed: _qty < max ? () => setState(() => _qty++) : null,
                  icon: const Icon(Icons.add),
                ),
              ]),
              Text('$max available',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Brand.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Text('Total'),
                  const Spacer(),
                  Text('$currency ${money.format(item.price * _qty)}',
                      style: Theme.of(context).textTheme.titleLarge),
                ]),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Your name and booking time will be visible to all bidders.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8593A6))),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: const Text('Confirm booking'),
        ),
      ],
    );
  }
}
