import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'feedback_fab.dart';
import 'labor_categories.dart';
import 'labour_export.dart';
import 'l10n/app_l10n.dart';

(double payable, double receivable) _outstandingFromTotals(
  dynamic totalPayable,
  dynamic totalPaid, {
  dynamic balance,
}) {
  double n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  final bal = balance != null ? n(balance) : n(totalPayable) - n(totalPaid);
  return (bal > 0 ? bal : 0, bal < 0 ? -bal : 0);
}

/// Searchable labourer directory + per-labour schedule summary.
class LabourSummaryPage extends StatefulWidget {
  const LabourSummaryPage({super.key});

  @override
  State<LabourSummaryPage> createState() => _LabourSummaryPageState();
}

class _LabourSummaryPageState extends State<LabourSummaryPage> {
  final ApiService _api = ApiService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _people = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0').format(_num(v).round())}';

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _load({String? q}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people = await _api.fetchLaborPeople(q: q);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load(q: v.trim());
    });
  }

  void _openDetail(Map<String, dynamic> person) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabourerDetailPage(
          name: person['name']?.toString() ?? '',
          mobile: person['mobile']?.toString(),
        ),
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
              title: tr('Labour Summary'),
              subtitle: tr('Search & schedule by labourer'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_summary',
                  actions: [
                    IconButton(
                      tooltip: tr('Refresh'),
                      onPressed: () => _load(q: _searchCtrl.text.trim()),
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: tr('Search by name or mobile…'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _loading
                      ? 'Loading…'
                      : '${_people.length} labourer${_people.length == 1 ? '' : 's'}',
                  style: AppText.caption,
                ),
              ),
            ),
            if (!_loading && _people.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Builder(builder: (_) {
                  double sumPay = 0, sumRec = 0;
                  for (final p in _people) {
                    final o = _outstandingFromTotals(
                      p['total_payable'],
                      p['total_paid'],
                      balance: p['balance'],
                    );
                    sumPay += o.$1;
                    sumRec += o.$2;
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${tr('Total Payable')}: ${_money(sumPay)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.income,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${tr('Total Receivable')}: ${_money(sumRec)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () =>
                                      _load(q: _searchCtrl.text.trim()),
                                  child: Text(tr('Retry')),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _people.isEmpty
                          ? AppCard(
                              margin: EdgeInsets.all(12),
                              child: EmptyState(
                                icon: Icons.person_search_rounded,
                                title: tr('No labourers found'),
                                subtitle:
                                    tr('Add labour entries first, then search here'),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () =>
                                  _load(q: _searchCtrl.text.trim()),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  24,
                                ),
                                itemCount: _people.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final p = _people[i];
                                  final name = p['name']?.toString() ?? '—';
                                  final mobile = p['mobile']?.toString();
                                  final gender = p['gender']?.toString() ?? '';
                                  return AppCard(
                                    onTap: () => _openDetail(p),
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppColors.primarySoft,
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                [
                                                  if (mobile != null &&
                                                      mobile.isNotEmpty)
                                                    mobile,
                                                  if (gender.isNotEmpty) gender,
                                                  '${p['entry_count'] ?? 0} entries',
                                                ].join(' · '),
                                                style: AppText.caption,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Last: ${_fmtDate(p['last_date'])}'
                                                '${(p['last_category']?.toString().isNotEmpty ?? false) ? ' · ${p['last_category']}' : ''}',
                                                style: AppText.caption,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Builder(builder: (_) {
                                              final o = _outstandingFromTotals(
                                                p['total_payable'],
                                                p['total_paid'],
                                                balance: p['balance'],
                                              );
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${tr('Payable')} ${_money(o.$1)}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12,
                                                      color: AppColors.income,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${tr('Receivable')} ${_money(o.$2)}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12,
                                                      color: AppColors.info,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppColors.textMuted,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selected labourer: profile + monthly/weekly schedule + entries.
class LabourerDetailPage extends StatefulWidget {
  final String name;
  final String? mobile;

  const LabourerDetailPage({
    super.key,
    required this.name,
    this.mobile,
  });

  @override
  State<LabourerDetailPage> createState() => _LabourerDetailPageState();
}

class _LabourerDetailPageState extends State<LabourerDetailPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _fromDate;
  DateTime? _toDate;
  String _period = 'Monthly'; // Monthly | Weekly | Custom
  String? _filterCategory;
  List<String> _categories = List<String>.from(kLaborWorkCategories);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _rates = [];
  double _totalPayable = 0;
  double _totalReceivable = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _applyPeriod('Monthly');
    loadLaborCategories().then((cats) {
      if (mounted) setState(() => _categories = cats);
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String? get _mobile {
    final m = widget.mobile?.trim();
    if (m != null && m.isNotEmpty) return m;
    return null;
  }

  Future<void> _showOpeningBalance() async {
    final amountCtrl = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(tr('Opening Balance')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if ((_mobile ?? '').isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_mobile!, style: AppText.caption),
                    ),
                  SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr('Opening amount'),
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      helperText: tr('Positive = payable opening'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: Text(DateFormat('dd/MM/yyyy').format(date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) setLocal(() => date = picked);
                    },
                  ),
                ],
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
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(ctx, true);
                  },
                  child: Text(tr('Save')),
                ),
              ],
            );
          },
        );
      },
    );
    final amount = double.tryParse(amountCtrl.text.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountCtrl.dispose();
    });
    if (ok != true) return;
    if (!mounted) return;
    if (amount == null || amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enter valid amount'))),
      );
      return;
    }
    final result = await _api.createLabor({
      'name': widget.name,
      if (_mobile != null) 'mobile': _mobile,
      'wage': amount.abs(),
      'hours': 1,
      'number_of_labours': 1,
      'entry_kind': 'opening',
      'category': 'Opening Balance',
      'shift': 'fullday',
      'gender': 'Male',
      'work_type': 'Daily Wages',
      'location': 'Farm',
      'date': DateFormat('yyyy-MM-dd').format(date),
      'narration': tr('Opening Balance'),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? tr('Opening balance saved')
              : (result['message']?.toString() ??
                  tr('Failed to save opening balance')),
        ),
      ),
    );
    if (result['success'] == true) await _load();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0').format(_num(v).round())}';

  String _hours(dynamic v) {
    final n = _num(v);
    return n == n.roundToDouble()
        ? n.toStringAsFixed(0)
        : n.toStringAsFixed(1);
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _report?[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _map(String key) {
    final raw = _report?[key];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  void _applyPeriod(String period) {
    final now = DateTime.now();
    _period = period;
    if (period == 'Monthly') {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate = DateTime(now.year, now.month + 1, 0);
      _selectedMonth = DateTime(now.year, now.month);
    } else if (period == 'Weekly') {
      final weekday = now.weekday; // Mon=1
      _fromDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      _toDate = _fromDate!.add(const Duration(days: 6));
    }
  }

  String? get _fromStr =>
      _fromDate == null ? null : DateFormat('yyyy-MM-dd').format(_fromDate!);
  String? get _toStr =>
      _toDate == null ? null : DateFormat('yyyy-MM-dd').format(_toDate!);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchLaborReports(
          year: _selectedMonth.year,
          month: _selectedMonth.month,
          months: 6,
          mobile: _mobile,
          name: _mobile == null ? widget.name : null,
          category: _filterCategory,
        ),
        _api.fetchLabors(
          mobile: _mobile,
          name: _mobile == null ? widget.name : null,
          from: _fromStr,
          to: _toStr,
          category: _filterCategory,
          limit: 200,
        ),
        _api.fetchLaborBalance(
          mobile: _mobile,
          name: _mobile == null ? widget.name : widget.name,
        ),
        if (_mobile != null) _api.fetchLaborRates(mobile: _mobile),
      ]);
      if (!mounted) return;
      final bal = results[2] as Map<String, dynamic>?;
      setState(() {
        _report = results[0] as Map<String, dynamic>;
        _entries = results[1] as List<Map<String, dynamic>>;
        if (bal != null) {
          _totalPayable = _num(bal['payable']);
          _totalReceivable = _num(bal['receivable']);
        } else {
          final allSum = _map('summary');
          final o = _outstandingFromTotals(
            allSum['total_payable'],
            allSum['total_paid'],
            balance: allSum['balance'],
          );
          _totalPayable = o.$1;
          _totalReceivable = o.$2;
        }
        if (results.length > 3) {
          _rates = results[3] as List<Map<String, dynamic>>;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      _period = 'Custom';
      _fromDate = picked;
    });
    _load();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      _period = 'Custom';
      _toDate = picked;
    });
    _load();
  }

  Future<void> _exportExcel() async {
    await shareLabourExcel(
      _entries,
      fileName: 'labour_${widget.name.replaceAll(' ', '_')}.xlsx',
    );
  }

  Future<void> _exportPdf() async {
    await shareLabourStatementPdf(
      title: '${tr('Labour Statement')} — ${widget.name}',
      subtitle: _mobile,
      totalPayable: _totalPayable,
      totalReceivable: _totalReceivable,
      entries: _entries,
      fileName: 'labour_${widget.name.replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final changed = await showLaborEntryEditDialog(context, entry, _api);
    if (changed == true) _load();
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final id = entry['id'];
    final intId = id is int ? id : int.tryParse('$id');
    if (intId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete labour entry?')),
        content: Text(tr('This cannot be undone.')),
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
    if (ok != true) return;
    final deleted = await _api.deleteLabor(intId);
    if (!mounted) return;
    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Labour entry deleted'))),
      );
      _load();
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _map('profile');
    final displayName =
        profile['name']?.toString().isNotEmpty == true
            ? profile['name'].toString()
            : widget.name;
    final displayMobile =
        profile['mobile']?.toString() ?? widget.mobile ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: displayName,
              subtitle: displayMobile.isNotEmpty
                  ? displayMobile
                  : 'Labour schedule',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_summary',
                  actions: [
                    IconButton(
                      tooltip: tr('Opening Balance'),
                      onPressed: _showOpeningBalance,
                      icon: const Icon(Icons.add_card_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Export Excel'),
                      onPressed: _entries.isEmpty ? null : _exportExcel,
                      icon: const Icon(Icons.table_chart_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Statement PDF'),
                      onPressed: _entries.isEmpty ? null : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Refresh'),
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${tr('Total Payable')}: ${_money(_totalPayable)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.income,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${tr('Total Receivable')}: ${_money(_totalReceivable)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(tr('Monthly')),
                        selected: _period == 'Monthly',
                        onSelected: (_) {
                          setState(() => _applyPeriod('Monthly'));
                          _load();
                        },
                      ),
                      ChoiceChip(
                        label: Text(tr('Weekly')),
                        selected: _period == 'Weekly',
                        onSelected: (_) {
                          setState(() => _applyPeriod('Weekly'));
                          _load();
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.date_range_rounded, size: 16),
                        label: Text(
                          _fromDate == null
                              ? tr('From')
                              : DateFormat('d MMM').format(_fromDate!),
                        ),
                        onPressed: _pickFrom,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.event_rounded, size: 16),
                        label: Text(
                          _toDate == null
                              ? tr('To')
                              : DateFormat('d MMM').format(_toDate!),
                        ),
                        onPressed: _pickTo,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _filterCategory,
                    decoration: InputDecoration(
                      labelText: tr('Category'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(tr('All categories')),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _filterCategory = v);
                      _load();
                    },
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.expand_more_rounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              isScrollable: true,
              tabs: [
                Tab(text: tr('Overview')),
                Tab(text: tr('Monthly')),
                Tab(text: tr('Weekly')),
                Tab(text: tr('Entries')),
              ],
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(onPressed: _load, child: Text(tr('Retry'))),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _buildOverview(profile),
                            _buildMonthly(),
                            _buildWeekly(),
                            _buildEntries(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(Map<String, dynamic> profile) {
    final monthSum = _map('month_summary');
    final allSum = _map('summary');
    final byCat = _list('by_category');
    final byShift = _list('by_shift');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile['name']?.toString() ?? widget.name,
                    style: AppText.h3),
                SizedBox(height: 6),
                if ((profile['mobile'] ?? widget.mobile)
                        ?.toString()
                        .isNotEmpty ==
                    true)
                  _kv('Mobile', (profile['mobile'] ?? widget.mobile).toString()),
                if ((profile['gender']?.toString() ?? '').isNotEmpty)
                  _kv('Gender', profile['gender'].toString()),
                if ((profile['last_work_type']?.toString() ?? '').isNotEmpty)
                  _kv('Work type', profile['last_work_type'].toString()),
                if ((profile['last_location']?.toString() ?? '').isNotEmpty)
                  _kv('Last location', profile['last_location'].toString()),
                if ((profile['last_category']?.toString() ?? '').isNotEmpty)
                  _kv('Last category', profile['last_category'].toString()),
              ],
            ),
          ),
          SizedBox(height: 12),
          Text(
            _report?['month_label']?.toString() ?? 'This month',
            style: AppText.h3,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Cost',
                  _money(monthSum['total_cost']),
                  AppColors.primary,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _stat(
                  'Days/Hrs',
                  _hours(monthSum['total_hours']),
                  AppColors.info,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _stat(
                  'Entries',
                  '${monthSum['entry_count'] ?? 0}',
                  AppColors.accent,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('All-time'), style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                _kv('Total cost', _money(allSum['total_cost'])),
                _kv('Total days/hrs', _hours(allSum['total_hours'])),
                _kv('Entries', '${allSum['entry_count'] ?? 0}'),
                _kv('Avg rate', _money(allSum['avg_rate'])),
              ],
            ),
          ),
          if (byCat.isNotEmpty) ...[
            SizedBox(height: 14),
            Text(tr('Category this month'), style: AppText.h3),
            SizedBox(height: 8),
            ...byCat.map((c) {
              final pct = _num(c['pct']).clamp(0, 100).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['category']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _money(c['total_cost']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.primarySoft,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_hours(c['total_hours'])} days/hrs · ${c['count'] ?? 0} entries · ${pct.toStringAsFixed(0)}%',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (byShift.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(tr('Shift this month'), style: AppText.h3),
            SizedBox(height: 8),
            ...byShift.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s['shift']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(_money(s['total_cost'])),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_rates.isNotEmpty) ...[
            SizedBox(height: 14),
            Text(tr('Saved rates'), style: AppText.h3),
            SizedBox(height: 8),
            AppCard(
              child: Column(
                children: _rates
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(r['category']?.toString() ?? '')),
                            Text(
                              _money(r['rate']),
                              style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildMonthly() {
    final monthly = _list('monthly');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(tr('Monthly schedule'), style: AppText.h3),
          SizedBox(height: 4),
          Text(tr('Cost & days by month for this labourer'), style: AppText.caption),
          SizedBox(height: 12),
          if (monthly.isEmpty)
            AppCard(child: Text(tr('No monthly data')))
          else
            ...monthly.reversed.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            m['label']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _money(m['total_cost']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${_hours(m['total_hours'])} days/hrs · ${m['count'] ?? 0} entries',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildWeekly() {
    final weekly = _list('weekly');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(
            'Weekly schedule · ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            style: AppText.h3,
          ),
          SizedBox(height: 4),
          Text(tr('Week-wise work for selected month'), style: AppText.caption),
          SizedBox(height: 12),
          if (weekly.isEmpty)
            AppCard(child: Text(tr('No weekly data')))
          else
            ...weekly.map((w) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w['label']?.toString() ?? 'Week',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _money(w['total_cost']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_hours(w['total_hours'])} days/hrs · ${w['count'] ?? 0} entries',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEntries() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _entries.isEmpty
          ? ListView(
              children: [
                SizedBox(height: 40),
                Center(child: Text(tr('No entries for this labourer'))),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = _entries[i];
                final wage = _num(e['wage']);
                final hours = _num(e['hours']);
                DateTime? date;
                try {
                  date = DateTime.parse(e['date'].toString());
                } catch (_) {}
                return AppCard(
                  onTap: () => _editEntry(e),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e['category']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _money(wage * hours),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            tooltip: tr('Delete'),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.expense, size: 20),
                            onPressed: () => _deleteEntry(e),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        [
                          if (date != null)
                            DateFormat('d MMM yyyy').format(date),
                          e['shift']?.toString() ?? '',
                          e['location']?.toString() ?? '',
                          e['entry_kind']?.toString() ?? '',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: AppText.caption,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Rate ${_money(wage)} × ${_hours(hours)} · ${e['work_type'] ?? ''}',
                        style: AppText.caption,
                      ),
                      if ((e['narration']?.toString() ?? '').isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          e['narration'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(label, style: AppText.caption),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: TextStyle(color: AppColors.textSecondary)),
          ),
          Text(v, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Full labour entry history across all labourers — searchable, with an
/// alphabetical (by name) / newest-first (by date) sort toggle. Unlike the
/// entry page (which only shows the latest 5 entries), this page loads the
/// complete history.
class LaborHistoryPage extends StatefulWidget {
  const LaborHistoryPage({super.key});

  @override
  State<LaborHistoryPage> createState() => _LaborHistoryPageState();
}

class _LaborHistoryPageState extends State<LaborHistoryPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _sortByName = false;
  List<Map<String, dynamic>> _entries = [];
  DateTime? _fromDate;
  DateTime? _toDate;
  String _period = 'All';
  String? _filterCategory;
  List<String> _categories = List<String>.from(kLaborWorkCategories);

  @override
  void initState() {
    super.initState();
    loadLaborCategories().then((cats) {
      if (mounted) setState(() => _categories = cats);
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  void _applyPeriod(String period) {
    final now = DateTime.now();
    _period = period;
    if (period == 'Monthly') {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate = DateTime(now.year, now.month + 1, 0);
    } else if (period == 'Weekly') {
      final weekday = now.weekday;
      _fromDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      _toDate = _fromDate!.add(const Duration(days: 6));
    } else {
      _fromDate = null;
      _toDate = null;
    }
  }

  void _sortEntries() {
    if (_sortByName) {
      _entries.sort((a, b) => (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase()));
    } else {
      _entries.sort((a, b) {
        final da =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
    }
  }

  Future<void> _load({String? q}) async {
    setState(() => _loading = true);
    final rows = await _api.fetchLabors(
      q: q,
      from: _fromDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_fromDate!),
      to: _toDate == null ? null : DateFormat('yyyy-MM-dd').format(_toDate!),
      category: _filterCategory,
      limit: 300,
    );
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _sortEntries();
      _loading = false;
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(q: v.trim()),
    );
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      _period = 'Custom';
      _fromDate = picked;
    });
    _load(q: _searchCtrl.text.trim());
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      _period = 'Custom';
      _toDate = picked;
    });
    _load(q: _searchCtrl.text.trim());
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final changed = await showLaborEntryEditDialog(context, entry, _api);
    if (changed == true) _load(q: _searchCtrl.text.trim());
  }

  Future<void> _exportExcel() async {
    await shareLabourExcel(_entries, fileName: 'labour_history.xlsx');
  }

  Future<void> _exportPdf() async {
    await shareLabourStatementPdf(
      title: tr('Labour History Statement'),
      entries: _entries,
      fileName: 'labour_history.pdf',
    );
  }

  double get _totalCredit {
    var sum = 0.0;
    for (final e in _entries) {
      final kind = (e['entry_kind']?.toString() ?? 'payable').toLowerCase();
      if (kind == 'payment' || kind == 'tally') continue;
      sum += _num(e['wage']) * _num(e['hours']);
    }
    return sum;
  }

  double get _totalDebit {
    var sum = 0.0;
    for (final e in _entries) {
      final kind = (e['entry_kind']?.toString() ?? 'payable').toLowerCase();
      if (kind != 'payment') continue;
      sum += _num(e['wage']) * _num(e['hours']);
    }
    return sum;
  }

  String _money(double v) => '₹${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

  String _entryKindLabel(String? kind) {
    final k = (kind ?? 'payable').toLowerCase();
    if (k == 'payment') return tr('Debit');
    if (k == 'tally') return tr('Tally');
    return tr('Credit'); // payable + opening
  }

  Color _entryKindColor(String? kind) {
    final k = (kind ?? 'payable').toLowerCase();
    if (k == 'payment') return AppColors.expense;
    if (k == 'tally') return AppColors.info;
    return AppColors.income;
  }

  Map<String, double> _extrasFrom(Map e) {
    final extra = e['extra'];
    double toD(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }
    if (extra is Map) {
      return {
        'rent': toD(extra['rent']),
        'food': toD(extra['food']),
        'bonus': toD(extra['bonus']),
      };
    }
    return {'rent': 0.0, 'food': 0.0, 'bonus': 0.0};
  }

  void _showOthersDetail(Map e) {
    final x = _extrasFrom(e);
    final sum = x['rent']! + x['food']! + x['bonus']!;
    if (sum <= 0) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Others')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tr('Rent')}: ${_money(x['rent']!)}'),
            const SizedBox(height: 6),
            Text('${tr('Food')}: ${_money(x['food']!)}'),
            const SizedBox(height: 6),
            Text('${tr('Bonus')}: ${_money(x['bonus']!)}'),
            const Divider(),
            Text(
              '${tr('Total')}: ${_money(sum)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Close'))),
        ],
      ),
    );
  }

  Widget _summaryBox(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
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
              title: tr('History'),
              subtitle: tr('All labour entries'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_summary',
                  actions: [
                    IconButton(
                      tooltip: tr('Export Excel'),
                      onPressed: _entries.isEmpty ? null : _exportExcel,
                      icon: const Icon(Icons.table_chart_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Statement PDF'),
                      onPressed: _entries.isEmpty ? null : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: _sortByName
                          ? tr('Sort by date')
                          : tr('Sort by name'),
                      onPressed: () {
                        setState(() {
                          _sortByName = !_sortByName;
                          _sortEntries();
                        });
                      },
                      icon: Icon(
                        _sortByName
                            ? Icons.sort_by_alpha_rounded
                            : Icons.calendar_today_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: tr('Search by name, category, location…'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                _load();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(tr('All')),
                        selected: _period == 'All',
                        onSelected: (_) {
                          setState(() => _applyPeriod('All'));
                          _load(q: _searchCtrl.text.trim());
                        },
                      ),
                      ChoiceChip(
                        label: Text(tr('Monthly')),
                        selected: _period == 'Monthly',
                        onSelected: (_) {
                          setState(() => _applyPeriod('Monthly'));
                          _load(q: _searchCtrl.text.trim());
                        },
                      ),
                      ChoiceChip(
                        label: Text(tr('Weekly')),
                        selected: _period == 'Weekly',
                        onSelected: (_) {
                          setState(() => _applyPeriod('Weekly'));
                          _load(q: _searchCtrl.text.trim());
                        },
                      ),
                      ActionChip(
                        label: Text(
                          _fromDate == null
                              ? tr('From')
                              : DateFormat('d MMM').format(_fromDate!),
                        ),
                        onPressed: _pickFrom,
                      ),
                      ActionChip(
                        label: Text(
                          _toDate == null
                              ? tr('To')
                              : DateFormat('d MMM').format(_toDate!),
                        ),
                        onPressed: _pickTo,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _filterCategory,
                    decoration: InputDecoration(
                      labelText: tr('Category'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(tr('All categories')),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _filterCategory = v);
                      _load(q: _searchCtrl.text.trim());
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _summaryBox(
                      tr('Credit'),
                      _loading ? '…' : _money(_totalCredit),
                      AppColors.income,
                      Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryBox(
                      tr('Debit'),
                      _loading ? '…' : _money(_totalDebit),
                      AppColors.expense,
                      Icons.trending_down_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryBox(
                      tr('Balance'),
                      _loading ? '…' : _money(_totalCredit - _totalDebit),
                      AppColors.primary,
                      Icons.account_balance_wallet_rounded,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _loading
                      ? tr('Loading…')
                      : '${_entries.length} ${_entries.length == 1 ? tr('entry') : tr('entries')}',
                  style: AppText.caption,
                ),
              ),
            ),
            SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? AppCard(
                          margin: const EdgeInsets.all(12),
                          child: EmptyState(
                            icon: Icons.history_rounded,
                            title: tr('No labour entries found'),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(q: _searchCtrl.text.trim()),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: _entries.length,
                            separatorBuilder: (_, _) => SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final e = _entries[i];
                              final wage = _num(e['wage']);
                              final hours = _num(e['hours']);
                              final kind = e['entry_kind']?.toString();
                              final isTally = (kind ?? '').toLowerCase() == 'tally';
                              final amount = isTally ? 0.0 : wage * hours;
                              final kindColor = _entryKindColor(kind);
                              final extras = _extrasFrom(e);
                              final others =
                                  extras['rent']! + extras['food']! + extras['bonus']!;
                              DateTime? date;
                              try {
                                date = DateTime.parse(e['date'].toString());
                              } catch (_) {}
                              return AppCard(
                                onTap: () => _editEntry(e),
                                padding: const EdgeInsets.all(14),
                                color: isTally
                                    ? AppColors.info.withValues(alpha: 0.08)
                                    : AppColors.surface,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e['name']?.toString() ?? '',
                                            style: AppText.bodyStrong.copyWith(
                                              color: isTally ? AppColors.info : null,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          isTally ? tr('Tally') : _money(amount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: kindColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 4,
                                      children: [
                                        if ((e['category']?.toString() ?? '')
                                            .isNotEmpty)
                                          InfoChip(
                                            label: e['category'].toString(),
                                            color: isTally
                                                ? AppColors.info
                                                : AppColors.expense,
                                          ),
                                        InfoChip(
                                          label: _entryKindLabel(kind),
                                          color: kindColor,
                                        ),
                                        if (!isTally &&
                                            (e['shift']?.toString() ?? '')
                                                .isNotEmpty)
                                          InfoChip(
                                            label: e['shift'].toString(),
                                            color: AppColors.warning,
                                          ),
                                        if ((e['location']?.toString() ?? '')
                                            .isNotEmpty)
                                          InfoChip(
                                            label: e['location'].toString(),
                                            color: AppColors.textMuted,
                                          ),
                                        if (others > 0)
                                          GestureDetector(
                                            onTap: () => _showOthersDetail(e),
                                            child: InfoChip(
                                              label:
                                                  '${tr('Others')} ${_money(others)}',
                                              color: AppColors.accent,
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      [
                                        if (date != null)
                                          DateFormat('dd/MM/yyyy').format(date),
                                        if (!isTally)
                                          '₹${wage.toStringAsFixed(0)} × ${hours.toStringAsFixed(hours == hours.roundToDouble() ? 0 : 1)}',
                                        if (isTally &&
                                            (e['narration']?.toString() ?? '')
                                                .isNotEmpty)
                                          e['narration'].toString(),
                                      ].join('  ·  '),
                                      style: AppText.caption.copyWith(
                                        color: isTally ? AppColors.info : null,
                                      ),
                                    ),
                                    if ((e['narration']?.toString() ?? '')
                                        .isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        e['narration'].toString(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared edit dialog for a labour entry map (history / detail).
Future<bool?> showLaborEntryEditDialog(
  BuildContext context,
  Map<String, dynamic> entry,
  ApiService api,
) async {
  final idRaw = entry['id'];
  final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
  if (id == null) return false;

  final nameCtrl = TextEditingController(text: entry['name']?.toString() ?? '');
  final wageCtrl = TextEditingController(
    text: (entry['wage'] is num
            ? (entry['wage'] as num).toStringAsFixed(0)
            : entry['wage']?.toString()) ??
        '',
  );
  final hoursCtrl = TextEditingController(
    text: entry['hours']?.toString() ?? '1',
  );
  final narrationCtrl =
      TextEditingController(text: entry['narration']?.toString() ?? '');
  final categoryCtrl =
      TextEditingController(text: entry['category']?.toString() ?? '');
  DateTime date =
      DateTime.tryParse(entry['date']?.toString() ?? '') ?? DateTime.now();

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Edit labour entry'), style: AppText.h3),
                  SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: tr('Name')),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: categoryCtrl,
                    decoration: InputDecoration(labelText: tr('Category')),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: wageCtrl,
                          decoration: InputDecoration(labelText: tr('Wage')),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: hoursCtrl,
                          decoration:
                              InputDecoration(labelText: tr('Days / Hour')),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary),
                    title: Text(DateFormat('dd/MM/yyyy').format(date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) setLocal(() => date = picked);
                    },
                  ),
                  TextField(
                    controller: narrationCtrl,
                    decoration:
                        InputDecoration(labelText: tr('Narration (optional)')),
                    maxLines: 2,
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(ctx, false);
                        },
                        child: Text(tr('Cancel')),
                      ),
                      FilledButton(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(ctx, true);
                        },
                        child: Text(tr('Save')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  final name = nameCtrl.text.trim();
  final wage = double.tryParse(wageCtrl.text.trim());
  final hours = double.tryParse(hoursCtrl.text.trim());
  final category = categoryCtrl.text.trim();
  final narration = narrationCtrl.text.trim();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    nameCtrl.dispose();
    wageCtrl.dispose();
    hoursCtrl.dispose();
    narrationCtrl.dispose();
    categoryCtrl.dispose();
  });

  if (saved != true) return false;
  if (name.isEmpty || wage == null || hours == null || hours <= 0) {
    return false;
  }

  final payload = <String, dynamic>{
    'name': name,
    'wage': wage,
    'hours': hours,
    'category': category.isEmpty ? (entry['category'] ?? '') : category,
    'narration': narration,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'shift': entry['shift'] ?? 'fullday',
    'gender': entry['gender'] ?? '',
    'work_type': entry['work_type'] ?? 'Daily Wages',
    'labour_head': entry['labour_head'] ?? '',
    'location': entry['location'] ?? '',
    'number_of_labours': entry['number_of_labours'] ?? 1,
    if ((entry['mobile']?.toString() ?? '').isNotEmpty)
      'mobile': entry['mobile'],
    if ((entry['entry_kind']?.toString() ?? '').isNotEmpty)
      'entry_kind': entry['entry_kind'],
  };

  final result = await api.updateLabor(id, payload);
  return result['success'] == true;
}
