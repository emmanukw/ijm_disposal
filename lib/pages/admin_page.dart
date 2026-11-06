import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/auction_settings.dart';
import '../models/bid.dart';
import '../models/bid_status.dart';
import '../models/item.dart';
import '../services/report_service.dart';
import '../services/repository.dart';
import '../services/session.dart';
import 'home_page.dart' show LogoMark;
import 'login_page.dart' show AuthBackground;
import '../theme.dart';
import '../widgets/admin_bids.dart';
import '../widgets/bids_dashboard.dart';
import '../widgets/item_card.dart' show money;
import '../widgets/item_form_dialog.dart';
import '../widgets/item_image.dart';

/// Admin area (the StaffGate in main.dart has already signed the user in).
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SessionController.instance,
        builder: (context, _) {
          final s = SessionController.instance.value;
          return s.isAdmin ? const _AdminHome() : _NotAdmin(user: s.user!);
        },
      );
}

class _NotAdmin extends StatelessWidget {
  final User user;
  const _NotAdmin({required this.user});
  @override
  Widget build(BuildContext context) => AuthBackground(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.admin_panel_settings_outlined,
              color: Brand.amber, size: 48),
          const SizedBox(height: 12),
          Text('Admins only', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${user.email} is not an admin.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7A90))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Brand.bg, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(
              'To make this person an admin, create a Firestore document at\n'
              'admins/${user.uid}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to booking site'),
            ),
          ),
          TextButton(
            onPressed: () => Repository.instance.signOut(),
            child: const Text('Sign out'),
          ),
        ]),
      );
}

// ------------------------------------------------------------- admin home

class _AdminHome extends StatefulWidget {
  const _AdminHome();
  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  final repo = Repository.instance;
  late final Stream<List<Item>> _items = repo.items();
  late final Stream<List<Bid>> _bids = repo.bids();
  late final Stream<Map<String, BidStatus>> _statuses = repo.bidStatuses();
  int _tab = 0;

  static const _dests = [
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Items'),
    (Icons.tune_outlined, Icons.tune, 'Settings'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Bookings'),
    (Icons.insights_outlined, Icons.insights, 'Live overview'),
    (Icons.download_outlined, Icons.download, 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final body = StreamBuilder<List<Item>>(
      stream: _items,
      builder: (context, itemsSnap) {
        final items = itemsSnap.data ?? const <Item>[];
        return StreamBuilder<List<Bid>>(
          stream: _bids,
          builder: (context, bidsSnap) {
            final bids = bidsSnap.data ?? const <Bid>[];
            return StreamBuilder<Map<String, BidStatus>>(
              stream: _statuses,
              builder: (context, stSnap) {
                final statuses = stSnap.data ?? const <String, BidStatus>{};
                return switch (_tab) {
                  0 => _ItemsAdmin(items: items),
                  1 => const _ScheduleAdmin(),
                  2 => _Padded(
                      title: 'Bookings',
                      subtitle: 'Track payment and collection for every booking. '
                          'Only admins can see this page.',
                      child: AdminBidsView(
                        bids: bids,
                        statuses: statuses,
                        onDelete: (b) => _confirmDeleteBid(context, b),
                      ),
                    ),
                  3 => _Padded(
                      title: 'Live overview',
                      subtitle: 'The same live dashboard staff see on the booking site.',
                      child: BidsDashboard(items: items, bids: bids),
                    ),
                  _ => _ReportsAdmin(items: items, bids: bids, statuses: statuses),
                };
              },
            );
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          const LogoMark(),
          const SizedBox(width: 12),
          Flexible(
            child: Text(wide ? '$orgName Disposal · Admin' : 'Admin',
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        actions: [
          if (wide) ...[
            TextButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.public, size: 18),
              label: const Text('Booking site'),
            ),
            TextButton.icon(
              onPressed: () async {
                await repo.signOut();
                if (context.mounted) context.go('/');
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Booking site',
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.public),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await repo.signOut();
                if (context.mounted) context.go('/');
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          const SizedBox(width: 12),
        ],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Brand.border)),
      ),
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              NavigationRail(
                backgroundColor: Colors.white,
                extended: MediaQuery.sizeOf(context).width >= 1100,
                minExtendedWidth: 200,
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                indicatorColor: Brand.blue.withValues(alpha: 0.12),
                destinations: [
                  for (final d in _dests)
                    NavigationRailDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2, color: Brand.blue),
                        label: Text(d.$3)),
                ],
              ),
              const VerticalDivider(width: 1, color: Brand.border),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final d in _dests)
                  NavigationDestination(
                      icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
              ],
            ),
    );
  }

