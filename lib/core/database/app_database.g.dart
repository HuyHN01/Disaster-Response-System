// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, fullName, role, phone, avatarUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String fullName;
  final String role;
  final String? phone;
  final String? avatarUrl;
  const User({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.avatarUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['full_name'] = Variable<String>(fullName);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      fullName: Value(fullName),
      role: Value(role),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      fullName: serializer.fromJson<String>(json['fullName']),
      role: serializer.fromJson<String>(json['role']),
      phone: serializer.fromJson<String?>(json['phone']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fullName': serializer.toJson<String>(fullName),
      'role': serializer.toJson<String>(role),
      'phone': serializer.toJson<String?>(phone),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
    };
  }

  User copyWith({
    String? id,
    String? fullName,
    String? role,
    Value<String?> phone = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    role: role ?? this.role,
    phone: phone.present ? phone.value : this.phone,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      role: data.role.present ? data.role.value : this.role,
      phone: data.phone.present ? data.phone.value : this.phone,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('role: $role, ')
          ..write('phone: $phone, ')
          ..write('avatarUrl: $avatarUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fullName, role, phone, avatarUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.fullName == this.fullName &&
          other.role == this.role &&
          other.phone == this.phone &&
          other.avatarUrl == this.avatarUrl);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String> fullName;
  final Value<String> role;
  final Value<String?> phone;
  final Value<String?> avatarUrl;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.role = const Value.absent(),
    this.phone = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String fullName,
    required String role,
    this.phone = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fullName = Value(fullName),
       role = Value(role);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? fullName,
    Expression<String>? role,
    Expression<String>? phone,
    Expression<String>? avatarUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fullName != null) 'full_name': fullName,
      if (role != null) 'role': role,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<String>? fullName,
    Value<String>? role,
    Value<String?>? phone,
    Value<String?>? avatarUrl,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('role: $role, ')
          ..write('phone: $phone, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DisasterEventsTable extends DisasterEvents
    with TableInfo<$DisasterEventsTable, DisasterEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DisasterEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    eventType,
    status,
    createdAt,
    createdBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'disaster_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<DisasterEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DisasterEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DisasterEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
    );
  }

  @override
  $DisasterEventsTable createAlias(String alias) {
    return $DisasterEventsTable(attachedDatabase, alias);
  }
}

