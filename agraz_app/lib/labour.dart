import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'labor_categories.dart';
import 'labour_summary.dart';
import 'l10n/app_l10n.dart';
import 'update_labour_rate.dart';
import 'voice_dictation.dart';

const double _fieldHeight = 48;

class _PendingLabour {
  final String name;
  final String? mobile;
  final String shift;
  final double daysHour;
  final String gender;
  final double rate;
  final String category;
  final double rent;
  final double food;
  final double bonus;

  const _PendingLabour({
    required this.name,
    this.mobile,
    required this.shift,
    required this.daysHour,
    required this.gender,
    required this.rate,
    required this.category,
    this.rent = 0,
    this.food = 0,
    this.bonus = 0,
  });

  double get totalCost => rate * daysHour;
  double get othersTotal => rent + food + bonus;
}

class LaborManagementPage extends StatefulWidget {
  const LaborManagementPage({super.key});

  @override
  _LaborManagementPageState createState() => _LaborManagementPageState();
}

class _LaborManagementPageState extends State<LaborManagementPage>
    with SingleTickerProviderStateMixin {
  final List<Laborer> _laborers = [];
  final List<_PendingLabour> _pending = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _daysHourController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _labourHeadController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _paymentAmountController = TextEditingController();
  final TextEditingController _obPayableController = TextEditingController();
  final TextEditingController _obPaymentController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedWorkType = 'Daily Wages';
  String? _selectedLocation = 'Farm';
  String _selectedShift = 'fullday';
  String _selectedGender = 'Male';
  String _selectedCategory = 'Plucking';
  /// Top mode: Payable / Labour Entry, Payment, or OB/Tally.
  String _entryMode = 'Payable';
  /// Outstanding balance for selected labourer (green chip).
  double? _labourBalance;
  double? _labourPayable;
  double? _labourReceivable;
  /// Optional extras (rent/food/bonus) applied to next pending labourer.
  double _extraRent = 0;
  double _extraFood = 0;
  double _extraBonus = 0;

  final List<String> _workTypes = ['Daily Wages', 'Contract'];
  final List<String> _shifts = ['fullday', 'morning', 'evening', 'night'];
  final List<String> _genders = ['Male', 'Female'];
  List<String> _categories = List<String>.from(kLaborWorkCategories);
  final List<String> _locations = [
    'Farm',
    'Warehouse',
    'Processing Unit',
    'Field',
  ];

  late AnimationController _animController;
  late CurvedAnimation _fadeAnim;
  String _searchQuery = '';
  bool _loading = true;
  bool _submitting = false;
  final ApiService _api = ApiService();
  /// Settings rate per category for the current labourer (takes priority).
  Map<String, double> _ratesForLabourer = {};
  /// Latest historically entered rate per category, used as a fallback
  /// when no settings rate exists for that category.
  Map<String, double> _latestRatesForLabourer = {};
  /// Name suggestions shown below the Name field while typing.
  List<String> _nameSuggestions = [];
  /// Gender remembered per suggested name (from last history row).
  Map<String, String> _nameSuggestionGenders = {};
  bool _suppressSuggestions = false;
  Timer? _rateLookupDebounce;
  bool _suppressIdentityListener = false;
  bool _identityRebuildScheduled = false;

  bool get _isContract => _selectedWorkType == 'Contract';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _nameController.addListener(_onLabourerIdentityChanged);
    _mobileController.addListener(_onLabourerIdentityChanged);
    _applyShiftDefaultDays(_selectedShift);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapLogin());
  }

  Future<void> _bootstrapLogin() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _loadLabors();
    await _loadCategories();
  }

  /// Default days/hour by shift: fullday=1, morning=0.5, evening=0.5, night=1.
  void _applyShiftDefaultDays(String shift) {
    final v = switch (shift) {
      'morning' || 'evening' => '0.5',
      'night' || 'fullday' => '1',
      _ => '1',
    };
    _daysHourController.text = v;
  }

  @override
  void dispose() {
    _rateLookupDebounce?.cancel();
    _nameController.removeListener(_onLabourerIdentityChanged);
    _mobileController.removeListener(_onLabourerIdentityChanged);
    _fadeAnim.dispose();
    _animController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _daysHourController.dispose();
    _rateController.dispose();
    _labourHeadController.dispose();
    _narrationController.dispose();
    _paidAmountController.dispose();
    _paymentAmountController.dispose();
    _obPayableController.dispose();
    _obPaymentController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await loadLaborCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      if (!_categories.contains(_selectedCategory) && _categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });
  }

  void _onLabourerIdentityChanged() {
    if (_suppressIdentityListener || !mounted) return;

    // Avoid nested setState while Add/Save is already rebuilding the tree.
    if (!_identityRebuildScheduled) {
      _identityRebuildScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _identityRebuildScheduled = false;
        if (mounted) setState(() {});
      });
    }

    _suppressSuggestions = false;
    _rateLookupDebounce?.cancel();
    final mobile = _mobileController.text.trim();
    final name = _nameController.text.trim();
    if (mobile.length == 10) {
      _rateLookupDebounce = Timer(const Duration(milliseconds: 350), () {
        _loadRatesForLabourer(mobile: mobile, name: name);
      });
      return;
    }
    if (name.length < 2) {
      _ratesForLabourer = {};
      _latestRatesForLabourer = {};
      _nameSuggestions = [];
      _nameSuggestionGenders = {};
      _labourBalance = null;
      _labourPayable = null;
      _labourReceivable = null;
      return;
    }
    _rateLookupDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadRatesForLabourer(name: name);
    });
  }

  void _clearLabourerIdentityFields() {
    _suppressIdentityListener = true;
    _nameController.clear();
    _mobileController.clear();
    _suppressIdentityListener = false;
    _addressController.clear();
    _ratesForLabourer = {};
    _latestRatesForLabourer = {};
    _nameSuggestions = [];
    _nameSuggestionGenders = {};
    _suppressSuggestions = false;
    _labourBalance = null;
    _labourPayable = null;
    _labourReceivable = null;
  }

  void _resetLabourEntryForm() {
    stopVoiceAndClearFields([
      _nameController,
      _mobileController,
      _addressController,
      _daysHourController,
      _rateController,
      _labourHeadController,
      _narrationController,
      _paidAmountController,
      _paymentAmountController,
      _obPayableController,
      _obPaymentController,
    ]);
    _clearLabourerIdentityFields();
    setState(() {
      _pending.clear();
      _selectedDate = DateTime.now();
      _selectedWorkType = 'Daily Wages';
      _selectedLocation = 'Farm';
      _selectedShift = 'fullday';
      _selectedGender = 'Male';
      _selectedCategory =
          _categories.isNotEmpty ? _categories.first : 'Plucking';
      _searchQuery = '';
      _extraRent = 0;
      _extraFood = 0;
      _extraBonus = 0;
      _applyShiftDefaultDays('fullday');
    });
  }

  Future<void> _refreshLabourBalance({String? mobile, String? name}) async {
    final m = (mobile ?? _mobileController.text).trim();
    final n = (name ?? _nameController.text).trim();
    if (m.isEmpty && n.length < 2) {
      if (mounted) {
        setState(() {
          _labourBalance = null;
          _labourPayable = null;
          _labourReceivable = null;
        });
      }
      return;
    }
    final bal = await _api.fetchLaborBalance(
      mobile: m.isNotEmpty ? m : null,
      name: m.isEmpty ? n : null,
    );
    if (!mounted) return;
    setState(() {
      if (bal == null) {
        _labourBalance = null;
        _labourPayable = null;
        _labourReceivable = null;
      } else {
        _labourBalance = (bal['balance'] is num)
            ? (bal['balance'] as num).toDouble()
            : double.tryParse('${bal['balance']}');
        _labourPayable = (bal['payable'] is num)
            ? (bal['payable'] as num).toDouble()
            : double.tryParse('${bal['payable']}');
        _labourReceivable = (bal['receivable'] is num)
            ? (bal['receivable'] as num).toDouble()
            : double.tryParse('${bal['receivable']}');
      }
    });
  }

  /// Loads both the "settings" rate (explicit per-labourer rate, set via the
  /// rate popup) and the "latest" historically entered rate per category for
  /// the labourer identified by [mobile] and/or [name]. Settings rates take
  /// priority; latest entered rate is the fallback (requirement: settings
  /// rate OR latest entered rate). Also refreshes name suggestions.
  Future<void> _loadRatesForLabourer({String? mobile, String? name}) async {
    final byMobile = mobile != null && mobile.isNotEmpty;
    final results = await Future.wait([
      _api.fetchLaborRates(mobile: mobile, name: byMobile ? null : name),
      _api.fetchLabors(
        mobile: mobile,
        name: byMobile ? null : name,
        limit: 30,
      ),
    ]);
    if (!mounted) return;

    final settingsRows = results[0];
    final historyRows = results[1];

    final settingsMap = <String, double>{};
    for (final r in settingsRows) {
      final cat = r['category']?.toString() ?? '';
      final rate = r['rate'];
      final value = rate is num
          ? rate.toDouble()
          : double.tryParse(rate?.toString() ?? '');
      if (cat.isNotEmpty && value != null && value > 0) {
        settingsMap[cat] = value;
      }
    }

    final latestMap = <String, double>{};
    final suggestions = <String>{};
    final suggestionGender = <String, String>{};
    final query = (name ?? '').trim().toLowerCase();
    String? lastGender;
    for (final r in historyRows) {
      final rowName = r['name']?.toString().trim() ?? '';
      final rowGender = r['gender']?.toString().trim() ?? '';
      final exactNameMatch =
          query.isNotEmpty && rowName.toLowerCase() == query;

      final cat = r['category']?.toString() ?? '';
      final kind = (r['entry_kind']?.toString() ?? 'payable').toLowerCase();
      // Prefer rates from work rows (not payment / opening / tally).
      if (cat.isNotEmpty &&
          !latestMap.containsKey(cat) &&
          (kind == 'payable')) {
        final wage = r['wage'];
        final value = wage is num
            ? wage.toDouble()
            : double.tryParse(wage?.toString() ?? '');
        if (value != null && value > 0) latestMap[cat] = value;
      }

      // Gender from most recent matching transaction (prefer exact name).
      if (lastGender == null &&
          (rowGender == 'Male' || rowGender == 'Female') &&
          (exactNameMatch || byMobile || query.isEmpty)) {
        lastGender = rowGender;
      } else if (lastGender == null &&
          (rowGender == 'Male' || rowGender == 'Female') &&
          !byMobile &&
          query.isNotEmpty &&
          rowName.toLowerCase().startsWith(query)) {
        // While typing, take gender from closest name prefix match.
        lastGender = rowGender;
      }

      if (!byMobile && rowName.isNotEmpty && rowName.toLowerCase() != query) {
        suggestions.add(rowName);
        if ((rowGender == 'Male' || rowGender == 'Female') &&
            !suggestionGender.containsKey(rowName)) {
          suggestionGender[rowName] = rowGender;
        }
      }
    }

    // If searching by mobile, fall back to first history gender.
    // For name search, only use exact/prefix matches above (avoid ILIKE noise).
    if (lastGender == null && byMobile) {
      for (final r in historyRows) {
        final g = r['gender']?.toString().trim() ?? '';
        if (g == 'Male' || g == 'Female') {
          lastGender = g;
          break;
        }
      }
    }

    setState(() {
      _ratesForLabourer = settingsMap;
      _latestRatesForLabourer = latestMap;
      _nameSuggestionGenders = suggestionGender;
      if (lastGender != null) {
        _selectedGender = lastGender;
      }
      if (!_suppressSuggestions) {
        final list = suggestions.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _nameSuggestions = list.take(5).toList();
      }
    });
    _applyRateForSelectedCategory();
    await _refreshLabourBalance(mobile: mobile, name: name);
  }

  void _applyRateForSelectedCategory() {
    final rate =
        _ratesForLabourer[_selectedCategory] ?? _latestRatesForLabourer[_selectedCategory];
    if (rate == null || rate <= 0) return;
    _rateController.text = rate.toStringAsFixed(0);
  }

  /// Fills the name field with a picked suggestion, then restores any saved
  /// mobile/address and loads rates + gender for that labourer.
  Future<void> _selectNameSuggestion(String name) async {
    _suppressIdentityListener = true;
    _nameController.text = name;
    _nameController.selection = TextSelection.collapsed(offset: name.length);
    _suppressIdentityListener = false;

    final knownGender = _nameSuggestionGenders[name];
    setState(() {
      _nameSuggestions = [];
      _suppressSuggestions = true;
      if (knownGender == 'Male' || knownGender == 'Female') {
        _selectedGender = knownGender!;
      }
    });
    FocusManager.instance.primaryFocus?.unfocus();

    final savedMobile = await loadLaborMobile(name);
    final savedAddress = await loadLaborAddress(name);
    if (!mounted) return;
    _suppressIdentityListener = true;
    _mobileController.text = savedMobile ?? '';
    _suppressIdentityListener = false;
    setState(() => _addressController.text = savedAddress ?? '');

    await _loadRatesForLabourer(
      mobile: (savedMobile != null && savedMobile.length == 10)
          ? savedMobile
          : null,
      name: name,
    );
  }

  Future<void> _loadLabors() async {
    setState(() => _loading = true);
    // Only the latest entries are shown below the entry form; use History
    // for the full list.
    final rows = await _api.fetchLabors(limit: 5);
    if (!mounted) return;
    setState(() {
      _laborers
        ..clear()
        ..addAll(rows.map(Laborer.fromJson));
      for (final labor in _laborers) {
        if (labor.location.isNotEmpty && !_locations.contains(labor.location)) {
          _locations.add(labor.location);
        }
      }
      _loading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.expense : AppColors.primary,
      ),
    );
  }

  Future<void> _showExtrasPopup() async {
    final rentCtrl =
        TextEditingController(text: _extraRent > 0 ? _extraRent.toStringAsFixed(0) : '');
    final foodCtrl =
        TextEditingController(text: _extraFood > 0 ? _extraFood.toStringAsFixed(0) : '');
    final bonusCtrl =
        TextEditingController(text: _extraBonus > 0 ? _extraBonus.toStringAsFixed(0) : '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('Others (Rent / Food / Bonus)')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppField(
              controller: rentCtrl,
              label: tr('Rent'),
              icon: Icons.home_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              required: false,
            ),
            const SizedBox(height: 10),
            AppField(
              controller: foodCtrl,
              label: tr('Food'),
              icon: Icons.restaurant_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              required: false,
            ),
            const SizedBox(height: 10),
            AppField(
              controller: bonusCtrl,
              label: tr('Bonus'),
              icon: Icons.card_giftcard_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              required: false,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Apply'))),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rentCtrl.dispose();
      foodCtrl.dispose();
      bonusCtrl.dispose();
    });
    if (ok == true && mounted) {
      setState(() {
        _extraRent = double.tryParse(rentCtrl.text.trim()) ?? 0;
        _extraFood = double.tryParse(foodCtrl.text.trim()) ?? 0;
        _extraBonus = double.tryParse(bonusCtrl.text.trim()) ?? 0;
      });
    }
  }

  Future<void> _showLaborRatesPopup() async {
    final mobile = _mobileController.text.trim();
    final name = _nameController.text.trim();
    if (mobile.isEmpty && name.isEmpty) {
      _showSnack('Enter labourer name or mobile first', error: true);
      return;
    }

    final existing = await _api.fetchLaborRates(
      mobile: mobile.isEmpty ? null : mobile,
      name: mobile.isEmpty ? name : null,
    );
    if (!mounted) return;

    final controllers = <String, TextEditingController>{};
    for (final cat in _categories) {
      String rateVal = '';
      for (final r in existing) {
        if (r['category']?.toString() == cat) {
          final raw = r['rate'];
          rateVal = raw is num
              ? raw.toStringAsFixed(0)
              : (raw?.toString() ?? '');
          break;
        }
      }
      if (rateVal.isEmpty && _ratesForLabourer[cat] != null) {
        rateVal = _ratesForLabourer[cat]!.toStringAsFixed(0);
      }
      controllers[cat] = TextEditingController(text: rateVal);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  tr('Labour Rates'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Edit rates for this labourer. Tap category to apply to Rate field.'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              final rate = double.tryParse(
                                  controllers[cat]!.text.trim());
                              setState(() => _selectedCategory = cat);
                              if (rate != null && rate > 0) {
                                _rateController.text = rate.toStringAsFixed(0);
                              }
                              Navigator.pop(ctx);
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tr(cat),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDeep,
                                    ),
                                  ),
                                ),
                                Icon(Icons.check_circle_outline,
                                    size: 14, color: Colors.green.shade700),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextField(
                            controller: controllers[cat],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              prefixText: '₹ ',
                              hintText: tr('Rate'),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(ctx);
              },
              child: Text(tr('Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final rates = <String, double>{};
                for (final cat in _categories) {
                  final v = double.tryParse(controllers[cat]!.text.trim());
                  if (v != null && v >= 0) rates[cat] = v;
                }
                if (rates.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final ok = await _api.saveLaborRates(
                  mobile: mobile.isEmpty ? null : mobile,
                  name: name.isEmpty ? null : name,
                  rates: rates,
                );
                if (ok) {
                  setState(() => _ratesForLabourer = rates);
                  _applyRateForSelectedCategory();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        ok ? 'Labour rates saved' : 'Failed to save rates'),
                    backgroundColor: ok ? AppColors.primary : Colors.red,
                  ),
                );
              },
              child: Text(tr('Save Rates')),
            ),
          ],
        );
      },
    );

    // Dispose after the dialog route finishes removing (avoids TextField
    // using a disposed controller during the close animation).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  Future<void> _addLocation() async {
    // Unfocus form fields so the soft keyboard does not sit on top of
    // dialog actions (common cause of "Cancel/Add do nothing" on phones).
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _AddLocationDialog(),
    );
    if (!mounted || result == null) return;
    if (result.isEmpty) {
      _showSnack('Enter a location name', error: true);
      return;
    }
    setState(() {
      if (!_locations.contains(result)) {
        _locations.add(result);
      }
      _selectedLocation = result;
    });
    _showSnack('Location "$result" added');
  }

  Future<void> _addCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _AddCategoryDialog(),
    );
    if (!mounted || result == null) return;
    if (result.isEmpty) {
      _showSnack(tr('Enter a category name'), error: true);
      return;
    }
    final updated = await addCustomLaborCategory(result);
    if (!mounted) return;
    final match = updated.firstWhere(
      (c) => c.toLowerCase() == result.toLowerCase(),
      orElse: () => result,
    );
    setState(() {
      _categories = updated;
      _selectedCategory = match;
    });
    _applyRateForSelectedCategory();
    _showSnack(trf('Category "{0}" added', [match]));
  }

  Future<void> _showCategorySearchDialog() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _CategorySearchDialog(categories: _categories),
    );
    if (selected != null && mounted) {
      setState(() => _selectedCategory = selected);
      _applyRateForSelectedCategory();
    }
  }

  Future<void> _showAdditionalInfoDialog() async {
    final name = _nameController.text.trim();
    final mobileCtrl = TextEditingController(text: _mobileController.text.trim());
    final addressCtrl = TextEditingController(text: _addressController.text);

    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Additional information')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: tr('Mobile'),
                  filled: true,
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Address'),
                  filled: true,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx, false);
            },
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final m = mobileCtrl.text.trim();
              if (m.isNotEmpty && m.length != 10) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(tr('Mobile must be 10 digits')),
                    backgroundColor: AppColors.expense,
                  ),
                );
                return;
              }
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx, true);
            },
            child: Text(tr('Save')),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final mobile = mobileCtrl.text.trim();
      final address = addressCtrl.text.trim();
      _suppressIdentityListener = true;
      _mobileController.text = mobile;
      _suppressIdentityListener = false;
      setState(() => _addressController.text = address);
      if (name.isNotEmpty) {
        await saveLaborMobile(name, mobile);
        await saveLaborAddress(name, address);
      }
      if (mobile.length == 10) {
        _loadRatesForLabourer(mobile: mobile, name: name);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mobileCtrl.dispose();
      addressCtrl.dispose();
    });
  }

  Future<void> _addPendingLabour() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final daysHourText = _daysHourController.text.trim();
    final rateText = _rateController.text.trim();

    if (name.isEmpty) {
      _showSnack('Enter labourer name', error: true);
      return;
    }
    if (mobile.isNotEmpty && mobile.length != 10) {
      _showSnack('Mobile must be 10 digits', error: true);
      return;
    }
    final daysHour = double.tryParse(daysHourText);
    final rate = double.tryParse(rateText);
    if (daysHour == null || daysHour <= 0) {
      _showSnack('Enter valid days/hour', error: true);
      return;
    }
    if (rate == null || rate <= 0) {
      _showSnack('Enter valid rate', error: true);
      return;
    }

    setState(() {
      _pending.add(_PendingLabour(
        name: name,
        mobile: mobile.isEmpty ? null : mobile,
        shift: _selectedShift,
        daysHour: daysHour,
        gender: _selectedGender,
        rate: rate,
        category: _selectedCategory,
        rent: _extraRent,
        food: _extraFood,
        bonus: _extraBonus,
      ));
      _extraRent = 0;
      _extraFood = 0;
      _extraBonus = 0;
    });
    // Remember mobile/address for this name so autocomplete can restore it.
    if (mobile.isNotEmpty) saveLaborMobile(name, mobile);
    if (_addressController.text.trim().isNotEmpty) {
      saveLaborAddress(name, _addressController.text.trim());
    }
    // Clear after setState so listeners cannot nest rebuilds.
    _clearLabourerIdentityFields();
    if (mounted) setState(() {});
  }

  Future<void> _removePending(int index) async {
    final ok = await _confirmDelete(
      title: tr('Remove labourer?'),
      message: 'Remove this labourer from the pending list?',
    );
    if (ok != true || !mounted) return;
    setState(() => _pending.removeAt(index));
  }

  Future<void> _submitPayment() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final amount = double.tryParse(_paymentAmountController.text.trim());
    final narration = _narrationController.text.trim();

    if (name.isEmpty) {
      _showSnack(tr('Enter labourer name'), error: true);
      return;
    }
    if (mobile.isNotEmpty && mobile.length != 10) {
      _showSnack(tr('Mobile must be 10 digits'), error: true);
      return;
    }
    if (amount == null || amount <= 0) {
      _showSnack(tr('Enter valid amount'), error: true);
      return;
    }

    var token = await getValidAuthToken();
    if (token == null || token.isEmpty) {
      final ok = await _promptLoginForSave();
      if (ok != true) return;
      token = await getValidAuthToken();
      if (token == null || token.isEmpty) {
        _showSnack(tr('Login required to save labour'), error: true);
        return;
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      if (mobile.isNotEmpty) 'mobile': mobile,
      'wage': amount,
      'hours': 1,
      'number_of_labours': 1,
      'entry_kind': 'payment',
      'shift': 'fullday',
      'category': 'Payment',
      'gender': _selectedGender,
      'work_type': 'Daily Wages',
      'location': _selectedLocation ?? 'Farm',
      'narration': narration.isNotEmpty ? narration : tr('Payment'),
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
    };

    setState(() => _submitting = true);
    var result = await _api.createLabor(payload);
    if (!mounted) return;
    if (result['success'] != true && _isAuthFailure(result)) {
      setState(() => _submitting = false);
      final ok = await _promptLoginForSave();
      if (ok == true && mounted) {
        setState(() => _submitting = true);
        result = await _api.createLabor(payload);
        if (!mounted) return;
      }
    }
    setState(() => _submitting = false);

    if (result['success'] != true) {
      final msg = result['message']?.toString() ?? tr('Failed to save payment');
      if (_isAuthFailure(result)) {
        await _showJwtExpiredDialog(msg);
      } else {
        _showSnack(msg, error: true);
      }
      return;
    }

    _resetLabourEntryForm();
    await _loadLabors();
    _showSnack(tr('Payment saved'));
  }

  Future<void> _submitLabours() async {
    if (_entryMode == 'Payment') {
      await _submitPayment();
      return;
    }
    if (_entryMode == 'Tally') {
      await _submitTally();
      return;
    }

    final narration = _narrationController.text.trim();
    final labourHead = _labourHeadController.text.trim();

    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      _showSnack(tr('Please select a location'), error: true);
      return;
    }
    if (_isContract && labourHead.isEmpty) {
      _showSnack(tr('Labour head is required for Contract'), error: true);
      return;
    }
    // Direct save: if fields are filled but user forgot "Add", queue them.
    if (_pending.isEmpty && _nameController.text.trim().isNotEmpty) {
      final before = _pending.length;
      await _addPendingLabour();
      if (_pending.length == before) {
        // Validation inside _addPendingLabour already showed a snack.
        return;
      }
    }
    if (_pending.isEmpty) {
      _showSnack(tr('Add at least one labourer'), error: true);
      return;
    }

    // Saving requires a valid login — guest browse is allowed, write is not.
    var token = await getValidAuthToken();
    if (token == null || token.isEmpty) {
      final ok = await _promptLoginForSave();
      if (ok != true) return;
      token = await getValidAuthToken();
      if (token == null || token.isEmpty) {
        _showSnack(tr('Login required to save labour'), error: true);
        return;
      }
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final partialPaid = double.tryParse(_paidAmountController.text.trim());
    final payloads = <Map<String, dynamic>>[];
    for (var i = 0; i < _pending.length; i++) {
      final row = _pending[i];
      final map = <String, dynamic>{
        'name': row.name,
        'wage': row.rate,
        'hours': row.daysHour,
        'number_of_labours': 1,
        'shift': row.shift,
        'category': row.category,
        'gender': row.gender,
        'work_type': _selectedWorkType,
        'labour_head': _isContract ? labourHead : '',
        'location': _selectedLocation,
        'narration': narration,
        'date': dateStr,
        'entry_kind':
            row.category == 'Opening Balance' ? 'opening' : 'payable',
        if (row.mobile != null && row.mobile!.isNotEmpty) 'mobile': row.mobile,
        if (row.rent > 0) 'rent': row.rent,
        if (row.food > 0) 'food': row.food,
        if (row.bonus > 0) 'bonus': row.bonus,
      };
      if (partialPaid != null && partialPaid > 0 && i == 0) {
        map['paid_amount'] = partialPaid;
      }
      payloads.add(map);
    }

    setState(() => _submitting = true);
    var result = await _api.createLaborsBatch(payloads);
    if (!mounted) return;

    // Retry once after re-login if JWT was rejected.
    if (result['success'] != true && _isAuthFailure(result)) {
      setState(() => _submitting = false);
      final ok = await _promptLoginForSave();
      if (ok == true && mounted) {
        setState(() => _submitting = true);
        result = await _api.createLaborsBatch(payloads);
        if (!mounted) return;
      }
    }

    setState(() => _submitting = false);

    if (result['success'] != true) {
      final msg = result['message']?.toString() ?? tr('Failed to add labourers');
      if (_isAuthFailure(result)) {
        await _showJwtExpiredDialog(msg);
      } else {
        _showSnack(msg, error: true);
      }
      return;
    }

    final data = result['data'];
    final createdCount = data is List ? data.length : _pending.length;

    _resetLabourEntryForm();

    await _loadLabors();

    _showSnack(
        createdCount == 1
            ? tr('Laborer added successfully')
            : trf('{0} labourers added successfully', [createdCount]));
  }

  Future<void> _submitTally() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final narration = _narrationController.text.trim();
    final payable = double.tryParse(_obPayableController.text.trim()) ?? 0;
    final payment = double.tryParse(_obPaymentController.text.trim()) ?? 0;

    if (name.isEmpty) {
      _showSnack(tr('Enter labourer name'), error: true);
      return;
    }
    if (payable < 0 || payment < 0) {
      _showSnack(tr('Amount cannot be negative'), error: true);
      return;
    }
    if (narration.isEmpty) {
      _showSnack(tr('Enter narration'), error: true);
      return;
    }
    if (mobile.isNotEmpty && mobile.length != 10) {
      _showSnack(tr('Mobile must be 10 digits'), error: true);
      return;
    }

    var token = await getValidAuthToken();
    if (token == null || token.isEmpty) {
      final ok = await _promptLoginForSave();
      if (ok != true) return;
      token = await getValidAuthToken();
      if (token == null || token.isEmpty) {
        _showSnack(tr('Login required to save labour'), error: true);
        return;
      }
    }

    final net = payable - payment;
    final isTally = net == 0;
    final payload = <String, dynamic>{
      'name': name,
      if (mobile.isNotEmpty) 'mobile': mobile,
      'wage': isTally ? 0 : net,
      'hours': 1,
      'number_of_labours': 1,
      'entry_kind': isTally ? 'tally' : 'opening',
      'shift': 'fullday',
      'category': isTally ? 'Tally' : 'Opening Balance',
      'gender': _selectedGender,
      'work_type': 'Daily Wages',
      'location': _selectedLocation ?? 'Farm',
      'narration': narration,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
    };

    setState(() => _submitting = true);
    var result = await _api.createLabor(payload);
    if (!mounted) return;
    if (result['success'] != true && _isAuthFailure(result)) {
      setState(() => _submitting = false);
      final ok = await _promptLoginForSave();
      if (ok == true && mounted) {
        setState(() => _submitting = true);
        result = await _api.createLabor(payload);
        if (!mounted) return;
      }
    }
    setState(() => _submitting = false);

    if (result['success'] != true) {
      final msg =
          result['message']?.toString() ?? tr('Failed to save OB/Tally');
      if (_isAuthFailure(result)) {
        await _showJwtExpiredDialog(msg);
      } else {
        _showSnack(msg, error: true);
      }
      return;
    }

    _resetLabourEntryForm();
    await _loadLabors();
    _showSnack(
      isTally ? tr('Tally marked — account restarts at 0') : tr('Opening saved — account restarts from this date'),
    );
  }

  bool _isAuthFailure(Map<String, dynamic> result) {
    final code = result['statusCode'];
    if (code == 401) return true;
    final msg = (result['message']?.toString() ?? '').toLowerCase();
    return msg.contains('jwt') ||
        msg.contains('unauthorized') ||
        msg.contains('login required') ||
        msg.contains('missing or malformed');
  }

  Future<bool?> _promptLoginForSave() async {
    if (!mounted) return false;
    return ensureLoggedIn(context, force: true);
  }

  Future<void> _showJwtExpiredDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Icon(
              Icons.lock_clock_rounded,
              size: 72,
              color: AppColors.expense.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Session expired'),
              textAlign: TextAlign.center,
              style: AppText.h3,
            ),
            const SizedBox(height: 8),
            Text(
              message.isNotEmpty
                  ? message
                  : tr('Invalid or expired JWT. Please login again to continue.'),
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _promptLoginForSave();
            },
            child: Text(tr('Login')),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _removeLaborer(int index) async {
    if (index < 0 || index >= _laborers.length) return;
    final laborer = _laborers[index];
    final ok = await _confirmDelete(
      title: tr('Delete labour entry?'),
      message:
          'Delete ${laborer.name.isEmpty ? 'this entry' : laborer.name}? This cannot be undone.',
    );
    if (ok != true || !mounted) return;
    if (laborer.id != null) {
      final deleted = await _api.deleteLabor(laborer.id!);
      if (!deleted) {
        _showSnack('Failed to delete laborer', error: true);
        return;
      }
    }
    setState(() => _laborers.removeAt(index));
    _showSnack('Labour entry deleted');
  }

  Future<void> _openLaborDetail(Laborer laborer) async {
    if (laborer.id == null) {
      _showSnack('Save this entry before viewing details', error: true);
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LaborDetailSheet(
        laborer: laborer,
        workTypes: _workTypes,
        shifts: _shifts,
        genders: _genders,
        categories: _categories,
        locations: List<String>.from(_locations),
        onUpdate: (payload) => _api.updateLabor(laborer.id!, payload),
        onDelete: () => _api.deleteLabor(laborer.id!),
      ),
    );
    if (!mounted) return;
    if (result == 'updated' || result == 'deleted') {
      await _loadLabors();
      if (result == 'deleted' && mounted) {
        _showSnack('Labour entry deleted');
      }
    }
  }

  double get _totalLaborCost {
    return _filteredLaborers.fold(
      0.0,
      (sum, l) => sum + (l.isTally || l.isOpening ? 0.0 : l.totalCost),
    );
  }

  List<Laborer> get _filteredLaborers {
    if (_searchQuery.isEmpty) return _laborers;
    final q = _searchQuery.toLowerCase();
    return _laborers
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.narration.toLowerCase().contains(q) ||
            l.location.toLowerCase().contains(q) ||
            l.labourHead.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              AppHeader(
                title: tr('Labour Management'),
                subtitle: tr('Daily wages & contract labour'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: tr('Update Labour Rate'),
                      icon: const Icon(Icons.currency_exchange_rounded),
                      color: AppColors.primaryDeep,
                      onPressed: () => showUpdateLabourRateDialog(context),
                    ),
                    ...withFeedbackAction(
                      context,
                      menu: 'labour',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          children: [
                            _buildLabourSummaryButton(),
                            SizedBox(height: 12),
                            _buildAddFormCard(),
                            SizedBox(height: 14),
                            _buildSummaryCard(),
                            SizedBox(height: 14),
                            _buildLaborerList(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabourSummaryButton() {
    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: tr('Summary'),
            icon: Icons.badge_rounded,
            color: AppColors.info,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LabourSummaryPage()),
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: SecondaryButton(
            label: tr('History'),
            icon: Icons.history_rounded,
            color: AppColors.accent,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LaborHistoryPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryModeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeTab(
              'Payable',
              Icons.person_add_alt_1_rounded,
              tr('Labour Entry'),
            ),
          ),
          Expanded(
            child: _modeTab(
              'Payment',
              Icons.payments_rounded,
              tr('Payment'),
            ),
          ),
          Expanded(
            child: _modeTab(
              'Tally',
              Icons.fact_check_rounded,
              tr('OB/Tally'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(String value, IconData icon, String label) {
    final selected = _entryMode == value;
    return GestureDetector(
      onTap: () => setState(() {
        _entryMode = value;
        if (_entryMode == 'Payment' || _entryMode == 'Tally') {
          _pending.clear();
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: AppColors.buttonGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObTallyHint() {
    final payable = double.tryParse(_obPayableController.text.trim()) ?? 0;
    final payment = double.tryParse(_obPaymentController.text.trim()) ?? 0;
    final net = payable - payment;
    final String msg;
    if (net == 0) {
      msg = tr('Tally — account restarts at 0 from this date');
    } else if (net > 0) {
      msg = '${tr('Payable opening')} ₹${net.toStringAsFixed(net == net.roundToDouble() ? 0 : 2)} — ${tr('account restarts from this date')}';
    } else {
      msg = '${tr('Payment opening')} ₹${(-net).toStringAsFixed(net == net.roundToDouble() ? 0 : 2)} — ${tr('account restarts from this date')}';
    }
    return Text(
      msg,
      style: AppText.caption.copyWith(
        color: net == 0
            ? AppColors.info
            : (net > 0 ? AppColors.income : AppColors.expense),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAddFormCard() {
    final isPayment = _entryMode == 'Payment';
    final isTally = _entryMode == 'Tally';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _compactDateField(),
          SizedBox(height: 12),
          _buildEntryModeTabs(),
          if (isTally) ...[
            SizedBox(height: 14),
            SectionTitle(
              icon: Icons.fact_check_rounded,
              title: tr('OB/Tally'),
              subtitle: tr(
                'Both 0 = tally (settled). Any amount starts a new balance from this date.',
              ),
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _nameController,
                    label: tr('Name'),
                    icon: Icons.person_rounded,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_name_tally',
                  controller: _nameController,
                ),
              ],
            ),
            if (_nameSuggestions.isNotEmpty) ...[
              SizedBox(height: 6),
              _buildNameSuggestions(),
            ],
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppField(
                    controller: _obPayableController,
                    label: tr('Payable'),
                    hint: tr('We still owe them'),
                    icon: Icons.trending_up_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: AppField(
                    controller: _obPaymentController,
                    label: tr('Payment'),
                    hint: tr('Extra already paid'),
                    icon: Icons.trending_down_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            _buildObTallyHint(),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _narrationController,
                    label: tr('Narration'),
                    icon: Icons.description_rounded,
                    minLines: 3,
                    maxLines: 8,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_tally_narration',
                  controller: _narrationController,
                ),
              ],
            ),
            SizedBox(height: 14),
            PrimaryButton(
              label: _submitting ? tr('Saving…') : tr('Save OB/Tally'),
              icon: Icons.save_rounded,
              onPressed: _submitting ? null : _submitLabours,
              loading: _submitting,
            ),
          ] else if (isPayment) ...[
            SizedBox(height: 14),
            SectionTitle(
              icon: Icons.payments_rounded,
              title: tr('Payment details'),
              subtitle: tr('Pay against labour balance'),
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _nameController,
                    label: tr('Name'),
                    icon: Icons.person_rounded,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_name_pay',
                  controller: _nameController,
                ),
              ],
            ),
            if (_nameSuggestions.isNotEmpty) ...[
              SizedBox(height: 6),
              _buildNameSuggestions(),
            ],
            if (_labourBalance != null ||
                _nameController.text.trim().length >= 2) ...[
              SizedBox(height: 8),
              _buildBalanceChip(),
            ],
            SizedBox(height: 10),
            AppField(
              controller: _paymentAmountController,
              label: tr('Payment'),
              icon: Icons.currency_rupee_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _narrationController,
                    label: tr('Narration (optional)'),
                    icon: Icons.description_rounded,
                    minLines: 3,
                    maxLines: 8,
                    required: false,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_narration_pay',
                  controller: _narrationController,
                ),
              ],
            ),
            SizedBox(height: 14),
            PrimaryButton(
              label: _submitting ? tr('Saving…') : tr('Save Payment'),
              icon: Icons.save_rounded,
              onPressed: _submitting ? null : _submitLabours,
              loading: _submitting,
            ),
          ] else ...[
            SizedBox(height: 10),
            AppDropdown(
              label: 'Work Type',
              value: _selectedWorkType,
              items: _workTypes,
              icon: Icons.work_outline_rounded,
              onChanged: (v) => setState(() {
                _selectedWorkType = v ?? 'Daily Wages';
                if (!_isContract) _labourHeadController.clear();
              }),
            ),
            if (_isContract) ...[
              SizedBox(height: 10),
              AppField(
                controller: _labourHeadController,
                label: 'Labour Head',
                icon: Icons.supervisor_account_rounded,
              ),
            ],
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppDropdown(
                    label: 'Location',
                    value: _selectedLocation,
                    items: _locations,
                    icon: Icons.location_on_rounded,
                    onChanged: (v) => setState(() => _selectedLocation = v),
                  ),
                ),
                SizedBox(width: 10),
                _addLocationButton(),
              ],
            ),
            SizedBox(height: 16),
            SectionTitle(
              icon: Icons.badge_outlined,
              title: tr('Labourer details'),
              subtitle: tr('Add one labourer at a time'),
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _nameController,
                    label: 'Name',
                    icon: Icons.person_rounded,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_name',
                  controller: _nameController,
                ),
                SizedBox(width: 4),
                _squareIconButton(
                  icon: Icons.info_outline_rounded,
                  tooltip: tr('Additional information'),
                  onTap: _showAdditionalInfoDialog,
                  color: AppColors.info,
                  background: AppColors.infoSoft,
                ),
              ],
            ),
            if (_nameSuggestions.isNotEmpty) ...[
              SizedBox(height: 6),
              _buildNameSuggestions(),
            ],
            if (_labourBalance != null ||
                _nameController.text.trim().length >= 2) ...[
              SizedBox(height: 8),
              _buildBalanceChip(),
            ],
            SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppDropdown(
                    label: 'Category',
                    value: _selectedCategory,
                    items: _categories,
                    icon: Icons.category_rounded,
                    onChanged: (v) {
                      setState(() => _selectedCategory = v!);
                      _applyRateForSelectedCategory();
                    },
                  ),
                ),
                SizedBox(width: 8),
                _squareIconButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: tr('Category rate settings'),
                  onTap: _showLaborRatesPopup,
                ),
                SizedBox(width: 8),
                _squareIconButton(
                  icon: Icons.search_rounded,
                  tooltip: tr('Search category'),
                  onTap: _showCategorySearchDialog,
                  color: AppColors.info,
                  background: AppColors.infoSoft,
                ),
                SizedBox(width: 8),
                _squareIconButton(
                  icon: Icons.add_rounded,
                  tooltip: tr('Add category'),
                  onTap: _addCategory,
                  color: Colors.white,
                  background: AppColors.primary,
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppDropdown(
                    label: 'Shift',
                    value: _selectedShift,
                    items: _shifts,
                    icon: Icons.wb_sunny_rounded,
                    onChanged: (v) => setState(() {
                      _selectedShift = v ?? 'fullday';
                      _applyShiftDefaultDays(_selectedShift);
                    }),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: AppField(
                    controller: _daysHourController,
                    label: 'Days / Hour',
                    icon: Icons.access_time_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppDropdown(
                    label: 'Gender',
                    value: _selectedGender,
                    items: _genders,
                    icon: Icons.wc_rounded,
                    onChanged: (v) =>
                        setState(() => _selectedGender = v ?? 'Male'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: AppField(
                    controller: _rateController,
                    label: 'Rate',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                _squareIconButton(
                  icon: Icons.add_rounded,
                  tooltip: tr('Rent / Food / Bonus'),
                  onTap: _showExtrasPopup,
                  color: Colors.white,
                  background: AppColors.accent,
                ),
              ],
            ),
            if (_extraRent > 0 || _extraFood > 0 || _extraBonus > 0) ...[
              SizedBox(height: 8),
              Text(
                '${tr('Others')}: ₹${(_extraRent + _extraFood + _extraBonus).toStringAsFixed(0)}'
                ' (${tr('Rent')} ${_extraRent.toStringAsFixed(0)}, '
                '${tr('Food')} ${_extraFood.toStringAsFixed(0)}, '
                '${tr('Bonus')} ${_extraBonus.toStringAsFixed(0)})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
            SizedBox(height: 12),
            PrimaryButton(
              label: tr('Add Labourer'),
              icon: Icons.add_rounded,
              onPressed: _addPendingLabour,
              height: 50,
            ),
            if (_pending.isNotEmpty) ...[
              SizedBox(height: 16),
              SectionTitle(
                icon: Icons.grid_on_rounded,
                title: 'Added labourers (${_pending.length})',
              ),
              SizedBox(height: 10),
              _buildPendingGrid(),
            ],
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _narrationController,
                    label: tr('Narration (optional)'),
                    icon: Icons.description_rounded,
                    minLines: 3,
                    maxLines: 8,
                    required: false,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_narration',
                  controller: _narrationController,
                ),
              ],
            ),
            SizedBox(height: 12),
            AppField(
              controller: _paidAmountController,
              label: tr('Payment'),
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              required: false,
            ),
            SizedBox(height: 14),
            PrimaryButton(
              label: _submitting ? 'Saving…' : 'Save Entry',
              icon: Icons.save_rounded,
              onPressed: _submitting ? null : _submitLabours,
              loading: _submitting,
            ),
          ],
          SizedBox(height: 12),
          SecondaryButton(
            label: tr('Update Labour Rate'),
            icon: Icons.currency_exchange_rounded,
            color: AppColors.expense,
            onPressed: () => showUpdateLabourRateDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    final payable = _labourPayable ?? 0;
    final receivable = _labourReceivable ?? 0;
    final bal = _labourBalance ?? 0;
    final label = receivable > 0
        ? '${tr('Receivable')}: ₹${receivable.toStringAsFixed(0)}'
        : '${tr('Payable')}: ₹${payable > 0 ? payable.toStringAsFixed(0) : bal.toStringAsFixed(0)}';
    if (_labourBalance == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.incomeSoft,
              AppColors.income.withValues(alpha: 0.06),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.income.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 15,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.income,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addLocationButton() {
    return SizedBox(
      width: 56,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.buttonGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _addLocation,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// Compact square icon button used for the row of actions beside the
  /// Name and Category fields (additional info / rate settings / search /
  /// add category).
  Widget _squareIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    String? tooltip,
    Color color = AppColors.primary,
    Color background = const Color(0xFFE8F5E9),
  }) {
    final button = SizedBox(
      height: _fieldHeight,
      width: _fieldHeight,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  /// Dropdown-style list of matching labourer names shown below the Name
  /// field while typing (name autocomplete).
  Widget _buildNameSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.softShadow],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _nameSuggestions.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) {
          final n = _nameSuggestions[i];
          final g = _nameSuggestionGenders[n];
          return InkWell(
            onTap: () => _selectNameSuggestion(n),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n, style: AppText.bodyStrong),
                        if (g != null && g.isNotEmpty)
                          Text(
                            g,
                            style: AppText.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingGrid() {
    return Column(
      children: List.generate(_pending.length, (index) {
        final row = _pending[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.field.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.buttonGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _miniChip(tr(row.shift), AppColors.warning),
                        _miniChip('${row.daysHour}', AppColors.info),
                        _miniChip(tr(row.gender), AppColors.primary),
                        _miniChip(tr(row.category), AppColors.expense),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${row.rate.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${row.totalCost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.income,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.expense,
                ),
                onPressed: () => _removePending(index),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _compactDateField() {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final entries = _filteredLaborers.length;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              Icons.group_rounded,
              '$entries',
              tr('Number of labour'),
              AppColors.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryItem(
              Icons.currency_rupee_rounded,
              '₹${_totalLaborCost.toStringAsFixed(0)}',
              'Total Cost',
              AppColors.income,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryItem(
              Icons.hourglass_bottom_rounded,
              '${_pending.length}',
              'In Queue',
              AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          TintedIcon(
            icon: icon,
            color: color,
            boxSize: 34,
            size: 17,
            radius: 10,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }

  Widget _buildLaborerList() {
    if (_laborers.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.people_alt_outlined,
          title: tr('No labourers saved yet'),
          subtitle: tr('Add your first labour entry above'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_laborers.length > 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [AppColors.softShadow],
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: tr('Search labourers'),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 44,
                  minHeight: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ..._filteredLaborers.asMap().entries.map((entry) {
          final index = _laborers.indexOf(entry.value);
          return _laborerCard(entry.value, index);
        }),
      ],
    );
  }

  Widget _laborerCard(Laborer laborer, int index) {
    final cost = laborer.totalCost;
    final isTally = laborer.isTally;
    final isOpening = laborer.isOpening;
    final isReset = isTally || isOpening;
    final isPayment = laborer.isPayment;
    final resetColor =
        isOpening && cost < 0 ? AppColors.expense : AppColors.info;
    return AppCard(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      radius: 16,
      color: isReset
          ? resetColor.withValues(alpha: 0.08)
          : AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openLaborDetail(laborer),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isReset
                      ? [resetColor, resetColor.withValues(alpha: 0.75)]
                      : AppColors.buttonGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (isReset ? resetColor : AppColors.primary)
                        .withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isReset ? Icons.fact_check_rounded : Icons.person_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    laborer.name,
                    style: AppText.bodyStrong.copyWith(
                      color: isReset ? resetColor : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      if (isTally)
                        _chip(tr('Tally'), AppColors.info)
                      else if (isOpening)
                        _chip(
                          cost < 0 ? tr('Payment') : tr('Payable'),
                          resetColor,
                        )
                      else ...[
                        if (laborer.workType.isNotEmpty)
                          _chip(tr(laborer.workType), AppColors.info),
                        _chip(tr(laborer.shift), AppColors.warning),
                        _chip(tr(laborer.gender), AppColors.primary),
                        if (laborer.category.isNotEmpty)
                          _chip(tr(laborer.category), AppColors.expense),
                      ],
                      if (laborer.location.isNotEmpty)
                        _chip(tr(laborer.location), AppColors.textMuted),
                      if (laborer.othersTotal > 0)
                        _chip(
                          '${tr('Others')} ₹${laborer.othersTotal.toStringAsFixed(0)}',
                          AppColors.accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isTally
                              ? (laborer.narration.isEmpty
                                  ? tr('Tally')
                                  : laborer.narration)
                              : isOpening
                                  ? '₹${cost.abs().toStringAsFixed(0)}'
                                  : isPayment
                                      ? '₹${cost.toStringAsFixed(0)}'
                                      : '₹${laborer.wage.toStringAsFixed(0)} × ${laborer.hours}',
                          style: AppText.small.copyWith(
                            color: isReset ? resetColor : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isReset && !isPayment) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.incomeSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '= ₹${cost.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.income,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(laborer.date),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.info,
                    size: 21,
                  ),
                  tooltip: tr('Labourer schedule'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LabourerDetailPage(
                          name: laborer.name,
                          mobile: laborer.mobile,
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: tr('View / Edit'),
                      onPressed: () => _openLaborDetail(laborer),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.expense,
                        size: 20,
                      ),
                      tooltip: tr('Delete'),
                      onPressed: () => _removeLaborer(index),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

}

/// Dedicated dialog so Cancel/Add keep reliable hit targets above the keyboard
/// and the text controller is disposed with the dialog route (not after pop).
class _AddLocationDialog extends StatefulWidget {
  const _AddLocationDialog();

  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cancel() {
    _focusNode.unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final name = _controller.text.trim();
    _focusNode.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Add Location'), style: AppText.h3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: tr('Location name'),
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancel,
                    child: Text(tr('Cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 44),
                    ),
                    onPressed: _submit,
                    child: Text(tr('Add')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to add a new labour category (persisted via SharedPreferences).
class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cancel() {
    _focusNode.unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final name = _controller.text.trim();
    _focusNode.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Add Category'), style: AppText.h3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: tr('Category name'),
                  prefixIcon: const Icon(Icons.category_rounded),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancel,
                    child: Text(tr('Cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 44),
                    ),
                    onPressed: _submit,
                    child: Text(tr('Add')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to search categories (alphabetical) and select one.
class _CategorySearchDialog extends StatefulWidget {
  final List<String> categories;

  const _CategorySearchDialog({required this.categories});

  @override
  State<_CategorySearchDialog> createState() => _CategorySearchDialogState();
}

class _CategorySearchDialogState extends State<_CategorySearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List<String>.from(widget.categories);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    final q = v.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List<String>.from(widget.categories)
          : widget.categories
              .where((c) => c.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              tr('Search category'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDeep,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: tr('Search category'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        tr('No categories found'),
                        style: AppText.caption,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) {
                        final cat = _filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            tr(cat),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, cat),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaborDetailSheet extends StatefulWidget {
  final Laborer laborer;
  final List<String> workTypes;
  final List<String> shifts;
  final List<String> genders;
  final List<String> categories;
  final List<String> locations;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)
      onUpdate;
  final Future<bool> Function() onDelete;

  const _LaborDetailSheet({
    required this.laborer,
    required this.workTypes,
    required this.shifts,
    required this.genders,
    required this.categories,
    required this.locations,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_LaborDetailSheet> createState() => _LaborDetailSheetState();
}

class _LaborDetailSheetState extends State<_LaborDetailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _labourHeadCtrl;
  late final TextEditingController _narrationCtrl;
  late DateTime _date;
  late String _workType;
  late String _shift;
  late String _gender;
  late String _category;
  late String _location;
  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final l = widget.laborer;
    _nameCtrl = TextEditingController(text: l.name);
    _mobileCtrl = TextEditingController(text: l.mobile ?? '');
    _hoursCtrl = TextEditingController(text: l.hours.toString());
    _rateCtrl = TextEditingController(text: l.wage.toStringAsFixed(0));
    _labourHeadCtrl = TextEditingController(text: l.labourHead);
    _narrationCtrl = TextEditingController(text: l.narration);
    _date = l.date;
    _workType = l.workType.isNotEmpty ? l.workType : 'Daily Wages';
    _shift = l.shift.isNotEmpty ? l.shift : 'fullday';
    _gender = l.gender.isNotEmpty ? l.gender : 'Male';
    _category = l.category;
    _location = l.location.isNotEmpty ? l.location : widget.locations.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _hoursCtrl.dispose();
    _rateCtrl.dispose();
    _labourHeadCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  bool get _isContract => _workType == 'Contract';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final hours = double.tryParse(_hoursCtrl.text.trim());
    final rate = double.tryParse(_rateCtrl.text.trim());
    final narration = _narrationCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Name is required', error: true);
      return;
    }
    if (hours == null || hours <= 0) {
      _toast('Enter valid days/hour', error: true);
      return;
    }
    if (rate == null || rate <= 0) {
      _toast('Enter valid rate', error: true);
      return;
    }
    if (_isContract && _labourHeadCtrl.text.trim().isEmpty) {
      _toast('Labour head is required for Contract', error: true);
      return;
    }

    final payload = <String, dynamic>{
      'name': name,
      'wage': rate,
      'hours': hours,
      'number_of_labours': widget.laborer.numberOfLabours < 1
          ? 1
          : widget.laborer.numberOfLabours,
      'shift': _shift,
      'category': _category,
      'gender': _gender,
      'work_type': _workType,
      'labour_head': _isContract ? _labourHeadCtrl.text.trim() : '',
      'location': _location,
      'narration': narration,
      'date': DateFormat('yyyy-MM-dd').format(_date),
    };
    final mobile = _mobileCtrl.text.trim();
    if (mobile.isNotEmpty) payload['mobile'] = mobile;

    setState(() => _saving = true);
    final result = await widget.onUpdate(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      Navigator.pop(context, 'updated');
    } else {
      _toast(result['message']?.toString() ?? 'Update failed', error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete labour entry?')),
        content: Text(
          'Delete ${widget.laborer.name.isEmpty ? 'this entry' : widget.laborer.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final deleted = await widget.onDelete();
    if (!mounted) return;
    setState(() => _deleting = false);
    if (deleted) {
      Navigator.pop(context, 'deleted');
    } else {
      _toast('Failed to delete', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.expense : AppColors.primary,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(tr(label), style: AppText.small)),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : tr(value),
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'Edit labour entry' : 'Labour entry details',
                    style: AppText.title,
                  ),
                ),
                if (!_editing)
                  IconButton(
                    tooltip: tr('Edit'),
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_rounded,
                        color: AppColors.primary),
                  ),
                IconButton(
                  tooltip: tr('Delete'),
                  onPressed: _deleting ? null : _delete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense
                        .withValues(alpha: _deleting ? 0.4 : 1),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: _editing ? _buildEdit() : _buildView(),
              ),
            ),
            if (_editing) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _editing = false),
                      child: Text(tr('Cancel')),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr('Save')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildView() {
    final l = widget.laborer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('Name', l.name),
        if (l.mobile != null && l.mobile!.isNotEmpty) _row('Mobile', l.mobile!),
        _row('Work type', l.workType),
        _row('Shift', l.shift),
        _row('Gender', l.gender),
        _row('Category', l.category),
        _row('Location', l.location),
        _row('Days / Hour', l.hours.toString()),
        _row('Rate', '₹${l.wage.toStringAsFixed(0)}'),
        _row('Total', '₹${l.totalCost.toStringAsFixed(0)}'),
        _row('Date', DateFormat('dd/MM/yyyy').format(l.date)),
        if (l.labourHead.isNotEmpty) _row('Labour head', l.labourHead),
        _row('Narration', l.narration),
        SizedBox(height: 8),
        Text(
          tr('Tap the edit icon to change this entry.'),
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: tr('Name'), filled: true),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _mobileCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(labelText: tr('Mobile'), filled: true),
        ),
        SizedBox(height: 10),
        AppDropdown(
          label: 'Work Type',
          value: _workType,
          items: widget.workTypes,
          icon: Icons.work_outline_rounded,
          onChanged: (v) => setState(() => _workType = v ?? 'Daily Wages'),
        ),
        if (_isContract) ...[
          SizedBox(height: 10),
          TextField(
            controller: _labourHeadCtrl,
            decoration:
                InputDecoration(labelText: tr('Labour Head'), filled: true),
          ),
        ],
        SizedBox(height: 10),
        AppDropdown(
          label: 'Location',
          value: widget.locations.contains(_location) ? _location : null,
          items: widget.locations,
          icon: Icons.location_on_rounded,
          onChanged: (v) => setState(() => _location = v ?? _location),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppDropdown(
                label: 'Shift',
                value: _shift,
                items: widget.shifts,
                icon: Icons.wb_sunny_rounded,
                onChanged: (v) => setState(() => _shift = v ?? 'fullday'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: AppDropdown(
                label: 'Gender',
                value: _gender,
                items: widget.genders,
                icon: Icons.wc_rounded,
                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        AppDropdown(
          label: 'Category',
          value: widget.categories.contains(_category) ? _category : null,
          items: widget.categories,
          icon: Icons.category_rounded,
          onChanged: (v) {
            if (v != null) setState(() => _category = v);
          },
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hoursCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: tr('Days / Hour'), filled: true),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    InputDecoration(labelText: tr('Rate'), filled: true),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: tr('Date'),
              filled: true,
              prefixIcon: Icon(Icons.event_rounded),
            ),
            child: Text(DateFormat('dd/MM/yyyy').format(_date)),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _narrationCtrl,
          minLines: 3,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: tr('Narration (optional)'),
            filled: true,
          ),
        ),
      ],
    );
  }
}

class Laborer {
  final int? id;
  final String name;
  final String? mobile;
  final double wage;
  final double hours;
  final int numberOfLabours;
  final DateTime date;
  final String shift;
  final String category;
  final String gender;
  final String workType;
  final String labourHead;
  final String location;
  final String narration;
  final String entryKind;
  final double rent;
  final double food;
  final double bonus;

  Laborer({
    this.id,
    required this.name,
    this.mobile,
    required this.wage,
    required this.hours,
    required this.numberOfLabours,
    required this.date,
    required this.shift,
    required this.category,
    this.gender = '',
    this.workType = '',
    this.labourHead = '',
    this.location = '',
    required this.narration,
    this.entryKind = 'payable',
    this.rent = 0,
    this.food = 0,
    this.bonus = 0,
  });

  double get totalCost => wage * hours;
  double get othersTotal => rent + food + bonus;
  bool get isTally => entryKind == 'tally';
  bool get isPayment => entryKind == 'payment';
  bool get isOpening => entryKind == 'opening';

  factory Laborer.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 1;
      return 1;
    }

    final mobileRaw = json['mobile']?.toString().trim();
    final extra = json['extra'];
    double rent = 0, food = 0, bonus = 0;
    if (extra is Map) {
      rent = toDouble(extra['rent']);
      food = toDouble(extra['food']);
      bonus = toDouble(extra['bonus']);
    } else {
      rent = toDouble(json['rent']);
      food = toDouble(json['food']);
      bonus = toDouble(json['bonus']);
    }
    return Laborer(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      name: json['name']?.toString() ?? '',
      mobile: (mobileRaw == null || mobileRaw.isEmpty) ? null : mobileRaw,
      wage: toDouble(json['wage']),
      hours: toDouble(json['hours']),
      numberOfLabours: toInt(json['number_of_labours']),
      date: parseDate(json['date']),
      shift: json['shift']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      workType: json['work_type']?.toString() ?? '',
      labourHead: json['labour_head']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      narration: json['narration']?.toString() ?? '',
      entryKind: json['entry_kind']?.toString() ?? 'payable',
      rent: rent,
      food: food,
      bonus: bonus,
    );
  }
}
