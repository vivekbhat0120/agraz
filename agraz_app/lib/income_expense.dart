import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'income_expense_data.dart';
import 'income_expense_view.dart';
import 'income_expense_report.dart';
import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'voice_dictation.dart';

class IncomeExpensePage extends StatefulWidget {
  const IncomeExpensePage({super.key});

  @override
  State<IncomeExpensePage> createState() => _IncomeExpensePageState();
}

class _IncomeExpensePageState extends State<IncomeExpensePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final IncomeExpenseData _formData = IncomeExpenseData();
  final ApiService _apiService = ApiService();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _narrationController = TextEditingController();
  final _amountController = TextEditingController();
  final _villageController = TextEditingController();
  final _postController = TextEditingController();
  final _talukController = TextEditingController();
  final _districtController = TextEditingController();
  final _extraAddressController = TextEditingController();
  final _pincodeController = TextEditingController();

  final List<String> receiptPaymentOptions = ['Income', 'Expense'];
  String? _pressedToggle;
  List<String> categories = [];
  List<String> subCategories = [];
  bool isLoading = false;
  List<Map<String, dynamic>> _organizations = [];

  /// Signed party balance (Income − Expense). Null when unknown / not loaded.
  double? _partyBalance;
  String _partyBalanceSide = 'settled';
  bool _partyDetailsLoaded = false;
  Timer? _nameSearchDebounce;
  List<Map<String, dynamic>> _nameSuggestions = [];
  bool _showNameSuggestions = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  String get _partyLabel {
    if (_formData.receiptPaymentType == 'Expense') return tr('To');
    if (_formData.receiptPaymentType == 'Income') return tr('By');
    return tr('By / To');
  }

  bool _isJwtError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('invalid or expired jwt') ||
        msg.contains('missing or malformed jwt') ||
        msg.contains('unauthorized') ||
        msg.contains('401');
  }

  @override
  void initState() {
    super.initState();
    _formData.transactionDate = DateTime.now();
    _formData.transactionMode = 'Cash';
    _updateCategories();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapLogin());
  }

  Future<void> _bootstrapLogin() async {
    final ok = await ensureLoggedIn(context);
    if (!ok) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    try {
      final token = await getValidAuthToken();
      if (token == null || token.isEmpty) return;
      final rows = await _apiService.fetchOrganizations();
      if (!mounted) return;
      setState(() => _organizations = rows);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameSearchDebounce?.cancel();
    _animController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _narrationController.dispose();
    _amountController.dispose();
    _villageController.dispose();
    _postController.dispose();
    _talukController.dispose();
    _districtController.dispose();
    _extraAddressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _updateCategories() {
    if (_formData.receiptPaymentType == 'Income') {
      categories = ['Farming Income', 'Non-Farming Income'];
    } else if (_formData.receiptPaymentType == 'Expense') {
      categories = ['Farming Expense', 'Living Expense'];
    } else {
      categories = [];
    }
    _formData.category = null;
    _formData.subCategory = null;
    _formData.subCategories = [];
    subCategories = [];
  }

  void _updateSubCategories(String selectedCategory) {
    setState(() {
      subCategories =
          _formData.categorySubCategoryMap[selectedCategory]?.keys.toList() ??
              [];
      _formData.subCategory = null;
      _formData.subCategories = [];
    });
  }

  void _toggleSubCategory(String option) {
    setState(() {
      if (_formData.subCategories.contains(option)) {
        _formData.subCategories.remove(option);
      } else {
        _formData.subCategories.add(option);
      }
      _formData.subCategory = _formData.subCategories.isEmpty
          ? null
          : _formData.subCategories.first;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _formData.transactionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _formData.transactionDate) {
      setState(() {
        _formData.transactionDate = picked;
      });
    }
  }

  void _clearPartyBalance() {
    _partyBalance = null;
    _partyBalanceSide = 'settled';
    _partyDetailsLoaded = false;
  }

  Future<void> _loadPartyBalance(String mobile) async {
    if (mobile.length != 10) {
      setState(_clearPartyBalance);
      return;
    }
    final bal = await _apiService.fetchPartyBalance(mobile);
    if (!mounted) return;
    if (bal == null) {
      setState(_clearPartyBalance);
      return;
    }
    setState(() {
      _partyBalance = (bal['balance'] as num?)?.toDouble() ?? 0;
      _partyBalanceSide = bal['side']?.toString() ?? 'settled';
      _partyDetailsLoaded = true;
    });
  }

  void _applyTransactionDetails(Map transaction) {
    if (_nameController.text.isEmpty) {
      _nameController.text = transaction['name']?.toString() ?? '';
    }
    final mobile = transaction['mobile']?.toString() ?? '';
    if (_mobileController.text.isEmpty && mobile.isNotEmpty) {
      _mobileController.text = mobile;
    }
    _villageController.text = transaction['village']?.toString() ?? '';
    _postController.text = transaction['post']?.toString() ?? '';
    _talukController.text = transaction['taluk']?.toString() ?? '';
    _districtController.text = transaction['district']?.toString() ?? '';
    _extraAddressController.text =
        transaction['extra_address']?.toString() ??
            transaction['extraAddress']?.toString() ??
            '';
    _pincodeController.text = transaction['pincode']?.toString() ?? '';
  }

  Future<void> _prefetchByMobile(String mobile) async {
    if (mobile.length != 10) {
      setState(_clearPartyBalance);
      return;
    }
    try {
      final responseData = await _apiService.fetchUserByMobile(mobile);
      if (!mounted) return;
      if (responseData != null &&
          responseData['data'] != null &&
          responseData['data'].isNotEmpty) {
        final transaction = responseData['data'][0];
        setState(() => _applyTransactionDetails(transaction));
      }
      await _loadPartyBalance(mobile);
    } catch (_) {
      if (mounted) await _loadPartyBalance(mobile);
    }
  }

  void _onNameChanged(String value) {
    _nameSearchDebounce?.cancel();
    final name = value.trim();
    if (name.length < 2) {
      setState(() {
        _nameSuggestions = [];
        _showNameSuggestions = false;
      });
      return;
    }
    _nameSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchNameSuggestions(name);
    });
  }

  Future<void> _searchNameSuggestions(String name) async {
    try {
      final rows = await _apiService.searchUsersByName(name);
      if (!mounted) return;
      setState(() {
        _nameSuggestions = rows;
        _showNameSuggestions = rows.isNotEmpty;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _nameSuggestions = [];
          _showNameSuggestions = false;
        });
      }
    }
  }

  void _applySuggestion(Map<String, dynamic> row) {
    setState(() {
      _applyTransactionDetails(row);
      _nameSuggestions = [];
      _showNameSuggestions = false;
    });
    final mobile = _mobileController.text.trim();
    if (mobile.length == 10) {
      _loadPartyBalance(mobile);
    }
  }

  void _syncFormDataFromControllers() {
    _formData.name = _nameController.text.trim().isEmpty
        ? ''
        : _nameController.text.trim();
    _formData.mobile = _mobileController.text.trim().isEmpty
        ? ''
        : _mobileController.text.trim();
    _formData.narration = _narrationController.text.trim().isEmpty
        ? null
        : _narrationController.text.trim();
    final amt = double.tryParse(_amountController.text.trim());
    if (amt != null) _formData.amount = amt;
    _formData.village = _villageController.text.trim().isEmpty
        ? null
        : _villageController.text.trim();
    _formData.post =
        _postController.text.trim().isEmpty ? null : _postController.text.trim();
    _formData.taluk = _talukController.text.trim().isEmpty
        ? null
        : _talukController.text.trim();
    _formData.district = _districtController.text.trim().isEmpty
        ? null
        : _districtController.text.trim();
    _formData.extraAddress = _extraAddressController.text.trim().isEmpty
        ? null
        : _extraAddressController.text.trim();
    _formData.pincode = _pincodeController.text.trim().isEmpty
        ? null
        : _pincodeController.text.trim();
  }

  Future<void> _showJwtExpiredDialog() async {
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
              tr('Invalid or expired JWT. Please login again to continue.'),
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
              final ok = await ensureLoggedIn(context, force: true);
              if (ok && mounted) {
                // Stay on the form; user can tap save again.
              }
            },
            child: Text(tr('Login')),
          ),
        ],
      ),
    );
  }

  void _clearFormForNextEntry() {
    final keptType = _formData.receiptPaymentType;
    // Do not call Form.reset() after clear — it restores TextFormField
    // values (including narration) from the last save.
    stopVoiceAndClearFields([
      _nameController,
      _mobileController,
      _narrationController,
      _amountController,
      _villageController,
      _postController,
      _talukController,
      _districtController,
      _extraAddressController,
      _pincodeController,
    ]);

    setState(() {
      _formData.amount = null;
      _formData.narration = null;
      _formData.mobile = null;
      _formData.name = null;
      _formData.village = null;
      _formData.post = null;
      _formData.taluk = null;
      _formData.district = null;
      _formData.extraAddress = null;
      _formData.pincode = null;
      _formData.transactionDate = DateTime.now();
      _formData.receiptPaymentType = keptType;
      _formData.transactionMode = 'Cash';
      _formData.organizationId = null;
      _nameSuggestions = [];
      _showNameSuggestions = false;
      _clearPartyBalance();
      _formData.subCategories = [];
      _updateCategories();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _syncFormDataFromControllers();

    if (_formData.receiptPaymentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please select Income or Expense')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (_formData.category == null ||
        _formData.effectiveSubCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please select category and sub category')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (_formData.amount == null || _formData.amount! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please enter a valid amount')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (_formData.transactionMode == 'Transfer' &&
        _formData.organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please select an organization for transfer')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    // Saving requires a valid login.
    if (!await ensureLoggedIn(context)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Login required to save')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final success = await _apiService.submitTransaction(_formData);
      if (!mounted) return;
      setState(() => isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Transaction recorded successfully!')),
            backgroundColor: AppColors.income,
          ),
        );
        _clearFormForNextEntry();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (_isJwtError(e)) {
        await _showJwtExpiredDialog();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Future<void> _showOtherInfoSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      TintedIcon(
                        icon: Icons.location_on_rounded,
                        color: AppColors.primary,
                        boxSize: 40,
                        size: 20,
                        radius: 12,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(tr('Other Information'), style: AppText.h3),
                      ),
                      IconButton(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(tr('Optional address details'), style: AppText.small),
                  SizedBox(height: 16),
                  AppField(
                    label: 'Village',
                    icon: Icons.location_city_rounded,
                    controller: _villageController,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'Post',
                    icon: Icons.local_post_office_rounded,
                    controller: _postController,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'Taluk',
                    icon: Icons.map_rounded,
                    controller: _talukController,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'District',
                    icon: Icons.place_rounded,
                    controller: _districtController,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'Extra Address',
                    icon: Icons.note_add_rounded,
                    controller: _extraAddressController,
                    maxLines: 2,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'Pincode',
                    icon: Icons.pin_drop_rounded,
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Done',
                    icon: Icons.check_rounded,
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    setState(() {});
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Farming Income':
        return AppColors.income;
      case 'Non-Farming Income':
        return AppColors.info;
      case 'Farming Expense':
        return AppColors.warning;
      case 'Living Expense':
        return AppColors.expense;
      default:
        return AppColors.textMuted;
    }
  }

  bool get _hasOtherInfo {
    return _villageController.text.isNotEmpty ||
        _postController.text.isNotEmpty ||
        _talukController.text.isNotEmpty ||
        _districtController.text.isNotEmpty ||
        _extraAddressController.text.isNotEmpty ||
        _pincodeController.text.isNotEmpty;
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
                title: tr('Record Transaction'),
                subtitle: tr('Income & Expense'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: withFeedbackAction(
                    context,
                    menu: 'income_expense',
                    actions: const [],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStepper(),
                        const SizedBox(height: 12),
                        _buildTransactionTypeCard(),
                        const SizedBox(height: 12),
                        _buildTransactionModeCard(),
                        const SizedBox(height: 12),
                        _buildDateAmountCard(),
                        if (_formData.receiptPaymentType != null &&
                            categories.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildCategorySection(),
                        ],
                        if (_formData.category != null &&
                            subCategories.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildSubCategorySection(),
                        ],
                        const SizedBox(height: 12),
                        _buildPartyCard(),
                        const SizedBox(height: 12),
                        _buildNarrationCard(),
                        const SizedBox(height: 14),
                        _buildSubmitButton(),
                        const SizedBox(height: 10),
                        _buildSecondaryActions(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final typeDone = _formData.receiptPaymentType != null;
    final detailsDone =
        _formData.category != null && (_formData.amount ?? 0) > 0;
    final partyDone = _nameController.text.trim().isNotEmpty ||
        _mobileController.text.trim().isNotEmpty;

    Widget step(String label, bool done) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: done
                  ? const LinearGradient(
                      colors: AppColors.buttonGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: done ? null : AppColors.field,
              border: Border.all(
                color: done ? Colors.transparent : AppColors.border,
                width: 1.4,
              ),
              boxShadow: done
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.circle_outlined,
              color: done ? Colors.white : AppColors.textMuted,
              size: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              color: done ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      );
    }

    Widget connector(bool done) {
      return Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.fromLTRB(6, 0, 6, 18),
          decoration: BoxDecoration(
            color: done
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.softShadow],
      ),
      child: Row(
        children: [
          step(tr('Type'), typeDone),
          connector(typeDone),
          step(tr('Details'), detailsDone),
          connector(detailsDone),
          step(tr('Party'), partyDone),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.swap_horiz_rounded,
            title: tr('Transaction Type'),
            subtitle: tr('Is this money in or money out?'),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _typeToggle(
                  'Income',
                  Icons.trending_up_rounded,
                  AppColors.income,
                  AppColors.incomeSoft,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _typeToggle(
                  'Expense',
                  Icons.trending_down_rounded,
                  AppColors.expense,
                  AppColors.expenseSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionModeCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.payments_rounded,
            title: tr('Transaction Mode'),
            subtitle: tr('Cash or bank transfer'),
          ),
          SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _formData.transactionMode,
            decoration: InputDecoration(
              labelText: tr('Mode'),
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            ),
            items: [
              DropdownMenuItem(value: 'Cash', child: Text(tr('Cash'))),
              DropdownMenuItem(value: 'Transfer', child: Text(tr('Transfer'))),
            ],
            onChanged: (v) {
              setState(() {
                _formData.transactionMode = v ?? 'Cash';
                if (_formData.transactionMode != 'Transfer') {
                  _formData.organizationId = null;
                } else if (_organizations.isEmpty) {
                  _loadOrganizations();
                }
              });
            },
          ),
          if (_formData.transactionMode == 'Transfer') ...[
            SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _formData.organizationId,
              decoration: InputDecoration(
                labelText: tr('Organization'),
                prefixIcon: const Icon(Icons.business_rounded),
              ),
              items: _organizations.map((o) {
                final id = o['id'];
                final idInt = id is int ? id : int.tryParse('$id');
                return DropdownMenuItem<int>(
                  value: idInt,
                  child: Text('${o['name'] ?? ''}'),
                );
              }).where((e) => e.value != null).toList(),
              onChanged: (v) => setState(() => _formData.organizationId = v),
              validator: (v) {
                if (_formData.transactionMode == 'Transfer' && v == null) {
                  return tr('Select organization');
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeToggle(String type, IconData icon, Color color, Color softColor) {
    final selected = _formData.receiptPaymentType == type;
    final pressed = _pressedToggle == type;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedToggle = type),
      onTapUp: (_) => setState(() => _pressedToggle = null),
      onTapCancel: () => setState(() => _pressedToggle = null),
      onTap: () {
        setState(() {
          _formData.receiptPaymentType = type;
          _updateCategories();
        });
      },
      child: AnimatedScale(
        scale: pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(color, Colors.white, 0.18)!,
                      color,
                    ],
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.6 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0.12),
                              ],
                            )
                          : null,
                      color: selected ? null : softColor,
                      border: Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.4)
                            : color.withValues(alpha: 0.2),
                        width: 1.4,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? Colors.white : color,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          type,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selected ? 'Selected' : 'Tap to select',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.9)
                                : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.check_rounded, color: color, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateAmountCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.calendar_month_rounded,
            title: tr('Date & Amount'),
            subtitle: tr('When and how much?'),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildDateField()),
              SizedBox(width: 12),
              Expanded(child: _buildAmountField()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy').format(_formData.transactionDate!),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    final type = _formData.receiptPaymentType;
    final accent = type == 'Expense' ? AppColors.expense : AppColors.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.2),
      ),
      child: TextFormField(
        controller: _amountController,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) {
          setState(() {
            _formData.amount = double.tryParse(v.trim());
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) return tr('Required');
          if (double.tryParse(value) == null) return tr('Invalid');
          if (double.parse(value) <= 0) return tr('Must be > 0');
          return null;
        },
        onSaved: (value) => _formData.amount = double.tryParse(value!),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          prefixIcon: Icon(
            Icons.currency_rupee_rounded,
            color: accent,
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          hintText: tr('Amount'),
          hintStyle: TextStyle(color: accent.withValues(alpha: 0.5), fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.category_rounded,
            title: tr('Category'),
            subtitle: tr('Pick the type of income or expense'),
          ),
          SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories.map((cat) => _categoryChip(cat)).toList(),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Farming Income':
        return Icons.agriculture_rounded;
      case 'Non-Farming Income':
        return Icons.storefront_rounded;
      case 'Farming Expense':
        return Icons.eco_rounded;
      case 'Living Expense':
        return Icons.home_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _categoryChip(String label) {
    final selected = _formData.category == label;
    final color = _getCategoryColor(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          _formData.category = label;
          _updateSubCategories(label);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(color, Colors.white, 0.2)!, color],
                )
              : null,
          color: selected ? null : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 1.6 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.white,
              ),
              child: Icon(
                _categoryIcon(label),
                color: selected ? Colors.white : color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tr(label),
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategorySection() {
    final preview = _formData.splitPreview();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(tr('Sub Category'), Icons.list_alt_rounded),
          Text(
            tr('Select one or more — amount splits equally'),
            style: AppText.caption,
          ),
          SizedBox(height: 10),
          _buildSubCategoryGrid(),
          if (preview.length >= 2) ...[
            SizedBox(height: 14),
            Text(tr('Split preview'), style: AppText.label),
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: preview
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(tr(p.name), style: AppText.small),
                            ),
                            Text(
                              '₹${NumberFormat('#,##0').format(p.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubCategoryGrid() {
    final color = _getCategoryColor(_formData.category!);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: subCategories.map((option) {
        final selected = _formData.subCategories.contains(option);
        final emoji =
            _formData.categorySubCategoryMap[_formData.category]![option] ??
                '📋';
        return FilterChip(
          selected: selected,
          showCheckmark: true,
          checkmarkColor: Colors.white,
          avatar: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.22)
                  : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 13))),
          ),
          label: Text(
            tr(option),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
          selectedColor: color,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected ? color : AppColors.border,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: (_) => _toggleSubCategory(option),
        );
      }).toList(),
    );
  }

  Widget _buildPartyCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(_partyLabel, Icons.person_rounded),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tr('Search by name or mobile'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    onChanged: _onNameChanged,
                    onSaved: (v) => _formData.name = v?.trim() ?? '',
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.badge_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: tr('Name (optional, for search)'),
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              VoiceMicButton(
                fieldId: 'ie_name',
                controller: _nameController,
                onTextChanged: () => _onNameChanged(_nameController.text),
              ),
            ],
          ),
          if (_showNameSuggestions && _nameSuggestions.isNotEmpty) ...[
            SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
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
                itemBuilder: (context, index) {
                  final row = _nameSuggestions[index];
                  final name = row['name']?.toString() ?? '';
                  final mobile = row['mobile']?.toString() ?? '';
                  final village = row['village']?.toString() ?? '';
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_search_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (mobile.isNotEmpty) mobile,
                        if (village.isNotEmpty) village,
                      ].join(' · '),
                      style: AppText.caption,
                    ),
                    onTap: () => _applySuggestion(row),
                  );
                },
              ),
            ),
          ],
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextFormField(
              controller: _mobileController,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    value.length != 10) {
                  return '10 digits required';
                }
                return null;
              },
              onChanged: _prefetchByMobile,
              onSaved: (v) => _formData.mobile = v?.trim() ?? '',
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                prefixIcon: const Icon(
                  Icons.phone_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: tr('By/To mobile'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_partyDetailsLoaded && _partyBalance != null) ...[
            SizedBox(height: 10),
            _buildBalanceChip(),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    final amount = _partyBalance!.abs();
    final isCredit = _partyBalanceSide == 'credit' || (_partyBalance! > 0);
    final isDebit = _partyBalanceSide == 'debit' || (_partyBalance! < 0);
    final color = isDebit
        ? AppColors.expense
        : isCredit
            ? AppColors.income
            : Colors.grey.shade600;
    final label = isDebit
        ? 'Debit'
        : isCredit
            ? 'Credit'
            : 'Settled';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDebit
                  ? Icons.arrow_downward_rounded
                  : isCredit
                      ? Icons.arrow_upward_rounded
                      : Icons.check_circle_outline,
              size: 14,
              color: color,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Balance: $label ${fmt.format(amount)}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrationCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  tr('Narration (optional)'),
                  Icons.description_rounded,
                ),
              ),
              VoiceMicButton(
                fieldId: 'ie_narration',
                controller: _narrationController,
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextFormField(
              controller: _narrationController,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              minLines: 3,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              validator: (value) {
                return null;
              },
              onSaved: (value) => _formData.narration =
                  (value == null || value.trim().isEmpty) ? null : value.trim(),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: tr('Describe the transaction (optional)...'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _halfOutlinedButton(
                label: 'Reports',
                icon: Icons.insights_rounded,
                color: AppColors.info,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncomeExpenseReportPage(),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _halfOutlinedButton(
                label: 'View All',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF2E7D32),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncomeExpenseListScreen(),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _halfOutlinedButton(
                label: _hasOtherInfo ? 'Other Info ✓' : 'Other Info',
                icon: _hasOtherInfo
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: const Color(0xFF1565C0),
                onPressed: _showOtherInfoSheet,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _halfOutlinedButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45), width: 1.3),
        backgroundColor: color.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        minimumSize: const Size(0, 44),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.ctaGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isLoading ? null : _submitForm,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
