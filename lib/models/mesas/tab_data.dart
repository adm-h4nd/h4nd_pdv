import 'package:flutter/material.dart';

/// Dados de uma tab
class TabData {
  final String? comandaId;
  final String label;
  final IconData icon;

  TabData({
    required this.comandaId,
    required this.label,
    required this.icon,
  });
}
