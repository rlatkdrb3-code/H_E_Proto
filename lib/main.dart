import 'dart:convert';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ink/ink_canvas.dart';
import 'ink/ink_models.dart';
import 'ink/ink_toolbar.dart';

void main() {
  runApp(const InkLecturePrototypeApp());
}

enum PrototypeVariant { a, b }

const _defaultSheetEndpoint =
    'https://script.google.com/macros/s/AKfycbxPIHJYPo0VotYjlftKwe4rtaQ-0mOKyD7elNp-wCtEEYjQ84hmbWLA2O9tMnwYIZGw/exec';
const _defaultSheetToken = 'a6d087b47cddd90b7b0b9b1cf6ea4a26';
const _sheetEndpoint = String.fromEnvironment(
  'SHEET_ENDPOINT',
  defaultValue: _defaultSheetEndpoint,
);
const _sheetToken = String.fromEnvironment(
  'SHEET_TOKEN',
  defaultValue: _defaultSheetToken,
);

class ToolSwitchLog {
  final int trial;
  final DateTime timestamp;
  final int? elapsedMs;
  final bool isTemporaryMode;
  final String from;
  final String to;
  final int? accessDurationMs;
  int? switchDurationMs;
  final bool misoperation;

  ToolSwitchLog({
    required this.trial,
    required this.timestamp,
    required this.elapsedMs,
    required this.isTemporaryMode,
    required this.from,
    required this.to,
    required this.accessDurationMs,
    this.switchDurationMs,
    required this.misoperation,
  });

  Map<String, dynamic> toJson() => {
    'trial': trial,
    'timestamp': _formatClockTime(timestamp),
    'timestampIso': timestamp.toIso8601String(),
    'elapsedSec': _secondsFromMs(elapsedMs),
    'elapsedMs': _secondsFromMs(elapsedMs),
    'isTemporaryMode': isTemporaryMode ? 1 : 0,
    'from': from,
    'to': to,
    'accessDurationSec': _secondsFromMs(accessDurationMs),
    'accessDurationMs': _secondsFromMs(accessDurationMs),
    'switchDurationSec': _secondsFromMs(switchDurationMs),
    'switchDurationMs': _secondsFromMs(switchDurationMs),
    'misoperation': misoperation ? 1 : 0,
  };

  static double? _secondsFromMs(int? milliseconds) {
    if (milliseconds == null) {
      return null;
    }
    return double.parse((milliseconds / 1000).toStringAsFixed(2));
  }

  static String _formatClockTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

class InkLecturePrototypeApp extends StatelessWidget {
  final PrototypeVariant? initialVariant;

  const InkLecturePrototypeApp({super.key, this.initialVariant});

  @override
  Widget build(BuildContext context) {
    final variant = initialVariant ?? _variantFromUrl();
    return MaterialApp(
      title: '화상강의',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4C5AC7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F5F9),
        fontFamily: 'Apple SD Gothic Neo',
      ),
      home: LectureInkPrototypeScreen(variant: variant),
    );
  }

  PrototypeVariant _variantFromUrl() {
    const variantOverride = String.fromEnvironment('PROTOTYPE_VARIANT');
    if (variantOverride.toLowerCase() == 'b') {
      return PrototypeVariant.b;
    }
    if (variantOverride.toLowerCase() == 'a') {
      return PrototypeVariant.a;
    }
    final variantName = Uri.base.queryParameters['variant']?.toLowerCase();
    return variantName == 'b' ? PrototypeVariant.b : PrototypeVariant.a;
  }
}

class LectureInkPrototypeScreen extends StatefulWidget {
  final PrototypeVariant variant;

  const LectureInkPrototypeScreen({super.key, required this.variant});

  @override
  State<LectureInkPrototypeScreen> createState() =>
      _LectureInkPrototypeScreenState();
}

class _LectureInkPrototypeScreenState extends State<LectureInkPrototypeScreen> {
  final List<InkStroke> _strokes = <InkStroke>[];
  List<InkPreset> _presets = InkPreset.defaults();
  late PrototypeVariant _variant;
  int _selectedPresetIndex = 0;
  bool _inkEnabled = true;
  bool _isStrokeActive = false;
  bool _isTestRunning = false;
  bool _isCountdownActive = false;
  bool _bottomPresetTrayOpen = false;
  int? _holdOriginalPresetIndex;
  int? _hoverPresetIndex;
  DateTime? _lastStrokeEndedAt;
  DateTime? _lastToolPointerDownAt;
  int _switchesSinceStroke = 0;
  bool _misoperationCounted = false;
  DateTime? _testStartedAt;
  int _trialCounter = 0;
  bool _isSubmitting = false;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;
  Timer? _testElapsedTimer;
  int _testElapsedSeconds = 0;
  String? _userId;
  final List<ToolSwitchLog> _toolSwitchLogs = <ToolSwitchLog>[];

