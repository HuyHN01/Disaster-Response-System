// lib/core/services/clipboard/clipboard_image_service.dart
//
// CONDITIONAL IMPORT — Dart compiler tự chọn implementation đúng:
//   • Trên Web  → clipboard_image_service_web.dart   (dùng package:web)
//   • Còn lại   → clipboard_image_service_stub.dart  (trả null)
//
// ĐÂY LÀ FILE DUY NHẤT bạn import ở nơi khác. Không bao giờ import
// trực tiếp file _web hay _stub.

export 'clipboard_image_service_stub.dart'
    if (dart.library.js_interop) 'clipboard_image_service_web.dart';