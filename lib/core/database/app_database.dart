import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'app_database.g.dart';

// ============ BẢNG USERS ============
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text()();
  TextColumn get role => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ BẢNG DISASTER EVENTS ============
class DisasterEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get eventType => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ BẢNG POSTS ============
class Posts extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text().references(DisasterEvents, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get postType => text()();
  TextColumn get content => text()();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ BẢNG LOCATIONS ============
class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get postId => text().references(Posts, #id)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get addressText => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ BẢNG ATTACHMENTS ============
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get postId => text().references(Posts, #id)();
  TextColumn get fileUrl => text()();
  TextColumn get fileType => text()();
  TextColumn get fileName => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ APP DATABASE ============
@DriftDatabase(tables: [Users, DisasterEvents, Posts, Locations, Attachments])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Constructor mặc định: NativeDatabase cho Mobile/Desktop, WasmDatabase cho Web
  factory AppDatabase.defaults() => AppDatabase(createConnection());

  @override
  int get schemaVersion => 1;
}