  @override
  void initState() {
    super.initState();
    _variant = widget.variant;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _testElapsedTimer?.cancel();
    super.dispose();
  }

  InkPreset get _selectedPreset => _presets[_selectedPresetIndex];
  bool get _isVariantB => _variant == PrototypeVariant.b;
  int get _eraserPresetIndex =>
      _presets.indexWhere((preset) => preset.tool == InkTool.eraser);
  void _selectPreset(int index) {
    if (index < 0 || index >= _presets.length) {
      return;
    }
    _recordToolSwitch(index);
    setState(() {
      _selectedPresetIndex = index;
      _inkEnabled = true;
      _bottomPresetTrayOpen = false;
    });
  }

  Future<void> _toggleTest() async {
    if (_isCountdownActive) {
      return;
    }
    final willStart = !_isTestRunning;
    if (!willStart) {
      final logs = List<ToolSwitchLog>.from(_toolSwitchLogs);
      final startedAt = _testStartedAt;
      final endedAt = DateTime.now();
      _stopElapsedTimer(endedAt: endedAt);
      setState(() {
        _isTestRunning = false;
        _lastStrokeEndedAt = null;
        _lastToolPointerDownAt = null;
        _switchesSinceStroke = 0;
        _misoperationCounted = false;
      });
      await _submitTestLogs(logs, startedAt: startedAt, endedAt: endedAt);
      return;
    }
    final userId = await _ensureUserId();
    if (userId == null || !mounted) {
      return;
    }
    _startCountdown(userId);
  }

