import 'package:flutter/material.dart';

import 'ink_canvas.dart';
import 'ink_models.dart';

class InkToolbar extends StatelessWidget {
  final bool enabled;
  final List<InkPreset> presets;
  final int selectedPresetIndex;
  final bool hasStrokes;
  final Axis direction;
  final bool showEnabledToggle;
  final bool showUtilityActions;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<int>? onPresetPointerDown;
  final VoidCallback onCustomize;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const InkToolbar({
    super.key,
    required this.enabled,
    required this.presets,
    required this.selectedPresetIndex,
    required this.hasStrokes,
    this.direction = Axis.vertical,
    this.showEnabledToggle = true,
    this.showUtilityActions = true,
    required this.onEnabledChanged,
    required this.onPresetSelected,
    this.onPresetPointerDown,
    required this.onCustomize,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      if (showEnabledToggle)
        _InkIconButton(
          selected: enabled,
          icon: Icons.edit_rounded,
          tooltip: '필기 켜기',
          onTap: () => onEnabledChanged(!enabled),
        ),
      if (enabled) ...[
        for (var index = 0; index < presets.length; index += 1)
          _InkPresetButton(
            preset: presets[index],
            selected: selectedPresetIndex == index,
            onPointerDown: () => onPresetPointerDown?.call(index),
            onTap: () => onPresetSelected(index),
          ),
        if (showUtilityActions) ...[
          _InkIconButton(
            selected: false,
            icon: Icons.tune_rounded,
            tooltip: '펜 설정',
            onTap: onCustomize,
          ),
          _InkIconButton(
            selected: false,
            icon: Icons.undo_rounded,
            tooltip: '되돌리기',
            onTap: hasStrokes ? onUndo : null,
          ),
          _InkIconButton(
            selected: false,
            icon: Icons.delete_outline_rounded,
            tooltip: '전체 지우기',
            onTap: hasStrokes ? onClear : null,
          ),
        ],
      ],
    ];

    return InkExclusionZone(
      padding: const EdgeInsets.all(10),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.zero,
          child: direction == Axis.horizontal
              ? Row(mainAxisSize: MainAxisSize.min, children: children)
              : Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _InkIconButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _InkIconButton({
    required this.selected,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      iconSize: 20,
      constraints: const BoxConstraints.tightFor(width: 46, height: 46),
      style: IconButton.styleFrom(
        minimumSize: const Size(46, 46),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: selected
            ? const Color(0xFFEEF1FF)
            : Colors.transparent,
        foregroundColor: selected
            ? const Color(0xFF4C5AC7)
            : const Color(0xFF4B5368),
        disabledForegroundColor: const Color(0xFFC0C6D4),
      ),
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

class _InkPresetButton extends StatelessWidget {
  final InkPreset preset;
  final bool selected;
  final VoidCallback? onPointerDown;
  final VoidCallback onTap;

  const _InkPresetButton({
    required this.preset,
    required this.selected,
    this.onPointerDown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPointerDown?.call(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEF1FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: const Color(0xFFBFCBFF), width: 1.2)
                : null,
          ),
          child: preset.isEraser
              ? const Icon(
                  Icons.cleaning_services_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                )
              : CustomPaint(
                  size: const Size(24, 24),
                  painter: InkPresetPreviewPainter(preset),
                ),
        ),
      ),
    );
  }
}

class InkPresetPreviewPainter extends CustomPainter {
  final InkPreset preset;

  const InkPresetPreviewPainter(this.preset);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = preset.tool == InkTool.highlighter
          ? preset.color.withValues(alpha: 0.42)
          : preset.color
      ..strokeWidth = preset.tool == InkTool.highlighter
          ? (preset.width * 1.6).clamp(3.0, 10.0)
          : preset.width.clamp(2.0, 7.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.18,
        size.width * 0.62,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.78,
        size.width * 0.88,
        size.height * 0.34,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant InkPresetPreviewPainter oldDelegate) {
    return oldDelegate.preset != preset;
  }
}

class InkPresetEditorSheet extends StatefulWidget {
  final InkPreset initialPreset;
  final int presetNumber;

  const InkPresetEditorSheet({
    super.key,
    required this.initialPreset,
    required this.presetNumber,
  });

  @override
  State<InkPresetEditorSheet> createState() => _InkPresetEditorSheetState();
}

class _InkPresetEditorSheetState extends State<InkPresetEditorSheet> {
  late InkTool _tool;
  late HSVColor _hsvColor;
  late double _width;

  @override
  void initState() {
    super.initState();
    _tool = widget.initialPreset.tool;
    _hsvColor = HSVColor.fromColor(widget.initialPreset.color);
    _width = widget.initialPreset.width;
  }

  Color get _color => _hsvColor.toColor();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final selectedPreset = InkPreset(tool: _tool, color: _color, width: _width);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 14 + bottomInset),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: CustomPaint(
                        size: const Size(28, 28),
                        painter: InkPresetPreviewPainter(selectedPreset),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${widget.presetNumber}번 펜 설정',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<InkTool>(
                  segments: const [
                    ButtonSegment(
                      value: InkTool.pen,
                      icon: Icon(Icons.draw_rounded),
                      label: Text('펜'),
                    ),
                    ButtonSegment(
                      value: InkTool.highlighter,
                      icon: Icon(Icons.border_color_rounded),
                      label: Text('형광'),
                    ),
                    ButtonSegment(
                      value: InkTool.eraser,
                      icon: Icon(Icons.cleaning_services_rounded),
                      label: Text('지우개'),
                    ),
                  ],
                  selected: {_tool},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _tool = selection.first;
                      if (_tool == InkTool.eraser) {
                        _width = _width.clamp(8.0, 22.0);
                      }
                    });
                  },
                ),
                if (_tool != InkTool.eraser) ...[
                  const SizedBox(height: 16),
                  _InkColorField(
                    hsvColor: _hsvColor,
                    onChanged: (color) => setState(() => _hsvColor = color),
                  ),
                ],
                const SizedBox(height: 16),
                _InkSliderRow(
                  label: _tool == InkTool.eraser ? '지우개 크기' : '선 굵기',
                  value: _width,
                  min: _tool == InkTool.eraser ? 8 : 1.5,
                  max: _tool == InkTool.eraser ? 22 : 9,
                  onChanged: (value) => setState(() => _width = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      InkPreset(tool: _tool, color: _color, width: _width),
                    );
                  },
                  child: const Text('이 펜으로 저장'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InkColorFamily {
  final Color color;
  final double hue;

  const _InkColorFamily({required this.color, required this.hue});
}

class _InkColorField extends StatefulWidget {
  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onChanged;

  const _InkColorField({required this.hsvColor, required this.onChanged});

  @override
  State<_InkColorField> createState() => _InkColorFieldState();
}

class _InkColorFieldState extends State<_InkColorField> {
  static const List<_InkColorFamily> _families = [
    _InkColorFamily(color: Color(0xFF111827), hue: -1),
    _InkColorFamily(color: Color(0xFFDC2626), hue: 0),
    _InkColorFamily(color: Color(0xFFF97316), hue: 24),
    _InkColorFamily(color: Color(0xFFEAB308), hue: 48),
    _InkColorFamily(color: Color(0xFF16A34A), hue: 132),
    _InkColorFamily(color: Color(0xFF0D9488), hue: 174),
    _InkColorFamily(color: Color(0xFF2563EB), hue: 220),
    _InkColorFamily(color: Color(0xFF7C3AED), hue: 262),
    _InkColorFamily(color: Color(0xFFDB2777), hue: 330),
  ];

  late int _selectedFamilyIndex;

  @override
  void initState() {
    super.initState();
    _selectedFamilyIndex = _familyIndexFor(widget.hsvColor);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = widget.hsvColor.toColor();
    final selectedRgb = _rgbKey(currentColor);
    final palette = _paletteFor(_families[_selectedFamilyIndex]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 74,
              child: Text(
                '선택색',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4B5368),
                ),
              ),
            ),
            Container(
              width: 34,
              height: 24,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD8DFEA)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: palette.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final color = palette[index];
              final selected = _rgbKey(color) == selectedRgb;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onChanged(
                    HSVColor.fromColor(
                      color.withValues(alpha: widget.hsvColor.alpha),
                    ),
                  );
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? Colors.white : const Color(0x14000000),
                      width: selected ? 2.2 : 0.8,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _families.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final family = _families[index];
              final selected = _selectedFamilyIndex == index;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedFamilyIndex = index),
                child: Container(
                  width: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEEF1FF)
                        : const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFBFCBFF)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: family.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _InkSliderRow(
          label: '투명도',
          value: widget.hsvColor.alpha,
          min: 0.18,
          max: 1,
          activeColor: widget.hsvColor.toColor(),
          onChanged: (value) =>
              widget.onChanged(widget.hsvColor.withAlpha(value)),
        ),
      ],
    );
  }

  List<Color> _paletteFor(_InkColorFamily family) {
    if (family.hue < 0) {
      return [
        for (final value in const [
          0.07,
          0.14,
          0.21,
          0.28,
          0.35,
          0.44,
          0.56,
          0.72,
          0.90,
        ])
          HSVColor.fromAHSV(1, 220, 0.08, value).toColor(),
      ];
    }
    return [
      for (final saturation in const [0.90, 0.68, 0.48])
        for (final value in const [0.62, 0.74, 0.86])
          HSVColor.fromAHSV(1, family.hue, saturation, value).toColor(),
    ];
  }

  int _familyIndexFor(HSVColor color) {
    if (color.saturation < 0.16) {
      return 0;
    }
    var bestIndex = 1;
    var bestDistance = double.infinity;
    for (var index = 1; index < _families.length; index += 1) {
      final hue = _families[index].hue;
      final distance = (color.hue - hue).abs();
      final circularDistance = distance < 180 ? distance : 360 - distance;
      if (circularDistance < bestDistance) {
        bestDistance = circularDistance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  static int _rgbKey(Color color) => color.toARGB32() & 0x00FFFFFF;
}

class _InkSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color? activeColor;
  final ValueChanged<double> onChanged;

  const _InkSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4B5368),
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: activeColor ?? const Color(0xFF4C5AC7),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
