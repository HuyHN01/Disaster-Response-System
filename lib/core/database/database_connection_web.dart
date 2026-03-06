import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// WasmDatabase cho Web. Sử dụng SQLite qua WebAssembly.
/// Yêu cầu: sqlite3.wasm và drift_worker.dart.js trong thư mục web/
/// Xem: https://drift.simonbinder.eu/web/
QueryExecutor createConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'app_database',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.dart.js'),
      );
      return result.resolvedExecutor;
    }),
  );
}
