import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_theme.dart';
import 'l10n/app_l10n.dart';
import 'l10n/locale_controller.dart';

/// Shared speech-to-text helper used by Income/Expense (and similar) fields.
class VoiceDictation extends ChangeNotifier {
  VoiceDictation._();
  static final VoiceDictation instance = VoiceDictation._();

  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  String? _activeFieldId;

  bool get isListening => _speech.isListening;
  String? get activeFieldId => _activeFieldId;

  Future<bool> ensureReady() async {
    if (_ready) return true;
    _ready = await _speech.initialize(
      onError: (e) {
        debugPrint('speech error: ${e.errorMsg}');
        _activeFieldId = null;
        notifyListeners();
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _activeFieldId = null;
          notifyListeners();
        }
      },
    );
    return _ready;
  }

  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    _activeFieldId = null;
    notifyListeners();
  }

  String get _localeId =>
      LocaleController.instance.isKannada ? 'kn_IN' : 'en_IN';

  /// Toggle listening for [fieldId]. Appends recognized words into [controller].
  Future<String?> toggle({
    required String fieldId,
    required TextEditingController controller,
  }) async {
    if (_speech.isListening && _activeFieldId == fieldId) {
      await stop();
      return null;
    }
    if (_speech.isListening) {
      await stop();
    }

    final ok = await ensureReady();
    if (!ok) {
      return tr('Speech recognition is not available on this device');
    }

    _activeFieldId = fieldId;
    notifyListeners();

    final base = controller.text;
    final prefix = base.trim().isEmpty ? '' : '${base.trim()} ';

    await _speech.listen(
      onResult: (result) {
        final heard = result.recognizedWords.trim();
        if (heard.isEmpty) return;
        final next = '$prefix$heard';
        controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        if (result.finalResult) {
          _activeFieldId = null;
          notifyListeners();
        }
      },
      localeId: _localeId,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
    return null;
  }
}

/// Unfocus, stop speech, and clear fields now and on the next frame
/// (IME composition can restore text if we only clear once).
void stopVoiceAndClearFields(List<TextEditingController> controllers) {
  VoiceDictation.instance.stop();
  FocusManager.instance.primaryFocus?.unfocus();
  for (final c in controllers) {
    c.clear();
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final c in controllers) {
      if (c.text.isNotEmpty) c.clear();
    }
  });
}

/// Mic button that fills [controller] via speech-to-text.
class VoiceMicButton extends StatelessWidget {
  final String fieldId;
  final TextEditingController controller;
  final VoidCallback? onTextChanged;

  const VoiceMicButton({
    super.key,
    required this.fieldId,
    required this.controller,
    this.onTextChanged,
  });

  Future<void> _tap(BuildContext context) async {
    final err = await VoiceDictation.instance.toggle(
      fieldId: fieldId,
      controller: controller,
    );
    onTextChanged?.call();
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.expense),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VoiceDictation.instance,
      builder: (context, _) {
        final active = VoiceDictation.instance.isListening &&
            VoiceDictation.instance.activeFieldId == fieldId;
        return IconButton(
          tooltip: active ? tr('Stop listening') : tr('Speak to type'),
          onPressed: () => _tap(context),
          icon: Icon(
            active ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: active ? AppColors.expense : AppColors.primary,
            size: 22,
          ),
        );
      },
    );
  }
}
