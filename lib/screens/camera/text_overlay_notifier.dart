import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class TextOverlay {
  final String id;
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const TextOverlay({
    required this.id,
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
  });

  TextOverlay copyWith({
    String? id,
    String? text,
    Offset? position,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return TextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }
}

class TextOverlayNotifier extends StateNotifier<List<TextOverlay>> {
  TextOverlayNotifier() : super([]);

  void add(TextOverlay overlay) {
    state = [...state, overlay];
  }

  void update(TextOverlay overlay) {
    state = [
      for (final o in state)
        if (o.id == overlay.id) overlay else o,
    ];
  }

  void remove(String id) {
    state = state.where((o) => o.id != id).toList();
  }
}

final textOverlayProvider = StateNotifierProvider<TextOverlayNotifier, List<TextOverlay>>((ref) {
  return TextOverlayNotifier();
});
