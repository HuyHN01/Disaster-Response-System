import 'package:drift/drift.dart';

import 'database_connection_stub.dart'
    if (dart.library.io) 'database_connection_native.dart'
    if (dart.library.html) 'database_connection_web.dart' as connection;

/// Tạo QueryExecutor phù hợp với platform:
/// - Mobile/Desktop: NativeDatabase (SQLite qua FFI)
/// - Web: WasmDatabase (SQLite qua WebAssembly)
QueryExecutor createConnection() => connection.createConnection();
