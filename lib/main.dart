import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'ink/ink_canvas.dart';
import 'ink/ink_models.dart';
import 'ink/ink_toolbar.dart';

void main() {
  runApp(const InkLecturePrototypeApp());
}

enum PrototypeVariant { a, b }

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
  bool _bottomPresetTrayOpen = false;
  int? _holdOriginalPresetIndex;
  int? _hoverPresetIndex;
  DateTime? _lastStrokeEndedAt;
  int _switchesSinceStroke = 0;
  bool _misoperationCounted = false;
  int _misoperationCount = 0;
  final List<int> _transitionTimesMs = <int>[];

  @override
  void initState() {
    super.initState();
    _variant = widget.variant;
  }

  InkPreset get _selectedPreset => _presets[_selectedPresetIndex];
  bool get _isVariantB => _variant == PrototypeVariant.b;
  int get _eraserPresetIndex =>
      _presets.indexWhere((preset) => preset.tool == InkTool.eraser);
  int? get _latestTransitionMs =>
      _transitionTimesMs.isEmpty ? null : _transitionTimesMs.last;
  int? get _averageTransitionMs {
    if (_transitionTimesMs.isEmpty) {
      return null;
    }
    final total = _transitionTimesMs.fold<int>(0, (sum, time) => sum + time);
    return (total / _transitionTimesMs.length).round();
  }

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

  void _toggleTest() {
    setState(() {
      _isTestRunning = !_isTestRunning;
      _inkEnabled = true;
      _lastStrokeEndedAt = null;
      _switchesSinceStroke = 0;
      _misoperationCounted = false;
      _misoperationCount = 0;
      _transitionTimesMs.clear();
    });
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

  void _recordToolSwitch(int nextIndex) {
    if (!_isTestRunning ||
        _lastStrokeEndedAt == null ||
        nextIndex == _selectedPresetIndex) {
      return;
    }
    _switchesSinceStroke += 1;
    if (_switchesSinceStroke >= 2 && !_misoperationCounted) {
      _misoperationCount += 1;
      _misoperationCounted = true;
    }
  }

  void _recordToolSwitchFrom(int previousIndex, int nextIndex) {
    if (!_isTestRunning ||
        _lastStrokeEndedAt == null ||
        nextIndex == previousIndex) {
      return;
    }
    _switchesSinceStroke += 1;
    if (_switchesSinceStroke >= 2 && !_misoperationCounted) {
      _misoperationCount += 1;
      _misoperationCounted = true;
    }
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
        if (_lastStrokeEndedAt != null && _switchesSinceStroke > 0) {
          _transitionTimesMs.add(
            now.difference(_lastStrokeEndedAt!).inMilliseconds,
          );
        }
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
    final eraserIndex = _eraserPresetIndex;
    if (eraserIndex < 0) {
      return;
    }
    setState(() {
      _holdOriginalPresetIndex = _selectedPresetIndex;
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
      _selectedPresetIndex = index ?? eraserIndex;
    });
  }

  void _endBottomHold(int? index) {
    final originalIndex = _holdOriginalPresetIndex;
    final nextIndex = index ?? originalIndex;
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
            return Column(
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
                  onCustomize: _openPresetEditor,
                  onUndo: _undoStroke,
                  onClear: _clearStrokes,
                  onToggleTest: _toggleTest,
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
                  onHoldStarted: _startBottomHold,
                  onHoldTargetChanged: _updateBottomHoldTarget,
                  onHoldEnded: _endBottomHold,
                ),
              ),
            ),
          if (_isTestRunning)
            Positioned(
              right: 22,
              bottom: 22,
              child: InkExclusionZone(
                padding: const EdgeInsets.all(8),
                child: _TestDataPanel(
                  latestTransitionMs: _latestTransitionMs,
                  averageTransitionMs: _averageTransitionMs,
                  transitionCount: _transitionTimesMs.length,
                  switchesSinceStroke: _switchesSinceStroke,
                  misoperationCount: _misoperationCount,
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
  final VoidCallback onCustomize;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onToggleTest;

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
    required this.onCustomize,
    required this.onUndo,
    required this.onClear,
    required this.onToggleTest,
  });

  bool get _isVariantA => variant == PrototypeVariant.a;
  String get _title =>
      _isVariantA ? 'A안 · 도구 전환 방식: 상단 메뉴' : 'B안 · 도구 전환 방식: 좌측 하단 버튼';

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
          FilledButton(
            onPressed: onToggleTest,
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
            child: Text(isTestRunning ? '테스트 종료' : '테스트 시작'),
          ),
        ],
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
  final VoidCallback onHoldStarted;
  final ValueChanged<int?> onHoldTargetChanged;
  final ValueChanged<int?> onHoldEnded;

  const _BottomPresetLauncher({
    required this.presets,
    required this.selectedPresetIndex,
    required this.trayOpen,
    required this.hoverPresetIndex,
    required this.onPresetSelected,
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
                  onTap: () => onPresetSelected(index),
                ),
              ),
          Positioned(
            left: _centerButtonCenter.dx - _buttonSize / 2,
            top: _centerButtonCenter.dy - _buttonSize / 2,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => onHoldStarted(),
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

class _TestDataPanel extends StatelessWidget {
  final int? latestTransitionMs;
  final int? averageTransitionMs;
  final int transitionCount;
  final int switchesSinceStroke;
  final int misoperationCount;

  const _TestDataPanel({
    required this.latestTransitionMs,
    required this.averageTransitionMs,
    required this.transitionCount,
    required this.switchesSinceStroke,
    required this.misoperationCount,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E7F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '수집 데이터',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 8),
            _MetricLine(
              label: '최근 전환 시간',
              value: _formatTime(latestTransitionMs),
            ),
            _MetricLine(
              label: '평균 전환 시간',
              value: _formatTime(averageTransitionMs),
            ),
            _MetricLine(label: '전환 기록', value: '$transitionCount회'),
            _MetricLine(label: '필기 전 전환', value: '$switchesSinceStroke회'),
            _MetricLine(label: '오조작', value: '$misoperationCount회'),
          ],
        ),
      ),
    );
  }

  static String _formatTime(int? milliseconds) {
    if (milliseconds == null) {
      return '-';
    }
    return '${(milliseconds / 1000).toStringAsFixed(2)}초';
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetricLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPresetChoice extends StatelessWidget {
  final InkPreset preset;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  const _BottomPresetChoice({
    required this.preset,
    required this.selected,
    this.emphasized = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected || emphasized ? 70.0 : 50.0;
    final previewSize = selected || emphasized ? 36.0 : 25.0;
    return GestureDetector(
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
                            children: const [
                              _ProblemPage(
                                number: '0787',
                                prompt: _ProblemText(),
                                feeCard: _AdmissionFeeCard(),
                              ),
                              SizedBox(height: 34),
                              _ProblemPage(
                                number: '0788',
                                prompt: _SecondProblemText(),
                                feeCard: _BusFareCard(),
                              ),
                            ],
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

class _ProblemPage extends StatelessWidget {
  final String number;
  final Widget prompt;
  final Widget feeCard;

  const _ProblemPage({
    required this.number,
    required this.prompt,
    required this.feeCard,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 960,
      height: 560,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFDFEFE),
          border: Border.all(color: const Color(0xFFE6EDF7)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(52, 42, 52, 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4E8A38),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: prompt),
                    const SizedBox(width: 34),
                    feeCard,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProblemText extends StatelessWidget {
  const _ProblemText();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 28,
      height: 1.6,
      fontWeight: FontWeight.w800,
      color: Color(0xFF1F2937),
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: '어느 동물원의 입장료는 오른쪽과\n'),
          const TextSpan(text: '같다. 지난달 이 동물원에 입장한 어른은 '),
          TextSpan(
            text: 'x',
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
          const TextSpan(
            text:
                '명이고 청소년은 어른의 2배보다 6명이 많았고, 어린이는 어른의 3배보다 2명이 적었다. 지난달의 동물원 입장료의 총액을 ',
          ),
          TextSpan(
            text: 'x',
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
          const TextSpan(text: '를 사용한 식으로 나타내시오.'),
        ],
      ),
    );
  }
}

class _SecondProblemText extends StatelessWidget {
  const _SecondProblemText();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 28,
      height: 1.6,
      fontWeight: FontWeight.w800,
      color: Color(0xFF1F2937),
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: '어느 시내버스의 이용 요금은 오른쪽과\n'),
          const TextSpan(text: '같다. 오늘 이 버스를 이용한 어른은 '),
          TextSpan(
            text: 'x',
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
          const TextSpan(
            text:
                '명이고 청소년은 어른보다 12명이 적었으며, 어린이는 청소년의 2배보다 5명이 많았다. 오늘의 버스 요금 총액을 ',
          ),
          TextSpan(
            text: 'x',
            style: style.copyWith(fontStyle: FontStyle.italic),
          ),
          const TextSpan(text: '를 사용한 식으로 나타내시오.'),
        ],
      ),
    );
  }
}

class _AdmissionFeeCard extends StatelessWidget {
  const _AdmissionFeeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD7DDE7), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '동물원 입장료',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          const _FeeRow(label: '어른', value: '5000원'),
          const _FeeRow(label: '청소년', value: '3000원'),
          const _FeeRow(label: '어린이', value: '2000원'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Icon(Icons.forest_rounded, color: Color(0xFF79A858), size: 28),
              Icon(Icons.park_rounded, color: Color(0xFFF6A13A), size: 30),
              Icon(
                Icons.child_care_rounded,
                color: Color(0xFFEA6A52),
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusFareCard extends StatelessWidget {
  const _BusFareCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD7DDE7), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '시내버스 요금',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          const _FeeRow(label: '어른', value: '1500원'),
          const _FeeRow(label: '청소년', value: '900원'),
          const _FeeRow(label: '어린이', value: '600원'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Icon(
                Icons.directions_bus_rounded,
                color: Color(0xFF2563EB),
                size: 30,
              ),
              Icon(Icons.route_rounded, color: Color(0xFF16A34A), size: 28),
              Icon(
                Icons.confirmation_number_rounded,
                color: Color(0xFFF97316),
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;

  const _FeeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
