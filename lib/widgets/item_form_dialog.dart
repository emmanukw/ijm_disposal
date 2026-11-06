import 'package:flutter/material.dart';

import '../config.dart';
import '../models/item.dart';
import '../services/image_helper.dart';
import '../services/repository.dart';
import 'item_image.dart';

/// Add (item == null) or edit an item.
Future<void> showItemFormDialog(BuildContext context, {Item? item}) =>
    showDialog(context: context, builder: (_) => _ItemForm(item: item));

class _ItemForm extends StatefulWidget {
  final Item? item;
  const _ItemForm({this.item});
  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _desc = TextEditingController(text: widget.item?.description);
  late final _qty =
      TextEditingController(text: widget.item?.quantity.toString() ?? '1');
  late final _price = TextEditingController(text: widget.item?.price.toString());
  late String? _image = widget.item?.imageBase64;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _desc, _qty, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final b64 = await pickThumbnailBase64();
      if (b64 != null) setState(() => _image = b64);
    } catch (e) {
      setState(() => _error = 'Image error: $e');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = Repository.instance;
    try {
      final qty = int.parse(_qty.text.trim());
      final price = num.parse(_price.text.trim());
      if (widget.item == null) {
        await repo.addItem(
          name: _name.text.trim(),
          description: _desc.text.trim(),
          imageBase64: _image,
          quantity: qty,
          price: price,
        );
      } else {
        await repo.updateItem(
          widget.item!,
          name: _name.text.trim(),
          description: _desc.text.trim(),
          imageBase64: _image,
          quantity: qty,
          price: price,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return AlertDialog(
      title: Text(editing ? 'Edit item' : 'Add item',
          style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ItemImage(base64: _image, height: 96, width: 96),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImage,
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(_image == null ? 'Add photo' : 'Change photo'),
                  ),
                  if (_image != null)
                    TextButton(
                      onPressed: () => setState(() => _image = null),
                      child: const Text('Remove photo'),
                    ),
                ]),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Item name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(
                    labelText: 'Description / condition (optional)'),
                maxLines: 2,
              ),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    decoration: InputDecoration(
                      labelText: 'Quantity *',
                      helperText: editing
                          ? '${widget.item!.booked} already booked'
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 1) return 'Whole number ≥ 1';
                      if (editing && n < widget.item!.booked) {
                        return 'Min ${widget.item!.booked}';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration:
                        const InputDecoration(labelText: 'Price ($currency) *'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = num.tryParse(v?.trim() ?? '');
                      return (n == null || n < 0) ? 'Enter a valid amount' : null;
                    },
                  ),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
