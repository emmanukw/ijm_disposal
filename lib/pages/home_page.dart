import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../models/auction_settings.dart';
import '../models/bid.dart';
import '../models/item.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../widgets/bid_dialog.dart';
import '../widgets/bids_dashboard.dart';
import '../widgets/countdown_banner.dart';
import '../widgets/item_card.dart';

enum _View { items, dashboard }

enum _Filter { all, available, finished }

/// Public page for bidders: hero + countdown, items grid and live dashboard.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repo = Repository.instance;
  late final Timer _tick;
  late final Stream<AuctionSettings> _settings = repo.settings();
  late final Stream<List<Item>> _items = repo.items();
  late final Stream<List<Bid>> _bids = repo.bids();

  _View _view = _View.items;
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Re-evaluate "is booking open" every second so buttons lock at the deadline.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuctionSettings>(
      stream: _settings,
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data ?? AuctionSettings.empty;
        return StreamBuilder<List<Item>>(
          stream: _items,
          builder: (context, itemsSnap) => StreamBuilder<List<Bid>>(
            stream: _bids,
            builder: (context, bidsSnap) {
              final items = itemsSnap.data;
              final bids = bidsSnap.data ?? const <Bid>[];
              return Scaffold(
                body: CustomScrollView(slivers: [
                  _TopBar(onAdmin: () => context.go('/admin')),
                  SliverToBoxAdapter(
                    child: _Hero(
                        settings: settings, items: items ?? const [], bids: bids),
                  ),
                  SliverToBoxAdapter(child: _controls()),
                  if (itemsSnap.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Error: ${itemsSnap.error}')),
                    )
                  else if (items == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_view == _View.items)
                    ..._itemsSlivers(items, settings)
                  else
                    SliverToBoxAdapter(
                      child: _Width(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: BidsDashboard(items: items, bids: bids),
                        ),
                      ),
                    ),
                ]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _controls() => _Width(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _ViewToggle(
                value: _view,
                onChanged: (v) => setState(() => _view = v),
              ),
              if (_view == _View.items)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search items…',
                        prefixIcon: Icon(Icons.search),
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  for (final f in _Filter.values)
                    ChoiceChip(
                      label: Text(switch (f) {
                        _Filter.all => 'All',
                        _Filter.available => 'Available',
                        _Filter.finished => 'Finished',
                      }),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ]),
            ],
          ),
        ),
      );

  List<Widget> _itemsSlivers(List<Item> items, AuctionSettings settings) {
    final q = _query.trim().toLowerCase();
    final shown = items.where((i) {
      if (_filter == _Filter.available && i.soldOut) return false;
      if (_filter == _Filter.finished && !i.soldOut) return false;
      return q.isEmpty ||
          i.name.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q);
    }).toList()
      // Available items first, finished ones at the end.
      ..sort((a, b) => (a.soldOut ? 1 : 0).compareTo(b.soldOut ? 1 : 0));

    if (shown.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: Column(children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 56, color: Color(0xFFB4C0D0)),
              const SizedBox(height: 12),
              Text(items.isEmpty
                  ? 'No items have been listed yet.'
                  : 'No items match your search.'),
            ]),
          ),
        ),
      ];
    }
    final open = settings.isOpen(DateTime.now());
    return [
      SliverLayoutBuilder(builder: (context, c) {
        final side = ((c.crossAxisExtent - 1200) / 2).clamp(16.0, double.infinity);
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 0, side, 48),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 410,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
            ),
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final item = shown[i];
              return ItemCard(
                item: item,
                bookingOpen: open,
                onBook: () async {
                  final ok = await showBidDialog(context, item);
                  if (ok == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Color(0xFF4ADE80)),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Booked "${item.name}" successfully.')),
                      ]),
                    ));
                  }
                },
              );
            },
          ),
        );
      }),
    ];
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onAdmin;
  const _TopBar({required this.onAdmin});

  @override
  Widget build(BuildContext context) => SliverAppBar(
        pinned: true,
        backgroundColor: Brand.navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(children: [
          const LogoMark(),
          const SizedBox(width: 12),
          Text('$orgName Disposal',
              style: Theme.of(context)
                  .appBarTheme
                  .titleTextStyle
                  ?.copyWith(color: Colors.white)),
        ]),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: onAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('Admin'),
          ),
          const SizedBox(width: 12),
        ],
      );
}

/// Small rounded logo square used in headers.
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.teal, Brand.blue]),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(Icons.gavel_rounded, color: Colors.white, size: size * 0.55),
      );
}

class _Hero extends StatelessWidget {
  final AuctionSettings settings;
  final List<Item> items;
  final List<Bid> bids;
  const _Hero({required this.settings, required this.items, required this.bids});

  @override
  Widget build(BuildContext context) {
    final available = items.where((i) => !i.soldOut).length;
    final piecesLeft = items.fold<int>(0, (a, i) => a + i.remaining);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(settings.title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.white, fontSize: 32)),
        const SizedBox(height: 8),
        const Text(
          'Browse items being disposed, enter your name and book the pieces '
          'you want before the timer runs out.',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _HeroChip(Icons.inventory_2_outlined, '$available available items'),
          _HeroChip(Icons.layers_outlined, '$piecesLeft pieces left'),
          _HeroChip(Icons.gavel_rounded, '${bids.length} bids so far'),
        ]),
      ],
    );

    return Container(
      decoration: const BoxDecoration(gradient: Brand.heroGradient),
      child: Stack(children: [
        // decorative circles
        Positioned(
            right: -60,
            top: -80,
            child: _Circle(260, Colors.white.withValues(alpha: 0.05))),
        Positioned(
            right: 160,
            bottom: -120,
            child: _Circle(220, Brand.teal.withValues(alpha: 0.15))),
        _Width(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: LayoutBuilder(builder: (context, c) {
              final countdown = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: CountdownBanner(settings: settings),
              );
              if (c.maxWidth < 820) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [intro, const SizedBox(height: 24), countdown],
                );
              }
              return Row(children: [
                Expanded(child: intro),
                const SizedBox(width: 40),
                countdown,
              ]);
            }),
          ),
        ),
      ]),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroChip(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      );
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle(this.size, this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Centers content with a max width and side gutters.
class _Width extends StatelessWidget {
  final Widget child;
  const _Width({required this.child});
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      );
}

class _ViewToggle extends StatelessWidget {
  final _View value;
  final ValueChanged<_View> onChanged;
  const _ViewToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(_View v, IconData icon, String label) {
      final sel = v == value;
      return Material(
        color: sel ? Brand.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(v),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: sel ? Colors.white : Brand.navy),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : Brand.navy)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(_View.items, Icons.grid_view_rounded, 'Items'),
        seg(_View.dashboard, Icons.insights_rounded, 'Live bids'),
      ]),
    );
  }
}
