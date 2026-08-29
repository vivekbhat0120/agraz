import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';

class DailySummaryPage extends StatefulWidget {
  const DailySummaryPage({super.key});

  @override
  State<DailySummaryPage> createState() => _DailySummaryPageState();
}

class _DailySummaryPageState extends State<DailySummaryPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _displayFmt = DateFormat('dd/MM/yyyy');
  final _groupFmt = DateFormat('EEE, d MMM yyyy');

  late DateTime _from;
  late DateTime _to;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  static const _moduleMeta = <String, (IconData, Color)>{
    'income_expense': (Icons.account_balance_wallet_rounded, AppColors.income),
    'organization': (Icons.business_rounded, AppColors.primaryLight),
    'labour': (Icons.engineering_rounded, AppColors.warning),
    'labour_work': (Icons.handshake_rounded, AppColors.primaryLight),
    'dairy': (Icons.water_drop_rounded, AppColors.info),
    'dairy_owner': (Icons.local_drink_rounded, AppColors.primaryLight),
    'notes': (Icons.sticky_note_2_outlined, AppColors.accent),
    'future_plans': (Icons.flag_outlined, AppColors.info),
    'event_manage': (Icons.event_available_rounded, AppColors.warning),
    'rtc': (Icons.map_outlined, AppColors.primaryDark),
    'documents': (Icons.folder_rounded, AppColors.accent),
  };

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, today.day);
    _to = DateTime(today.year, today.month, today.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0.##').format(_num(v))}';

  String _moneyOrDash(dynamic v) {
    final n = _num(v);
    if (n == 0) return '—';
    return _money(n);
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _load({bool retried = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!retried) {
        final token = await getValidAuthToken();
        if (!mounted) return;
        if (token == null) {
          final ok = await ensureLoggedIn(context);
          if (!ok) {
            if (!mounted) return;
            setState(() {
              _error = tr(
                'Invalid or expired JWT. Please login again to continue.',
              );
              _loading = false;
            });
            return;
          }
        }
      }
      if (!mounted) return;
      final data = await _api.fetchDailySummary(
        from: _dateFmt.format(_from),
        to: _dateFmt.format(_to),
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (!retried && (msg.contains('401') || msg.contains('jwt'))) {
        await clearAuthToken();
        if (!mounted) return;
        final ok = await ensureLoggedIn(context, force: true);
        if (ok && mounted) {
          await _load(retried: true);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<DateTime?> _pickDate(DateTime current) {
    return showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _pickFrom() async {
    final picked = await _pickDate(_from);
    if (picked == null) return;
    final d = _dateOnly(picked);
    setState(() {
      _from = d;
      if (_to.isBefore(_from)) _to = _from;
    });
    await _load();
  }

  Future<void> _pickTo() async {
    final picked = await _pickDate(_to);
    if (picked == null) return;
    final d = _dateOnly(picked);
    setState(() {
      _to = d;
      if (_to.isBefore(_from)) _from = _to;
    });
    await _load();
  }

  (IconData, Color) _meta(String key) =>
      _moduleMeta[key] ?? (Icons.list_alt_rounded, AppColors.primary);

  Color _sideColor(String side) {
    switch (side) {
      case 'in':
        return AppColors.income;
      case 'out':
        return AppColors.expense;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _netColor(dynamic v) =>
      _num(v) >= 0 ? AppColors.income : AppColors.expense;

  Widget _dateCell({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.caption.copyWith(fontSize: 10.5),
                  ),
                  Text(
                    _displayFmt.format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(Map<String, dynamic> cat) {
    final key = cat['key']?.toString() ?? '';
    final entries = _list(_data?['entries'])
        .where((e) => (e['category_key']?.toString() ?? e['module']?.toString()) == key)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          builder: (_, scroll) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(cat['label']?.toString() ?? tr('Category details')),
                              style: AppText.h3,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tr('Credit')}: ${_money(cat['credit'])}   ${tr('Debit')}: ${_money(cat['debit'])}',
                              style: AppText.small,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Close'),
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: tr('No entries in this category'),
                        )
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: entries.length,
                          itemBuilder: (_, i) => _entryCard(entries[i]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _balanceRow({
    required String label,
    required dynamic amount,
    Color? color,
  }) {
    final c = color ?? _netColor(amount);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppText.bodyStrong),
          ),
          Text(
            _money(amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(Map<String, dynamic> cat) {
    final module = cat['module']?.toString() ?? '';
    final meta = _meta(module);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      onTap: () => _openCategory(cat),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: meta.$2.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.$1, color: meta.$2, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(cat['label']?.toString() ?? module),
                    style: AppText.bodyStrong,
                  ),
                  Text(
                    '${_int(cat['count'])} ${tr('Entries')}',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                _moneyOrDash(cat['credit']),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.income,
                ),
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                _moneyOrDash(cat['debit']),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.expense,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _list(_data?['categories']);
    if (categories.isEmpty) {
      final modules = _list(_data?['modules']);
      categories.addAll(modules);
    }
    final empty = !_loading &&
        _error == null &&
        categories.isEmpty &&
        _num(_data?['opening_balance']) == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Daily Summary'),
              subtitle: tr('Credit, debit & balances'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'daily_summary',
                  actions: [
                    IconButton(
                      tooltip: tr('Refresh'),
                      onPressed: _loading ? null : _load,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _dateCell(
                        label: tr('From date'),
                        date: _from,
                        onTap: _pickFrom,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dateCell(
                        label: tr('To date'),
                        date: _to,
                        onTap: _pickTo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _load,
                                  child: Text(tr('Retry')),
                                ),
                              ],
                            ),
                          ),
                        )
                      : empty
                          ? AppCard(
                              margin: const EdgeInsets.all(12),
                              child: EmptyState(
                                icon: Icons.menu_book_rounded,
                                title: tr('No entries in this period'),
                                subtitle: tr(
                                  'Entries you make across all options will show here',
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                              children: [
                                _balanceRow(
                                  label: tr('Opening Balance'),
                                  amount: _data?['opening_balance'],
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 0, 28, 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tr('Category'),
                                          style: AppText.caption,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Text(
                                          tr('Credit'),
                                          textAlign: TextAlign.end,
                                          style: AppText.caption.copyWith(
                                            color: AppColors.income,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Text(
                                          tr('Debit'),
                                          textAlign: TextAlign.end,
                                          style: AppText.caption.copyWith(
                                            color: AppColors.expense,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (categories.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      tr('No entries in this period'),
                                      textAlign: TextAlign.center,
                                      style: AppText.small,
                                    ),
                                  )
                                else
                                  ...categories.map(_categoryRow),
                                const SizedBox(height: 4),
                                _balanceRow(
                                  label: tr('Closing Balance'),
                                  amount: _data?['closing_balance'],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tr('Tap a category to see entries'),
                                  textAlign: TextAlign.center,
                                  style: AppText.caption,
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> e) {
    final module = e['module']?.toString() ?? '';
    final meta = _meta(module);
    final side = e['side']?.toString() ?? 'none';
    final amount = _num(e['amount']);
    DateTime? d;
    try {
      d = DateTime.tryParse(e['date']?.toString() ?? '');
    } catch (_) {}
    final dateLabel = d == null ? '' : _groupFmt.format(d);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: meta.$2.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(meta.$1, color: meta.$2, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateLabel.isNotEmpty)
                  Text(dateLabel, style: AppText.caption),
                Text(
                  e['title']?.toString() ?? '',
                  style: AppText.bodyStrong,
                ),
                if ((e['subtitle']?.toString() ?? '').trim().isNotEmpty)
                  Text(
                    e['subtitle'].toString(),
                    style: AppText.small,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (amount != 0)
            Text(
              _money(amount),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _sideColor(side),
              ),
            ),
        ],
      ),
    );
  }
}
