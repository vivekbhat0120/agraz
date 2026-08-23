import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'config.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';
import 'uk_land_geo.dart';

class RtcEntryPage extends StatefulWidget {
  const RtcEntryPage({super.key});

  @override
  State<RtcEntryPage> createState() => _RtcEntryPageState();
}

class _RtcEntryPageState extends State<RtcEntryPage> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  int? _editingId;
  String _state = UkLandGeo.defaultState;
  String _district = UkLandGeo.defaultDistrict;
  String _taluk = UkLandGeo.defaultTaluk;
  String? _hobli;
  final _surveyCtrl = TextEditingController();
  final _hissaCtrl = TextEditingController();
  final _acreCtrl = TextEditingController(text: '0');
  final _guntaCtrl = TextEditingController(text: '0');
  final _anaCtrl = TextEditingController(text: '0');
  final _detailsCtrl = TextEditingController();
  String _documentUrl = '';
  String? _localFilePath;
  String? _localFileName;

  static const _detailShortcuts = [
    'Owner self',
    'Joint holders',
    'Cultivated',
    'Arecanut',
    'Paddy',
    'Forest edge',
    'Irrigation well',
  ];

  @override
  void initState() {
    super.initState();
    _hobli = UkLandGeo.hoblisFor(_taluk).isNotEmpty
        ? UkLandGeo.hoblisFor(_taluk).first
        : null;
    _acreCtrl.addListener(_onAreaChanged);
    _guntaCtrl.addListener(_onAreaChanged);
    _anaCtrl.addListener(_onAreaChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _surveyCtrl.dispose();
    _hissaCtrl.dispose();
    _acreCtrl.dispose();
    _guntaCtrl.dispose();
    _anaCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _onAreaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    final ok = await _ensureLogin();
    if (!ok) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _load();
  }

  Future<bool> _ensureLogin() async {
    var token = await getAuthToken();
    if (token != null && token.isNotEmpty) return true;
    if (!mounted) return false;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (loggedIn != true) return false;
    token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchMyLandRtcs();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  ({int acre, int gunta, int ana, double totalAcres}) get _area {
    return UkLandGeo.normalizeArea(
      acre: int.tryParse(_acreCtrl.text.trim()) ?? 0,
      gunta: int.tryParse(_guntaCtrl.text.trim()) ?? 0,
      ana: int.tryParse(_anaCtrl.text.trim()) ?? 0,
    );
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _state = UkLandGeo.defaultState;
      _district = UkLandGeo.defaultDistrict;
      _taluk = UkLandGeo.defaultTaluk;
      final hoblis = UkLandGeo.hoblisFor(_taluk);
      _hobli = hoblis.isNotEmpty ? hoblis.first : null;
      _surveyCtrl.clear();
      _hissaCtrl.clear();
      _acreCtrl.text = '0';
      _guntaCtrl.text = '0';
      _anaCtrl.text = '0';
      _detailsCtrl.clear();
      _documentUrl = '';
      _localFilePath = null;
      _localFileName = null;
    });
  }

  void _fillFromRow(Map<String, dynamic> row) {
    final taluk = (row['taluk'] ?? UkLandGeo.defaultTaluk).toString();
    final hoblis = UkLandGeo.hoblisFor(taluk);
    final hobliVal = (row['hobli'] ?? '').toString();
    setState(() {
      _editingId = row['id'] is int ? row['id'] as int : int.tryParse('${row['id']}');
      _state = (row['state'] ?? UkLandGeo.defaultState).toString();
      _district = (row['district'] ?? UkLandGeo.defaultDistrict).toString();
      _taluk = taluk;
      _hobli = hobliVal.isEmpty
          ? (hoblis.isNotEmpty ? hoblis.first : null)
          : (hoblis.contains(hobliVal) ? hobliVal : hobliVal);
      _surveyCtrl.text = (row['survey_number'] ?? '').toString();
      _hissaCtrl.text = (row['hissa'] ?? '').toString();
      _acreCtrl.text = '${row['acre'] ?? 0}';
      _guntaCtrl.text = '${row['gunta'] ?? 0}';
      _anaCtrl.text = '${row['ana'] ?? 0}';
      _detailsCtrl.text = (row['details'] ?? '').toString();
      _documentUrl = (row['document_url'] ?? '').toString();
      _localFilePath = null;
      _localFileName = null;
    });
  }

  Future<void> _pickCamera() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (shot == null) return;
    setState(() {
      _localFilePath = shot.path;
      _localFileName = shot.name;
      _documentUrl = '';
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    setState(() {
      _localFilePath = f.path;
      _localFileName = f.name;
      _documentUrl = '';
    });
  }

  Future<void> _save() async {
    final survey = _surveyCtrl.text.trim();
    if (survey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Survey number is required'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var docUrl = _documentUrl;
      if (_localFilePath != null && _localFilePath!.isNotEmpty) {
        docUrl = await _api.uploadLandRtcDocument(
          filePath: _localFilePath!,
          filename: _localFileName,
        );
      }
      final area = _area;
      final body = <String, dynamic>{
        'state': _state,
        'district': _district,
        'taluk': _taluk,
        'hobli': _hobli ?? '',
        'survey_number': survey,
        'hissa': _hissaCtrl.text.trim(),
        'acre': area.acre,
        'gunta': area.gunta,
        'ana': area.ana,
        'details': _detailsCtrl.text.trim(),
        'document_url': docUrl,
      };
      if (_editingId != null) {
        await _api.updateLandRtc(_editingId!, body);
      } else {
        await _api.createLandRtc(body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(_editingId != null ? 'RTC updated' : 'RTC saved')),
        ),
      );
      _resetForm();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id'] is int ? row['id'] as int : int.tryParse('${row['id']}');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete RTC?')),
        content: Text(
          trf('Delete survey {0} / {1}?\nThis cannot be undone.', [
            row['survey_number'] ?? '',
            row['hissa'] ?? '-',
          ]),
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
    if (ok != true) return;
    try {
      await _api.deleteLandRtc(id);
      if (_editingId == id) _resetForm();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('RTC deleted'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _appendDetailShortcut(String chip) {
    final cur = _detailsCtrl.text.trim();
    if (cur.isEmpty) {
      _detailsCtrl.text = chip;
    } else if (!cur.toLowerCase().contains(chip.toLowerCase())) {
      _detailsCtrl.text = '$cur, $chip';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hoblis = UkLandGeo.hoblisFor(_taluk);
    final area = _area;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: tr('RTC Entry'),
        actions: [
          if (_editingId != null)
            TextButton(
              onPressed: _resetForm,
              child: Text(tr('New'), style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _buildFormCard(hoblis, area),
            const SizedBox(height: 18),
            Text(
              tr('My RTC records'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.expense)),
                    TextButton(onPressed: _load, child: Text(tr('Retry'))),
                  ],
                ),
              )
            else if (_rows.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(tr('No RTC entries yet. Add one above.')),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rows.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, i) => _RtcCard(
                  row: _rows[i],
                  onEdit: () => _fillFromRow(_rows[i]),
                  onDelete: () => _confirmDelete(_rows[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(
    List<String> hoblis,
    ({int acre, int gunta, int ana, double totalAcres}) area,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editingId == null
                ? tr('New RTC entry')
                : trf('Edit RTC #{0}', [_editingId]),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: tr('State'),
            value: _state,
            items: UkLandGeo.states,
            onChanged: (v) => setState(() => _state = v!),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: tr('District'),
            value: _district,
            items: UkLandGeo.districts,
            onChanged: (v) => setState(() => _district = v!),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: tr('Taluk'),
            value: _taluk,
            items: UkLandGeo.taluks,
            onChanged: (v) {
              final t = v!;
              final list = UkLandGeo.hoblisFor(t);
              setState(() {
                _taluk = t;
                _hobli = list.isNotEmpty ? list.first : null;
              });
            },
          ),
          const SizedBox(height: 10),
          if (hoblis.isEmpty)
            TextFormField(
              decoration: _dec(tr('Hobli')),
              initialValue: _hobli,
              onChanged: (v) => _hobli = v.trim(),
            )
          else
            DropdownButtonFormField<String>(
              value: hoblis.contains(_hobli) ? _hobli : hoblis.first,
              decoration: _dec(tr('Hobli')),
              items: hoblis
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: (v) => setState(() => _hobli = v),
            ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _surveyCtrl,
            decoration: _dec(tr('Survey number *')),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _hissaCtrl,
            decoration: _dec(tr('Hissa')),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _acreCtrl,
                  decoration: _dec(tr('Acre')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _guntaCtrl,
                  decoration: _dec(tr('Gunta')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _anaCtrl,
                  decoration: _dec(tr('Ana')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trf('Total: {0} A – {1} G – {2} An ({3} acre)', [
                area.acre,
                area.gunta,
                area.ana,
                UkLandGeo.formatTotal(area.totalAcres),
              ]),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _detailsCtrl,
            decoration: _dec(tr('Details / notes')),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 8),
          Text(
            tr('Shortcuts for details'),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _detailShortcuts
                .map(
                  (s) => ActionChip(
                    label: Text(tr(s), style: const TextStyle(fontSize: 12)),
                    onPressed: () => _appendDetailShortcut(s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            tr('Upload RTC document'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCamera,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(tr('Camera')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(tr('PDF/JPG')),
                ),
              ),
            ],
          ),
          if (_localFilePath != null || _documentUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _docPreview(),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(tr(_editingId == null ? 'Save RTC' : 'Update RTC')),
          ),
        ],
      ),
    );
  }

  Widget _docPreview() {
    final isLocalImage = _localFilePath != null &&
        ['.jpg', '.jpeg', '.png', '.webp']
            .any((e) => _localFilePath!.toLowerCase().endsWith(e));
    final remote = _documentUrl.isNotEmpty ? resolveStoreMediaUrl(_documentUrl) : '';
    final isRemoteImage = remote.isNotEmpty &&
        !remote.toLowerCase().endsWith('.pdf');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (isLocalImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_localFilePath!),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
          else if (isRemoteImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                remote,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.insert_drive_file),
              ),
            )
          else
            const Icon(Icons.picture_as_pdf, color: AppColors.expense, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _localFileName ??
                  (_documentUrl.isNotEmpty ? p.basename(_documentUrl) : tr('Document')),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: tr('Remove'),
            onPressed: () => setState(() {
              _localFilePath = null;
              _localFileName = null;
              _documentUrl = '';
            }),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.field,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: _dec(label),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _RtcCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RtcCard({
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final survey = (row['survey_number'] ?? '').toString();
    final hissa = (row['hissa'] ?? '').toString();
    final taluk = (row['taluk'] ?? '').toString();
    final hobli = (row['hobli'] ?? '').toString();
    final acre = row['acre'] ?? 0;
    final gunta = row['gunta'] ?? 0;
    final ana = row['ana'] ?? 0;
    final total = row['total_acres'];
    final doc = (row['document_url'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sy $survey${hissa.isNotEmpty ? '/$hissa' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Edit'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.info),
              ),
              IconButton(
                tooltip: tr('Delete'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.expense),
              ),
            ],
          ),
          Text(
            '$taluk · $hobli',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '$acre A · $gunta G · $ana An',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (total != null)
            Text(
              trf('Total {0} acre', [total]),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          const Spacer(),
          if (doc.isNotEmpty)
            Row(
              children: [
                Icon(
                  doc.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf
                      : Icons.image_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tr('Document attached'),
                    style: const TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