  void _startCountdown(String userId) {
    _countdownTimer?.cancel();
    setState(() {
      _isCountdownActive = true;
      _countdownSeconds = 5;
      _userId = userId;
      _inkEnabled = true;
      _lastStrokeEndedAt = null;
      _lastToolPointerDownAt = null;
      _switchesSinceStroke = 0;
      _misoperationCounted = false;
      _toolSwitchLogs.clear();
      _trialCounter = 0;
      _testElapsedSeconds = 0;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        _beginTestSession(userId);
        return;
      }
      setState(() {
        _countdownSeconds -= 1;
      });
    });
  }

  void _beginTestSession(String userId) {
    final startedAt = DateTime.now();
    setState(() {
      _isCountdownActive = false;
      _isTestRunning = true;
      _inkEnabled = true;
      _lastStrokeEndedAt = null;
      _lastToolPointerDownAt = null;
      _switchesSinceStroke = 0;
      _misoperationCounted = false;
      _toolSwitchLogs.clear();
      _trialCounter = 0;
      _testStartedAt = startedAt;
      _userId = userId;
    });
    _startElapsedTimer(startedAt);
  }

  void _startElapsedTimer(DateTime startedAt) {
    _testElapsedTimer?.cancel();
    _testElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _testElapsedTimer?.cancel();
        return;
      }
      setState(() {
        _testElapsedSeconds = DateTime.now().difference(startedAt).inSeconds;
      });
    });
  }

  void _stopElapsedTimer({required DateTime endedAt}) {
    _testElapsedTimer?.cancel();
    final startedAt = _testStartedAt;
    if (startedAt == null || !mounted) {
      return;
    }
    setState(() {
      _testElapsedSeconds = endedAt.difference(startedAt).inSeconds;
    });
  }

  Future<String?> _ensureUserId() async {
    final current = _userId?.trim();
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('피실험자 ID'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'userID',
              hintText: '예: 7011',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('시작'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) {
      return null;
    }
    _userId = result.trim();
    return _userId;
  }

  Future<void> _submitTestLogs(
    List<ToolSwitchLog> logs, {
    required DateTime? startedAt,
    required DateTime endedAt,
  }) async {
    if (!mounted) {
      return;
    }
    if (_sheetEndpoint.isEmpty) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    final payload = {
      'token': _sheetToken,
      'userID': _userId ?? '',
      'type': _variant == PrototypeVariant.a ? 'A' : 'B',
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'rows': logs.map((log) => log.toJson()).toList(),
    };
    try {
      final response = await http
          .post(
            Uri.parse(_sheetEndpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) {
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Test data submission failed: HTTP ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Test data submission failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _switchVariant(PrototypeVariant variant) {
    if (_variant == variant) {
      return;
    }
    setState(() {
      _variant = variant;
      _inkEnabled = true;
      _bottomPresetTrayOpen = false;
      _holdOriginalPresetIndex = null;
      _hoverPresetIndex = null;
    });
  }

  void _handleToolPointerDown(int index) {
    if (!_isTestRunning) {
      return;
    }
    if (index < 0 || index >= _presets.length) {
      return;
    }
    _lastToolPointerDownAt = DateTime.now();
  }

  void _recordToolSwitch(int nextIndex, {bool isTemporaryMode = false}) {
    if (!_isTestRunning || nextIndex == _selectedPresetIndex) {
      return;
    }
    final toolPointerDownAt = _lastToolPointerDownAt ?? DateTime.now();
    var misoperation = false;
    if (_lastStrokeEndedAt != null) {
      _switchesSinceStroke += 1;
      misoperation = _switchesSinceStroke >= 2;
      if (misoperation && !_misoperationCounted) {
        _misoperationCounted = true;
      }
    }
    _toolSwitchLogs.add(
      ToolSwitchLog(
        trial: ++_trialCounter,
        timestamp: toolPointerDownAt,
        elapsedMs: _testStartedAt == null
            ? null
            : toolPointerDownAt.difference(_testStartedAt!).inMilliseconds,
        isTemporaryMode: isTemporaryMode,
        from: _toolNameForPreset(_presets[_selectedPresetIndex]),
        to: _toolNameForPreset(_presets[nextIndex], temporary: isTemporaryMode),
        accessDurationMs: _accessDurationSinceLastStroke(toolPointerDownAt),
        misoperation: misoperation,
      ),
    );
  }

  void _recordToolSwitchFrom(
    int previousIndex,
    int nextIndex, {
    bool isTemporaryMode = false,
  }) {
    if (!_isTestRunning || nextIndex == previousIndex) {
      return;
    }
    final toolPointerDownAt = _lastToolPointerDownAt ?? DateTime.now();
    var misoperation = false;
    if (_lastStrokeEndedAt != null) {
      _switchesSinceStroke += 1;
      misoperation = _switchesSinceStroke >= 2;
      if (misoperation && !_misoperationCounted) {
        _misoperationCounted = true;
      }
    }
    _toolSwitchLogs.add(
      ToolSwitchLog(
        trial: ++_trialCounter,
        timestamp: toolPointerDownAt,
        elapsedMs: _testStartedAt == null
            ? null
            : toolPointerDownAt.difference(_testStartedAt!).inMilliseconds,
        isTemporaryMode: isTemporaryMode,
        from: _toolNameForPreset(_presets[previousIndex]),
        to: _toolNameForPreset(_presets[nextIndex], temporary: isTemporaryMode),
        accessDurationMs: _accessDurationSinceLastStroke(toolPointerDownAt),
        misoperation: misoperation,
      ),
    );
  }

  int? _accessDurationSinceLastStroke(DateTime toolPointerDownAt) {
    final strokeEndedAt = _lastStrokeEndedAt;
    if (strokeEndedAt == null || toolPointerDownAt.isBefore(strokeEndedAt)) {
      return null;
    }
    return toolPointerDownAt.difference(strokeEndedAt).inMilliseconds;
  }

  void _handleInkPointerDown(DateTime timestamp) {
    if (!_isTestRunning) {
      return;
    }
    final pendingLog = _toolSwitchLogs.isEmpty ? null : _toolSwitchLogs.last;
    if (pendingLog != null && pendingLog.switchDurationMs == null) {
      pendingLog.switchDurationMs = timestamp
          .difference(pendingLog.timestamp)
          .inMilliseconds;
    }
  }

  void _handleInkPointerUp(DateTime timestamp) {
    if (!_isTestRunning) {
      return;
    }
    _lastStrokeEndedAt = timestamp;
  }

  String _toolNameForPreset(InkPreset preset, {bool temporary = false}) {
    if (preset.tool == InkTool.eraser) {
      return temporary ? 'Temporary Eraser' : 'Eraser';
    }
    if (preset.tool == InkTool.highlighter) {
      return 'Highlighter';
    }
    if (preset.color.toARGB32() == const Color(0xFFE53935).toARGB32()) {
      return 'Red';
    }
    if (preset.color.toARGB32() == const Color(0xFF1E88E5).toARGB32()) {
      return 'Blue';
    }
    return 'Black';
  }

  void _handleStrokeActiveChanged(bool active) {
    if (_isStrokeActive == active) {
      return;
    }
    final now = DateTime.now();
    setState(() {
      _isStrokeActive = active;
      if (!_isTestRunning) {
        return;
      }
      if (active) {
        _switchesSinceStroke = 0;
        _misoperationCounted = false;
      } else {
        _lastStrokeEndedAt = now;
        _switchesSinceStroke = 0;
        _misoperationCounted = false;
      }
    });
  }

  void _startBottomHold() {
    if (_bottomPresetTrayOpen) {
      return;
    }
    final eraserIndex = _eraserPresetIndex;
    if (eraserIndex < 0) {
      return;
    }
    setState(() {
      _holdOriginalPresetIndex = _selectedPresetIndex;
      _recordToolSwitch(eraserIndex, isTemporaryMode: true);
      _selectedPresetIndex = eraserIndex;
      _hoverPresetIndex = null;
      _bottomPresetTrayOpen = true;
      _inkEnabled = true;
    });
  }

  void _updateBottomHoldTarget(int? index) {
    if (_hoverPresetIndex == index) {
      return;
    }
    final eraserIndex = _eraserPresetIndex;
    setState(() {
      _hoverPresetIndex = index;
      _selectedPresetIndex = eraserIndex;
    });
  }

  void _endBottomHold(int? index) {
    final originalIndex = _holdOriginalPresetIndex;
    final nextIndex = index ?? originalIndex;
    if (_isTestRunning) {
      _lastToolPointerDownAt = DateTime.now();
    }
    if (originalIndex != null &&
        nextIndex != null &&
        nextIndex != originalIndex) {
      _recordToolSwitchFrom(originalIndex, nextIndex);
    }
    setState(() {
      if (nextIndex != null && nextIndex >= 0 && nextIndex < _presets.length) {
        _selectedPresetIndex = nextIndex;
      }
      _holdOriginalPresetIndex = null;
      _hoverPresetIndex = null;
      _bottomPresetTrayOpen = false;
      _inkEnabled = true;
    });
  }

  Future<void> _openPresetEditor() async {
    final index = _selectedPresetIndex;
    final preset = await showModalBottomSheet<InkPreset>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => InkPresetEditorSheet(
        initialPreset: _presets[index],
        presetNumber: index + 1,
      ),
    );
    if (preset == null || !mounted) {
      return;
    }
    setState(() {
      final next = List<InkPreset>.from(_presets);
      next[index] = preset;
      _presets = next;
      _inkEnabled = true;
    });
  }

  void _undoStroke() {
    if (_strokes.isEmpty) {
      return;
    }
    setState(() {
      _strokes.removeLast();
    });
  }

  void _clearStrokes() {
    if (_strokes.isEmpty) {
      return;
    }
    setState(() {
      _strokes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            return Stack(
              children: [
                Column(
                  children: [
                    _TopTestBar(
                      variant: _variant,
                      onVariantChanged: _switchVariant,
                      inkEnabled: _inkEnabled,
                      presets: _presets,
                      selectedPresetIndex: _selectedPresetIndex,
                      hasStrokes: _strokes.isNotEmpty,
                      isTestRunning: _isTestRunning,
                      onEnabledChanged: (enabled) =>
                          setState(() => _inkEnabled = enabled),
                      onPresetSelected: _selectPreset,
                      onPresetPointerDown: _handleToolPointerDown,
                      onCustomize: _openPresetEditor,
                      onUndo: _undoStroke,
                      onClear: _clearStrokes,
                      onToggleTest: () => _toggleTest(),
                      isSubmitting: _isSubmitting,
                      isCountdownActive: _isCountdownActive,
                      elapsedSeconds: _testElapsedSeconds,
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 28,
                          compact ? 12 : 24,
                          compact ? 12 : 28,
                          compact ? 12 : 24,
                        ),
                        child: _buildLectureCanvas(),
                      ),
                    ),
                  ],
                ),
                if (_isCountdownActive)
                  Positioned.fill(
                    child: _CountdownOverlay(seconds: _countdownSeconds),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLectureCanvas() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Positioned.fill(
            child: InkAnnotationLayer(
              enabled: _inkEnabled,
              tool: _selectedPreset.tool,
              color: _selectedPreset.color,
              width: _selectedPreset.width,
              allowTouchInput: false,
              strokes: _strokes,
              onChanged: (strokes) => setState(() {
                _strokes
                  ..clear()
                  ..addAll(strokes);
              }),
              onStrokeActiveChanged: _handleStrokeActiveChanged,
              onInkPointerDown: _handleInkPointerDown,
              onInkPointerUp: _handleInkPointerUp,
              child: _LectureSlide(scrollLocked: _isStrokeActive),
            ),
          ),
          if (_isVariantB)
            Positioned(
              left: -34,
              bottom: -26,
              child: InkExclusionZone(
                padding: const EdgeInsets.all(12),
                child: _BottomPresetLauncher(
                  presets: _presets,
                  selectedPresetIndex: _selectedPresetIndex,
                  trayOpen: _bottomPresetTrayOpen,
                  hoverPresetIndex: _hoverPresetIndex,
                  onPresetSelected: _selectPreset,
                  onPointerDown: _handleToolPointerDown,
                  onHoldStarted: _startBottomHold,
                  onHoldTargetChanged: _updateBottomHoldTarget,
                  onHoldEnded: _endBottomHold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopTestBar extends StatelessWidget {
  final PrototypeVariant variant;
  final ValueChanged<PrototypeVariant> onVariantChanged;
  final bool inkEnabled;
  final List<InkPreset> presets;
  final int selectedPresetIndex;
  final bool hasStrokes;
  final bool isTestRunning;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<int> onPresetPointerDown;
  final VoidCallback onCustomize;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onToggleTest;
  final bool isSubmitting;
  final bool isCountdownActive;
  final int elapsedSeconds;

  const _TopTestBar({
    required this.variant,
    required this.onVariantChanged,
    required this.inkEnabled,
    required this.presets,
    required this.selectedPresetIndex,
    required this.hasStrokes,
    required this.isTestRunning,
    required this.onEnabledChanged,
    required this.onPresetSelected,
    required this.onPresetPointerDown,
    required this.onCustomize,
    required this.onUndo,
    required this.onClear,
    required this.onToggleTest,
    required this.isSubmitting,
    required this.isCountdownActive,
    required this.elapsedSeconds,
  });

  bool get _isVariantA => variant == PrototypeVariant.a;
  String get _title =>
      _isVariantA ? 'A안 · 도구 전환 방식: 상단 메뉴' : 'B안 · 도구 전환 방식: 좌측 하단 버튼';
  String get _elapsedLabel {
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FC),
        border: Border(bottom: BorderSide(color: Color(0xFFE7ECF6))),
      ),
      child: Row(
        children: [
          SegmentedButton<PrototypeVariant>(
            segments: const [
              ButtonSegment(value: PrototypeVariant.a, label: Text('A')),
              ButtonSegment(value: PrototypeVariant.b, label: Text('B')),
            ],
            selected: {variant},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              minimumSize: WidgetStateProperty.all(const Size(48, 38)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: (selection) =>
                onVariantChanged(selection.first),
          ),
          const SizedBox(width: 14),
          if (_isVariantA) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE1E7F5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: InkToolbar(
                  enabled: inkEnabled,
                  presets: presets,
                  selectedPresetIndex: selectedPresetIndex,
                  hasStrokes: hasStrokes,
                  direction: Axis.horizontal,
                  showEnabledToggle: false,
                  showUtilityActions: false,
                  onEnabledChanged: onEnabledChanged,
                  onPresetSelected: onPresetSelected,
                  onPresetPointerDown: onPresetPointerDown,
                  onCustomize: onCustomize,
                  onUndo: onUndo,
                  onClear: onClear,
                ),
              ),
            ),
            const SizedBox(width: 26),
          ],
          Expanded(
            child: Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 42,
            constraints: const BoxConstraints(minWidth: 86),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9E1F2)),
            ),
            child: Text(
              _elapsedLabel,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isSubmitting || isCountdownActive ? null : onToggleTest,
            style: FilledButton.styleFrom(
              minimumSize: const Size(112, 42),
              backgroundColor: isTestRunning
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF4169E1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isSubmitting ? '전송 중' : (isTestRunning ? '테스트 종료' : '테스트 시작'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  final int seconds;

  const _CountdownOverlay({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          width: 430,
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '5초 뒤 테스트가 시작됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '테스트 후 테스트 종료 버튼을 눌러주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '$seconds',
                style: const TextStyle(
                  fontSize: 92,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4169E1),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPresetLauncher extends StatelessWidget {
  final List<InkPreset> presets;
  final int selectedPresetIndex;
  final bool trayOpen;
  final int? hoverPresetIndex;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<int> onPointerDown;
  final VoidCallback onHoldStarted;
  final ValueChanged<int?> onHoldTargetChanged;
  final ValueChanged<int?> onHoldEnded;

  const _BottomPresetLauncher({
    required this.presets,
    required this.selectedPresetIndex,
    required this.trayOpen,
    required this.hoverPresetIndex,
    required this.onPresetSelected,
    required this.onPointerDown,
    required this.onHoldStarted,
    required this.onHoldTargetChanged,
    required this.onHoldEnded,
  });

  static const double _menuWidth = 238;
  static const double _menuHeight = 226;
  static const double _buttonSize = 74;
  static const double _choiceSize = 50;
  static const double _selectedChoiceSize = 70;
  static final GlobalKey _layerKey = GlobalKey();
  static const Offset _centerButtonCenter = Offset(114, 132);
  static const List<Offset> _choiceCenters = [
    Offset(168, 56),
    Offset(178, 176),
    Offset(202, 116),
    Offset(110, 32),
    Offset(50, 76),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedPreset = presets[selectedPresetIndex];

    int? targetFor(Offset globalPosition) {
      final box = _layerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        return null;
      }
      final localPosition = box.globalToLocal(globalPosition);
      var bestIndex = -1;
      var bestDistance = double.infinity;
      for (var index = 0; index < presets.length; index += 1) {
        final distance = (localPosition - _choiceCenters[index]).distance;
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = index;
        }
      }
      return bestDistance <= 68 ? bestIndex : null;
    }

    return SizedBox(
      key: _layerKey,
      width: _menuWidth,
      height: _menuHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (trayOpen)
            Positioned(
              left: 34,
              top: 58,
              child: IgnorePointer(
                child: Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5FB).withValues(alpha: 0.96),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          if (trayOpen)
            Positioned(
              left: _centerButtonCenter.dx - _buttonSize / 2,
              top: _centerButtonCenter.dy - _buttonSize / 2,
              child: _RadialEraserButton(),
            ),
          if (trayOpen)
            for (var index = 0; index < presets.length; index += 1)
              Positioned(
                left:
                    _choiceCenters[index].dx -
                    ((selectedPresetIndex == index || hoverPresetIndex == index)
                            ? _selectedChoiceSize
                            : _choiceSize) /
                        2,
                top:
                    _choiceCenters[index].dy -
                    ((selectedPresetIndex == index || hoverPresetIndex == index)
                            ? _selectedChoiceSize
                            : _choiceSize) /
                        2,
                child: _BottomPresetChoice(
                  preset: presets[index],
                  selected:
                      selectedPresetIndex == index || hoverPresetIndex == index,
                  emphasized: hoverPresetIndex == index,
                  onPointerDown: () => onPointerDown(index),
                  onTap: () => onPresetSelected(index),
                ),
              ),
          Positioned(
            left: _centerButtonCenter.dx - _buttonSize / 2,
            top: _centerButtonCenter.dy - _buttonSize / 2,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                onPointerDown(selectedPresetIndex);
                onHoldStarted();
              },
              onPointerMove: (event) {
                final target = targetFor(event.position);
                onHoldTargetChanged(target);
              },
              onPointerUp: (event) {
                final target = targetFor(event.position);
                onHoldEnded(target);
              },
              onPointerCancel: (_) => onHoldEnded(null),
              child: Material(
                color: trayOpen ? Colors.transparent : Colors.white,
                elevation: 9,
                shadowColor: Colors.black.withValues(alpha: 0.18),
                shape: const CircleBorder(),
                child: SizedBox(
                  width: _buttonSize,
                  height: _buttonSize,
                  child: Center(
                    child: trayOpen
                        ? const SizedBox.shrink()
                        : selectedPreset.isEraser
                        ? const Icon(
                            Icons.cleaning_services_rounded,
                            color: Color(0xFF64748B),
                            size: 28,
                          )
                        : CustomPaint(
                            size: const Size(34, 34),
                            painter: InkPresetPreviewPainter(selectedPreset),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialEraserButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xFFD9E1F0), width: 1.2),
      ),
      child: const SizedBox(
        width: 74,
        height: 74,
        child: Center(
          child: Icon(
            Icons.cleaning_services_rounded,
            color: Color(0xFF64748B),
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _BottomPresetChoice extends StatelessWidget {
  final InkPreset preset;
  final bool selected;
  final bool emphasized;
  final VoidCallback onPointerDown;
  final VoidCallback onTap;

  const _BottomPresetChoice({
    required this.preset,
    required this.selected,
    this.emphasized = false,
    required this.onPointerDown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected || emphasized ? 70.0 : 50.0;
    final previewSize = selected || emphasized ? 36.0 : 25.0;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPointerDown(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD9E1F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: selected || emphasized ? 0.18 : 0.08,
                ),
                blurRadius: selected || emphasized ? 12 : 7,
                offset: Offset(0, selected || emphasized ? 6 : 3),
              ),
            ],
          ),
          child: preset.isEraser
              ? Icon(
                  Icons.cleaning_services_rounded,
                  size: selected || emphasized ? 28 : 20,
                  color: const Color(0xFF64748B),
                )
              : CustomPaint(
                  size: Size(previewSize, previewSize),
                  painter: InkPresetPreviewPainter(preset),
                ),
        ),
      ),
    );
  }
}

class _TouchOnlyScrollBehavior extends MaterialScrollBehavior {
  const _TouchOnlyScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class _LectureSlide extends StatefulWidget {
  final bool scrollLocked;

  const _LectureSlide({required this.scrollLocked});

  @override
  State<_LectureSlide> createState() => _LectureSlideState();
}

class _LectureSlideState extends State<_LectureSlide> {
  static const double _designWidth = 960;
  static const double _zoomedScale = 1.55;
  static const double _maxZoomScale = 2.4;

  final TransformationController _zoomController = TransformationController();
  final Map<int, Offset> _activeTouchPositions = <int, Offset>{};
  final Set<int> _activeStylusPointers = <int>{};
  Offset _lastTapPosition = Offset.zero;
  bool _lastTapWasTouch = false;
  double? _pinchStartDistance;
  double? _pinchStartScale;
  Offset? _pinchStartSceneFocal;

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (isStylusPointerKind(event.kind)) {
      setState(() {
        _activeStylusPointers.add(event.pointer);
      });
      _lastTapWasTouch = false;
      _resetPinch();
      return;
    }
    if (event.kind != PointerDeviceKind.touch) {
      _lastTapWasTouch = false;
      return;
    }
    _activeTouchPositions[event.pointer] = event.localPosition;
    _lastTapPosition = event.localPosition;
    _lastTapWasTouch = true;
    if (_activeTouchPositions.length == 2) {
      _startPinch();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.kind != PointerDeviceKind.touch ||
        !_activeTouchPositions.containsKey(event.pointer)) {
      return;
    }
    _activeTouchPositions[event.pointer] = event.localPosition;
    _updatePinch();
  }

  void _handlePointerUp(PointerEvent event) {
    if (isStylusPointerKind(event.kind)) {
      if (_activeStylusPointers.remove(event.pointer)) {
        setState(() {});
      }
      return;
    }
    if (event.kind != PointerDeviceKind.touch) {
      return;
    }
    _activeTouchPositions.remove(event.pointer);
    _resetPinch();
    if (_activeTouchPositions.length == 2) {
      _startPinch();
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (details.kind != PointerDeviceKind.touch) {
      _lastTapWasTouch = false;
      return;
    }
    _lastTapWasTouch = true;
    _lastTapPosition = details.localPosition;
  }

  void _toggleZoom() {
    if (!_lastTapWasTouch || _activeStylusPointers.isNotEmpty) {
      return;
    }
    final currentScale = _zoomController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      _zoomController.value = Matrix4.identity();
      return;
    }
    _zoomController.value = _matrixForScaleAroundPoint(
      _zoomedScale,
      _lastTapPosition,
    );
  }

  void _startPinch() {
    final points = _activeTouchPositions.values.take(2).toList();
    _pinchStartDistance = (points[0] - points[1]).distance;
    _pinchStartScale = _zoomController.value.getMaxScaleOnAxis();
    _pinchStartSceneFocal = _zoomController.toScene(
      _midpoint(points[0], points[1]),
    );
  }

  void _updatePinch() {
    if (widget.scrollLocked ||
        _activeStylusPointers.isNotEmpty ||
        _activeTouchPositions.length < 2 ||
        _pinchStartDistance == null ||
        _pinchStartDistance! <= 0 ||
        _pinchStartScale == null ||
        _pinchStartSceneFocal == null) {
      return;
    }
    final points = _activeTouchPositions.values.take(2).toList();
    final nextScale =
        (_pinchStartScale! *
                ((points[0] - points[1]).distance / _pinchStartDistance!))
            .clamp(1.0, _maxZoomScale)
            .toDouble();
    if (nextScale <= 1.01) {
      _zoomController.value = Matrix4.identity();
      return;
    }
    _zoomController.value = _matrixForScaleAroundPoint(
      nextScale,
      _midpoint(points[0], points[1]),
      scenePoint: _pinchStartSceneFocal,
    );
  }

  void _resetPinch() {
    _pinchStartDistance = null;
    _pinchStartScale = null;
    _pinchStartSceneFocal = null;
  }

  Offset _midpoint(Offset a, Offset b) {
    return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }

  Matrix4 _matrixForScaleAroundPoint(
    double scale,
    Offset viewportPoint, {
    Offset? scenePoint,
  }) {
    final focalPoint = scenePoint ?? _zoomController.toScene(viewportPoint);
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, viewportPoint.dx - focalPoint.dx * scale)
      ..setEntry(1, 3, viewportPoint.dy - focalPoint.dy * scale);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerUp,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: _handleDoubleTapDown,
          onDoubleTap: _toggleZoom,
          child: ScrollConfiguration(
            behavior: const _TouchOnlyScrollBehavior(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  transformationController: _zoomController,
                  minScale: 1,
                  maxScale: _maxZoomScale,
                  boundaryMargin: const EdgeInsets.all(180),
                  panEnabled:
                      !widget.scrollLocked && _activeStylusPointers.isEmpty,
                  scaleEnabled: false,
                  constrained: true,
                  child: SingleChildScrollView(
                    physics: widget.scrollLocked
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: _designWidth,
                          child: Column(
                            children: const [_EquationProblemPage()],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EquationProblemPage extends StatelessWidget {
  const _EquationProblemPage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 960,
      height: 560,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Container(
              width: 948,
              height: 297,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const _EquationProblemContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _EquationProblemContent extends StatelessWidget {
  const _EquationProblemContent();

  static const _textColor = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        color: _textColor,
        fontSize: 21,
        height: 1.24,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '[문제 1] 다음 식을 만족하는 '),
                TextSpan(text: 'x', style: _mathStyle(fontSize: 22)),
                const TextSpan(text: '의 값을 구하시오.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: _EquationLine()),
          const SizedBox(height: 12),
          const Text('※ 풀이 조건: > 1. 암산하지 말고 모든 풀이 과정을 화면에 적어주세요.'),
          const SizedBox(height: 8),
          const Text(
            '2. 첫 줄에는 반드시 "양변에 분모의 최소공배수(6)를 곱하여 분모를 없앤 식"을 먼저 나열한 뒤, 전개',
          ),
          const Text('를 시작해 주세요.'),
        ],
      ),
    );
  }

  static TextStyle _mathStyle({double fontSize = 28}) {
    return const TextStyle(
      color: _textColor,
      fontWeight: FontWeight.w900,
      fontFamily: 'Times New Roman',
      fontStyle: FontStyle.italic,
      letterSpacing: 0,
    ).copyWith(fontSize: fontSize);
  }
}

class _EquationLine extends StatelessWidget {
  const _EquationLine();

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: _EquationProblemContent._mathStyle(fontSize: 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          _Fraction(
            numerator: TextSpan(
              children: [
                TextSpan(text: '3'),
                TextSpan(text: '('),
                TextSpan(text: 'x'),
                TextSpan(text: ' - 1)'),
              ],
            ),
            denominator: '2',
          ),
          SizedBox(width: 17),
          Text('-'),
          SizedBox(width: 17),
          _Fraction(
            numerator: TextSpan(
              children: [
                TextSpan(text: 'x'),
                TextSpan(text: ' + 4'),
              ],
            ),
            denominator: '3',
          ),
          SizedBox(width: 17),
          Text('= 1'),
        ],
      ),
    );
  }
}

class _Fraction extends StatelessWidget {
  final TextSpan numerator;
  final String denominator;

  const _Fraction({required this.numerator, required this.denominator});

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text.rich(numerator, style: style),
        ),
        Container(width: 112, height: 2, color: const Color(0xFF111827)),
        Text(denominator, style: style.copyWith(fontStyle: FontStyle.normal)),
      ],
    );
  }
}
