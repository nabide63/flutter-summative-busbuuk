// Home Screen - search bar, recent searches, network coverage, promos
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/destination_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/search_provider.dart';
import '../../widgets/primary_button.dart';

class _Promo {
  final String tag;
  final String title;
  final String subtitle;
  final String cta;
  final List<Color> gradient;
  final Color tagColor;
  final Color ctaBackground;
  final Color ctaForeground;
  const _Promo({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.gradient,
    required this.tagColor,
    required this.ctaBackground,
    required this.ctaForeground,
  });
}

const _kOverlap = 32.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fromController = TextEditingController(text: 'Kigali, Rwanda');
  final _toController = TextEditingController();
  DateTime _travelDate = DateTime.now();
  int _passengers = 1;
  bool _isRoundTrip = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDestinations();
    });
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _swapCities() {
    setState(() {
      final temp = _fromController.text;
      _fromController.text = _toController.text;
      _toController.text = temp;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _travelDate = picked);
  }

  Future<void> _search({String? from, String? to}) async {
    final fromCity = from ?? _fromController.text.trim();
    final toCity = to ?? _toController.text.trim();
    if (fromCity.isEmpty || toCity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('pick a departure and destination first')),
      );
      return;
    }

    context.read<SearchProvider>().search(
      from: fromCity,
      to: toCity,
      travelDate: _travelDate,
      passengers: _passengers,
      isRoundTrip: _isRoundTrip,
    );
    if (mounted) context.push('/home/search-results');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recentSearches = context.watch<SearchProvider>().recentSearches;
    final destinations = context.watch<AdminProvider>().destinations;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            'Busbuuk',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, colorScheme, destinations),
              // used Transform here instead of negative margin/padding (Flutter
              // won't allow negative there) to pull the search card up over the header
              Transform.translate(
                offset: const Offset(0, -_kOverlap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchCard(context, colorScheme),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (recentSearches.isNotEmpty) ...[
                            _buildRecentSearches(
                              context,
                              colorScheme,
                              recentSearches,
                            ),
                            const SizedBox(height: 28),
                          ],
                          _buildNetworkCoverage(colorScheme),
                          const SizedBox(height: 28),
                          _buildPromoCarousel(colorScheme),
                        ],
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

  // Header: navy hero with title, explore copy, country carousel 

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    List<DestinationModel> destinations,
  ) {
    return Container(
      width: double.infinity,
      color: colorScheme.secondary,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore East Africa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Secure your journey with absolute reliability.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          if (destinations.isNotEmpty) ...[
            const SizedBox(height: 20),
            _AutoScrollCarousel(
              height: 180,
              itemExtent: 172,
              items: [
                for (final destination in destinations)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 160,
                      child: _DestinationCard(destination: destination),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Search card: overlaps the header, holds the trip-planning form 

  Widget _buildSearchCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where would you like to go?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  TextField(
                    controller: _fromController,
                    decoration: InputDecoration(
                      labelText: 'From',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(
                        Icons.radio_button_checked,
                        color: colorScheme.secondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _toController,
                    decoration: InputDecoration(
                      labelText: 'To',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 8,
                top: 46,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _swapCities,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.swap_vert_rounded,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildDateField(colorScheme)),
                const SizedBox(width: 12),
                Expanded(child: _buildPassengersField(colorScheme)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTripToggle(colorScheme),
          const SizedBox(height: 16),
          PrimaryButton(
            label: "Let's Go!",
            icon: Icons.arrow_forward,
            onPressed: () => _search(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(ColorScheme colorScheme) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Travel Date',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${_travelDate.day} ${_monthName(_travelDate.month)}, ${_travelDate.year}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengersField(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passengers',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleStepButton(
                icon: Icons.remove,
                colorScheme: colorScheme,
                onTap: _passengers > 1
                    ? () => setState(() => _passengers--)
                    : null,
              ),
              Text(
                '$_passengers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              _circleStepButton(
                icon: Icons.add,
                colorScheme: colorScheme,
                onTap: _passengers < 9
                    ? () => setState(() => _passengers++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleStepButton({
    required IconData icon,
    required ColorScheme colorScheme,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surface,
          border: Border.all(
            color: enabled ? colorScheme.secondary : colorScheme.outline,
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? colorScheme.secondary : colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildTripToggle(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tripOption(
              colorScheme,
              'One-Way',
              selected: !_isRoundTrip,
              onTap: () => setState(() => _isRoundTrip = false),
            ),
          ),
          Expanded(
            child: _tripOption(
              colorScheme,
              'Round-Trip',
              selected: _isRoundTrip,
              onTap: () => setState(() => _isRoundTrip = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripOption(
    ColorScheme colorScheme,
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ---- Recent searches ----

  Widget _buildRecentSearches(
    BuildContext context,
    ColorScheme colorScheme,
    List<String> recentSearches,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.read<SearchProvider>().clearRecentSearches(),
              child: Text(
                'Clear',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recentSearches.map((entry) {
          final parts = entry.split(' → ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: parts.length == 2
                  ? () => _search(from: parts[0], to: parts[1])
                  : null,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        Icons.history,
                        size: 20,
                        color: colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---- Network coverage ----

  Widget _buildNetworkCoverage(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network Coverage',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
              ),
            ),
            child: Stack(
              children: [
                const Positioned(left: 70, top: 36, child: _MapDot()),
                const Positioned(left: 118, top: 92, child: _MapDot()),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '24+ Active Routes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- Promo & discounts carousel ----

  Widget _buildPromoCarousel(ColorScheme colorScheme) {
    final promos = [
      _Promo(
        tag: 'FIRST RIDE',
        title: 'Get 20% OFF',
        subtitle: 'Code: BUSBUUK20',
        cta: 'Claim',
        gradient: [
          colorScheme.secondary,
          colorScheme.secondary.withValues(alpha: 0.75),
        ],
        tagColor: colorScheme.primary,
        ctaBackground: colorScheme.primary,
        ctaForeground: Colors.white,
      ),
      _Promo(
        tag: 'GROUP BOOKING',
        title: 'Save up to \$50',
        subtitle: 'Min. 5 People',
        cta: 'Details',
        gradient: [
          colorScheme.primary,
          colorScheme.primary.withValues(alpha: 0.7),
        ],
        tagColor: Colors.white,
        ctaBackground: colorScheme.secondary,
        ctaForeground: Colors.white,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Promo & Discounts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _AutoScrollCarousel(
          height: 158,
          itemExtent: 312,
          pixelsPerSecond: 24,
          items: [
            for (final promo in promos)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(width: 300, child: _PromoCard(promo: promo)),
              ),
          ],
        ),
      ],
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _monthName(int month) => _months[month - 1];
}

// scrolls itself right-to-left on a loop, no PageView snapping
class _AutoScrollCarousel extends StatefulWidget {
  final List<Widget> items;
  final double itemExtent;
  final double height;
  final double pixelsPerSecond;

  const _AutoScrollCarousel({
    required this.items,
    required this.itemExtent,
    required this.height,
    this.pixelsPerSecond = 28,
  });

  @override
  State<_AutoScrollCarousel> createState() => _AutoScrollCarouselState();
}

class _AutoScrollCarouselState extends State<_AutoScrollCarousel>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  double get _loopExtent => widget.itemExtent * widget.items.length;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final deltaSeconds =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    // ticker can fire before the ListView finishes its first layout,
    // calling jumpTo() that early crashes, so just bail out if it's not ready yet
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }
    var offset =
        _scrollController.offset + widget.pixelsPerSecond * deltaSeconds;
    if (offset >= _loopExtent) offset -= _loopExtent;
    _scrollController.jumpTo(offset);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      // the ticker calls jumpTo() every frame forever, which repaints this
      // subtree's decorated cards (shadows/gradients) 60x/sec - isolate that
      // into its own compositing layer so it doesn't drag the rest of the
      // scrollable Home screen along with it
      child: RepaintBoundary(
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          // no manual dragging, the ticker already handles scrolling
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) => SizedBox(
            width: widget.itemExtent,
            child: widget.items[index % widget.items.length],
          ),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final DestinationModel destination;
  const _DestinationCard({required this.destination});

  // HomeScreen rebuilds this on every setState (passenger count, date
  // picker, trip toggle...), so cache the decoded bytes per destination -
  // otherwise every keystroke re-decodes and re-decompresses every photo.
  static final Map<String, Uint8List> _decodedImageCache = {};

  Uint8List get _imageBytes => _decodedImageCache.putIfAbsent(
    destination.id,
    () => base64Decode(destination.imageBase64),
  );

  @override
  Widget build(BuildContext context) {
    // cards render at ~160 logical px wide, but the source photo is saved at
    // up to 800x1000 - without cacheWidth, Skia decodes and keeps a full-res
    // bitmap per card (~15x more pixels than ever get painted), which is a
    // lot of avoidable decode/GC work for a carousel that's always animating
    final cacheWidth = (160 * MediaQuery.of(context).devicePixelRatio).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _imageBytes,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: Color(0xFF001856)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.4, 1],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination.country.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFEA619),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.city,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapDot extends StatelessWidget {
  const _MapDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFEA619),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFEA619).withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final _Promo promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: promo.gradient,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            promo.tag,
            style: TextStyle(
              color: promo.tagColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            promo.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            promo.subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: promo.ctaBackground,
                foregroundColor: promo.ctaForeground,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                promo.cta,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}