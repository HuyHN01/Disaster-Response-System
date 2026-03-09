import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

// Khởi tạo Database và cung cấp nó ra toàn App
final dbProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.defaults();
});