  Future<void> _confirmDeleteBid(BuildContext context, Bid b) async {
    final ok = await _confirm(context, 'Cancel bid?',
        'Cancel ${b.bidderName}\'s booking of ${b.quantity} × ${b.itemName}? '
        'The pieces return to stock, the person\'s booking allowance is freed, '
        'and any paid/collected record for it is removed.');
    if (ok) await Repository.instance.deleteBid(b);
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    ) ??
    false;

class _Padded extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget child;
  const _Padded(
      {required this.title, this.subtitle, this.action, required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.headlineMedium),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(subtitle!,
                                style: const TextStyle(color: Color(0xFF6B7A90))),
                          ),
                      ],
                    ),
                  ),
                  ?action,
                ]),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      );
}

// ------------------------------------------------------------------ items

class _ItemsAdmin extends StatelessWidget {
  final List<Item> items;
  const _ItemsAdmin({required this.items});

  @override
  Widget build(BuildContext context) {
    return _Padded(
      title: 'Items',
      subtitle: '${items.length} item(s) listed for disposal',
      action: FilledButton.icon(
        onPressed: () => showItemFormDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      child: Card(
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: Text('No items yet. Click "Add item".')),
              )
            : Column(children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Brand.border),
                  _ItemRow(item: items[i]),
                ],
              ]),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Item item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final it = item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ItemImage(base64: it.imageBase64, width: 64, height: 64),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 6, children: [
              StatusPill('$currency ${money.format(it.price)}', Brand.blue),
              StatusPill('Qty ${it.quantity}', Colors.blueGrey),
              it.soldOut
                  ? const StatusPill('Finished', Colors.grey, icon: Icons.block)
                  : StatusPill('${it.remaining} remaining', Brand.teal),
            ]),
          ]),
        ),
        IconButton.filledTonal(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => showItemFormDialog(context, item: it),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Delete',
          style: IconButton.styleFrom(
              backgroundColor: Brand.red.withValues(alpha: 0.1),
              foregroundColor: Brand.red),
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await _confirm(context, 'Delete item?',
                'Delete "${it.name}"? Existing bids on it stay in the report.');
            if (ok) await Repository.instance.deleteItem(it.id);
          },
        ),
      ]),
    );
  }
}

// --------------------------------------------------------------- schedule

class _ScheduleAdmin extends StatefulWidget {
  const _ScheduleAdmin();
  @override
  State<_ScheduleAdmin> createState() => _ScheduleAdminState();
}

