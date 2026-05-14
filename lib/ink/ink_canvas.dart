import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'ink_models.dart';

bool isStylusPointerKind(PointerDeviceKind kind) {
  return kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;
}

class InkAnnotationLayer extends StatefulWidget {
  final bool enabled;
  final InkTool tool;
  final Color color;
  final double width;
  final bool allowTouchInput;
  final List<InkStroke> strokes;
  final ValueChanged<List<InkStroke>> onChanged;
  final ValueChanged<bool>? onStrokeActiveChanged;
  final Widget child;

  const InkAnnotationLayer({
    super.key,
    required this.enabled,
    required this.tool,
    required this.color,
    required this.width,
    required this.allowTouchInput,
    required this.strokes,
    required this.onChanged,
    this.onStrokeActiveChanged,
    required this.child,
  });

  @override
  State<InkAnnotationLayer> createState() => _InkAnnotationLayerState();
}

class _InkAnnotationLayerState extends State<InkAnnotationLayer> {
  static const double _fingerStrokeStartSlop = 18;
  static const double _stylusStrokeStartSlop = 0;
  static const int _fingerStrokeStartDelayMs = 170;

  final GlobalKey _layerKey = GlobalKey();
  final List<InkPoint> _activePoints = <InkPoint>[];
  final Set<int> _activePointers = <int>{};
  final ValueNotifier<int> _activeStrokeRevision = ValueNotifier<int>(0);
  late final InkExclusionController _exclusionController =
      InkExclusionController();
  int? _drawingPointer;
  int? _scrollPointer;
  Offset? _pendingStrokeStart;
  int _pendingStrokeStartedAt = 0;
  PointerDeviceKind? _pendingPointerKind;
  bool _isMultiTouchScrolling = false;

