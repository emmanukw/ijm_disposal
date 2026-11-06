import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/auction_settings.dart';
import '../models/bid.dart';
import '../models/item.dart';
import '../services/report_service.dart';
import '../services/repository.dart';
import 'home_page.dart' show LogoMark;
import '../theme.dart';
import '../widgets/bids_dashboard.dart';
import '../widgets/item_card.dart' show money;
import '../widgets/item_form_dialog.dart';
import '../widgets/item_image.dart';

/// Admin area: login gate, then items / schedule / bids / reports.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final repo = Repository.instance;
  late final Stream<User?> _auth = repo.authChanges;
  late final Stream<bool> _isAdmin = repo.isAdmin();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth,
      builder: (context, userSnap) {
        final user = userSnap.data;
        if (user == null || user.isAnonymous) return const _LoginScreen();
        return StreamBuilder<bool>(
          stream: _isAdmin,
          builder: (context, adminSnap) {
            if (!adminSnap.hasData) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (adminSnap.data != true) return _NotAdmin(user: user);
            return const _AdminHome();
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------------ login

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();
  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Repository.instance.adminSignIn(_email.text.trim(), _pass.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'invalid-email' => 'That email address looks wrong.',
            'user-disabled' => 'This account has been disabled.',
            'too-many-requests' => 'Too many attempts. Try again later.',
            'network-request-failed' => 'Network error. Check your connection.',
            _ => 'Incorrect email or password.',
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.heroGradient),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AutofillGroup(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const LogoMark(size: 52),
                  const SizedBox(height: 16),
                  Text('Admin sign in',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text('$orgName Disposal management',
                      style: TextStyle(color: Color(0xFF6B7A90))),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline)),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _login,
                      child: Text(_busy ? 'Signing in…' : 'Sign in'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to public site'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotAdmin extends StatelessWidget {
  final User user;
  const _NotAdmin({required this.user});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Not authorised')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${user.email} is not an admin.'),
              const SizedBox(height: 8),
              SelectableText(
                  'To grant access, create a Firestore document at\nadmins/${user.uid}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await Repository.instance.signOut();
                  if (context.mounted) context.go('/');
                },
                child: const Text('Sign out'),
              ),
            ]),
          ),
        ),
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
  int _tab = 0;

  static const _dests = [
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Items'),
    (Icons.timer_outlined, Icons.timer, 'Schedule'),
    (Icons.insights_outlined, Icons.insights, 'Bids'),
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
            return switch (_tab) {
              0 => _ItemsAdmin(items: items),
              1 => const _ScheduleAdmin(),
              2 => _Padded(
                  title: 'Bids',
                  subtitle: 'Live view of every booking. Cancelling a bid '
                      'returns its pieces to stock.',
                  child: BidsDashboard(
                    items: items,
                    bids: bids,
                    onDeleteBid: (b) => _confirmDeleteBid(context, b),
                  ),
                ),
              _ => _ReportsAdmin(items: items, bids: bids),
            };
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(children: [
          LogoMark(),
          SizedBox(width: 12),
          Text('$orgName Disposal · Admin'),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.public, size: 18),
            label: const Text('Public site'),
          ),
          TextButton.icon(
            onPressed: () async {
              await repo.signOut();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
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
        'The pieces will be returned to stock.');
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
    setState(() => _busy = true);
    try {
      await Repository.instance.saveSettings(AuctionSettings(
          title: _title.text.trim().isEmpty
              ? AuctionSettings.empty.title
              : _title.text.trim(),
          startsAt: _start,
          endsAt: _end));
      _snack('Schedule saved.');
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
      title: 'Schedule',
      subtitle: 'Controls the countdown shown to bidders. Booking is only '
          'possible between these times.',
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save schedule'),
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
  const _ReportsAdmin({required this.items, required this.bids});

  @override
  Widget build(BuildContext context) {
    // Oldest first for reports.
    final ordered = bids.reversed.toList();
    final value = bids.fold<num>(0, (a, b) => a + b.total);
    final pieces = bids.fold<int>(0, (a, b) => a + b.quantity);
    return _Padded(
      title: 'Reports',
      subtitle: 'Export all bids with bidder names, quantities, amounts and '
          'timestamps.',
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
            const Text('Excel includes two sheets: every bid, and a per-item '
                'summary (booked, remaining, value).',
                style: TextStyle(color: Color(0xFF6B7A90))),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: () => downloadExcelReport(ordered, items),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Excel (.xlsx) — bids + item summary'),
              ),
              OutlinedButton.icon(
                onPressed: () => downloadBidsCsv(ordered),
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
