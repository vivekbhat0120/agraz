import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

const _farmerKinds = [
  'milk_given',
  'milk_bought',
  'payment_received',
  'payment_made',
];

String dairyKindLabel(String kind) {
  switch (kind) {
    case 'milk_given':
      return tr('Milk given');
    case 'milk_bought':
      return tr('Milk bought');
    case 'payment_received':
      return tr('Payment received');
    case 'payment_made':
      return tr('Payment made');
    default:
      return kind;
  }
}

double dairyNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String dairyMoney(dynamic v) {
  final n = dairyNum(v);
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(n);
}

String dairyLiters(dynamic v) {
  final n = dairyNum(v);
  if (n == n.roundToDouble()) return '${n.toInt()} L';
  return '${n.toStringAsFixed(2)} L';
}

class DairyPage extends StatefulWidget {
  const DairyPage({super.key, this.skipBootstrap = false});

  /// When true, skip login/API so widget tests can pump the Entry form.
  final bool skipBootstrap;

  @override
  State<DairyPage> createState() => _DairyPageState();
}

class _DairyPageState extends State<DairyPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();

  late TabController _tabs;
  DateTime _date = DateTime.now();
  String _kind = 'milk_given';
  String _shift = 'morning';
  bool _saving = false;
  bool _loading = true;
  int? _editingId;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _entries = [];

  bool get _isMilk =>
      _kind == 'milk_given' || _kind == 'milk_bought';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  void _recalcAmount() {
    if (!_isMilk) return;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final amt = qty * rate;
    if (amt > 0) {
      _amountCtrl.text = amt.toStringAsFixed(2);
    }
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
      final summary = await _api.fetchDairySummary();
      final entries = await _api.fetchDairyEntries();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(e.toString()))),
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

  void _resetForm() {
    _editingId = null;
    _nameCtrl.clear();
    _mobileCtrl.clear();
    _qtyCtrl.clear();
    _rateCtrl.clear();
    _amountCtrl.clear();
    _narrationCtrl.clear();
    _kind = 'milk_given';
    _shift = 'morning';
    _date = DateTime.now();
  }

  void _fillFrom(Map<String, dynamic> row) {
    _editingId = dairyNum(row['id']).toInt();
    _kind = '${row['kind'] ?? 'milk_given'}';
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
    final shift = '${row['shift'] ?? ''}';
    _shift = (shift == 'evening') ? 'evening' : 'morning';
    _date = DateTime.tryParse('${row['date']}') ?? DateTime.now();
    _tabs.animateTo(0);
    setState(() {});
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enter dairy / party name'))),
      );
      return;
    }
    final payload = <String, dynamic>{
      'kind': _kind,
      'party_name': name,
      'party_mobile': _mobileCtrl.text.trim(),
      'date': _dateFmt.format(_date),
      'shift': _isMilk ? _shift : '',
      'quantity_liters': double.tryParse(_qtyCtrl.text.trim()) ?? 0,
      'rate_per_liter': double.tryParse(_rateCtrl.text.trim()) ?? 0,
      'amount': double.tryParse(_amountCtrl.text.trim()) ?? 0,
      'narration': _narrationCtrl.text.trim(),
    };
    setState(() => _saving = true);
    try {
      if (_editingId != null) {
        await _api.updateDairyEntry(_editingId!, payload);
      } else {
        await _api.createDairyEntry(payload);
      }
      if (!mounted) return;
      _resetForm();
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Dairy entry saved'))),
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

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = dairyNum(row['id']).toInt();
    if (id < 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete')),
        content: Text(tr('Delete this dairy entry?')),
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
      await _api.deleteDairyEntry(id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
              title: tr('Dairy'),
              subtitle: tr('Milk given, bought and receivable'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(context, menu: 'dairy'),
              ),
            ),
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: tr('Entry')),
                  Tab(text: tr('Account')),
                ],
              ),
            ),
            Expanded(
              child: _tabs.index == 0 ? _buildForm() : _buildAccount(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final net = dairyNum(_summary['net']);
    final side = '${_summary['net_side'] ?? 'settled'}';
    Color netColor = AppColors.textSecondary;
    String netLabel = tr('Settled');
    if (side == 'receivable' && net > 0) {
      netColor = AppColors.income;
      netLabel = tr('Receivable');
    } else if (side == 'payable' && net < 0) {
      netColor = AppColors.expense;
      netLabel = tr('Payable');
    }
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _statChip(
                tr('Milk given'),
                dairyLiters(_summary['milk_given_liters']),
                AppColors.primary,
              ),
              const SizedBox(width: 8),
              _statChip(
                tr('Milk bought'),
                dairyLiters(_summary['milk_bought_liters']),
                AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statChip(
                tr('Receivable'),
                dairyMoney(_summary['receivable']),
                AppColors.income,
              ),
              const SizedBox(width: 8),
              _statChip(
                tr('Payable'),
                dairyMoney(_summary['payable']),
                AppColors.expense,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$netLabel  ${dairyMoney(net.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: netColor,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryStrip(),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  icon: Icons.water_drop_rounded,
                  title: _editingId == null
                      ? tr('New dairy entry')
                      : tr('Edit dairy entry'),
                  subtitle: tr(
                    'Entries from your dairy appear on Account automatically',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _farmerKinds.map((k) {
                    final selected = _kind == k;
                    return ChoiceChip(
                      label: Text(dairyKindLabel(k)),
                      selected: selected,
                      onSelected: (_) => setState(() => _kind = k),
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
                  label: tr('Dairy / party name'),
                  icon: Icons.store_rounded,
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
                  label: _editingId == null ? tr('Save') : tr('Update'),
                  icon: Icons.save_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
                if (_editingId != null) ...[
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: tr('Clear'),
                    onPressed: () => setState(_resetForm),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccount() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          _buildSummaryStrip(),
          if (_entries.isEmpty)
            AppCard(
              child: Text(
                tr('No dairy entries yet'),
                style: AppText.body,
              ),
            )
          else
            ..._entries.map(_entryCard),
        ],
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> row) {
    final fromDairy = row['from_dairy'] == true;
    final editable = row['editable'] == true;
    final kind = '${row['kind'] ?? ''}';
    final isMilk = kind == 'milk_given' || kind == 'milk_bought';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${row['party_name'] ?? ''}',
                  style: AppText.bodyStrong,
                ),
              ),
              if (fromDairy)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('From dairy'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${dairyKindLabel(kind)}  ·  ${row['date'] ?? ''}'
            '${isMilk && '${row['shift']}' != '' ? '  ·  ${row['shift']}' : ''}',
            style: AppText.caption,
          ),
          const SizedBox(height: 6),
          Text(
            isMilk
                ? '${dairyLiters(row['quantity_liters'])}  ·  ${dairyMoney(row['amount'])}'
                : dairyMoney(row['amount']),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if ('${row['narration'] ?? ''}'.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${row['narration']}', style: AppText.caption),
            ),
          if (editable)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _fillFrom(row),
                  child: Text(tr('Edit')),
                ),
                TextButton(
                  onPressed: () => _delete(row),
                  child: Text(tr('Delete')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