class _ScheduleAdminState extends State<_ScheduleAdmin> {
  final _title = TextEditingController();
  final _maxItem = TextEditingController();
  final _maxTotal = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _loaded = false;
  bool _busy = false;
  final _fmt = DateFormat('EEE d MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    Repository.instance.settings().first.then((s) {
      if (!mounted) return;
      setState(() {
        _title.text = s.title;
        _start = s.startsAt;
        _end = s.endsAt;
        _maxItem.text = s.maxPerItemPerPerson > 0 ? '${s.maxPerItemPerPerson}' : '';
        _maxTotal.text = s.maxTotalPerPerson > 0 ? '${s.maxTotalPerPerson}' : '';
        _loaded = true;
      });
    });
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    if (_end == null) return _snack('Please set the closing date & time.');
    if (_start != null && !_start!.isBefore(_end!)) {
      return _snack('Opening time must be before closing time.');
    }
    int? parse(TextEditingController c) {
      final t = c.text.trim();
      if (t.isEmpty) return 0;
      final n = int.tryParse(t);
      return (n == null || n < 0) ? null : n;
    }

    final maxItem = parse(_maxItem), maxTotal = parse(_maxTotal);
    if (maxItem == null || maxTotal == null) {
      return _snack('Limits must be whole numbers (leave blank for no limit).');
    }
    setState(() => _busy = true);
    try {
      await Repository.instance.saveSettings(AuctionSettings(
          title: _title.text.trim().isEmpty
              ? AuctionSettings.empty.title
              : _title.text.trim(),
          startsAt: _start,
          endsAt: _end,
          maxPerItemPerPerson: maxItem,
          maxTotalPerPerson: maxTotal));
      _snack('Settings saved.');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return _Padded(
      title: 'Settings',
      subtitle: 'Schedule and booking rules. Booking is only possible between '
          'the opening and closing times.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _title,
              decoration:
                  const InputDecoration(labelText: 'Title shown on the site'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Booking opens (optional)'),
              subtitle: Text(_start == null
                  ? 'Immediately'
                  : _fmt.format(_start!)),
              trailing: Wrap(children: [
                if (_start != null)
                  IconButton(
                      onPressed: () => setState(() => _start = null),
                      icon: const Icon(Icons.clear)),
                OutlinedButton(
                  onPressed: () async {
                    final d = await _pick(_start);
                    if (d != null) setState(() => _start = d);
                  },
                  child: const Text('Set'),
                ),
              ]),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop_circle_outlined),
              title: const Text('Booking closes *'),
              subtitle:
                  Text(_end == null ? 'Not set' : _fmt.format(_end!)),
              trailing: OutlinedButton(
                onPressed: () async {
                  final d = await _pick(_end);
                  if (d != null) setState(() => _end = d);
                },
                child: const Text('Set'),
              ),
            ),
            const Divider(height: 32, color: Brand.border),
            Text('Booking limits per person',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: Brand.navy)),
            const SizedBox(height: 4),
            const Text(
                'Leave blank for no limit. Limits apply to each staff account and '
                'are enforced by the server. Cancelling a bid frees up the allowance.',
                style: TextStyle(color: Color(0xFF6B7A90), fontSize: 13)),
            const SizedBox(height: 14),
            Wrap(spacing: 16, runSpacing: 12, children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _maxItem,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max pieces of the same item',
                    hintText: 'No limit',
                    prefixIcon: Icon(Icons.filter_1_outlined),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _maxTotal,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max pieces in total',
                    hintText: 'No limit',
                    prefixIcon: Icon(Icons.functions),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save settings'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- reports

class _ReportsAdmin extends StatelessWidget {
  final List<Item> items;
  final List<Bid> bids;
  final Map<String, BidStatus> statuses;
  const _ReportsAdmin(
      {required this.items, required this.bids, required this.statuses});

  @override
  Widget build(BuildContext context) {
    // Oldest first for reports.
    final ordered = bids.reversed.toList();
    final value = bids.fold<num>(0, (a, b) => a + b.total);
    final pieces = bids.fold<int>(0, (a, b) => a + b.quantity);
    return _Padded(
      title: 'Reports',
      subtitle: 'Export all bids with names, emails, quantities, amounts, '
          'timestamps and payment/collection status.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          StatCard('Bids', '${bids.length}', Icons.gavel_rounded, Brand.teal),
          StatCard('Pieces booked', '$pieces', Icons.shopping_bag_outlined,
              const Color(0xFF7C5CDB)),
          StatCard('Booked value', money.format(value),
              Icons.payments_outlined, Brand.blue),
        ]),
        const SizedBox(height: 16),
        Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Download report',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Excel has three sheets: every bid (with email, paid and '
                'collected status), a per-item summary, and a per-person summary '
                '(amount owed, paid, outstanding).',
                style: TextStyle(color: Color(0xFF6B7A90))),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: () => downloadExcelReport(ordered, items, statuses),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Excel (.xlsx) — bids + item summary'),
              ),
              OutlinedButton.icon(
                onPressed: () => downloadBidsCsv(ordered, statuses),
                icon: const Icon(Icons.description_outlined),
                label: const Text('CSV — all bids'),
              ),
            ]),
          ]),
        ),
      ),
      ]),
    );
  }
}
