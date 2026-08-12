import 'package:flutter/material.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

import '../../../core/constants/app_routes.dart';
import '../data/account_api_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.embedded = false, this.active = false});

  final bool embedded;
  final bool active;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _api = AccountApiService();
  bool _loading = true;
  AccountUser? _user;
  int? _wishlistCount;
  int? _ordersCount;
  int? _cartCount;
  bool _playRouteOpening = false;
  // Pre-warmed authenticated Play route — built eagerly when tab becomes
  // active so the first tap navigates instantly without an async wait.
  String? _prewarmedPlayRoute;
  // Purely visual — shows a brief cursor-line flash when the search bar is
  // pressed. Does not make the field editable; tap still navigates via
  // _openPlayRoute like before.
 

  // ---- Menu items, grouped exactly like the reference design ----
  // (unchanged keys/behaviour — only the visual grouping/order is new)
  static const List<_MenuItem> _profileGroup = [
    _MenuItem(
      keyName: 'profile',
      label: 'My Profile',
      subtitle: 'Personal details',
      icon: Icons.person_outline,
      tint: Color(0xFFE11D48),
      bg: Color(0xFFFFE4E6),
    ),
  ];

  static const List<_MenuItem> _shoppingGroup = [
    _MenuItem(
      keyName: 'orders',
      label: 'Orders',
      subtitle: 'Track & history',
      icon: Icons.shopping_bag_outlined,
      tint: Color(0xFF0D9488),
      bg: Color(0xFFCCFBF1),
    ),
    _MenuItem(
      keyName: 'wishlist',
      label: 'Wishlist',
      subtitle: 'Saved items',
      icon: Icons.favorite_border_rounded,
      tint: Color(0xFFDB2777),
      bg: Color(0xFFFCE7F3),
    ),
    _MenuItem(
      keyName: 'addresses',
      label: 'Addresses',
      subtitle: 'City & state',
      icon: Icons.location_on_outlined,
      tint: Color(0xFF4F46E5),
      bg: Color(0xFFE0E7FF),
    ),
  ];

  static const List<_MenuItem> _communityGroup = [
    _MenuItem(
      keyName: 'playProfile',
      label: 'Play Profile',
      subtitle: 'Videos & plays',
      icon: Icons.play_circle_outline,
      tint: Color(0xFF0EA5E9),
      bg: Color(0xFFE0F2FE),
    ),
    _MenuItem(
      keyName: 'supplierInfo',
      label: 'Supplier Info',
      subtitle: 'Brands & suppliers',
      icon: Icons.qr_code_scanner_outlined,
      tint: Color(0xFFEA580C),
      bg: Color(0xFFFFEDD5),
    ),
  ];

  static const List<_MenuItem> _preferencesGroup = [
    _MenuItem(
      keyName: 'help',
      label: 'Help Center',
      subtitle: 'Instant help',
      icon: Icons.headset_mic_outlined,
      tint: Color(0xFFD97706),
      bg: Color(0xFFFEF3C7),
    ),
    _MenuItem(
      keyName: 'settings',
      label: 'Settings',
      subtitle: 'Privacy & app',
      icon: Icons.settings_outlined,
      tint: Color(0xFF111827),
      bg: Color(0xFFF3F4F6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _prewarmPlayRoute();
  }

  @override
  void didUpdateWidget(covariant AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _load(silent: true);
      _prewarmPlayRoute(); // refresh on every tab activation
    }
  }

  /// Eagerly builds the authenticated Play route string while the user is
  /// reading the Account screen, so the first tap on "Play Profile" is instant.
  Future<void> _prewarmPlayRoute() async {
    try {
      _prewarmedPlayRoute =
          await _buildPlayRouteWithSession(play.AppRoutes.myProfile);
    } catch (_) {
      _prewarmedPlayRoute = null;
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      // Fetch everything in parallel — real counts, same endpoints the
      // Wishlist/Orders/Cart screens themselves use.
      final results = await Future.wait([
        _api.fetchUser(),
        _api.fetchWishlist(),
        _api.fetchOrdersCount(),
        _api.fetchCartCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as AccountUser?;
        _wishlistCount = (results[1] as List).length;
        _ordersCount = results[2] as int;
        _cartCount = results[3] as int;
      });
    } finally {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  // Future<void> _logout() async {
  //   await SessionStore.clearLogin();
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.clear();
  //   if (!mounted) return;
  //   Navigator.of(context)
  //       .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  // }

  void _onMenuTap(_MenuItem item) {
    switch (item.keyName) {
      case 'profile':
        Navigator.of(context).pushNamed(AppRoutes.profile);
        return;
      case 'playProfile':
        _openPlayRoute(play.AppRoutes.myProfile);
        return;
      case 'addresses':
        Navigator.of(context).pushNamed(AppRoutes.address);
        return;
      case 'orders':
        Navigator.of(context).pushNamed(AppRoutes.orders);
        return;
      case 'settings':
        Navigator.of(context).pushNamed(AppRoutes.settings);
        return;
      case 'wishlist':
        Navigator.of(context).pushNamed(AppRoutes.wishlist);
        return;
      case 'help':
        Navigator.of(context).pushNamed(AppRoutes.helpCenter);
        return;
      case 'supplierInfo':
        Navigator.of(context).pushNamed(AppRoutes.supplierInfo);
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.label} screen coming next')),
        );
    }
  }

  Future<void> _openPlayRoute(String routeName) async {
    if (_playRouteOpening) return;
    // setState immediately so the UI shows a loading state on the tapped item
    // before any async work begins — prevents the "first tap feels dropped" UX.
    setState(() => _playRouteOpening = true);
    try {
      // Use pre-warmed route if available (built when tab became active),
      // otherwise fall back to async build. The pre-warm eliminates the
      // SharedPreferences + API call delay on the tap path.
      final routeWithSession = (_prewarmedPlayRoute != null && routeName == play.AppRoutes.myProfile)
          ? _prewarmedPlayRoute!
          : await _buildPlayRouteWithSession(routeName);
      _prewarmedPlayRoute = null; // consume — re-warm on next activation

      final route = play.AppRoutes.onGenerateRoute(
        RouteSettings(name: routeWithSession),
      );
      if (route == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Play module route unavailable')),
        );
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(route);
    } finally {
      if (mounted) setState(() => _playRouteOpening = false);
    }
  }

  Future<String> _buildPlayRouteWithSession(String routeName) async {
    return play.PlayProfileHelper.buildAuthenticatedRoute(routeName);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final name = (_user?.name ?? 'User').trim();
    final phone = (_user?.phone ?? '').trim();
    final initials = name.isEmpty
        ? 'U'
        : name
            .split(' ')
            .where((s) => s.trim().isNotEmpty)
            .take(2)
            .map((s) => s.trim()[0].toUpperCase())
            .join();

    return SafeArea(
      top: true,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            _buildHeaderCard(name: name, phone: phone, initials: initials),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 20),
            _sectionLabel('YOUR ACCOUNT'),
            const SizedBox(height: 10),
            _buildGroupCard('PROFILE', _profileGroup),
            const SizedBox(height: 14),
            _buildGroupCard('SHOPPING', _shoppingGroup),
            const SizedBox(height: 14),
            _buildGroupCard('COMMUNITY', _communityGroup),
            const SizedBox(height: 14),
            _buildGroupCard('PREFERENCES', _preferencesGroup),
            // const SizedBox(height: 16),
            // _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  // Widget _buildLogoutButton() {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: const Color(0xFFF0F0F0)),
  //     ),
  //     child: InkWell(
  //       borderRadius: BorderRadius.circular(16),
  //       onTap: _logout,
  //       child: const Padding(
  //         padding: EdgeInsets.symmetric(vertical: 14),
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
  //             SizedBox(width: 8),
  //             Text(
  //               'Log out',
  //               style: TextStyle(
  //                 color: Color(0xFFDC2626),
  //                 fontWeight: FontWeight.w700,
  //                 fontSize: 14,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // ---------------- UI pieces ----------------

  Widget _buildHeaderCard({
    required String name,
    required String phone,
    required String initials,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD9622B), Color(0xFFE8823F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? 'User' : name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        size: 16, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  phone.isEmpty ? '—' : phone,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Edit', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      clipBehavior: Clip.antiAlias,
      // Material ancestor is required for InkWell taps below to register
      // and respond reliably — a plain Container alone isn't enough.
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _statItem(
                  icon: Icons.shopping_bag_outlined,
                  iconTint: const Color(0xFFEA580C),
                  iconBg: const Color(0xFFFFE9D6),
                  value: _ordersCount?.toString() ?? '—',
                  label: 'ORDERS',
               
                   
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _statItem(
                  icon: Icons.favorite_border_rounded,
                  iconTint: const Color(0xFF0D9488),
                  iconBg: const Color(0xFFCCFBF1),
                  value: _wishlistCount?.toString() ?? '—',
                  label: 'WISHLIST',
                 
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _statItem(
                  icon: Icons.shopping_cart_outlined,
                  iconTint: const Color(0xFFEA580C),
                  iconBg: const Color(0xFFFFE9D6),
                  value: _cartCount?.toString() ?? '—',
                  label: 'CART',
                 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color iconTint,
    required Color iconBg,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: iconTint),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    // InkWell sits under the Material ancestor added in _buildStatsRow so
    // taps register correctly. No SizedBox.expand here — that needs bounded
    // height and this Row doesn't provide one, which was causing a blank/
    // broken page.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }

  Widget _buildSearchBar() {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => _openPlayRoute(play.AppRoutes.search),
     
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        border: Border.all(
  color: const Color(0xFFE5E5E5),
),
        ),
        child: Row(
  children: [
    const Icon(
      Icons.search_rounded,
      color: Color(0xFF9CA3AF),
    ),
    const SizedBox(width: 10),
Expanded(
  child: const Text(
    'Search Welfog videos',
    style: TextStyle(
      color: Color(0xFF9CA3AF),
    ),
  ),
),
  ],
),
      ),
    );
  }

  Widget _sectionLabel(String label, {String? trailingBadge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Color(0xFF9CA3AF),
          ),
        ),
        if (trailingBadge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9D6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailingBadge,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEA580C),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupCard(String groupLabel, List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              groupLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Color(0xFFB0B0B0),
              ),
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
            _buildMenuRow(items[i]),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildMenuRow(_MenuItem m) {
    final bool isPlayItem = m.keyName == 'playProfile';
    final bool showSpinner = isPlayItem && _playRouteOpening;

    return InkWell(
      onTap: () => _onMenuTap(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: m.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: showSpinner
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
                      ),
                    )
                  : Icon(m.icon, size: 19, color: m.tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0xFFC7C7C7),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: const Color(0xFFF0F0F0),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.keyName,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.bg,
  });

  final String keyName;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color bg;
}