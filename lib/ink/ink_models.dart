import 'package:flutter/material.dart';

double? _parseDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

int? _parseInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

enum InkTool { pen, highlighter, eraser }

class InkPreset {
  final InkTool tool;
  final Color color;
  final double width;

  const InkPreset({
    required this.tool,
    required this.color,
    required this.width,
  });

  bool get isEraser => tool == InkTool.eraser;

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'color': color.toARGB32(),
    'width': width,
  };

  static InkPreset? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final toolName = value['tool']?.toString();
    InkTool? tool;
    for (final item in InkTool.values) {
      if (item.name == toolName) {
        tool = item;
        break;
      }
    }
    final colorValue = value['color'];
    final width = _parseDouble(value['width']);
    if (tool == null || colorValue is! int || width == null) {
      return null;
    }
    return InkPreset(tool: tool, color: Color(colorValue), width: width);
  }

  static List<InkPreset> defaults() => const [
    InkPreset(tool: InkTool.pen, color: Color(0xFF111827), width: 3.2),
    InkPreset(tool: InkTool.pen, color: Color(0xFFE53935), width: 3.2),
    InkPreset(tool: InkTool.pen, color: Color(0xFF1E88E5), width: 3.2),
    InkPreset(tool: InkTool.highlighter, color: Color(0xFFF6C445), width: 4),
    InkPreset(tool: InkTool.eraser, color: Color(0xFF64748B), width: 12),
  ];
}

class InkPoint {
  final double x;
  final double y;

  const InkPoint(this.x, this.y);

  Offset toOffset() => Offset(x, y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  static InkPoint? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final x = _parseDouble(value['x']);
    final y = _parseDouble(value['y']);
    if (x == null || y == null) {
      return null;
    }
    return InkPoint(x, y);
  }
}

class InkStroke {
  final List<InkPoint> points;
  final Color color;
  final double width;
  final bool highlighter;
  final int savedAt;

  const InkStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.highlighter,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'points': points.map((point) => point.toJson()).toList(),
    'color': color.toARGB32(),
    'width': width,
    'highlighter': highlighter,
    'savedAt': savedAt,
  };

  static InkStroke? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final rawPoints = value['points'];
    if (rawPoints is! List) {
      return null;
    }
    final points = rawPoints.map(InkPoint.fromJson).whereType<InkPoint>();
    final colorValue = value['color'];
    final width = _parseDouble(value['width']) ?? 3;
    final savedAt = _parseInt(value['savedAt']) ?? 0;
    if (colorValue is! int) {
      return null;
    }
    return InkStroke(
      points: points.toList(),
      color: Color(colorValue),
      width: width,
      highlighter: value['highlighter'] == true,
      savedAt: savedAt,
    );
  }
}
