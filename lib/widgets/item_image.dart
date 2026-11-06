import 'dart:convert';

import 'package:flutter/material.dart';

/// Shows an item's base64 thumbnail, or a soft placeholder.
class ItemImage extends StatelessWidget {
  final String? base64;
  final double? height;
  final double? width;
  const ItemImage({super.key, this.base64, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    final b = base64;
    if (b == null || b.isEmpty) {
      return Container(
        height: height,
        width: width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8EEF6), Color(0xFFD9E3F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          size: 40,
          color: Color(0xFF8DA2BD),
        ),
      );
    }
    return Image.memory(
      base64Decode(b),
      height: height,
      width: width,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}
