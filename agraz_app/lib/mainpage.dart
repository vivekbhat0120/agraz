import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'income_expense.dart';
import 'manage_organization.dart';
import 'services.dart';
import 'labour.dart';
import 'diary.dart';
import 'dairy.dart';
import 'dairy_owner.dart';
import 'future_plans.dart';
import 'labour_work.dart';
import 'marke_report.dart';
import 'buy_and_sell.dart';
import 'farmer_education.dart';
import 'government_facilities.dart';
import 'weather_report.dart';
import 'rtc_entry.dart';
import 'documents.dart';
import 'event_manage.dart';
import 'event_alarms.dart';
import 'auth_token.dart';
import 'config.dart';
import 'login.dart';
import 'welcome_screen.dart';
import 'app_theme.dart';
import 'feedback_fab.dart';
import 'feedback_page.dart';
import 'l10n/app_l10n.dart';
import 'l10n/locale_controller.dart';
import 'app_update.dart';
import 'api_service.dart';
import 'account_session.dart';
import 'getting_started_page.dart';
import 'faq_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'family_members_page.dart';
import 'offline_sync.dart';

const _prefsUserCreatedAt = 'agraz_user_created_at';
const _freeYearDays = 365;

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _ServiceFeature {
  final IconData icon;
  final String title;
  final String description;
  final List<String> details;

  _ServiceFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.details,
  });
}

class _MainPageState extends State<MainPage> {
  bool _isLoggedIn = false;
  int? _freeDaysRemaining;
  int _pendingLaborShares = 0;
  AccountSession _session = AccountSession.guest;

  final List<String> _sliderImages = [
    'assets/images/areca.jpg',
    'assets/images/banana.jpeg',
    'assets/images/pepper.jpg',
    'assets/images/coffee.jpeg',
    'assets/images/bhatta.jpeg',
  ];

