import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'labor_categories.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';
import 'voice_dictation.dart';

class LabourWorkPage extends StatefulWidget {
  final int initialTab;
  const LabourWorkPage({super.key, this.initialTab = 0});

  @override
  State<LabourWorkPage> createState() => _LabourWorkPageState();
}

class _LabourWorkPageState extends State<LabourWorkPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _daysHourCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  late TabController _tabs;
  DateTime _date = DateTime.now();
  String _category = kLaborWorkCategories.first;
  String _shift = 'fullday';
  String _gender = 'Male';
  bool _saving = false;
  List<Map<String, dynamic>> _pendingShares = [];
  int _pendingCount = 0;
  bool _loadingShares = false;
  int? _actingShareId;

  final _shifts = const ['fullday', 'morning', 'evening', 'night'];
  final _genders = const ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
    _applyShiftDefaultDays(_shift);
    _loadPendingShares();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _daysHourCtrl.dispose();
    _rateCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  void _applyShiftDefaultDays(String shift) {
    final v = switch (shift) {
      'morning' || 'evening' => '0.5',
      'night' || 'fullday' => '1',
      _ => '1',
    };
    _daysHourCtrl.text = v;
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String get _entryKind => _tabs.index == 1 ? 'receipt' : 'receivable';

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  Future<void> _loadPendingShares() async {
    final token = await getAuthToken();
    if (token == null || token.isEmpty) return;
    setState(() => _loadingShares = true);
    try {
      final rows = await _api.fetchLaborShares();
      if (!mounted) return;
      setState(() {
        _pendingShares = rows;
        _pendingCount = rows.length;
      });
    } catch (_) {
      // Keep the form usable even if confirmations fail to load.
    } finally {
      if (mounted) setState(() => _loadingShares = false);
    }
  }

  Future<void> _decideShare(Map<String, dynamic> row, {required bool accept}) async {
    final id = _asInt(row['id']);
    if (id == null) return;
    final name = '${row['name'] ?? ''}'.trim();
    final kind = '${row['entry_kind'] ?? ''}';
    final wage = _asDouble(row['wage']);
    final hours = _asDouble(row['hours']);
    final total = wage * hours;
    final dateStr = '${row['date'] ?? ''}'.split('T').first;
    final recordedAs = '${row['recorded_as'] ?? ''}'.trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          accept ? tr('Confirm this entry?') : tr('Reject this entry?'),
        ),
        content: Text(
          accept
              ? (kind == 'receipt'
                  ? trf(
                      '{0} recorded a payment of {1} to you on {2}. Confirm to save it as a receipt in your Labour Work.',
                      [name, total.toStringAsFixed(2), dateStr],
                    )
                  : trf(
                      '{0} recorded work for you on {1} for {2}. Confirm to save it as receivable in your Labour Work.',
                      [name, dateStr, total.toStringAsFixed(2)],
                    ))
              : tr(
                  'This will not be added to your books. The other person\'s entry stays as-is.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: accept
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(d, true),
            child: Text(accept ? tr('Confirm') : tr('Reject')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    setState(() => _actingShareId = id);
    try {
      final res = accept
          ? await _api.acceptLaborShare(id)
          : await _api.rejectLaborShare(id);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? (recordedAs.isEmpty
                      ? tr('Added to your work entries')
                      : trf('Added to your work entries as {0}', [recordedAs]))
                  : tr('Entry rejected'),
            ),
            backgroundColor: accept ? AppColors.income : AppColors.warning,
          ),
        );
        await _loadPendingShares();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res['message'] ?? tr('Failed')}'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _actingShareId = null);
    }
  }

  Widget _buildConfirmations() {
    if (_loadingShares && _pendingShares.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingShares.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr('No entries waiting for confirmation'),
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPendingShares,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        itemCount: _pendingShares.length,
        itemBuilder: (context, i) {
          final row = _pendingShares[i];
          final id = _asInt(row['id']);
          final wage = _asDouble(row['wage']);
          final hours = _asDouble(row['hours']);
          final total = wage * hours;
          final kind = '${row['entry_kind'] ?? ''}';
          final dateStr = '${row['date'] ?? ''}'.split('T').first;
          final recordedAs = '${row['recorded_as'] ?? ''}'.trim();
          final category = '${row['category'] ?? ''}'.trim();
          final shift = '${row['shift'] ?? ''}'.trim();
          final mobile = '${row['mobile'] ?? ''}'.trim();
          final rent = _asDouble(row['rent']);
          final food = _asDouble(row['food']);
          final bonus = _asDouble(row['bonus']);
          final extras = <String>[
            if (rent > 0) '${tr('Rent')} ${rent.toStringAsFixed(2)}',
            if (food > 0) '${tr('Food')} ${food.toStringAsFixed(2)}',
            if (bonus > 0) '${tr('Bonus')} ${bonus.toStringAsFixed(2)}',
          ];
          final busy = _actingShareId == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row['name'] ?? ''}',
                    style: AppText.title,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      dateStr,
                      kind == 'receipt' ? tr('Receipt') : tr('Work Entry'),
                      if (category.isNotEmpty) category,
                      if (shift.isNotEmpty) tr(shift),
                      if (hours > 0) '${tr('Days / Hour')} ${hours.toStringAsFixed(2)}',
                      '${tr('Rate')} ${wage.toStringAsFixed(2)}',
                      total.toStringAsFixed(2),
                      if (mobile.isNotEmpty) mobile,
                    ].join(' · '),
                    style: AppText.small,
                  ),
                  if (recordedAs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      trf('Recorded you as {0}', [recordedAs]),
                      style: AppText.caption,
                    ),
                  ],
                  if (extras.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(extras.join(' · '), style: AppText.caption),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => _decideShare(row, accept: false),
                          child: Text(tr('Reject')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : () => _decideShare(row, accept: true),
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(tr('Confirm')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!await _ensureLogin()) return;
    if (!mounted) return;
    final name = _nameCtrl.text.trim();
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final hours = double.tryParse(_daysHourCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Name is required'))),
      );
      return;
    }
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Rate must be greater than zero'))),
      );
      return;
    }
    if (_entryKind == 'receivable' && hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Days/hour must be greater than zero'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'name': name,
        'wage': rate,
        'hours': _entryKind == 'receipt' && hours <= 0 ? 1.0 : hours,
        'shift': _shift,
        'category': _entryKind == 'receipt' ? 'Receipt' : _category,
        'gender': _gender,
        'narration': _narrationCtrl.text.trim(),
        'entry_kind': _entryKind,
        'date': _dateFmt.format(_date),
        'work_type': 'Daily Wages',
        'location': 'Farm',
        'number_of_labours': 1,
      };
      final res = await _api.createLaborWork(payload);
      if (!mounted) return;
      if (res['success'] == true) {
        stopVoiceAndClearFields([
          _nameCtrl,
          _rateCtrl,
          _narrationCtrl,
        ]);
        setState(() {
          _date = DateTime.now();
          _category = kLaborWorkCategories.first;
          _shift = 'fullday';
          _gender = 'Male';
        });
        _applyShiftDefaultDays(_shift);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res['message'] ?? tr('Saved')}'),
            backgroundColor: AppColors.income,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res['message'] ?? tr('Failed')}'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LabourWorkReportsPage()),
    );
  }

  Widget _buildForm() {
    final isReceipt = _tabs.index == 1;
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
                  icon: isReceipt
                      ? Icons.payments_rounded
                      : Icons.work_history_rounded,
                  title: isReceipt ? tr('Receipt') : tr('Work Entry'),
                  subtitle: isReceipt
                      ? tr('Money received')
                      : tr('Receivable work'),
                ),
                const SizedBox(height: 14),
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
                  label: tr('Name'),
                  icon: Icons.person_rounded,
                  required: true,
                ),
                if (!isReceipt) ...[
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: tr('Category'),
                    value: _category,
                    items: kLaborWorkCategories,
                    icon: Icons.category_rounded,
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: tr('Shift'),
                    value: _shift,
                    items: _shifts,
                    icon: Icons.schedule_rounded,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _shift = v;
                        _applyShiftDefaultDays(v);
                      });
                    },
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _daysHourCtrl,
                    label: tr('Days / Hour'),
                    icon: Icons.timelapse_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    required: true,
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  AppField(
                    controller: _daysHourCtrl,
                    label: tr('Days / Hour'),
                    icon: Icons.timelapse_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    hint: '1',
                  ),
                ],
                const SizedBox(height: 12),
                AppField(
                  controller: _rateCtrl,
                  label: tr('Rate'),
                  icon: Icons.currency_rupee_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  required: true,
                ),
                const SizedBox(height: 12),
                AppDropdown(
                  label: tr('Gender'),
                  value: _gender,
                  items: _genders,
                  icon: Icons.wc_rounded,
                  onChanged: (v) {
                    if (v != null) setState(() => _gender = v);
                  },
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _narrationCtrl,
                  label: tr('Narration'),
                  icon: Icons.notes_rounded,
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: tr('Save'),
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openReports,
            icon: const Icon(Icons.insights_rounded),
            label: Text(tr('History / Reports')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Labour Work'),
              subtitle: tr('Receivable & receipts'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_work',
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.insights_rounded, color: Colors.white),
                      tooltip: tr('Reports'),
                      onPressed: _openReports,
                    ),
                  ],
                ),
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
                onTap: (_) => setState(() {}),
                tabs: [
                  Tab(text: tr('Work Entry')),
                  Tab(text: tr('Receipt')),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('Confirm')),
                        if (_pendingCount > 0) ...[
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: AppColors.accent,
                            child: Text(
                              '$_pendingCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tabs.index == 2 ? _buildConfirmations() : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }
}

class LabourWorkReportsPage extends StatefulWidget {
  const LabourWorkReportsPage({super.key});

  @override
  State<LabourWorkReportsPage> createState() => _LabourWorkReportsPageState();
}

class _LabourWorkReportsPageState extends State<LabourWorkReportsPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _searchCtrl = TextEditingController();

  DateTime? _from;
  DateTime? _to;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = _from == null ? null : _dateFmt.format(_from!);
      final to = _to == null ? null : _dateFmt.format(_to!);
      final q = _searchCtrl.text.trim();
      final results = await Future.wait([
        _api.fetchLaborWorkReports(name: q.isEmpty ? null : q, from: from, to: to),
        _api.fetchLaborWorks(q: q.isEmpty ? null : q, from: from, to: to, limit: 100),
      ]);
      final report = results[0];
      final listRes = results[1];
      final list = (listRes['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _summary = Map<String, dynamic>.from(
          (report['summary'] as Map?) ?? {},
        );
        _rows = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Delete Entry')),
        content: Text(tr('Delete this work entry?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteLaborWork(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Widget _summaryBox(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(label, style: AppText.caption),
          Text(
            value.toStringAsFixed(2),
            style: AppText.title.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receivable = _asDouble(_summary['total_receivable']);
    final received = _asDouble(_summary['total_received']);
    final balance = _asDouble(_summary['balance']);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Work Reports'),
              subtitle: tr('Receivable · Received · Balance'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_work_reports',
                  actions: const [],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: _from ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (p != null) setState(() => _from = p);
                            },
                            child: Text(
                              _from == null
                                  ? tr('From')
                                  : _dateFmt.format(_from!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: _to ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (p != null) setState(() => _to = p);
                            },
                            child: Text(
                              _to == null ? tr('To') : _dateFmt.format(_to!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        labelText: tr('Search'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.filter_alt_rounded),
                          onPressed: _load,
                        ),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _summaryBox(
                                  tr('Receivable'),
                                  receivable,
                                  AppColors.info,
                                  Icons.trending_up_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summaryBox(
                                  tr('Received'),
                                  received,
                                  AppColors.income,
                                  Icons.payments_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summaryBox(
                                  tr('Balance'),
                                  balance,
                                  AppColors.accent,
                                  Icons.account_balance_wallet_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_rows.isEmpty)
                            Center(child: Text(tr('No entries')))
                          else
                            ..._rows.map((row) {
                              final id = _asInt(row['id']);
                              final wage = _asDouble(row['wage']);
                              final hours = _asDouble(row['hours']);
                              final total = wage * hours;
                              final kind = '${row['entry_kind'] ?? ''}';
                              final dateStr =
                                  '${row['date'] ?? ''}'.split('T').first;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppCard(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${row['name'] ?? ''}',
                                      style: AppText.title,
                                    ),
                                    subtitle: Text(
                                      [
                                        dateStr,
                                        kind,
                                        if ('${row['category'] ?? ''}'.isNotEmpty)
                                          '${row['category']}',
                                        total.toStringAsFixed(2),
                                      ].join(' · '),
                                      style: AppText.small,
                                    ),
                                    trailing: id == null
                                        ? null
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.expense,
                                            ),
                                            onPressed: () => _delete(id),
                                          ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
