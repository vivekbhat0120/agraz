import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'dairy.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

const _ownerKinds = ['collected', 'sold', 'paid', 'received'];

String dairyOwnerKindLabel(String kind) {
  switch (kind) {
    case 'collected':
      return tr('Milk collected');
    case 'sold':
      return tr('Milk sold');
    case 'paid':
      return tr('Paid to customer');
    case 'received':
      return tr('Received from customer');
    default:
      return kind;
  }
}

class DairyOwnerPage extends StatefulWidget {
  const DairyOwnerPage({super.key, this.skipBootstrap = false});

  /// When true, skip login/API so widget tests can pump the Entry form.
  final bool skipBootstrap;

  @override
  State<DairyOwnerPage> createState() => _DairyOwnerPageState();
}

class _DairyOwnerPageState extends State<DairyOwnerPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  final _custNameCtrl = TextEditingController();
  final _custMobileCtrl = TextEditingController();
  final _custVillageCtrl = TextEditingController();
  final _custRateCtrl = TextEditingController();

  late TabController _tabs;
  DateTime _date = DateTime.now();
  String _ownerKind = 'collected';
  String _shift = 'morning';
  bool _saving = false;
  bool _loading = true;
  int? _editingEntryId;
  int? _editingCustomerId;
  int? _selectedCustomerId;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _entries = [];

  bool get _isMilk =>
      _ownerKind == 'collected' || _ownerKind == 'sold';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
    _qtyCtrl.addListener(_recalcAmount);
    _rateCtrl.addListener(_recalcAmount);
    if (widget.skipBootstrap) {
      _loading = false;
    } else {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _villageCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    _custNameCtrl.dispose();
    _custMobileCtrl.dispose();
    _custVillageCtrl.dispose();
    _custRateCtrl.dispose();
    super.dispose();
  }

  void _recalcAmount() {
    if (!_isMilk) return;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final amt = qty * rate;
    if (amt > 0) _amountCtrl.text = amt.toStringAsFixed(2);
  }

  Future<bool> _ensureLogin() async {
    var token = await getAuthToken();
    if (token != null && token.isNotEmpty) return true;
    if (!mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return ok == true;
  }

  Future<void> _bootstrap() async {
    if (!await _ensureLogin()) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final summary = await _api.fetchOwnerDairySummary();
      final customers = await _api.fetchDairyCustomers();
      final entries = await _api.fetchOwnerDairyEntries();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _customers = customers;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _applyCustomer(Map<String, dynamic> c) {
    _selectedCustomerId = dairyNum(c['id']).toInt();
    _nameCtrl.text = '${c['name'] ?? ''}';
    _mobileCtrl.text = '${c['mobile'] ?? ''}';
    _villageCtrl.text = '${c['village'] ?? ''}';
    final rate = dairyNum(c['default_rate']);
    if (rate > 0 && _rateCtrl.text.trim().isEmpty) {
      _rateCtrl.text = rate.toStringAsFixed(2);
      _recalcAmount();
    }
    setState(() {});
  }

  Future<void> _saveEntry() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enter customer name'))),
      );
      return;
    }
    final payload = <String, dynamic>{
      'owner_kind': _ownerKind,
      'party_name': name,
      'party_mobile': _mobileCtrl.text.trim(),
      'date': _dateFmt.format(_date),
      'shift': _isMilk ? _shift : '',
      'quantity_liters': double.tryParse(_qtyCtrl.text.trim()) ?? 0,
      'rate_per_liter': double.tryParse(_rateCtrl.text.trim()) ?? 0,
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'narration': _narrationCtrl.text.trim(),
      if (_selectedCustomerId != null) 'customer_id': _selectedCustomerId,
    };
    setState(() => _saving = true);
    try {
      Map<String, dynamic> res;
      if (_editingEntryId != null) {
        res = await _api.updateOwnerDairyEntry(_editingEntryId!, payload);
      } else {
        res = await _api.createOwnerDairyEntry(payload);
      }
      if (!mounted) return;
      _resetEntryForm();
      await _reload();
      if (!mounted) return;
      final linked = res['linked_account'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            linked
                ? tr('Saved. This will show on the customer Dairy page.')
                : tr('Saved. Customer will see this once they use this mobile in the app.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetEntryForm() {
    _editingEntryId = null;
    _selectedCustomerId = null;
    _nameCtrl.clear();
    _mobileCtrl.clear();
    _villageCtrl.clear();
    _qtyCtrl.clear();
    _rateCtrl.clear();
    _amountCtrl.clear();
    _narrationCtrl.clear();
    _ownerKind = 'collected';
    _shift = 'morning';
    _date = DateTime.now();
  }

  void _fillEntry(Map<String, dynamic> row) {
    _editingEntryId = dairyNum(row['id']).toInt();
    _ownerKind = '${row['owner_kind'] ?? 'collected'}';
    if (!_ownerKinds.contains(_ownerKind)) _ownerKind = 'collected';
    _nameCtrl.text = '${row['party_name'] ?? ''}';
    _mobileCtrl.text = '${row['party_mobile'] ?? ''}';
    _qtyCtrl.text = dairyNum(row['quantity_liters']) > 0
        ? '${dairyNum(row['quantity_liters'])}'
        : '';
    _rateCtrl.text = dairyNum(row['rate_per_liter']) > 0
        ? '${dairyNum(row['rate_per_liter'])}'
        : '';
    _amountCtrl.text = dairyNum(row['amount']) > 0
        ? dairyNum(row['amount']).toStringAsFixed(2)
        : '';
    _narrationCtrl.text = '${row['narration'] ?? ''}';
    _shift = '${row['shift']}' == 'evening' ? 'evening' : 'morning';
    _date = DateTime.tryParse('${row['date']}') ?? DateTime.now();
    _selectedCustomerId = dairyNum(row['customer_id']).toInt();
    if (_selectedCustomerId == 0) _selectedCustomerId = null;
    _tabs.animateTo(0);
    setState(() {});
  }

  Future<void> _deleteEntry(Map<String, dynamic> row) async {
    final id = dairyNum(row['id']).toInt();
    if (id < 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete')),
        content: Text(tr('Delete this milk entry?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteOwnerDairyEntry(id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _saveCustomer() async {
    final name = _custNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enter customer name'))),
      );
      return;
    }
    final payload = {
      'name': name,
      'mobile': _custMobileCtrl.text.trim(),
      'village': _custVillageCtrl.text.trim(),
      'default_rate': double.tryParse(_custRateCtrl.text.trim()) ?? 0,
    };
    setState(() => _saving = true);
    try {
      if (_editingCustomerId != null) {
        await _api.updateDairyCustomer(_editingCustomerId!, payload);
      } else {
        await _api.createDairyCustomer(payload);
      }
      if (!mounted) return;
      _custNameCtrl.clear();
      _custMobileCtrl.clear();
      _custVillageCtrl.clear();
      _custRateCtrl.clear();
      _editingCustomerId = null;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Dairy Owner'),
              subtitle: tr('Record customer milk — it shows on their account'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(context, menu: 'dairy_owner'),
              ),
            ),
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: tr('Collect milk')),
                  Tab(text: tr('Customers')),
                  Tab(text: tr('Entries')),
                ],
              ),
            ),
            Expanded(
              child: _tabs.index == 0
                  ? _buildCollectForm()
                  : _tabs.index == 1
                      ? _buildCustomers()
                      : _buildEntries(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ownerSummary() {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _chip(
                tr('Milk collected'),
                dairyLiters(_summary['milk_bought_liters']),
                AppColors.primary,
              ),
              const SizedBox(width: 8),
              _chip(
                tr('Milk sold'),
                dairyLiters(_summary['milk_given_liters']),
                AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(
                tr('Payable to farmers'),
                dairyMoney(_summary['payable']),
                AppColors.expense,
              ),
              const SizedBox(width: 8),
              _chip(
                tr('Receivable'),
                dairyMoney(_summary['receivable']),
                AppColors.income,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ownerSummary(),
          if (_customers.isNotEmpty) ...[
            Text(tr('Pick a customer'), style: AppText.label),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _customers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = _customers[i];
                  final id = dairyNum(c['id']).toInt();
                  final selected = _selectedCustomerId == id;
                  return ChoiceChip(
                    label: Text('${c['name'] ?? ''}'),
                    selected: selected,
                    onSelected: (_) => _applyCustomer(c),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  icon: Icons.local_drink_rounded,
                  title: _editingEntryId == null
                      ? tr('Milk entry')
                      : tr('Edit milk entry'),
                  subtitle: tr(
                    'Customer sees this on Dairy if the mobile matches their app login',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ownerKinds.map((k) {
                    return ChoiceChip(
                      label: Text(dairyOwnerKindLabel(k)),
                      selected: _ownerKind == k,
                      onSelected: (_) => setState(() => _ownerKind = k),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: tr('Date'),
                      prefixIcon:
                          const Icon(Icons.calendar_today_rounded, size: 20),
                    ),
                    child: Text(_dateFmt.format(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _nameCtrl,
                  label: tr('Customer name'),
                  icon: Icons.person_rounded,
                  required: true,
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _mobileCtrl,
                  label: tr('Mobile'),
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                if (_isMilk) ...[
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: tr('Shift'),
                    value: _shift,
                    items: const ['morning', 'evening'],
                    icon: Icons.schedule_rounded,
                    onChanged: (v) {
                      if (v != null) setState(() => _shift = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _qtyCtrl,
                    label: tr('Quantity (liters)'),
                    icon: Icons.opacity_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _rateCtrl,
                    label: tr('Rate per liter'),
                    icon: Icons.currency_rupee_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                const SizedBox(height: 12),
                AppField(
                  controller: _amountCtrl,
                  label: tr('Amount'),
                  icon: Icons.payments_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  required: true,
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _narrationCtrl,
                  label: tr('Narration'),
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _editingEntryId == null ? tr('Save') : tr('Update'),
                  icon: Icons.save_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _saveEntry,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomers() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  icon: Icons.people_alt_rounded,
                  title: _editingCustomerId == null
                      ? tr('Add customer')
                      : tr('Edit customer'),
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _custNameCtrl,
                  label: tr('Name'),
                  icon: Icons.person_rounded,
                  required: true,
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _custMobileCtrl,
                  label: tr('Mobile'),
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _custVillageCtrl,
                  label: tr('Village'),
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _custRateCtrl,
                  label: tr('Default rate per liter'),
                  icon: Icons.currency_rupee_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _editingCustomerId == null ? tr('Save') : tr('Update'),
                  loading: _saving,
                  onPressed: _saving ? null : _saveCustomer,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_customers.isEmpty)
            AppCard(child: Text(tr('No customers yet'), style: AppText.body))
          else
            ..._customers.map((c) {
              final bal = c['balance'] is Map
                  ? Map<String, dynamic>.from(c['balance'] as Map)
                  : <String, dynamic>{};
              final linked = c['linked_account'] == true;
              return AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${c['name'] ?? ''}', style: AppText.bodyStrong),
                        ),
                        if (linked)
                          InfoChip(
                            label: tr('In app'),
                            color: AppColors.income,
                          ),
                      ],
                    ),
                    Text(
                      '${c['mobile'] ?? ''}  ${c['village'] ?? ''}'.trim(),
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${tr('Payable')} ${dairyMoney(bal['payable'])}  ·  ${tr('Milk collected')} ${dairyLiters(bal['milk_bought_liters'])}',
                      style: AppText.small,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _applyCustomer(c);
                            _tabs.animateTo(0);
                          },
                          child: Text(tr('Collect')),
                        ),
                        TextButton(
                          onPressed: () {
                            _editingCustomerId = dairyNum(c['id']).toInt();
                            _custNameCtrl.text = '${c['name'] ?? ''}';
                            _custMobileCtrl.text = '${c['mobile'] ?? ''}';
                            _custVillageCtrl.text = '${c['village'] ?? ''}';
                            _custRateCtrl.text = dairyNum(c['default_rate']) > 0
                                ? dairyNum(c['default_rate']).toStringAsFixed(2)
                                : '';
                            setState(() {});
                          },
                          child: Text(tr('Edit')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEntries() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          _ownerSummary(),
          if (_entries.isEmpty)
            AppCard(child: Text(tr('No dairy entries yet'), style: AppText.body))
          else
            ..._entries.map((row) {
              final kind = '${row['owner_kind'] ?? ''}';
              final isMilk = kind == 'collected' || kind == 'sold';
              return AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['party_name'] ?? ''}', style: AppText.bodyStrong),
                    Text(
                      '${dairyOwnerKindLabel(kind)}  ·  ${row['date'] ?? ''}',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isMilk
                          ? '${dairyLiters(row['quantity_liters'])}  ·  ${dairyMoney(row['amount'])}'
                          : dairyMoney(row['amount']),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _fillEntry(row),
                          child: Text(tr('Edit')),
                        ),
                        TextButton(
                          onPressed: () => _deleteEntry(row),
                          child: Text(tr('Delete')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
