import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// WasmDatabase cho Web. Sử dụng SQLite qua WebAssembly.
/// Yêu cầu: sqlite3.wasm và drift_worker.js trong thư mục web/
/// Chạy scripts/download_web_assets.ps1 nếu thiếu file. Xem web/README.md
QueryExecutor createConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'app_database',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      return result.resolvedExecutor;
    }),
  );
}