  late PageController _pageController;
  late Timer _autoSlideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _refreshAuthState();
    _currentPage = 0;
    _pageController = PageController(viewportFraction: 1.0);
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _currentPage++;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final updating = await promptInAppUpdateIfNeeded(context);
      if (updating && mounted) await _refreshAuthState();
    });
  }

  @override
  void dispose() {
    _autoSlideTimer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshAuthState() async {
    final token = await getValidAuthToken();
    if (!mounted) return;
    setState(() => _isLoggedIn = token != null);
    if (token != null) {
      await _loadFreeDaysRemaining();
      await _loadPendingLaborShares();
      EventAlarms.instance.syncFromApi();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsUserCreatedAt);
      if (mounted) {
        setState(() {
          _freeDaysRemaining = null;
          _pendingLaborShares = 0;
          _session = AccountSession.guest;
        });
      }
    }
  }

  Future<void> _loadFreeDaysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsUserCreatedAt);
    if (cached != null && cached.isNotEmpty) {
      final remaining = _remainingFreeDaysFrom(cached);
      if (remaining != null && mounted) {
        setState(() => _freeDaysRemaining = remaining);
      }
    }
    try {
      final headers = await authGetHeaders();
      final res = await OfflineSync.instance.get(
        Uri.parse('${normalizedBaseUrl()}/api/me'),
        headers: headers,
      );
      if (!mounted) return;
      if (res.statusCode < 200 || res.statusCode >= 300) return;
      final data = jsonDecode(res.body);
      if (data is! Map) return;
      final session = AccountSession.fromJson(Map<String, dynamic>.from(data));
      final raw = data['created_at']?.toString();
      if (raw != null && raw.isNotEmpty) {
        await prefs.setString(_prefsUserCreatedAt, raw);
      }
      final remaining = (raw != null && raw.isNotEmpty)
          ? _remainingFreeDaysFrom(raw)
          : _freeDaysRemaining;
      if (mounted) {
        setState(() {
          _session = session;
          if (remaining != null) _freeDaysRemaining = remaining;
        });
      }
    } catch (_) {
      // Keep cached remaining days when offline.
    }
  }

  Future<void> _loadPendingLaborShares() async {
    try {
      final n = await ApiService().fetchLaborSharePendingCount();
      if (mounted) setState(() => _pendingLaborShares = n);
    } catch (_) {
      if (mounted) setState(() => _pendingLaborShares = 0);
    }
  }

  int? _remainingFreeDaysFrom(String rawCreatedAt) {
    try {
      final registered = DateTime.parse(rawCreatedAt).toLocal();
      final start = DateTime(registered.year, registered.month, registered.day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return (_freeYearDays - today.difference(start).inDays).clamp(0, _freeYearDays);
    } catch (_) {
      return null;
    }
  }

  bool _featureEnabled(String key) {
    if (!_isLoggedIn || !_session.isSubUser) return true;
    return _session.allows(key);
  }

  void _showFeatureDisabled() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('This option is disabled for your account'))),
    );
  }

  /// Opens [page] without requiring login (modules remain visible to guests).
  Future<void> _openModule(
    Widget page, {
    bool closeDrawer = false,
    String? feature,
  }) async {
    if (closeDrawer) Navigator.pop(context);
    if (feature != null && !_featureEnabled(feature)) {
      _showFeatureDisabled();
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (mounted) await _refreshAuthState();
  }

  /// Opens [page] if logged in; otherwise shows login, then opens [page] on success.
  Future<void> _openProtected(
    Widget page, {
    bool closeDrawer = false,
    String? feature,
  }) async {
    if (closeDrawer) Navigator.pop(context);
    if (feature != null && !_featureEnabled(feature)) {
      _showFeatureDisabled();
      return;
    }

    final token = await getAuthToken();
    if (token != null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
      if (mounted) await _refreshAuthState();
      return;
    }

    if (!mounted) return;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (loggedIn == true && mounted) {
      await _refreshAuthState();
      if (!mounted) return;
      if (feature != null && !_featureEnabled(feature)) {
        _showFeatureDisabled();
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  Future<void> _goToLogin() async {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (loggedIn == true && mounted) {
      await _refreshAuthState();
      if (!mounted) return;
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const WelcomeScreen(),
          transitionsBuilder:
              (_, anim, _, child) =>
                  FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => Scaffold(
      appBar: GradientAppBar(
        title: "AgRaz",
        actions: withFeedbackAction(
          context,
          menu: 'home',
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: tr('About Team'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutTeamPage()),
                );
              },
            ),
            if (_featureEnabled(AppFeatureCatalog.settings))
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: tr('Settings'),
                onPressed: () => _openProtected(
                  const SettingsPage(),
                  feature: AppFeatureCatalog.settings,
                ),
              ),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHelpCenter(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.help_rounded, color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Hero Section (Image Slider) ---
            _buildHero(),
            _buildFreeVersionNote(),
            if (_isLoggedIn && _session.isSubUser) _buildFamilyAccountBanner(),
            _buildQuickShortcuts(),
            if (_isLoggedIn)
              ListenableBuilder(
                listenable: OfflineSync.instance,
                builder: (context, _) => _buildOfflineSyncBanner(),
              ),
            if (_isLoggedIn &&
                _pendingLaborShares > 0 &&
                _featureEnabled(AppFeatureCatalog.labourWork))
              _buildLaborShareBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  // --- What is AgRaz? ---
                  _buildAboutCard(),
                  SizedBox(height: 28),
                  // --- Services ---
                  _buildSectionHeader('Our Services for Farmers'),
                  SizedBox(height: 14),
                  _buildServicesGrid(),
                  SizedBox(height: 28),
                  // --- Why Choose AgRaz? ---
                  _buildSectionHeader('Why Choose AgRaz?'),
                  SizedBox(height: 14),
                  _buildWhyChooseCard(
                    icon: Icons.auto_awesome_rounded,
                    text: tr('AI-driven insights tailored to your farm'),
                    color: AppColors.accent,
                    index: '01',
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.wifi_off_rounded,
                    text: tr('Works offline & syncs automatically'),
                    color: AppColors.info,
                    index: '02',
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.language_rounded,
                    text: tr('Available in local languages'),
                    color: AppColors.warning,
                    index: '03',
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.verified_rounded,
                    text: tr('Backed by agriculture experts'),
                    color: AppColors.primary,
                    index: '04',
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.shield_rounded,
                    text: tr('Secure and farmer-first design'),
                    color: AppColors.expense,
                    index: '05',
                  ),
                  SizedBox(height: 28),
                  // --- Let AgRaz Work For You ---
                  _buildCtaCard(),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Drawer / Sidebar                                                  */
  /* ------------------------------------------------------------------ */

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      width: 308,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _drawerSectionLabel(tr('MENU')),
                  _drawerTile(
                    Icons.home_filled,
                    tr('Home'),
                    AppColors.primary,
                    () => Navigator.pop(context),
                    active: true,
                  ),
                  if (_featureEnabled(AppFeatureCatalog.incomeExpense))
                    _drawerTile(
                      Icons.account_balance_wallet_rounded,
                      tr('Income & Expense'),
                      AppColors.income,
                      () => _openProtected(
                        const IncomeExpensePage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.incomeExpense,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.organization))
                    _drawerTile(
                      Icons.business_rounded,
                      tr('Manage Organization'),
                      AppColors.primaryLight,
                      () => _openModule(
                        const ManageOrganizationPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.organization,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.labour))
                    _drawerTile(
                      Icons.engineering_rounded,
                      tr('Labour Management'),
                      AppColors.warning,
                      () => _openProtected(
                        const LaborManagementPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.labour,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.labourWork))
                    _drawerTile(
                      Icons.handshake_rounded,
                      tr('Labour Work Entry'),
                      AppColors.primaryLight,
                      () => _openProtected(
                        const LabourWorkPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.labourWork,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.dairy))
                    _drawerTile(
                      Icons.water_drop_rounded,
                      tr('Dairy'),
                      AppColors.info,
                      () => _openProtected(
                        const DairyPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.dairy,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.dairyOwner))
                    _drawerTile(
                      Icons.local_drink_rounded,
                      tr('Dairy Owner'),
                      AppColors.primaryLight,
                      () => _openProtected(
                        const DairyOwnerPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.dairyOwner,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.notes))
                    _drawerTile(
                      Icons.sticky_note_2_outlined,
                      tr('Notes'),
                      AppColors.accent,
                      () => _openProtected(
                        const DiaryPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.notes,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.futurePlans))
                    _drawerTile(
                      Icons.flag_outlined,
                      tr('Future Plans'),
                      AppColors.info,
                      () => _openProtected(
                        const FuturePlansPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.futurePlans,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.market))
                    _drawerTile(
                      Icons.trending_up_rounded,
                      tr('Market Reports'),
                      AppColors.info,
                      () => _openModule(
                        const RatesComparisonPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.market,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.weather))
                    _drawerTile(
                      Icons.cloud_outlined,
                      tr('Weather Report'),
                      AppColors.info,
                      () => _openModule(
                        const WeatherReportPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.weather,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.services))
                    _drawerTile(
                      Icons.miscellaneous_services_rounded,
                      tr('General Services'),
                      AppColors.expense,
                      () => _openModule(
                        const ServiceListingPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.services,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.buySell))
                    _drawerTile(
                      Icons.store_rounded,
                      tr('Buy & Sell'),
                      AppColors.primaryLight,
                      () => _openModule(
                        const BuySellApp(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.buySell,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.farmerEducation))
                    _drawerTile(
                      Icons.menu_book_rounded,
                      tr('Farmer Education'),
                      AppColors.accent,
                      () => _openModule(
                        const FarmerEducationPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.farmerEducation,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.government))
                    _drawerTile(
                      Icons.account_balance_rounded,
                      tr('Government Facilities'),
                      AppColors.info,
                      () => _openModule(
                        const GovernmentFacilitiesPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.government,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.rtc))
                    _drawerTile(
                      Icons.map_outlined,
                      tr('RTC Entry'),
                      AppColors.primaryDark,
                      () => _openProtected(
                        const RtcEntryPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.rtc,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.documents))
                    _drawerTile(
                      Icons.folder_rounded,
                      tr('Documents'),
                      AppColors.accent,
                      () => _openProtected(
                        const DocumentsPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.documents,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.eventManage))
                    _drawerTile(
                      Icons.event_available_rounded,
                      tr('Event Manage'),
                      AppColors.warning,
                      () => _openProtected(
                        const EventManagePage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.eventManage,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.feedback))
                    _drawerTile(
                      Icons.feedback_outlined,
                      tr('Feedback'),
                      AppColors.accent,
                      () => _openModule(
                        const FeedbackPage(initialMenu: 'home'),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.feedback,
                      ),
                    ),
                  _drawerSectionLabel(tr('ACCOUNT')),
                  if (_featureEnabled(AppFeatureCatalog.profile))
                    _drawerTile(
                      Icons.person_rounded,
                      tr('Profile'),
                      AppColors.info,
                      () => _openProtected(
                        const ProfilePage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.profile,
                      ),
                    ),
                  if (_isLoggedIn &&
                      _session.canManageFamily &&
                      !_session.isSubUser)
                    _drawerTile(
                      Icons.family_restroom,
                      tr('Family members'),
                      AppColors.primary,
                      () => _openProtected(
                        const FamilyMembersPage(),
                        closeDrawer: true,
                      ),
                    ),
                  if (_featureEnabled(AppFeatureCatalog.settings))
                    _drawerTile(
                      Icons.settings_rounded,
                      tr('Settings'),
                      AppColors.textSecondary,
                      () => _openProtected(
                        const SettingsPage(),
                        closeDrawer: true,
                        feature: AppFeatureCatalog.settings,
                      ),
                    ),
                  _drawerTile(
                    Icons.groups_rounded,
                    tr('About Team'),
                    AppColors.primaryLight,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutTeamPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildDrawerFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              'assets/images/logo.jpeg',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AgRaz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Smart Agriculture ERP',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 6),
      child: Text(label, style: AppText.caption),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                TintedIcon(
                  icon: icon,
                  color: color,
                  boxSize: 36,
                  size: 18,
                  radius: 10,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? color : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: _isLoggedIn
          ? _buildLogoutButton()
          : _buildLoginButton(),
    );
  }

  Widget _buildLoginButton() {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          _goToLogin();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3FA97E), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.login_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Sign in to your account',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Material(
      color: AppColors.expenseSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          _showLogoutConfirmationDialog(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF88B83), AppColors.expense],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.expense.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.expense,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Sign out of your account',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.expense,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Home sections                                                     */
  /* ------------------------------------------------------------------ */

  Widget _buildFreeVersionNote() {
    if (!_isLoggedIn || _freeDaysRemaining == null) {
      return const SizedBox.shrink();
    }
    final days = _freeDaysRemaining!;
    final label = days == 1
        ? trf('Enjoy free version for {0} day', [days])
        : trf('Enjoy free version for {0} days', [days]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyAccountBanner() {
    final member = _session.memberName ?? tr('Family member');
    final account = _session.accountName.isEmpty
        ? tr('main account')
        : _session.accountName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.family_restroom, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trf('Signed in as {0}. You are using {1}\'s account.', [
                    member,
                    account,
                  ]),
                  style: AppText.bodyStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineSyncBanner() {
    final sync = OfflineSync.instance;
    if (sync.pendingCount <= 0 && !sync.isSyncing) {
      return const SizedBox.shrink();
    }
    final label = sync.isSyncing
        ? tr('Syncing saved changes…')
        : !sync.isOnline
            ? tr('Offline. Changes will sync automatically.')
            : sync.pendingCount == 1
                ? tr('1 change waiting to sync')
                : trf('{0} changes waiting to sync', [sync.pendingCount]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => OfflineSync.instance.sync(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  sync.isSyncing
                      ? Icons.sync_rounded
                      : sync.isOnline
                          ? Icons.cloud_upload_rounded
                          : Icons.cloud_off_rounded,
                  color: AppColors.info,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label, style: AppText.bodyStrong),
                ),
                if (sync.isSyncing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.sync_rounded, color: AppColors.info),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLaborShareBanner() {
    final label = _pendingLaborShares == 1
        ? tr('1 work entry waiting for confirmation')
        : trf('{0} work entries waiting for confirmation', [_pendingLaborShares]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openProtected(
            const LabourWorkPage(initialTab: 2),
            feature: AppFeatureCatalog.labourWork,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_rounded, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label, style: AppText.bodyStrong),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickShortcuts() {
    final items = <({
      IconData icon,
      String label,
      Color color,
      String feature,
      VoidCallback open,
    })>[
      (
        icon: Icons.account_balance_wallet_rounded,
        label: tr('Income & Expense'),
        color: AppColors.income,
        feature: AppFeatureCatalog.incomeExpense,
        open: () => _openProtected(
          const IncomeExpensePage(),
          feature: AppFeatureCatalog.incomeExpense,
        ),
      ),
      (
        icon: Icons.business_rounded,
        label: tr('Organizations'),
        color: AppColors.primaryLight,
        feature: AppFeatureCatalog.organization,
        open: () => _openModule(
          const ManageOrganizationPage(),
          feature: AppFeatureCatalog.organization,
        ),
      ),
      (
        icon: Icons.engineering_rounded,
        label: tr('Labour'),
        color: AppColors.warning,
        feature: AppFeatureCatalog.labour,
        open: () => _openProtected(
          const LaborManagementPage(),
          feature: AppFeatureCatalog.labour,
        ),
      ),
      (
        icon: Icons.handshake_rounded,
        label: tr('Work Entry'),
        color: AppColors.primaryLight,
        feature: AppFeatureCatalog.labourWork,
        open: () => _openProtected(
          const LabourWorkPage(),
          feature: AppFeatureCatalog.labourWork,
        ),
      ),
      (
        icon: Icons.water_drop_rounded,
        label: tr('Dairy'),
        color: AppColors.info,
        feature: AppFeatureCatalog.dairy,
        open: () => _openProtected(
          const DairyPage(),
          feature: AppFeatureCatalog.dairy,
        ),
      ),
      (
        icon: Icons.local_drink_rounded,
        label: tr('Dairy Owner'),
        color: AppColors.primaryLight,
        feature: AppFeatureCatalog.dairyOwner,
        open: () => _openProtected(
          const DairyOwnerPage(),
          feature: AppFeatureCatalog.dairyOwner,
        ),
      ),
      (
        icon: Icons.sticky_note_2_outlined,
        label: tr('Notes'),
        color: AppColors.accent,
        feature: AppFeatureCatalog.notes,
        open: () => _openProtected(
          const DiaryPage(),
          feature: AppFeatureCatalog.notes,
        ),
      ),
      (
        icon: Icons.flag_outlined,
        label: tr('Plans'),
        color: AppColors.info,
        feature: AppFeatureCatalog.futurePlans,
        open: () => _openProtected(
          const FuturePlansPage(),
          feature: AppFeatureCatalog.futurePlans,
        ),
      ),
      (
        icon: Icons.trending_up_rounded,
        label: tr('Market'),
        color: AppColors.info,
        feature: AppFeatureCatalog.market,
        open: () => _openModule(
          const RatesComparisonPage(),
          feature: AppFeatureCatalog.market,
        ),
      ),
      (
        icon: Icons.cloud_outlined,
        label: tr('Weather'),
        color: AppColors.info,
        feature: AppFeatureCatalog.weather,
        open: () => _openModule(
          const WeatherReportPage(),
          feature: AppFeatureCatalog.weather,
        ),
      ),
      (
        icon: Icons.miscellaneous_services_rounded,
        label: tr('Services'),
        color: AppColors.expense,
        feature: AppFeatureCatalog.services,
        open: () => _openModule(
          const ServiceListingPage(),
          feature: AppFeatureCatalog.services,
        ),
      ),
      (
        icon: Icons.store_rounded,
        label: tr('Buy & Sell'),
        color: AppColors.primaryLight,
        feature: AppFeatureCatalog.buySell,
        open: () => _openModule(
          const BuySellApp(),
          feature: AppFeatureCatalog.buySell,
        ),
      ),
      (
        icon: Icons.menu_book_rounded,
        label: tr('Education'),
        color: AppColors.accent,
        feature: AppFeatureCatalog.farmerEducation,
        open: () => _openModule(
          const FarmerEducationPage(),
          feature: AppFeatureCatalog.farmerEducation,
        ),
      ),
      (
        icon: Icons.account_balance_rounded,
        label: tr('Govt'),
        color: AppColors.info,
        feature: AppFeatureCatalog.government,
        open: () => _openModule(
          const GovernmentFacilitiesPage(),
          feature: AppFeatureCatalog.government,
        ),
      ),
      (
        icon: Icons.map_outlined,
        label: tr('RTC'),
        color: AppColors.primaryDark,
        feature: AppFeatureCatalog.rtc,
        open: () => _openProtected(
          const RtcEntryPage(),
          feature: AppFeatureCatalog.rtc,
        ),
      ),
      (
        icon: Icons.folder_rounded,
        label: tr('Documents'),
        color: AppColors.accent,
        feature: AppFeatureCatalog.documents,
        open: () => _openProtected(
          const DocumentsPage(),
          feature: AppFeatureCatalog.documents,
        ),
      ),
      (
        icon: Icons.event_available_rounded,
        label: tr('Events'),
        color: AppColors.warning,
        feature: AppFeatureCatalog.eventManage,
        open: () => _openProtected(
          const EventManagePage(),
          feature: AppFeatureCatalog.eventManage,
        ),
      ),
      (
        icon: Icons.feedback_outlined,
        label: tr('Feedback'),
        color: AppColors.primary,
        feature: AppFeatureCatalog.feedback,
        open: () => _openModule(
          const FeedbackPage(initialMenu: 'home'),
          feature: AppFeatureCatalog.feedback,
        ),
      ),
    ].where((e) => _featureEnabled(e.feature)).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final item = items[i];
            return InkWell(
              onTap: item.open,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero() {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: null,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final imageIndex = index % _sliderImages.length;
              return Image.asset(
                _sliderImages[imageIndex],
                fit: BoxFit.cover,
                width: double.infinity,
                height: 280,
              );
            },
          ),
          // Gradient scrim for readability
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.68),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          // Caption
          Positioned(
            left: 20,
            right: 20,
            bottom: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'AGRICULTURE ERP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: Color(0xFF3D2A06),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Smart Farming,\nSimplified.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          // Dots
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sliderImages.length, (i) {
                final isActive = _currentPage % _sliderImages.length == i;
                return GestureDetector(
                  onTap: () {
                    int target =
                        (_currentPage ~/ _sliderImages.length) *
                            _sliderImages.length +
                        i;
                    if (target < _currentPage) {
                      target += _sliderImages.length;
                    }
                    _pageController.animateToPage(
                      target,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TintedIcon(
                icon: Icons.agriculture_rounded,
                color: AppColors.primary,
                boxSize: 46,
                size: 24,
                radius: 14,
              ),
              SizedBox(width: 12),
              Expanded(child: Text(tr('What is AgRaz?'), style: AppText.h3)),
            ],
          ),
          SizedBox(height: 14),
          Text(
            tr(
              'AgRaz is a smart Agriculture ERP platform built for modern farmers and agribusinesses. Whether you\'re managing a small farm or large-scale operations, AgRaz helps you digitize, simplify, and grow your agricultural journey.',
            ),
            style: AppText.body.copyWith(height: 1.55),
          ),
          SizedBox(height: 16),
          if (_isLoggedIn)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.incomeSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.income,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('You\'re logged in — explore all features'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.income,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            PrimaryButton(
              label: tr('Login to Get Started'),
              icon: Icons.login_rounded,
              onPressed: _goToLogin,
              height: 48,
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            tr(title),
            style: AppText.h3.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesGrid() {
    final services = [
      _ServiceFeature(
        icon: Icons.account_balance_wallet_rounded,
        title: tr('Income & Expense'),
        description: tr(
          'Log crop-wise income and spending, and see monthly reports so you always know the farm balance.',
        ),
        details: [
          tr('Record income and expense by crop and season'),
          tr('Categorize daily and seasonal spending'),
          tr('Generate monthly reports'),
          tr('Keep a clear running balance'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.business_rounded,
        title: tr('Manage Organization'),
        description: tr(
          'Organize farms, groups, and agribusiness units with shared records in one place.',
        ),
        details: [
          tr('Create and manage farm organizations'),
          tr('Keep contacts and unit details together'),
          tr('Share organization reports with your team'),
          tr('Switch between farm units easily'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.engineering_rounded,
        title: tr('Labour Management'),
        description: tr(
          'Maintain labour names, rates, categories, and payments with daily and seasonal summaries.',
        ),
        details: [
          tr('Save labour names, gender, shift, and category'),
          tr('Set and update rates quickly'),
          tr('Track rent, food, and bonus costs'),
          tr('Export labour summaries for payroll'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.handshake_rounded,
        title: tr('Labour Work Entry'),
        description: tr(
          'Enter daily work and share it with family members so they can confirm what was done.',
        ),
        details: [
          tr('Record work by date, shift, and category'),
          tr('Share entries with family for confirmation'),
          tr('See pending work waiting for approval'),
          tr('Keep a complete work history'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.water_drop_rounded,
        title: tr('Dairy'),
        description: tr(
          'For farmers: record milk given or bought, morning and evening shifts, and payments receivable.',
        ),
        details: [
          tr('Log milk given and milk bought in liters'),
          tr('Capture morning and evening shifts'),
          tr('Record payments received and made'),
          tr('See receivable totals automatically'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.local_drink_rounded,
        title: tr('Dairy Owner'),
        description: tr(
          'For dairy owners: manage customers, milk collection, sales, and amounts payable.',
        ),
        details: [
          tr('Save customer name, mobile, village, and default rate'),
          tr('Record milk collected and milk sold'),
          tr('Track paid and received amounts'),
          tr('View owner summary of liters and payable'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.sticky_note_2_outlined,
        title: tr('Notes'),
        description: tr(
          'Keep farm notes, checklists, and reminders so nothing important is forgotten.',
        ),
        details: [
          tr('Create lists and checklists'),
          tr('Mark tasks done as you work'),
          tr('Use icons for money, work, food, and more'),
          tr('Find notes quickly when you need them'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.flag_outlined,
        title: tr('Future Plans'),
        description: tr(
          'Plan upcoming farm work and budgets so you can prepare money, labour, and materials in advance.',
        ),
        details: [
          tr('List planned work with dates'),
          tr('Attach estimated costs in rupees'),
          tr('Track what is still pending'),
          tr('Review plans before the season starts'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.trending_up_rounded,
        title: tr('Market Reports'),
        description: tr(
          'Compare live APMC and market rates so you can sell at a better price.',
        ),
        details: [
          tr('See arrivals, traded quantity, and varieties'),
          tr('Compare prices across markets and taluks'),
          tr('Follow agents and APMC updates'),
          tr('Spot better selling opportunities'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.cloud_outlined,
        title: tr('Weather Report'),
        description: tr(
          'Get local weather, a 7-day forecast, and farm advice for the week ahead.',
        ),
        details: [
          tr('View temperature, rain chance, and wind'),
          tr('Check a 7-day forecast'),
          tr('Read farm advice for the next week'),
          tr('Reports refresh automatically'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.miscellaneous_services_rounded,
        title: tr('General Services'),
        description: tr(
          'Find local agri services you need — from equipment to repair and farm support.',
        ),
        details: [
          tr('Browse service categories near you'),
          tr('Register your own service for farmers'),
          tr('Reach trusted local providers'),
          tr('Keep service contacts in the app'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.store_rounded,
        title: tr('Buy & Sell'),
        description: tr(
          'Trade seeds, fertilizers, pesticides, and harvested crops with trusted vendors and buyers.',
        ),
        details: [
          tr('List produce and agri inputs'),
          tr('Connect with verified vendors and buyers'),
          tr('Check market-linked prices'),
          tr('Sell farm-to-market from your phone'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.menu_book_rounded,
        title: tr('Farmer Education'),
        description: tr(
          'Learn better farming practices with practical guidance from agriculture experts.',
        ),
        details: [
          tr('Read crop and farm education content'),
          tr('Follow expert-backed practices'),
          tr('Learn in English or Kannada'),
          tr('Apply tips to your own farm'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.account_balance_rounded,
        title: tr('Government Facilities'),
        description: tr(
          'Discover agricultural loans, insurance, and government schemes that can support your farm.',
        ),
        details: [
          tr('Browse government schemes and facilities'),
          tr('Find loan and insurance information'),
          tr('Track schemes relevant to your farm'),
          tr('Keep important facility details handy'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.map_outlined,
        title: tr('RTC Entry'),
        description: tr(
          'Store land RTC records and survey details so farm land information stays with you.',
        ),
        details: [
          tr('Enter RTC and survey details'),
          tr('Keep land records in one place'),
          tr('Update entries when records change'),
          tr('Refer back anytime you need them'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.folder_rounded,
        title: tr('Documents'),
        description: tr(
          'Keep personal papers such as Aadhaar and PAN. Create a folder for each family member and add photos.',
        ),
        details: [
          tr('Create a folder for each family member'),
          tr('Upload Aadhaar, PAN, and other papers'),
          tr('Add multiple photos to a document'),
          tr('Open a name to view the photos'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.event_available_rounded,
        title: tr('Event Manage'),
        description: tr(
          'Remember birthdays, insurance renewals, and other important dates with an alarm on your phone.',
        ),
        details: [
          tr('Add event name, date, and notification time'),
          tr('Repeat yearly, monthly, weekly, or daily'),
          tr('Hear an alarm sound when the time comes'),
          tr('Edit or delete reminders anytime'),
        ],
      ),
      _ServiceFeature(
        icon: Icons.family_restroom,
        title: tr('Family Members'),
        description: tr(
          'Share one farm account with family. The main holder chooses which options each member can use.',
        ),
        details: [
          tr('Add family login under the main account'),
          tr('Their entries stay on the same farm records'),
          tr('Turn options on or off per member'),
          tr('Work together on labour, dairy, and expenses'),
        ],
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < services.length; i += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildServiceCard(services[i])),
                SizedBox(width: 12),
                if (i + 1 < services.length)
                  Expanded(child: _buildServiceCard(services[i + 1]))
                else
                  Expanded(child: SizedBox()),
              ],
            ),
          ),
          if (i + 2 < services.length) SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildServiceCard(_ServiceFeature service) {
    return AppCard(
      onTap: () => _showServiceDetailModal(context, service),
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintedIcon(
                icon: service.icon,
                color: AppColors.primary,
                boxSize: 40,
                size: 20,
                radius: 12,
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_outward_rounded,
                color: AppColors.textMuted,
                size: 15,
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            service.title,
            style: AppText.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 5),
          Text(
            service.description.length > 72
                ? '${service.description.substring(0, 72)}…'
                : service.description,
            style: AppText.small,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'Learn more',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 3),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 13,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseCard({
    required IconData icon,
    required String text,
    required Color color,
    required String index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [AppColors.softShadow],
      ),
      child: Row(
        children: [
          TintedIcon(icon: icon, color: color, boxSize: 44, size: 22, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppText.bodyStrong),
          ),
          Text(
            index,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 13),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.ctaGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Let AgRaz Work For You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            'AgRaz empowers farmers with the right tools to:',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          SizedBox(height: 12),
          _buildBenefitRow(Icons.insights_rounded, 'Make informed decisions'),
          _buildBenefitRow(Icons.trending_up_rounded, 'Maximize profits'),
          _buildBenefitRow(Icons.shield_outlined, 'Reduce risks'),
          _buildBenefitRow(
            Icons.support_agent_rounded,
            'Access real-time support & services',
          ),
          SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, color: AppColors.accent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"Start your journey with AgRaz today – where technology meets tradition"',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoggedIn ? null : _goToLogin,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(_isLoggedIn ? tr('You\'re all set') : tr('Get Started')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDeep,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Dialogs                                                           */
  /* ------------------------------------------------------------------ */

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(tr('Logout')),
          content: Text(tr('Are you sure you want to logout?')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(tr('Cancel')),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogout();
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(tr('Logout')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    await EventAlarms.instance.cancelAll();
    await clearAuthToken();
    if (!mounted) return;
    await _refreshAuthState();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('Logged out successfully'))));
  }

  void _showHelpCenter(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TintedIcon(
                    icon: Icons.help_center_rounded,
                    color: AppColors.primary,
                    boxSize: 64,
                    size: 32,
                    radius: 20,
                  ),
                  SizedBox(height: 14),
                  Text(tr('Help Center'), style: AppText.h3),
                  SizedBox(height: 4),
                  Text(tr('How can we help you?'), style: AppText.small),
                  SizedBox(height: 18),
                  _buildHelpItem(
                    Icons.article_rounded,
                    tr('Getting Started'),
                    tr('Learn how to use AgRaz'),
                    AppColors.info,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openModule(const GettingStartedPage());
                    },
                  ),
                  SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.contact_support_rounded,
                    tr('Contact Support'),
                    tr('Reach out to our team'),
                    AppColors.warning,
                    onTap: () => _contactSupport(ctx),
                  ),
                  SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.quiz_rounded,
                    tr('FAQ'),
                    tr('Frequently asked questions'),
                    AppColors.accent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openModule(const FaqPage());
                    },
                  ),
                  SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.feedback_rounded,
                    tr('Send Feedback'),
                    tr('Help us improve'),
                    AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openModule(
                        const FeedbackPage(initialMenu: 'home'),
                        feature: AppFeatureCatalog.feedback,
                      );
                    },
                  ),
                  SizedBox(height: 18),
                  PrimaryButton(
                    label: tr('Close'),
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.pop(ctx),
                    height: 48,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildHelpItem(
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            TintedIcon(icon: icon, color: color, boxSize: 40, size: 20, radius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(subtitle, style: AppText.small),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contactSupport(BuildContext ctx) async {
    Navigator.pop(ctx);
    final uri = Uri(
      scheme: 'mailto',
      path: 'agraz.solutions@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': 'AgRaz Support Request',
      }),
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(tr('Could not open email app'))),
        );
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(tr('Could not open email app'))),
        );
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showServiceDetailModal(BuildContext context, _ServiceFeature service) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TintedIcon(
                    icon: service.icon,
                    color: AppColors.primary,
                    boxSize: 64,
                    size: 32,
                    radius: 20,
                  ),
                  SizedBox(height: 14),
                  Text(
                    service.title,
                    textAlign: TextAlign.center,
                    style: AppText.h3,
                  ),
                  SizedBox(height: 8),
                  Text(
                    service.description,
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  SizedBox(height: 18),
                  const Divider(),
                  SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SectionTitle(
                      icon: Icons.checklist_rounded,
                      title: tr('Key Features'),
                    ),
                  ),
                  SizedBox(height: 12),
                  ...service.details.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                              size: 14,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(child: Text(d, style: AppText.body)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Close',
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.pop(ctx),
                    height: 50,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
