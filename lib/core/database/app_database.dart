import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'app_database.g.dart';

// ============ BẢNG USERS ============
class Users extends Table {
  // `id` is kept as the local PK to preserve existing FK references from Posts.
  // It mirrors the same value as `uid` from Firebase Auth.
  TextColumn get id => text()();
  TextColumn get uid => text().unique()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();
  TextColumn get photoUrl => text().nullable()();
  IntColumn get role => integer()(); // 0=superadmin, 1=admin, 2=staff, 3=user
  IntColumn get status =>
      integer()(); // 0=inactive, 1=active, 2=pending, 3=banned
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
  BoolColumn get mfaEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get medicalProfileJson => text().nullable()();
  
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
  TextColumn get title => text().nullable()();
  TextColumn get attachmentUrl => text().nullable()();
  TextColumn get attachmentName => text().nullable()();
  TextColumn get content => text()();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  TextColumn get issuingLevel => text().nullable()();

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

// ============ BẢNG RESCUE STATIONS ============
class RescueStations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get address => text().nullable()();
  TextColumn get contactPhone => text().nullable()();
  IntColumn get capacity => integer().nullable()();
  IntColumn get occupancy => integer().withDefault(const Constant(0))();
  TextColumn get resourcesJson => text().withDefault(const Constant('{}'))();
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // active/inactive/full
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))(); // synced/pending

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CheckInLog')
class CheckInLogs extends Table {
  TextColumn get id => text()();
  TextColumn get stationId =>
      text().references(RescueStations, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text()(); // 'in' or 'out'
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ BẢNG COMMUNITY REPORTS ============
@DataClassName('CommunityReport')
class CommunityReports extends Table {
  TextColumn get id => text()();
  TextColumn get type =>
      text()(); // 'fallen_tree', 'flood', 'road_block', 'other'
  TextColumn get customTypeName => text().nullable()(); // Name for 'other'
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get description => text().nullable()();
  TextColumn get reportedBy =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ BẢNG THỐNG KÊ THIỆT HẠI SỰ KIỆN (SNAPSHOT) ============
@DataClassName('EventDamageStat')
class EventDamageStats extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text().references(DisasterEvents, #id, onDelete: KeyAction.cascade)();
  IntColumn get deaths => integer().withDefault(const Constant(0))();
  IntColumn get missing => integer().withDefault(const Constant(0))();
  IntColumn get injured => integer().withDefault(const Constant(0))();
  IntColumn get damagedHouses => integer().withDefault(const Constant(0))();
  RealColumn get propertyDamage => real().withDefault(const Constant(0.0))();
  DateTimeColumn get reportedAt => dateTime()();
  TextColumn get reportedBy => text().references(Users, #id)();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ APP DATABASE ============
@DriftDatabase(
  tables: [
    Users,
    DisasterEvents,
    Posts,
    Locations,
    Attachments,
    RescueStations,
    CheckInLogs,
    CommunityReports,
    EventDamageStats,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Constructor mặc định: NativeDatabase cho Mobile/Desktop, WasmDatabase cho Web
  factory AppDatabase.defaults() => AppDatabase(createConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(rescueStations);
      }

      if (from < 3) {
        await customStatement('PRAGMA foreign_keys = OFF;');

        await customStatement('''
CREATE TABLE users_new (
  id TEXT NOT NULL PRIMARY KEY,
  uid TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL,
  photo_url TEXT NULL,
  role INTEGER NOT NULL,
  status INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  created_by TEXT NULL,
  last_login_at INTEGER NULL,
  mfa_enabled INTEGER NOT NULL DEFAULT 0
);
''');

        await customStatement('''
INSERT INTO users_new (
  id,
  uid,
  email,
  display_name,
  photo_url,
  role,
  status,
  created_at,
  updated_at,
  created_by,
  last_login_at,
  mfa_enabled
)
SELECT
  id,
  id,
  '',
  COALESCE(full_name, ''),
  avatar_url,
  CASE
    WHEN typeof(role) = 'integer' THEN role
    WHEN trim(role) GLOB '[0-9]*' THEN CAST(role AS INTEGER)
    WHEN lower(trim(role)) = 'superadmin' THEN 0
    WHEN lower(trim(role)) = 'admin' THEN 1
    WHEN lower(trim(role)) = 'staff' THEN 2
    ELSE 3
  END,
  2,
  CAST(strftime('%s','now') AS INTEGER),
  CAST(strftime('%s','now') AS INTEGER),
  NULL,
  NULL,
  0
FROM users;
''');

        await customStatement('DROP TABLE users;');
        await customStatement('ALTER TABLE users_new RENAME TO users;');
        await customStatement('PRAGMA foreign_keys = ON;');
      }

      if (from < 4) {
        await m.addColumn(rescueStations, rescueStations.occupancy);
      }

      if (from < 5) {
        await m.createTable(checkInLogs);
      }

      if (from < 6) {
        await m.createTable(communityReports);
      }
      
      if (from < 7) {
        await m.createTable(eventDamageStats);
        await m.addColumn(posts, posts.issuingLevel);
        await m.addColumn(users, users.medicalProfileJson);
      }
    },
  );

  /// Clears local data tied to the authenticated user/session.
  ///
  /// Order matters because of foreign keys:
  /// attachments -> locations -> posts -> users.
  Future<void> clearUserScopedData() async {
    await transaction(() async {
      await delete(attachments).go();
      await delete(locations).go();
      await delete(checkInLogs).go();
      await delete(communityReports).go();
      await delete(eventDamageStats).go();
      await delete(posts).go();
      await delete(rescueStations).go();
      await delete(disasterEvents).go();
      await delete(users).go();
    });
  }
}
