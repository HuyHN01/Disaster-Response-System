// lib/core/services/clipboard/clipboard_image_service_stub.dart
//
// STUB dành cho Android / iOS / Desktop.
// Không import dart:js_interop hay package:web — hoàn toàn safe khi compile
// cho bất kỳ platform nào ngoài web.
//
// readImageBytesFromClipboard() trả về null ngay lập tức — platform này
// không hỗ trợ Web Clipboard API, Quill tự xử lý paste như thông thường.

import 'dart:typed_data';

/// Đọc bytes ảnh từ clipboard.
///
/// Trên mobile/desktop: luôn trả về null (không hỗ trợ Web Clipboard API).
/// Trên web: xem `clipboard_image_service_web.dart`.
Future<Uint8List?> readImageBytesFromClipboard() async => null;