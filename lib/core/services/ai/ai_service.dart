import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  
  static final String _apiKey = _getApiKey();
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String _getApiKey() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      // Nếu API Key không có, ném ra một lỗi rõ ràng hơn
      throw StateError(
          'GEMINI_API_KEY is not found in .env file. Please add it.');
    }
    return apiKey;
  }

  // System Prompt: Quy định tính cách và giới hạn của AI
  static const String _systemInstruction = '''
Bạn là "Trợ lý Cứu hộ OmniDisaster" - một chuyên gia về phòng chống thiên tai và sơ cấp cứu y tế tại Việt Nam.
Nhiệm vụ của bạn là hướng dẫn người dân kỹ năng sinh tồn trong các tình huống: Bão, Lũ lụt, Sạt lở đất.

QUY TẮC BẮT BUỘC:
1. LUÔN giữ thái độ bình tĩnh, đồng cảm và rõ ràng. Dùng câu ngắn gọn.
2. CHỈ trả lời các câu hỏi liên quan đến thiên tai, sơ cứu, sinh tồn.
3. Nếu người dùng hỏi các chủ đề khác (giải trí, toán học, chính trị...), TỪ CHỐI trả lời và nhắc họ bạn chỉ hỗ trợ khẩn cấp.
4. Nếu tình huống y tế quá nghiêm trọng (đứt động mạch, bất tỉnh), BẮT BUỘC khuyên họ gọi ngay 112 trước khi hướng dẫn sơ cứu.
''';

  Future<String> askQuestion(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {
                  "text":
                      "$_systemInstruction\n\nCâu hỏi của người dân: $userMessage",
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        print('Lỗi AI: ${response.body}');
        return "Xin lỗi, hệ thống AI đang quá tải hoặc mất kết nối. Vui lòng làm theo hướng dẫn trong Cẩm nang Offline.";
      }
    } catch (e) {
      return "Không thể kết nối đến Trợ lý AI. Vui lòng kiểm tra lại mạng.";
    }
  }
}


