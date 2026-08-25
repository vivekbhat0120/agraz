import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'config.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'l10n/locale_controller.dart';

const _kindAchiever = 'achiever';
const _kindInnovation = 'innovation';

class AchieversLobbyPage extends StatefulWidget {
  final bool skipNetwork;

  const AchieversLobbyPage({super.key, this.skipNetwork = false});

  @override
  State<AchieversLobbyPage> createState() => _AchieversLobbyPageState();
}

class _AchieversLobbyPageState extends State<AchieversLobbyPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabs;
  final _search = TextEditingController();

  String _kind = _kindAchiever;
  String? _category;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _latest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final next = _tabs.index == 0 ? _kindAchiever : _kindInnovation;
      if (next == _kind) return;
      setState(() {
        _kind = next;
        _category = null;
      });
      _load();
    });
    if (!widget.skipNetwork) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await _api.fetchAchieversLobbyCategories(kind: _kind);
      final latest = await _api.fetchLatestAchieversLobby(kind: _kind);
      final items = await _api.fetchAchieversLobby(
        kind: _kind,
        category: _category,
        q: _search.text,
      );
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _latest = latest;
        _items = items;
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

  String _catLabel(Map<String, dynamic> c) {
    if (!LocaleController.instance.isEnglish) {
      final kn = c['name_kn']?.toString().trim() ?? '';
      if (kn.isNotEmpty) return kn;
    }
    return c['name']?.toString() ?? '';
  }

  Future<void> _openUpload() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchieversLobbyUploadPage()),
    );
    if (mounted && !widget.skipNetwork) await _load();
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AchieversLobbyDetailPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => Scaffold(
        appBar: GradientAppBar(
          title: 'Achievers Lobby',
          actions: withFeedbackAction(
            context,
            menu: 'achievers_lobby',
            actions: [
              IconButton(
                tooltip: tr('Upload video'),
                icon: const Icon(Icons.video_call_rounded),
                onPressed: _openUpload,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openUpload,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.upload_rounded, color: Colors.white),
          label: Text(
            tr('Upload video'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        body: Column(
          children: [
            Material(
              color: AppColors.primaryDark,
              child: TabBar(
                controller: _tabs,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: tr('Achievers')),
                  Tab(text: tr('Innovations')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: tr('Search by name'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: tr('Search'),
                        onPressed: _load,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('lobby-filter-$_kind-${_category ?? ''}'),
                    initialValue: _category ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('Category'),
                      prefixIcon: const Icon(Icons.category_outlined, size: 20),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text(tr('All categories')),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem<String>(
                          value: c['name']?.toString(),
                          child: Text(_catLabel(c)),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() =>
                          _category = (v == null || v.isEmpty) ? null : v);
                      _load();
                    },
                  ),
                ],
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
                                SecondaryButton(
                                  label: tr('Retry'),
                                  onPressed: _load,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                            children: [
                              if (_latest != null) ...[
                                Text(tr('Latest'), style: AppText.title),
                                const SizedBox(height: 8),
                                _LobbyVideoCard(
                                  item: _latest!,
                                  featured: true,
                                  onTap: () => _openDetail(_latest!),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (_items.isEmpty)
                                EmptyState(
                                  icon: Icons.emoji_events_outlined,
                                  title: tr('No videos yet'),
                                  subtitle: tr(
                                    'Approved videos will appear here. You can upload your own video for review.',
                                  ),
                                )
                              else
                                ..._items.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _LobbyVideoCard(
                                      item: item,
                                      onTap: () => _openDetail(item),
                                    ),
                                  ),
                                ),
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

class _LobbyVideoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool featured;

  const _LobbyVideoCard({
    required this.item,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? '';
    final category = item['category']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    final address = item['address']?.toString() ?? '';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: featured ? 64 : 52,
            height: featured ? 64 : 52,
            decoration: BoxDecoration(
              color: featured ? AppColors.accentSoft : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: featured ? AppColors.accent : AppColors.primary,
              size: featured ? 36 : 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (featured)
                  Text(
                    tr('Latest'),
                    style: AppText.caption.copyWith(color: AppColors.accent),
                  ),
                Text(
                  title.isNotEmpty ? title : name,
                  style: AppText.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    name,
                    if (category.isNotEmpty) category,
                    if (address.isNotEmpty) address,
                  ].join(' · '),
                  style: AppText.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class AchieversLobbyDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const AchieversLobbyDetailPage({super.key, required this.item});

  @override
  State<AchieversLobbyDetailPage> createState() =>
      _AchieversLobbyDetailPageState();
}

class _AchieversLobbyDetailPageState extends State<AchieversLobbyDetailPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  String get _title {
    final t = widget.item['title']?.toString().trim() ?? '';
    if (t.isNotEmpty) return t;
    return widget.item['name']?.toString() ?? tr('Achievers Lobby');
  }

  @override
  void initState() {
    super.initState();
    final url = resolveStoreMediaUrl(widget.item['video_url']?.toString() ?? '');
    if (url.isEmpty) return;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          allowPlaybackSpeedChanging: true,
          aspectRatio: _videoController!.value.aspectRatio == 0
              ? 16 / 9
              : _videoController!.value.aspectRatio,
        );
        setState(() {});
      }).catchError((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name']?.toString() ?? '';
    final mobile = widget.item['mobile']?.toString() ?? '';
    final category = widget.item['category']?.toString() ?? '';
    final address = widget.item['address']?.toString() ?? '';
    final description = widget.item['description']?.toString() ?? '';
    final kind = widget.item['kind']?.toString() == _kindInnovation
        ? tr('Innovation')
        : tr('Achiever');

    return Scaffold(
      appBar: GradientAppBar(title: _title),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: Colors.black,
                child: _chewieController == null
                    ? const Center(child: CircularProgressIndicator())
                    : Chewie(controller: _chewieController!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(label: kind, color: AppColors.primary),
              if (category.isNotEmpty)
                InfoChip(label: category, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: AppText.title),
          if (mobile.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(mobile, style: AppText.body),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(address, style: AppText.body),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(description, style: AppText.body),
          ],
        ],
      ),
    );
  }
}

class AchieversLobbyUploadPage extends StatefulWidget {
  final bool skipNetwork;

  const AchieversLobbyUploadPage({super.key, this.skipNetwork = false});

  @override
  State<AchieversLobbyUploadPage> createState() =>
      _AchieversLobbyUploadPageState();
}

class _AchieversLobbyUploadPageState extends State<AchieversLobbyUploadPage> {
  final _api = ApiService();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _title = TextEditingController();
  final _picker = ImagePicker();

  String _kind = _kindAchiever;
  String? _category;
  List<Map<String, dynamic>> _categories = [];
  XFile? _video;
  bool _loadingCats = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (!widget.skipNetwork) {
      _loadCats();
    } else {
      _loadingCats = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    setState(() => _loadingCats = true);
    try {
      final rows = await _api.fetchAchieversLobbyCategories(kind: _kind);
      if (!mounted) return;
      setState(() {
        _categories = rows;
        if (_category != null &&
            !rows.any((c) => c['name']?.toString() == _category)) {
          _category = null;
        }
        _loadingCats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCats = false);
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final len = await file.length();
    if (len > 80 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Video must be under 80 MB'))),
      );
      return;
    }
    setState(() => _video = file);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Please select a video'))),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final url = await _api.uploadAchieversLobbyVideo(
        filePath: _video!.path,
        filename: _video!.name,
      );
      await _api.submitAchieversLobby(
        kind: _kind,
        name: _name.text.trim(),
        mobile: _mobile.text.trim(),
        category: _category ?? '',
        videoUrl: url,
        title: _title.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Submitted for approval. It will appear after admin review.'),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _catLabel(Map<String, dynamic> c) {
    if (!LocaleController.instance.isEnglish) {
      final kn = c['name_kn']?.toString().trim() ?? '';
      if (kn.isNotEmpty) return kn;
    }
    return c['name']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final catItems = _categories
        .map((c) => c['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: GradientAppBar(title: 'Upload video'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('Anyone can share a video. Admin will approve before it is shown.'),
              style: AppText.body,
            ),
            const SizedBox(height: 16),
            AppDropdown(
              label: 'Type',
              value: _kind == _kindInnovation ? 'Innovation' : 'Achiever',
              items: const ['Achiever', 'Innovation'],
              icon: Icons.emoji_events_outlined,
              required: true,
              onChanged: (v) {
                final next =
                    v == 'Innovation' ? _kindInnovation : _kindAchiever;
                setState(() {
                  _kind = next;
                  _category = null;
                });
                _loadCats();
              },
            ),
            const SizedBox(height: 12),
            AppField(
              controller: _name,
              label: 'Name',
              icon: Icons.person_outline_rounded,
              required: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? tr('Required') : null,
            ),
            const SizedBox(height: 12),
            AppField(
              controller: _mobile,
              label: 'Mobile',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              required: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? tr('Required') : null,
            ),
            const SizedBox(height: 12),
            if (_loadingCats)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey('lobby-upload-$_kind-$_category'),
                initialValue: catItems.contains(_category) ? _category : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '${tr('Category')} *',
                  prefixIcon: const Icon(Icons.category_outlined, size: 20),
                ),
                items: _categories
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['name']?.toString(),
                        child: Text(_catLabel(c)),
                      ),
                    )
                    .toList(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? tr('Required') : null,
                onChanged: (v) => setState(() => _category = v),
              ),
            const SizedBox(height: 12),
            AppField(
              controller: _title,
              label: 'Title',
              icon: Icons.title_rounded,
              hint: 'Optional short title',
            ),
            const SizedBox(height: 16),
            AppCard(
              onTap: _submitting ? null : _pickVideo,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const TintedIcon(
                    icon: Icons.videocam_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _video == null
                          ? tr('Select video')
                          : File(_video!.path).uri.pathSegments.last,
                      style: AppText.bodyStrong,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Submit',
              icon: Icons.send_rounded,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
