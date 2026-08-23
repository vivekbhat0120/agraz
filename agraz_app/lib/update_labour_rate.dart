import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

/// Opens a dialog to bulk-update labour rates for a date range.
Future<void> showUpdateLabourRateDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: 420,
        child: UpdateLabourRatePage(embedded: true),
      ),
    ),
  );
}

class UpdateLabourRatePage extends StatefulWidget {
  final bool embedded;

  const UpdateLabourRatePage({super.key, this.embedded = false});

  @override
  State<UpdateLabourRatePage> createState() => _UpdateLabourRatePageState();
}

class _UpdateLabourRatePageState extends State<UpdateLabourRatePage> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  Timer? _debounce;

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  List<Map<String, dynamic>> _people = [];
  Map<String, dynamic>? _selected;
  bool _searching = false;
  bool _submitting = false;
  int? _updatedCount;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() {
        _people = [];
        _searching = false;
      });
      return;
    }
    if (!await _ensureLogin()) return;
    setState(() => _searching = true);
    try {
      final rows = await _api.fetchLaborPeople(q: q);
      if (!mounted) return;
      setState(() => _people = rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickFrom() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => _from = p);
  }

  Future<void> _pickTo() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => _to = p);
  }

  Future<void> _submit() async {
    if (!await _ensureLogin()) return;
    if (!mounted) return;
    final name = '${_selected?['name'] ?? _searchCtrl.text}'.trim();
    final mobile = '${_selected?['mobile'] ?? ''}'.trim();
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    if (name.isEmpty && mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Select a labourer'))),
      );
      return;
    }
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Rate must be greater than zero'))),
      );
      return;
    }
    if (_to.isBefore(_from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('To date must be on or after from date'))),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _updatedCount = null;
    });
    try {
      final res = await _api.bulkUpdateLaborRate(
        name: name,
        mobile: mobile.isEmpty ? null : mobile,
        from: _dateFmt.format(_from),
        to: _dateFmt.format(_to),
        rate: rate,
      );
      if (!mounted) return;
      final count = res['updated_count'];
      setState(() {
        _updatedCount = count is int ? count : int.tryParse('$count');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr('Updated')}: ${_updatedCount ?? 0}',
          ),
          backgroundColor: AppColors.income,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: widget.embedded
          ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
          : const EdgeInsets.fromLTRB(12, 10, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.embedded) ...[
            Text(tr('Update Labour Rate'), style: AppText.h3),
            const SizedBox(height: 4),
            Text(
              tr('Bulk update payable rates by date range'),
              style: AppText.small,
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.embedded)
                  SectionTitle(
                    icon: Icons.currency_exchange_rounded,
                    title: tr('Update Labour Rate'),
                    subtitle: tr('Search labourer & set new rate'),
                  ),
                if (!widget.embedded) const SizedBox(height: 14),
                AppField(
                  controller: _searchCtrl,
                  label: tr('Search labour'),
                  icon: Icons.person_search_rounded,
                  onChanged: _onSearchChanged,
                  hint: tr('Name or mobile'),
                ),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_people.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _people.length,
                      itemBuilder: (context, i) {
                        final row = _people[i];
                        final name = '${row['name'] ?? ''}';
                        final mobile = '${row['mobile'] ?? ''}';
                        final selected = _selected != null &&
                            '${_selected!['name']}' == name &&
                            '${_selected!['mobile'] ?? ''}' == mobile;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          leading: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.person_outline_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(name, style: AppText.bodyStrong),
                          subtitle: mobile.isEmpty
                              ? null
                              : Text(mobile, style: AppText.caption),
                          onTap: () {
                            setState(() {
                              _selected = row;
                              _searchCtrl.text = name;
                              _people = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                if (_selected != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tr('Selected')}: ${_selected!['name']}'
                      '${_selected!['mobile'] != null && '${_selected!['mobile']}'.isNotEmpty ? ' · ${_selected!['mobile']}' : ''}',
                      style: AppText.bodyStrong,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickFrom,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: tr('From'),
                            prefixIcon: const Icon(Icons.date_range_rounded),
                          ),
                          child: Text(_dateFmt.format(_from)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTo,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: tr('To'),
                            prefixIcon: const Icon(Icons.event_rounded),
                          ),
                          child: Text(_dateFmt.format(_to)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _rateCtrl,
                  label: tr('New rate'),
                  icon: Icons.currency_rupee_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  required: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: tr('Update rates'),
            icon: Icons.save_rounded,
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          if (_updatedCount != null) ...[
            const SizedBox(height: 12),
            AppCard(
              color: AppColors.incomeSoft,
              child: Text(
                '${tr('Updated count')}: $_updatedCount',
                style: AppText.title.copyWith(color: AppColors.income),
              ),
            ),
          ],
          if (widget.embedded) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Close')),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: _buildBody(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Update Labour Rate'),
              subtitle: tr('Bulk rate by date range'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'update_labour_rate',
                  actions: const [],
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
