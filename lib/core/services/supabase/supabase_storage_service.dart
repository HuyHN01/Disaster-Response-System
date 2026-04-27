import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  // Hàm upload nhận vào Tên file và Dữ liệu nhị phân (bytes)
  static Future<String?> uploadAttachment(String fileName, Uint8List fileBytes) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Tạo tên file unique tránh trùng lặp
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final path = 'posts/$uniqueFileName';

      // Upload file dạng Binary (Bắt buộc dùng cách này cho Web)
      await supabase.storage.from('post_attachments').uploadBinary(
        path,
        fileBytes,
      );

      // Lấy link Public để lưu vào Firestore
      final publicUrl = supabase.storage.from('post_attachments').getPublicUrl(path);
      return publicUrl;
      
    } catch (e) {
      print('Lỗi upload Supabase: $e');
      throw Exception('Không thể tải tệp lên máy chủ: $e');
    }
  }
}