class DisasterEvent extends DataClass implements Insertable<DisasterEvent> {
  final String id;
  final String title;
  final String eventType;
  final String status;
  final DateTime createdAt;
  final String createdBy;
  const DisasterEvent({
    required this.id,
    required this.title,
    required this.eventType,
    required this.status,
    required this.createdAt,
    required this.createdBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['event_type'] = Variable<String>(eventType);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['created_by'] = Variable<String>(createdBy);
    return map;
  }

  DisasterEventsCompanion toCompanion(bool nullToAbsent) {
    return DisasterEventsCompanion(
      id: Value(id),
      title: Value(title),
      eventType: Value(eventType),
      status: Value(status),
      createdAt: Value(createdAt),
      createdBy: Value(createdBy),
    );
  }

  factory DisasterEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DisasterEvent(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      eventType: serializer.fromJson<String>(json['eventType']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'eventType': serializer.toJson<String>(eventType),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'createdBy': serializer.toJson<String>(createdBy),
    };
  }

  DisasterEvent copyWith({
    String? id,
    String? title,
    String? eventType,
    String? status,
    DateTime? createdAt,
    String? createdBy,
  }) => DisasterEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    eventType: eventType ?? this.eventType,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
  );
  DisasterEvent copyWithCompanion(DisasterEventsCompanion data) {
    return DisasterEvent(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DisasterEvent(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('eventType: $eventType, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, eventType, status, createdAt, createdBy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DisasterEvent &&
          other.id == this.id &&
          other.title == this.title &&
          other.eventType == this.eventType &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy);
}

class DisasterEventsCompanion extends UpdateCompanion<DisasterEvent> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> eventType;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<String> createdBy;
  final Value<int> rowid;
  const DisasterEventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.eventType = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DisasterEventsCompanion.insert({
    required String id,
    required String title,
    required String eventType,
    required String status,
    required DateTime createdAt,
    required String createdBy,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       eventType = Value(eventType),
       status = Value(status),
       createdAt = Value(createdAt),
       createdBy = Value(createdBy);
  static Insertable<DisasterEvent> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? eventType,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<String>? createdBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (eventType != null) 'event_type': eventType,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DisasterEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? eventType,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<String>? createdBy,
    Value<int>? rowid,
  }) {
    return DisasterEventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DisasterEventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('eventType: $eventType, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PostsTable extends Posts with TableInfo<$PostsTable, Post> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES disaster_events (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _postTypeMeta = const VerificationMeta(
    'postType',
  );
  @override
  late final GeneratedColumn<String> postType = GeneratedColumn<String>(
    'post_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentUrlMeta = const VerificationMeta(
    'attachmentUrl',
  );
  @override
  late final GeneratedColumn<String> attachmentUrl = GeneratedColumn<String>(
    'attachment_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentNameMeta = const VerificationMeta(
    'attachmentName',
  );
  @override
  late final GeneratedColumn<String> attachmentName = GeneratedColumn<String>(
    'attachment_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isVerifiedMeta = const VerificationMeta(
    'isVerified',
  );
  @override
  late final GeneratedColumn<bool> isVerified = GeneratedColumn<bool>(
    'is_verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_verified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    userId,
    postType,
    title,
    attachmentUrl,
    attachmentName,
    content,
    isVerified,
    createdAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Post> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('post_type')) {
      context.handle(
        _postTypeMeta,
        postType.isAcceptableOrUnknown(data['post_type']!, _postTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_postTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('attachment_url')) {
      context.handle(
        _attachmentUrlMeta,
        attachmentUrl.isAcceptableOrUnknown(
          data['attachment_url']!,
          _attachmentUrlMeta,
        ),
      );
    }
    if (data.containsKey('attachment_name')) {
      context.handle(
        _attachmentNameMeta,
        attachmentName.isAcceptableOrUnknown(
          data['attachment_name']!,
          _attachmentNameMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('is_verified')) {
      context.handle(
        _isVerifiedMeta,
        isVerified.isAcceptableOrUnknown(data['is_verified']!, _isVerifiedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Post map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Post(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      postType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      attachmentUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_url'],
      ),
      attachmentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_name'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      isVerified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_verified'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $PostsTable createAlias(String alias) {
    return $PostsTable(attachedDatabase, alias);
  }
}

class Post extends DataClass implements Insertable<Post> {
  final String id;
  final String eventId;
  final String userId;
  final String postType;
  final String? title;
  final String? attachmentUrl;
  final String? attachmentName;
  final String content;
  final bool isVerified;
  final DateTime createdAt;
  final String syncStatus;
  const Post({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.postType,
    this.title,
    this.attachmentUrl,
    this.attachmentName,
    required this.content,
    required this.isVerified,
    required this.createdAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_id'] = Variable<String>(eventId);
    map['user_id'] = Variable<String>(userId);
    map['post_type'] = Variable<String>(postType);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || attachmentUrl != null) {
      map['attachment_url'] = Variable<String>(attachmentUrl);
    }
    if (!nullToAbsent || attachmentName != null) {
      map['attachment_name'] = Variable<String>(attachmentName);
    }
    map['content'] = Variable<String>(content);
    map['is_verified'] = Variable<bool>(isVerified);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  PostsCompanion toCompanion(bool nullToAbsent) {
    return PostsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      userId: Value(userId),
      postType: Value(postType),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      attachmentUrl: attachmentUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentUrl),
      attachmentName: attachmentName == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentName),
      content: Value(content),
      isVerified: Value(isVerified),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Post.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Post(
      id: serializer.fromJson<String>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      userId: serializer.fromJson<String>(json['userId']),
      postType: serializer.fromJson<String>(json['postType']),
      title: serializer.fromJson<String?>(json['title']),
      attachmentUrl: serializer.fromJson<String?>(json['attachmentUrl']),
      attachmentName: serializer.fromJson<String?>(json['attachmentName']),
      content: serializer.fromJson<String>(json['content']),
      isVerified: serializer.fromJson<bool>(json['isVerified']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventId': serializer.toJson<String>(eventId),
      'userId': serializer.toJson<String>(userId),
      'postType': serializer.toJson<String>(postType),
      'title': serializer.toJson<String?>(title),
      'attachmentUrl': serializer.toJson<String?>(attachmentUrl),
      'attachmentName': serializer.toJson<String?>(attachmentName),
      'content': serializer.toJson<String>(content),
      'isVerified': serializer.toJson<bool>(isVerified),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  Post copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? postType,
    Value<String?> title = const Value.absent(),
    Value<String?> attachmentUrl = const Value.absent(),
    Value<String?> attachmentName = const Value.absent(),
    String? content,
    bool? isVerified,
    DateTime? createdAt,
    String? syncStatus,
  }) => Post(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    userId: userId ?? this.userId,
    postType: postType ?? this.postType,
    title: title.present ? title.value : this.title,
    attachmentUrl: attachmentUrl.present
        ? attachmentUrl.value
        : this.attachmentUrl,
    attachmentName: attachmentName.present
        ? attachmentName.value
        : this.attachmentName,
    content: content ?? this.content,
    isVerified: isVerified ?? this.isVerified,
    createdAt: createdAt ?? this.createdAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Post copyWithCompanion(PostsCompanion data) {
    return Post(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      userId: data.userId.present ? data.userId.value : this.userId,
      postType: data.postType.present ? data.postType.value : this.postType,
      title: data.title.present ? data.title.value : this.title,
      attachmentUrl: data.attachmentUrl.present
          ? data.attachmentUrl.value
          : this.attachmentUrl,
      attachmentName: data.attachmentName.present
          ? data.attachmentName.value
          : this.attachmentName,
      content: data.content.present ? data.content.value : this.content,
      isVerified: data.isVerified.present
          ? data.isVerified.value
          : this.isVerified,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Post(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('userId: $userId, ')
          ..write('postType: $postType, ')
          ..write('title: $title, ')
          ..write('attachmentUrl: $attachmentUrl, ')
          ..write('attachmentName: $attachmentName, ')
          ..write('content: $content, ')
          ..write('isVerified: $isVerified, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    userId,
    postType,
    title,
    attachmentUrl,
    attachmentName,
    content,
    isVerified,
    createdAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Post &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.userId == this.userId &&
          other.postType == this.postType &&
          other.title == this.title &&
          other.attachmentUrl == this.attachmentUrl &&
          other.attachmentName == this.attachmentName &&
          other.content == this.content &&
          other.isVerified == this.isVerified &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus);
}

class PostsCompanion extends UpdateCompanion<Post> {
  final Value<String> id;
  final Value<String> eventId;
  final Value<String> userId;
  final Value<String> postType;
  final Value<String?> title;
  final Value<String?> attachmentUrl;
  final Value<String?> attachmentName;
  final Value<String> content;
  final Value<bool> isVerified;
  final Value<DateTime> createdAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const PostsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.userId = const Value.absent(),
    this.postType = const Value.absent(),
    this.title = const Value.absent(),
    this.attachmentUrl = const Value.absent(),
    this.attachmentName = const Value.absent(),
    this.content = const Value.absent(),
    this.isVerified = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PostsCompanion.insert({
    required String id,
    required String eventId,
    required String userId,
    required String postType,
    this.title = const Value.absent(),
    this.attachmentUrl = const Value.absent(),
    this.attachmentName = const Value.absent(),
    required String content,
    this.isVerified = const Value.absent(),
    required DateTime createdAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventId = Value(eventId),
       userId = Value(userId),
       postType = Value(postType),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<Post> custom({
    Expression<String>? id,
    Expression<String>? eventId,
    Expression<String>? userId,
    Expression<String>? postType,
    Expression<String>? title,
    Expression<String>? attachmentUrl,
    Expression<String>? attachmentName,
    Expression<String>? content,
    Expression<bool>? isVerified,
    Expression<DateTime>? createdAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (userId != null) 'user_id': userId,
      if (postType != null) 'post_type': postType,
      if (title != null) 'title': title,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentName != null) 'attachment_name': attachmentName,
      if (content != null) 'content': content,
      if (isVerified != null) 'is_verified': isVerified,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PostsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventId,
    Value<String>? userId,
    Value<String>? postType,
    Value<String?>? title,
    Value<String?>? attachmentUrl,
    Value<String?>? attachmentName,
    Value<String>? content,
    Value<bool>? isVerified,
    Value<DateTime>? createdAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return PostsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      postType: postType ?? this.postType,
      title: title ?? this.title,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      content: content ?? this.content,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (postType.present) {
      map['post_type'] = Variable<String>(postType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (attachmentUrl.present) {
      map['attachment_url'] = Variable<String>(attachmentUrl.value);
    }
    if (attachmentName.present) {
      map['attachment_name'] = Variable<String>(attachmentName.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (isVerified.present) {
      map['is_verified'] = Variable<bool>(isVerified.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PostsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('userId: $userId, ')
          ..write('postType: $postType, ')
          ..write('title: $title, ')
          ..write('attachmentUrl: $attachmentUrl, ')
          ..write('attachmentName: $attachmentName, ')
          ..write('content: $content, ')
          ..write('isVerified: $isVerified, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocationsTable extends Locations
    with TableInfo<$LocationsTable, Location> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<String> postId = GeneratedColumn<String>(
    'post_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES posts (id)',
    ),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressTextMeta = const VerificationMeta(
    'addressText',
  );
  @override
  late final GeneratedColumn<String> addressText = GeneratedColumn<String>(
    'address_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    postId,
    latitude,
    longitude,
    addressText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Location> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('post_id')) {
      context.handle(
        _postIdMeta,
        postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta),
      );
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('address_text')) {
      context.handle(
        _addressTextMeta,
        addressText.isAcceptableOrUnknown(
          data['address_text']!,
          _addressTextMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Location map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Location(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      postId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      addressText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_text'],
      ),
    );
  }

  @override
  $LocationsTable createAlias(String alias) {
    return $LocationsTable(attachedDatabase, alias);
  }
}

class Location extends DataClass implements Insertable<Location> {
  final String id;
  final String postId;
  final double latitude;
  final double longitude;
  final String? addressText;
  const Location({
    required this.id,
    required this.postId,
    required this.latitude,
    required this.longitude,
    this.addressText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['post_id'] = Variable<String>(postId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || addressText != null) {
      map['address_text'] = Variable<String>(addressText);
    }
    return map;
  }

  LocationsCompanion toCompanion(bool nullToAbsent) {
    return LocationsCompanion(
      id: Value(id),
      postId: Value(postId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      addressText: addressText == null && nullToAbsent
          ? const Value.absent()
          : Value(addressText),
    );
  }

  factory Location.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Location(
      id: serializer.fromJson<String>(json['id']),
      postId: serializer.fromJson<String>(json['postId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      addressText: serializer.fromJson<String?>(json['addressText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'postId': serializer.toJson<String>(postId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'addressText': serializer.toJson<String?>(addressText),
    };
  }

  Location copyWith({
    String? id,
    String? postId,
    double? latitude,
    double? longitude,
    Value<String?> addressText = const Value.absent(),
  }) => Location(
    id: id ?? this.id,
    postId: postId ?? this.postId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    addressText: addressText.present ? addressText.value : this.addressText,
  );
  Location copyWithCompanion(LocationsCompanion data) {
    return Location(
      id: data.id.present ? data.id.value : this.id,
      postId: data.postId.present ? data.postId.value : this.postId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      addressText: data.addressText.present
          ? data.addressText.value
          : this.addressText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Location(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('addressText: $addressText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, postId, latitude, longitude, addressText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Location &&
          other.id == this.id &&
          other.postId == this.postId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.addressText == this.addressText);
}

class LocationsCompanion extends UpdateCompanion<Location> {
  final Value<String> id;
  final Value<String> postId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String?> addressText;
  final Value<int> rowid;
  const LocationsCompanion({
    this.id = const Value.absent(),
    this.postId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.addressText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocationsCompanion.insert({
    required String id,
    required String postId,
    required double latitude,
    required double longitude,
    this.addressText = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       postId = Value(postId),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<Location> custom({
    Expression<String>? id,
    Expression<String>? postId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? addressText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postId != null) 'post_id': postId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (addressText != null) 'address_text': addressText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? postId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String?>? addressText,
    Value<int>? rowid,
  }) {
    return LocationsCompanion(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressText: addressText ?? this.addressText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (postId.present) {
      map['post_id'] = Variable<String>(postId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (addressText.present) {
      map['address_text'] = Variable<String>(addressText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationsCompanion(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('addressText: $addressText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<String> postId = GeneratedColumn<String>(
    'post_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES posts (id)',
    ),
  );
  static const VerificationMeta _fileUrlMeta = const VerificationMeta(
    'fileUrl',
  );
  @override
  late final GeneratedColumn<String> fileUrl = GeneratedColumn<String>(
    'file_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileTypeMeta = const VerificationMeta(
    'fileType',
  );
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
    'file_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    postId,
    fileUrl,
    fileType,
    fileName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('post_id')) {
      context.handle(
        _postIdMeta,
        postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta),
      );
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('file_url')) {
      context.handle(
        _fileUrlMeta,
        fileUrl.isAcceptableOrUnknown(data['file_url']!, _fileUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_fileUrlMeta);
    }
    if (data.containsKey('file_type')) {
      context.handle(
        _fileTypeMeta,
        fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileTypeMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      postId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_id'],
      )!,
      fileUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_url'],
      )!,
      fileType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_type'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String postId;
  final String fileUrl;
  final String fileType;
  final String fileName;
  const Attachment({
    required this.id,
    required this.postId,
    required this.fileUrl,
    required this.fileType,
    required this.fileName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['post_id'] = Variable<String>(postId);
    map['file_url'] = Variable<String>(fileUrl);
    map['file_type'] = Variable<String>(fileType);
    map['file_name'] = Variable<String>(fileName);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      postId: Value(postId),
      fileUrl: Value(fileUrl),
      fileType: Value(fileType),
      fileName: Value(fileName),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      postId: serializer.fromJson<String>(json['postId']),
      fileUrl: serializer.fromJson<String>(json['fileUrl']),
      fileType: serializer.fromJson<String>(json['fileType']),
      fileName: serializer.fromJson<String>(json['fileName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'postId': serializer.toJson<String>(postId),
      'fileUrl': serializer.toJson<String>(fileUrl),
      'fileType': serializer.toJson<String>(fileType),
      'fileName': serializer.toJson<String>(fileName),
    };
  }

  Attachment copyWith({
    String? id,
    String? postId,
    String? fileUrl,
    String? fileType,
    String? fileName,
  }) => Attachment(
    id: id ?? this.id,
    postId: postId ?? this.postId,
    fileUrl: fileUrl ?? this.fileUrl,
    fileType: fileType ?? this.fileType,
    fileName: fileName ?? this.fileName,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      postId: data.postId.present ? data.postId.value : this.postId,
      fileUrl: data.fileUrl.present ? data.fileUrl.value : this.fileUrl,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('fileType: $fileType, ')
          ..write('fileName: $fileName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, postId, fileUrl, fileType, fileName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.postId == this.postId &&
          other.fileUrl == this.fileUrl &&
          other.fileType == this.fileType &&
          other.fileName == this.fileName);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> postId;
  final Value<String> fileUrl;
  final Value<String> fileType;
  final Value<String> fileName;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.postId = const Value.absent(),
    this.fileUrl = const Value.absent(),
    this.fileType = const Value.absent(),
    this.fileName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String postId,
    required String fileUrl,
    required String fileType,
    required String fileName,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       postId = Value(postId),
       fileUrl = Value(fileUrl),
       fileType = Value(fileType),
       fileName = Value(fileName);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? postId,
    Expression<String>? fileUrl,
    Expression<String>? fileType,
    Expression<String>? fileName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postId != null) 'post_id': postId,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileType != null) 'file_type': fileType,
      if (fileName != null) 'file_name': fileName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? postId,
    Value<String>? fileUrl,
    Value<String>? fileType,
    Value<String>? fileName,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileName: fileName ?? this.fileName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (postId.present) {
      map['post_id'] = Variable<String>(postId.value);
    }
    if (fileUrl.present) {
      map['file_url'] = Variable<String>(fileUrl.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('fileType: $fileType, ')
          ..write('fileName: $fileName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $DisasterEventsTable disasterEvents = $DisasterEventsTable(this);
  late final $PostsTable posts = $PostsTable(this);
  late final $LocationsTable locations = $LocationsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    disasterEvents,
    posts,
    locations,
    attachments,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      required String id,
      required String fullName,
      required String role,
      Value<String?> phone,
      Value<String?> avatarUrl,
      Value<int> rowid,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<String> id,
      Value<String> fullName,
      Value<String> role,
      Value<String?> phone,
      Value<String?> avatarUrl,
      Value<int> rowid,
    });

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PostsTable, List<Post>> _postsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.posts,
    aliasName: $_aliasNameGenerator(db.users.id, db.posts.userId),
  );

  $$PostsTableProcessedTableManager get postsRefs {
    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_postsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> postsRefs(
    Expression<bool> Function($$PostsTableFilterComposer f) f,
  ) {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  Expression<T> postsRefs<T extends Object>(
    Expression<T> Function($$PostsTableAnnotationComposer a) f,
  ) {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, $$UsersTableReferences),
          User,
          PrefetchHooks Function({bool postsRefs})
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                fullName: fullName,
                role: role,
                phone: phone,
                avatarUrl: avatarUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fullName,
                required String role,
                Value<String?> phone = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                fullName: fullName,
                role: role,
                phone: phone,
                avatarUrl: avatarUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$UsersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({postsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (postsRefs) db.posts],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (postsRefs)
                    await $_getPrefetchedData<User, $UsersTable, Post>(
                      currentTable: table,
                      referencedTable: $$UsersTableReferences._postsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$UsersTableReferences(db, table, p0).postsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.userId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, $$UsersTableReferences),
      User,
      PrefetchHooks Function({bool postsRefs})
    >;
typedef $$DisasterEventsTableCreateCompanionBuilder =
    DisasterEventsCompanion Function({
      required String id,
      required String title,
      required String eventType,
      required String status,
      required DateTime createdAt,
      required String createdBy,
      Value<int> rowid,
    });
typedef $$DisasterEventsTableUpdateCompanionBuilder =
    DisasterEventsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> eventType,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<String> createdBy,
      Value<int> rowid,
    });

final class $$DisasterEventsTableReferences
    extends BaseReferences<_$AppDatabase, $DisasterEventsTable, DisasterEvent> {
  $$DisasterEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PostsTable, List<Post>> _postsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.posts,
    aliasName: $_aliasNameGenerator(db.disasterEvents.id, db.posts.eventId),
  );

  $$PostsTableProcessedTableManager get postsRefs {
    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_postsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DisasterEventsTableFilterComposer
    extends Composer<_$AppDatabase, $DisasterEventsTable> {
  $$DisasterEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> postsRefs(
    Expression<bool> Function($$PostsTableFilterComposer f) f,
  ) {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DisasterEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $DisasterEventsTable> {
  $$DisasterEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DisasterEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DisasterEventsTable> {
  $$DisasterEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  Expression<T> postsRefs<T extends Object>(
    Expression<T> Function($$PostsTableAnnotationComposer a) f,
  ) {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DisasterEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DisasterEventsTable,
          DisasterEvent,
          $$DisasterEventsTableFilterComposer,
          $$DisasterEventsTableOrderingComposer,
          $$DisasterEventsTableAnnotationComposer,
          $$DisasterEventsTableCreateCompanionBuilder,
          $$DisasterEventsTableUpdateCompanionBuilder,
          (DisasterEvent, $$DisasterEventsTableReferences),
          DisasterEvent,
          PrefetchHooks Function({bool postsRefs})
        > {
  $$DisasterEventsTableTableManager(
    _$AppDatabase db,
    $DisasterEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DisasterEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DisasterEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DisasterEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DisasterEventsCompanion(
                id: id,
                title: title,
                eventType: eventType,
                status: status,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String eventType,
                required String status,
                required DateTime createdAt,
                required String createdBy,
                Value<int> rowid = const Value.absent(),
              }) => DisasterEventsCompanion.insert(
                id: id,
                title: title,
                eventType: eventType,
                status: status,
                createdAt: createdAt,
                createdBy: createdBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DisasterEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({postsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (postsRefs) db.posts],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (postsRefs)
                    await $_getPrefetchedData<
                      DisasterEvent,
                      $DisasterEventsTable,
                      Post
                    >(
                      currentTable: table,
                      referencedTable: $$DisasterEventsTableReferences
                          ._postsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DisasterEventsTableReferences(
                            db,
                            table,
                            p0,
                          ).postsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.eventId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DisasterEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DisasterEventsTable,
      DisasterEvent,
      $$DisasterEventsTableFilterComposer,
      $$DisasterEventsTableOrderingComposer,
      $$DisasterEventsTableAnnotationComposer,
      $$DisasterEventsTableCreateCompanionBuilder,
      $$DisasterEventsTableUpdateCompanionBuilder,
      (DisasterEvent, $$DisasterEventsTableReferences),
      DisasterEvent,
      PrefetchHooks Function({bool postsRefs})
    >;
typedef $$PostsTableCreateCompanionBuilder =
    PostsCompanion Function({
      required String id,
      required String eventId,
      required String userId,
      required String postType,
      Value<String?> title,
      Value<String?> attachmentUrl,
      Value<String?> attachmentName,
      required String content,
      Value<bool> isVerified,
      required DateTime createdAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$PostsTableUpdateCompanionBuilder =
    PostsCompanion Function({
      Value<String> id,
      Value<String> eventId,
      Value<String> userId,
      Value<String> postType,
      Value<String?> title,
      Value<String?> attachmentUrl,
      Value<String?> attachmentName,
      Value<String> content,
      Value<bool> isVerified,
      Value<DateTime> createdAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });

final class $$PostsTableReferences
    extends BaseReferences<_$AppDatabase, $PostsTable, Post> {
  $$PostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DisasterEventsTable _eventIdTable(_$AppDatabase db) =>
      db.disasterEvents.createAlias(
        $_aliasNameGenerator(db.posts.eventId, db.disasterEvents.id),
      );

  $$DisasterEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$DisasterEventsTableTableManager(
      $_db,
      $_db.disasterEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _userIdTable(_$AppDatabase db) =>
      db.users.createAlias($_aliasNameGenerator(db.posts.userId, db.users.id));

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LocationsTable, List<Location>>
  _locationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.locations,
    aliasName: $_aliasNameGenerator(db.posts.id, db.locations.postId),
  );

  $$LocationsTableProcessedTableManager get locationsRefs {
    final manager = $$LocationsTableTableManager(
      $_db,
      $_db.locations,
    ).filter((f) => f.postId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_locationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: $_aliasNameGenerator(db.posts.id, db.attachments.postId),
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.postId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PostsTableFilterComposer extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postType => $composableBuilder(
    column: $table.postType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentUrl => $composableBuilder(
    column: $table.attachmentUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentName => $composableBuilder(
    column: $table.attachmentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$DisasterEventsTableFilterComposer get eventId {
    final $$DisasterEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.disasterEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DisasterEventsTableFilterComposer(
            $db: $db,
            $table: $db.disasterEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> locationsRefs(
    Expression<bool> Function($$LocationsTableFilterComposer f) f,
  ) {
    final $$LocationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.locations,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationsTableFilterComposer(
            $db: $db,
            $table: $db.locations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PostsTableOrderingComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postType => $composableBuilder(
    column: $table.postType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentUrl => $composableBuilder(
    column: $table.attachmentUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentName => $composableBuilder(
    column: $table.attachmentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$DisasterEventsTableOrderingComposer get eventId {
    final $$DisasterEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.disasterEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DisasterEventsTableOrderingComposer(
            $db: $db,
            $table: $db.disasterEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PostsTable> {
  $$PostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get postType =>
      $composableBuilder(column: $table.postType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get attachmentUrl => $composableBuilder(
    column: $table.attachmentUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentName => $composableBuilder(
    column: $table.attachmentName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get isVerified => $composableBuilder(
    column: $table.isVerified,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$DisasterEventsTableAnnotationComposer get eventId {
    final $$DisasterEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.disasterEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DisasterEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.disasterEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> locationsRefs<T extends Object>(
    Expression<T> Function($$LocationsTableAnnotationComposer a) f,
  ) {
    final $$LocationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.locations,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationsTableAnnotationComposer(
            $db: $db,
            $table: $db.locations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PostsTable,
          Post,
          $$PostsTableFilterComposer,
          $$PostsTableOrderingComposer,
          $$PostsTableAnnotationComposer,
          $$PostsTableCreateCompanionBuilder,
          $$PostsTableUpdateCompanionBuilder,
          (Post, $$PostsTableReferences),
          Post,
          PrefetchHooks Function({
            bool eventId,
            bool userId,
            bool locationsRefs,
            bool attachmentsRefs,
          })
        > {
  $$PostsTableTableManager(_$AppDatabase db, $PostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> postType = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> attachmentUrl = const Value.absent(),
                Value<String?> attachmentName = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> isVerified = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PostsCompanion(
                id: id,
                eventId: eventId,
                userId: userId,
                postType: postType,
                title: title,
                attachmentUrl: attachmentUrl,
                attachmentName: attachmentName,
                content: content,
                isVerified: isVerified,
                createdAt: createdAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventId,
                required String userId,
                required String postType,
                Value<String?> title = const Value.absent(),
                Value<String?> attachmentUrl = const Value.absent(),
                Value<String?> attachmentName = const Value.absent(),
                required String content,
                Value<bool> isVerified = const Value.absent(),
                required DateTime createdAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PostsCompanion.insert(
                id: id,
                eventId: eventId,
                userId: userId,
                postType: postType,
                title: title,
                attachmentUrl: attachmentUrl,
                attachmentName: attachmentName,
                content: content,
                isVerified: isVerified,
                createdAt: createdAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PostsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                eventId = false,
                userId = false,
                locationsRefs = false,
                attachmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (locationsRefs) db.locations,
                    if (attachmentsRefs) db.attachments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (eventId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.eventId,
                                    referencedTable: $$PostsTableReferences
                                        ._eventIdTable(db),
                                    referencedColumn: $$PostsTableReferences
                                        ._eventIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (userId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.userId,
                                    referencedTable: $$PostsTableReferences
                                        ._userIdTable(db),
                                    referencedColumn: $$PostsTableReferences
                                        ._userIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (locationsRefs)
                        await $_getPrefetchedData<Post, $PostsTable, Location>(
                          currentTable: table,
                          referencedTable: $$PostsTableReferences
                              ._locationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PostsTableReferences(
                                db,
                                table,
                                p0,
                              ).locationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.postId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          Post,
                          $PostsTable,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $$PostsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PostsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.postId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PostsTable,
      Post,
      $$PostsTableFilterComposer,
      $$PostsTableOrderingComposer,
      $$PostsTableAnnotationComposer,
      $$PostsTableCreateCompanionBuilder,
      $$PostsTableUpdateCompanionBuilder,
      (Post, $$PostsTableReferences),
      Post,
      PrefetchHooks Function({
        bool eventId,
        bool userId,
        bool locationsRefs,
        bool attachmentsRefs,
      })
    >;
typedef $$LocationsTableCreateCompanionBuilder =
    LocationsCompanion Function({
      required String id,
      required String postId,
      required double latitude,
      required double longitude,
      Value<String?> addressText,
      Value<int> rowid,
    });
typedef $$LocationsTableUpdateCompanionBuilder =
    LocationsCompanion Function({
      Value<String> id,
      Value<String> postId,
      Value<double> latitude,
      Value<double> longitude,
      Value<String?> addressText,
      Value<int> rowid,
    });

final class $$LocationsTableReferences
    extends BaseReferences<_$AppDatabase, $LocationsTable, Location> {
  $$LocationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PostsTable _postIdTable(_$AppDatabase db) => db.posts.createAlias(
    $_aliasNameGenerator(db.locations.postId, db.posts.id),
  );

  $$PostsTableProcessedTableManager get postId {
    final $_column = $_itemColumn<String>('post_id')!;

    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_postIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => ColumnFilters(column),
  );

  $$PostsTableFilterComposer get postId {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => ColumnOrderings(column),
  );

  $$PostsTableOrderingComposer get postId {
    final $$PostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableOrderingComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => column,
  );

  $$PostsTableAnnotationComposer get postId {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationsTable,
          Location,
          $$LocationsTableFilterComposer,
          $$LocationsTableOrderingComposer,
          $$LocationsTableAnnotationComposer,
          $$LocationsTableCreateCompanionBuilder,
          $$LocationsTableUpdateCompanionBuilder,
          (Location, $$LocationsTableReferences),
          Location,
          PrefetchHooks Function({bool postId})
        > {
  $$LocationsTableTableManager(_$AppDatabase db, $LocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> postId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String?> addressText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocationsCompanion(
                id: id,
                postId: postId,
                latitude: latitude,
                longitude: longitude,
                addressText: addressText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String postId,
                required double latitude,
                required double longitude,
                Value<String?> addressText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocationsCompanion.insert(
                id: id,
                postId: postId,
                latitude: latitude,
                longitude: longitude,
                addressText: addressText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({postId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (postId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.postId,
                                referencedTable: $$LocationsTableReferences
                                    ._postIdTable(db),
                                referencedColumn: $$LocationsTableReferences
                                    ._postIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationsTable,
      Location,
      $$LocationsTableFilterComposer,
      $$LocationsTableOrderingComposer,
      $$LocationsTableAnnotationComposer,
      $$LocationsTableCreateCompanionBuilder,
      $$LocationsTableUpdateCompanionBuilder,
      (Location, $$LocationsTableReferences),
      Location,
      PrefetchHooks Function({bool postId})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String postId,
      required String fileUrl,
      required String fileType,
      required String fileName,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> postId,
      Value<String> fileUrl,
      Value<String> fileType,
      Value<String> fileName,
      Value<int> rowid,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PostsTable _postIdTable(_$AppDatabase db) => db.posts.createAlias(
    $_aliasNameGenerator(db.attachments.postId, db.posts.id),
  );

  $$PostsTableProcessedTableManager get postId {
    final $_column = $_itemColumn<String>('post_id')!;

    final manager = $$PostsTableTableManager(
      $_db,
      $_db.posts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_postIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileUrl => $composableBuilder(
    column: $table.fileUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  $$PostsTableFilterComposer get postId {
    final $$PostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableFilterComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileUrl => $composableBuilder(
    column: $table.fileUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  $$PostsTableOrderingComposer get postId {
    final $$PostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableOrderingComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileUrl =>
      $composableBuilder(column: $table.fileUrl, builder: (column) => column);

  GeneratedColumn<String> get fileType =>
      $composableBuilder(column: $table.fileType, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  $$PostsTableAnnotationComposer get postId {
    final $$PostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.posts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostsTableAnnotationComposer(
            $db: $db,
            $table: $db.posts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({bool postId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> postId = const Value.absent(),
                Value<String> fileUrl = const Value.absent(),
                Value<String> fileType = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                postId: postId,
                fileUrl: fileUrl,
                fileType: fileType,
                fileName: fileName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String postId,
                required String fileUrl,
                required String fileType,
                required String fileName,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                postId: postId,
                fileUrl: fileUrl,
                fileType: fileType,
                fileName: fileName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({postId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (postId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.postId,
                                referencedTable: $$AttachmentsTableReferences
                                    ._postIdTable(db),
                                referencedColumn: $$AttachmentsTableReferences
                                    ._postIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({bool postId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$DisasterEventsTableTableManager get disasterEvents =>
      $$DisasterEventsTableTableManager(_db, _db.disasterEvents);
  $$PostsTableTableManager get posts =>
      $$PostsTableTableManager(_db, _db.posts);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db, _db.locations);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
}
