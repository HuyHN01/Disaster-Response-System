import 'package:flutter/material.dart';

class NewsFormatter {
  static Color getLevelColor(String? level) {
    switch (level) {
      case 'central':
        return const Color(0xFF991B1B); // Đỏ đậm
      case 'province':
        return const Color(0xFFDC2626); // Đỏ tươi
      case 'district':
        return const Color(0xFFD97706); // Cam
      case 'ward':
        return const Color(0xFF059669); // Xanh lá
      default:
        return const Color(0xFF6B7280); // Xám
    }
  }

  static String getLevelLabel(String? level) {
    switch (level) {
      case 'central':
        return 'TRUNG ƯƠNG';
      case 'province':
        return 'CẤP TỈNH';
      case 'district':
        return 'CẤP QUẬN';
      case 'ward':
        return 'CẤP XÃ';
      default:
        return 'TIN TỨC';
    }
  }
}