  @override
  void dispose() {
    _activeStrokeRevision.dispose();
    _exclusionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InkAnnotationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled &&
        (_activePoints.isNotEmpty ||
            _activePointers.isNotEmpty ||
            _drawingPointer != null ||
            _pendingStrokeStart != null ||
            _isMultiTouchScrolling)) {
      _cancelActiveStroke();
      _activePointers.clear();
      _scrollPointer = null;
      _isMultiTouchScrolling = false;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || !_isInkPointer(event.kind)) {
      return;
    }
    if (!_isInsideInkBounds(event.localPosition)) {
      return;
    }
    if (_exclusionController.contains(event.localPosition)) {
      return;
    }
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) {
      _isMultiTouchScrolling = true;
      _scrollPointer ??= event.pointer;
      _cancelActiveStroke();
      return;
    }
    _drawingPointer = event.pointer;
    _pendingStrokeStart = event.localPosition;
    _pendingPointerKind = event.kind;
    _pendingStrokeStartedAt = event.timeStamp.inMilliseconds;
    if (isStylusPointerKind(event.kind)) {
      _replaceActivePoints([_pointFor(event.localPosition)]);
    }
    widget.onStrokeActiveChanged?.call(true);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.enabled || !_isInkPointer(event.kind)) {
      return;
    }
    if (_activePointers.length > 1 || _isMultiTouchScrolling) {
      _scrollPointer ??= event.pointer;
      if (_scrollPointer == event.pointer) {
        _scrollAncestorBy(event.delta.dy);
      }
      _cancelActiveStroke();
      return;
    }
    if (_drawingPointer != event.pointer) {
      return;
    }
    if (_activePoints.isEmpty) {
      final start = _pendingStrokeStart;
      if (start == null) {
        return;
      }
      final clampedPosition = _clampOffsetToInkBounds(event.localPosition);
      final isStylus =
          _pendingPointerKind != null &&
          isStylusPointerKind(_pendingPointerKind!);
      final elapsedMs =
          event.timeStamp.inMilliseconds - _pendingStrokeStartedAt;
      final distance = (clampedPosition - start).distance;
      final requiredDistance = isStylus
          ? _stylusStrokeStartSlop
          : _fingerStrokeStartSlop;
      if (distance < requiredDistance ||
          (!isStylus && elapsedMs < _fingerStrokeStartDelayMs)) {
        return;
      }
      _replaceActivePoints([_pointFor(start), _pointFor(clampedPosition)]);
      return;
    }
    _appendSmoothedActivePoint(
      _pointFor(_clampOffsetToInkBounds(event.localPosition)),
    );
  }

  void _handlePointerUp(PointerEvent event) {
    if (!_isInkPointer(event.kind)) {
      return;
    }
    final wasDrawingPointer = _drawingPointer == event.pointer;
    _activePointers.remove(event.pointer);
    if (_scrollPointer == event.pointer) {
      _scrollPointer = _activePointers.isEmpty ? null : _activePointers.first;
    }
    if (wasDrawingPointer) {
      _finishStroke();
      _drawingPointer = null;
      _pendingStrokeStart = null;
      _pendingPointerKind = null;
      _pendingStrokeStartedAt = 0;
      widget.onStrokeActiveChanged?.call(false);
    }
    if (_activePointers.isEmpty) {
      _isMultiTouchScrolling = false;
      _scrollPointer = null;
      _pendingStrokeStart = null;
      _pendingPointerKind = null;
      _pendingStrokeStartedAt = 0;
    }
  }

  bool _isInkPointer(PointerDeviceKind kind) {
    if (isStylusPointerKind(kind)) {
      return true;
    }
    if (!widget.allowTouchInput) {
      return false;
    }
    return kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.trackpad;
  }

  void _scrollAncestorBy(double deltaY) {
    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable?.position;
    if (position == null || !position.hasPixels) {
      return;
    }
    final target = (position.pixels - deltaY).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) {
      position.jumpTo(target);
    }
  }

  void _cancelActiveStroke() {
    if (_activePoints.isEmpty && _drawingPointer == null) {
      return;
    }
    _clearActivePoints();
    _drawingPointer = null;
    _pendingStrokeStart = null;
    _pendingPointerKind = null;
    _pendingStrokeStartedAt = 0;
    widget.onStrokeActiveChanged?.call(false);
  }

  void _finishStroke() {
    if (!widget.enabled || _activePoints.length < 2) {
      _clearActivePoints();
      return;
    }
    if (widget.tool == InkTool.eraser) {
      final erased = widget.strokes
          .where((stroke) => !_strokeHitsEraser(stroke.points, _activePoints))
          .toList();
      widget.onChanged(erased);
    } else {
      final stroke = InkStroke(
        points: List<InkPoint>.unmodifiable(_activePoints),
        color: widget.color,
        width: widget.tool == InkTool.highlighter
            ? widget.width * 3
            : widget.width,
        highlighter: widget.tool == InkTool.highlighter,
        savedAt: DateTime.now().millisecondsSinceEpoch,
      );
      widget.onChanged([...widget.strokes, stroke]);
    }
    _clearActivePoints();
  }

  void _replaceActivePoints(Iterable<InkPoint> points) {
    _activePoints
      ..clear()
      ..addAll(points);
    _notifyActiveStrokeChanged();
  }

  void _appendSmoothedActivePoint(InkPoint point) {
    if (_activePoints.length >= 2) {
      final previousIndex = _activePoints.length - 1;
      _activePoints[previousIndex] = _smoothedMiddlePoint(
        _activePoints[previousIndex - 1],
        _activePoints[previousIndex],
        point,
      );
    }
    _activePoints.add(point);
    _notifyActiveStrokeChanged();
  }

  InkPoint _smoothedMiddlePoint(
    InkPoint before,
    InkPoint middle,
    InkPoint after,
  ) {
    const middleWeight = 6.0;
    const edgeWeight = 1.0;
    const totalWeight = middleWeight + edgeWeight * 2;
    return InkPoint(
      (before.x * edgeWeight + middle.x * middleWeight + after.x * edgeWeight) /
          totalWeight,
      (before.y * edgeWeight + middle.y * middleWeight + after.y * edgeWeight) /
          totalWeight,
    );
  }

  void _clearActivePoints() {
    if (_activePoints.isEmpty) {
      return;
    }
    _activePoints.clear();
    _notifyActiveStrokeChanged();
  }

  void _notifyActiveStrokeChanged() {
    _activeStrokeRevision.value += 1;
  }

  bool _isInsideInkBounds(Offset offset) {
    final size = context.size;
    if (size == null) {
      return true;
    }
    return offset.dx >= 0 &&
        offset.dy >= 0 &&
        offset.dx <= size.width &&
        offset.dy <= size.height;
  }

  Offset _clampOffsetToInkBounds(Offset offset) {
    final size = context.size;
    if (size == null) {
      return offset;
    }
    return Offset(
      offset.dx.clamp(0.0, size.width).toDouble(),
      offset.dy.clamp(0.0, size.height).toDouble(),
    );
  }

  InkPoint _pointFor(Offset offset) {
    final clampedOffset = _clampOffsetToInkBounds(offset);
    return InkPoint(clampedOffset.dx, clampedOffset.dy);
  }

  bool _strokeHitsEraser(List<InkPoint> stroke, List<InkPoint> eraser) {
    for (final point in stroke) {
      for (final eraserPoint in eraser) {
        if ((point.toOffset() - eraserPoint.toOffset()).distance <= 18) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _layerKey,
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: InkExclusionScope(
        controller: _exclusionController,
        layerKey: _layerKey,
        child: ClipRect(
          child: CustomPaint(
            foregroundPainter: InkAnnotationPainter(
              strokes: widget.strokes,
              activePoints: _activePoints,
              activeColor: widget.tool == InkTool.eraser
                  ? const Color(0xFF64748B)
                  : widget.color,
              activeWidth: widget.tool == InkTool.highlighter
                  ? widget.width * 3
                  : widget.width,
              activeHighlighter: widget.tool == InkTool.highlighter,
              repaint: Listenable.merge([
                _activeStrokeRevision,
                _exclusionController,
              ]),
            ),
            child: RepaintBoundary(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class InkExclusionController extends ChangeNotifier {
  final Map<Object, Rect> _rects = <Object, Rect>{};

  bool contains(Offset position) {
    for (final rect in _rects.values) {
      if (rect.contains(position)) {
        return true;
      }
    }
    return false;
  }

  void update(Object token, Rect rect) {
    if (_rects[token] == rect) {
      return;
    }
    _rects[token] = rect;
    notifyListeners();
  }

  void remove(Object token) {
    if (_rects.remove(token) != null) {
      notifyListeners();
    }
  }
}

class InkExclusionScope extends InheritedWidget {
  final InkExclusionController controller;
  final GlobalKey layerKey;

  const InkExclusionScope({
    super.key,
    required this.controller,
    required this.layerKey,
    required super.child,
  });

  static InkExclusionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InkExclusionScope>();
  }

  @override
  bool updateShouldNotify(covariant InkExclusionScope oldWidget) {
    return controller != oldWidget.controller || layerKey != oldWidget.layerKey;
  }
}

class InkExclusionZone extends StatefulWidget {
  final EdgeInsets padding;
  final Widget child;

  const InkExclusionZone({
    super.key,
    this.padding = EdgeInsets.zero,
    required this.child,
  });

  @override
  State<InkExclusionZone> createState() => _InkExclusionZoneState();
}

class _InkExclusionZoneState extends State<InkExclusionZone> {
  final Object _token = Object();
  final GlobalKey _key = GlobalKey();
  InkExclusionScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScope = InkExclusionScope.maybeOf(context);
    if (_scope?.controller != nextScope?.controller) {
      _scope?.controller.remove(_token);
      _scope = nextScope;
    } else {
      _scope = nextScope;
    }
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant InkExclusionZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _scope?.controller.remove(_token);
    super.dispose();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _measure();
      }
    });
  }

  void _measure() {
    final scope = _scope;
    final zoneBox = _key.currentContext?.findRenderObject() as RenderBox?;
    final layerBox =
        scope?.layerKey.currentContext?.findRenderObject() as RenderBox?;
    if (scope == null ||
        zoneBox == null ||
        layerBox == null ||
        !zoneBox.hasSize ||
        !layerBox.hasSize) {
      scope?.controller.remove(_token);
      return;
    }

    final topLeft = layerBox.globalToLocal(zoneBox.localToGlobal(Offset.zero));
    final rect = topLeft & zoneBox.size;
    final paddedRect = Rect.fromLTRB(
      rect.left - widget.padding.left,
      rect.top - widget.padding.top,
      rect.right + widget.padding.right,
      rect.bottom + widget.padding.bottom,
    );
    scope.controller.update(_token, paddedRect);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class InkAnnotationPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final List<InkPoint> activePoints;
  final Color activeColor;
  final double activeWidth;
  final bool activeHighlighter;

  InkAnnotationPainter({
    required this.strokes,
    required this.activePoints,
    required this.activeColor,
    required this.activeWidth,
    required this.activeHighlighter,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    void drawPoints(
      List<InkPoint> points, {
      required Color color,
      required double width,
      required bool highlighter,
    }) {
      if (points.length < 2) {
        return;
      }

      final paint = Paint()
        ..color = highlighter ? color.withValues(alpha: 0.32) : color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = highlighter ? BlendMode.multiply : BlendMode.srcOver;

      final path = Path()..moveTo(points.first.x, points.first.y);
      for (var i = 1; i < points.length; i += 1) {
        final previous = points[i - 1];
        final current = points[i];
        path.quadraticBezierTo(
          previous.x,
          previous.y,
          (previous.x + current.x) / 2,
          (previous.y + current.y) / 2,
        );
      }
      final last = points.last;
      path.lineTo(last.x, last.y);
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawPoints(
        stroke.points,
        color: stroke.color,
        width: stroke.width,
        highlighter: stroke.highlighter,
      );
    }
    drawPoints(
      activePoints,
      color: activeColor,
      width: activeWidth,
      highlighter: activeHighlighter,
    );
  }

  @override
  bool shouldRepaint(covariant InkAnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activePoints != activePoints ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeWidth != activeWidth ||
        oldDelegate.activeHighlighter != activeHighlighter;
  }
}
