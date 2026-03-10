// lib/core/services/clipboard/clipboard_image_service_web.dart
//
// WEB IMPLEMENTATION — chỉ được compile khi target là Flutter Web.
// Dart conditional import đảm bảo file này không bao giờ được compile
// trên Android / iOS / Desktop.
//
// Import dart:js_interop và package:web ở đây là an toàn tuyệt đối vì
// conditional import đã cô lập chúng khỏi các platform khác.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Đọc bytes ảnh đầu tiên tìm thấy trong Web Clipboard API.
///
/// Trả về null nếu:
///   • Clipboard không chứa ảnh
///   • Người dùng từ chối quyền clipboard-read
///   • Trang không chạy trong ngữ cảnh bảo mật (HTTPS)
///
/// Caller nhận null → bỏ qua, để Quill tự paste text như thường.
Future<Uint8List?> readImageBytesFromClipboard() async {
  try {
    final items =
        await web.window.navigator.clipboard.read().toDart;

    for (var i = 0; i < items.length; i++) {
      final item = items[i] as web.ClipboardItem;

      // Thử theo thứ tự phổ biến:
      //   PNG  — Snipping Tool, screenshot macOS, copy từ browser
      //   JPEG — ảnh từ nhiều nguồn
      //   WebP — Chrome copy ảnh từ trang web
      //   GIF  — ảnh động
      for (final mimeType in [
        'image/png',
        'image/jpeg',
        'image/webp',
        'image/gif',
      ]) {
        try {
          final blob = await item.getType(mimeType).toDart;
          final buffer = await blob.arrayBuffer().toDart;
          return buffer.toDart.asUint8List();
        } catch (_) {
          // Mime type này không có trong clipboard item → thử tiếp
          continue;
        }
      }
    }

    return null; // Không tìm thấy ảnh nào trong clipboard
  } catch (_) {
    // navigator.clipboard.read() bị từ chối hoặc không khả dụng
    return null;
  }
}