// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SubjectsTable extends Subjects
    with TableInfo<$SubjectsTable, SubjectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 24,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    archivedAt,
    deletedAt,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubjectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubjectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubjectRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $SubjectsTable createAlias(String alias) {
    return $SubjectsTable(attachedDatabase, alias);
  }
}

class SubjectRow extends DataClass implements Insertable<SubjectRow> {
  /// Hand-assigned rather than autoIncrement: the seed writes 1..4 at fixed
  /// ids so it is idempotent across launches and migrations, and a chapter
  /// never ends up pointing at a renumbered subject. New subjects take
  /// `max(id) + 1`, computed in the repository.
  final int id;

  /// `SubjectCode.name` -- biology / physics / chemistry / english -- or
  /// `custom` for a subject the student added.
  final String code;

  /// The student's own name for a subject they created. Null for the seeded
  /// four, whose names are translated rather than stored.
  final String? name;

  /// Set when the student **archives** a subject: puts it away deliberately,
  /// because they are done with it. Nothing under it is touched.
  final DateTime? archivedAt;

  /// Set when the student **deletes** a subject. Also touches nothing under it
  /// -- the row simply stops being visible anywhere and moves to the recycle
  /// bin, where it can be restored or destroyed for real.
  ///
  /// The two columns are separate because archiving and deleting are different
  /// intentions, not two words for hiding: archive is "I am done with this",
  /// trash is "I did not mean to have this". Collapsing them into one flag
  /// would force one list to answer both questions.
  ///
  /// The actual cascade -- the one that takes every chapter, lesson and exam
  /// underneath -- happens only when the bin is emptied.
  final DateTime? deletedAt;
  final int sortOrder;
  const SubjectRow({
    required this.id,
    required this.code,
    this.name,
    this.archivedAt,
    this.deletedAt,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SubjectsCompanion toCompanion(bool nullToAbsent) {
    return SubjectsCompanion(
      id: Value(id),
      code: Value(code),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      sortOrder: Value(sortOrder),
    );
  }

  factory SubjectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubjectRow(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String?>(json['name']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String?>(name),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SubjectRow copyWith({
    int? id,
    String? code,
    Value<String?> name = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? sortOrder,
  }) => SubjectRow(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name.present ? name.value : this.name,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  SubjectRow copyWithCompanion(SubjectsCompanion data) {
    return SubjectRow(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubjectRow(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, code, name, archivedAt, deletedAt, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectRow &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.sortOrder == this.sortOrder);
}

class SubjectsCompanion extends UpdateCompanion<SubjectRow> {
  final Value<int> id;
  final Value<String> code;
  final Value<String?> name;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> sortOrder;
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  SubjectsCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    this.name = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required int sortOrder,
  }) : code = Value(code),
       sortOrder = Value(sortOrder);
  static Insertable<SubjectRow> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  SubjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? code,
    Value<String?>? name,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? sortOrder,
  }) {
    return SubjectsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters
    with TableInfo<$ChaptersTable, ChapterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES subjects (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _masteredAtMeta = const VerificationMeta(
    'masteredAt',
  );
  @override
  late final GeneratedColumn<DateTime> masteredAt = GeneratedColumn<DateTime>(
    'mastered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    name,
    masteredAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mastered_at')) {
      context.handle(
        _masteredAtMeta,
        masteredAt.isAcceptableOrUnknown(data['mastered_at']!, _masteredAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChapterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      masteredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}mastered_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class ChapterRow extends DataClass implements Insertable<ChapterRow> {
  final int id;
  final int subjectId;
  final String name;

  /// Set when "أتقنت الباب" succeeds; null until then.
  final DateTime? masteredAt;
  final DateTime createdAt;
  const ChapterRow({
    required this.id,
    required this.subjectId,
    required this.name,
    this.masteredAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_id'] = Variable<int>(subjectId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || masteredAt != null) {
      map['mastered_at'] = Variable<DateTime>(masteredAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      name: Value(name),
      masteredAt: masteredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(masteredAt),
      createdAt: Value(createdAt),
    );
  }

  factory ChapterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterRow(
      id: serializer.fromJson<int>(json['id']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      name: serializer.fromJson<String>(json['name']),
      masteredAt: serializer.fromJson<DateTime?>(json['masteredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectId': serializer.toJson<int>(subjectId),
      'name': serializer.toJson<String>(name),
      'masteredAt': serializer.toJson<DateTime?>(masteredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChapterRow copyWith({
    int? id,
    int? subjectId,
    String? name,
    Value<DateTime?> masteredAt = const Value.absent(),
    DateTime? createdAt,
  }) => ChapterRow(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    name: name ?? this.name,
    masteredAt: masteredAt.present ? masteredAt.value : this.masteredAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ChapterRow copyWithCompanion(ChaptersCompanion data) {
    return ChapterRow(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      name: data.name.present ? data.name.value : this.name,
      masteredAt: data.masteredAt.present
          ? data.masteredAt.value
          : this.masteredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterRow(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('name: $name, ')
          ..write('masteredAt: $masteredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, subjectId, name, masteredAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterRow &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.name == this.name &&
          other.masteredAt == this.masteredAt &&
          other.createdAt == this.createdAt);
}

class ChaptersCompanion extends UpdateCompanion<ChapterRow> {
  final Value<int> id;
  final Value<int> subjectId;
  final Value<String> name;
  final Value<DateTime?> masteredAt;
  final Value<DateTime> createdAt;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.name = const Value.absent(),
    this.masteredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ChaptersCompanion.insert({
    this.id = const Value.absent(),
    required int subjectId,
    required String name,
    this.masteredAt = const Value.absent(),
    required DateTime createdAt,
  }) : subjectId = Value(subjectId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ChapterRow> custom({
    Expression<int>? id,
    Expression<int>? subjectId,
    Expression<String>? name,
    Expression<DateTime>? masteredAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (name != null) 'name': name,
      if (masteredAt != null) 'mastered_at': masteredAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ChaptersCompanion copyWith({
    Value<int>? id,
    Value<int>? subjectId,
    Value<String>? name,
    Value<DateTime?>? masteredAt,
    Value<DateTime>? createdAt,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      masteredAt: masteredAt ?? this.masteredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (masteredAt.present) {
      map['mastered_at'] = Variable<DateTime>(masteredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('name: $name, ')
          ..write('masteredAt: $masteredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LessonsTable extends Lessons with TableInfo<$LessonsTable, LessonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta(
    'lastReviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReviewedAt =
      GeneratedColumn<DateTime>(
        'last_reviewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastNotifiedAtMeta = const VerificationMeta(
    'lastNotifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastNotifiedAt =
      GeneratedColumn<DateTime>(
        'last_notified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
  static const VerificationMeta _watchedLessonMeta = const VerificationMeta(
    'watchedLesson',
  );
  @override
  late final GeneratedColumn<bool> watchedLesson = GeneratedColumn<bool>(
    'watched_lesson',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("watched_lesson" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readNotesMeta = const VerificationMeta(
    'readNotes',
  );
  @override
  late final GeneratedColumn<bool> readNotes = GeneratedColumn<bool>(
    'read_notes',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read_notes" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _didHomeworkMeta = const VerificationMeta(
    'didHomework',
  );
  @override
  late final GeneratedColumn<bool> didHomework = GeneratedColumn<bool>(
    'did_homework',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("did_homework" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _didExamMeta = const VerificationMeta(
    'didExam',
  );
  @override
  late final GeneratedColumn<bool> didExam = GeneratedColumn<bool>(
    'did_exam',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("did_exam" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reviewedNotesMeta = const VerificationMeta(
    'reviewedNotes',
  );
  @override
  late final GeneratedColumn<bool> reviewedNotes = GeneratedColumn<bool>(
    'reviewed_notes',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reviewed_notes" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chapterId,
    name,
    lastReviewedAt,
    lastNotifiedAt,
    createdAt,
    watchedLesson,
    readNotes,
    didHomework,
    didExam,
    reviewedNotes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lessons';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(
          data['last_reviewed_at']!,
          _lastReviewedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_notified_at')) {
      context.handle(
        _lastNotifiedAtMeta,
        lastNotifiedAt.isAcceptableOrUnknown(
          data['last_notified_at']!,
          _lastNotifiedAtMeta,
        ),
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
    if (data.containsKey('watched_lesson')) {
      context.handle(
        _watchedLessonMeta,
        watchedLesson.isAcceptableOrUnknown(
          data['watched_lesson']!,
          _watchedLessonMeta,
        ),
      );
    }
    if (data.containsKey('read_notes')) {
      context.handle(
        _readNotesMeta,
        readNotes.isAcceptableOrUnknown(data['read_notes']!, _readNotesMeta),
      );
    }
    if (data.containsKey('did_homework')) {
      context.handle(
        _didHomeworkMeta,
        didHomework.isAcceptableOrUnknown(
          data['did_homework']!,
          _didHomeworkMeta,
        ),
      );
    }
    if (data.containsKey('did_exam')) {
      context.handle(
        _didExamMeta,
        didExam.isAcceptableOrUnknown(data['did_exam']!, _didExamMeta),
      );
    }
    if (data.containsKey('reviewed_notes')) {
      context.handle(
        _reviewedNotesMeta,
        reviewedNotes.isAcceptableOrUnknown(
          data['reviewed_notes']!,
          _reviewedNotesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LessonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reviewed_at'],
      ),
      lastNotifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_notified_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      watchedLesson: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}watched_lesson'],
      )!,
      readNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read_notes'],
      )!,
      didHomework: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}did_homework'],
      )!,
      didExam: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}did_exam'],
      )!,
      reviewedNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reviewed_notes'],
      )!,
    );
  }

  @override
  $LessonsTable createAlias(String alias) {
    return $LessonsTable(attachedDatabase, alias);
  }
}

class LessonRow extends DataClass implements Insertable<LessonRow> {
  final int id;
  final int chapterId;
  final String name;

  /// Last time understanding was *proven*. Drives the 30-day decay cycle.
  /// Null means never examined -- which is not the same as overdue.
  final DateTime? lastReviewedAt;

  /// Notification bookkeeping only, so the same overdue lesson does not post a
  /// reminder every single day. Not review state.
  final DateTime? lastNotifiedAt;
  final DateTime createdAt;
  final bool watchedLesson;
  final bool readNotes;
  final bool didHomework;
  final bool didExam;
  final bool reviewedNotes;
  const LessonRow({
    required this.id,
    required this.chapterId,
    required this.name,
    this.lastReviewedAt,
    this.lastNotifiedAt,
    required this.createdAt,
    required this.watchedLesson,
    required this.readNotes,
    required this.didHomework,
    required this.didExam,
    required this.reviewedNotes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chapter_id'] = Variable<int>(chapterId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt);
    }
    if (!nullToAbsent || lastNotifiedAt != null) {
      map['last_notified_at'] = Variable<DateTime>(lastNotifiedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['watched_lesson'] = Variable<bool>(watchedLesson);
    map['read_notes'] = Variable<bool>(readNotes);
    map['did_homework'] = Variable<bool>(didHomework);
    map['did_exam'] = Variable<bool>(didExam);
    map['reviewed_notes'] = Variable<bool>(reviewedNotes);
    return map;
  }

  LessonsCompanion toCompanion(bool nullToAbsent) {
    return LessonsCompanion(
      id: Value(id),
      chapterId: Value(chapterId),
      name: Value(name),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
      lastNotifiedAt: lastNotifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastNotifiedAt),
      createdAt: Value(createdAt),
      watchedLesson: Value(watchedLesson),
      readNotes: Value(readNotes),
      didHomework: Value(didHomework),
      didExam: Value(didExam),
      reviewedNotes: Value(reviewedNotes),
    );
  }

  factory LessonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonRow(
      id: serializer.fromJson<int>(json['id']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      name: serializer.fromJson<String>(json['name']),
      lastReviewedAt: serializer.fromJson<DateTime?>(json['lastReviewedAt']),
      lastNotifiedAt: serializer.fromJson<DateTime?>(json['lastNotifiedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      watchedLesson: serializer.fromJson<bool>(json['watchedLesson']),
      readNotes: serializer.fromJson<bool>(json['readNotes']),
      didHomework: serializer.fromJson<bool>(json['didHomework']),
      didExam: serializer.fromJson<bool>(json['didExam']),
      reviewedNotes: serializer.fromJson<bool>(json['reviewedNotes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chapterId': serializer.toJson<int>(chapterId),
      'name': serializer.toJson<String>(name),
      'lastReviewedAt': serializer.toJson<DateTime?>(lastReviewedAt),
      'lastNotifiedAt': serializer.toJson<DateTime?>(lastNotifiedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'watchedLesson': serializer.toJson<bool>(watchedLesson),
      'readNotes': serializer.toJson<bool>(readNotes),
      'didHomework': serializer.toJson<bool>(didHomework),
      'didExam': serializer.toJson<bool>(didExam),
      'reviewedNotes': serializer.toJson<bool>(reviewedNotes),
    };
  }

  LessonRow copyWith({
    int? id,
    int? chapterId,
    String? name,
    Value<DateTime?> lastReviewedAt = const Value.absent(),
    Value<DateTime?> lastNotifiedAt = const Value.absent(),
    DateTime? createdAt,
    bool? watchedLesson,
    bool? readNotes,
    bool? didHomework,
    bool? didExam,
    bool? reviewedNotes,
  }) => LessonRow(
    id: id ?? this.id,
    chapterId: chapterId ?? this.chapterId,
    name: name ?? this.name,
    lastReviewedAt: lastReviewedAt.present
        ? lastReviewedAt.value
        : this.lastReviewedAt,
    lastNotifiedAt: lastNotifiedAt.present
        ? lastNotifiedAt.value
        : this.lastNotifiedAt,
    createdAt: createdAt ?? this.createdAt,
    watchedLesson: watchedLesson ?? this.watchedLesson,
    readNotes: readNotes ?? this.readNotes,
    didHomework: didHomework ?? this.didHomework,
    didExam: didExam ?? this.didExam,
    reviewedNotes: reviewedNotes ?? this.reviewedNotes,
  );
  LessonRow copyWithCompanion(LessonsCompanion data) {
    return LessonRow(
      id: data.id.present ? data.id.value : this.id,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      name: data.name.present ? data.name.value : this.name,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
      lastNotifiedAt: data.lastNotifiedAt.present
          ? data.lastNotifiedAt.value
          : this.lastNotifiedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      watchedLesson: data.watchedLesson.present
          ? data.watchedLesson.value
          : this.watchedLesson,
      readNotes: data.readNotes.present ? data.readNotes.value : this.readNotes,
      didHomework: data.didHomework.present
          ? data.didHomework.value
          : this.didHomework,
      didExam: data.didExam.present ? data.didExam.value : this.didExam,
      reviewedNotes: data.reviewedNotes.present
          ? data.reviewedNotes.value
          : this.reviewedNotes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonRow(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('name: $name, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('lastNotifiedAt: $lastNotifiedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('watchedLesson: $watchedLesson, ')
          ..write('readNotes: $readNotes, ')
          ..write('didHomework: $didHomework, ')
          ..write('didExam: $didExam, ')
          ..write('reviewedNotes: $reviewedNotes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chapterId,
    name,
    lastReviewedAt,
    lastNotifiedAt,
    createdAt,
    watchedLesson,
    readNotes,
    didHomework,
    didExam,
    reviewedNotes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonRow &&
          other.id == this.id &&
          other.chapterId == this.chapterId &&
          other.name == this.name &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.lastNotifiedAt == this.lastNotifiedAt &&
          other.createdAt == this.createdAt &&
          other.watchedLesson == this.watchedLesson &&
          other.readNotes == this.readNotes &&
          other.didHomework == this.didHomework &&
          other.didExam == this.didExam &&
          other.reviewedNotes == this.reviewedNotes);
}

class LessonsCompanion extends UpdateCompanion<LessonRow> {
  final Value<int> id;
  final Value<int> chapterId;
  final Value<String> name;
  final Value<DateTime?> lastReviewedAt;
  final Value<DateTime?> lastNotifiedAt;
  final Value<DateTime> createdAt;
  final Value<bool> watchedLesson;
  final Value<bool> readNotes;
  final Value<bool> didHomework;
  final Value<bool> didExam;
  final Value<bool> reviewedNotes;
  const LessonsCompanion({
    this.id = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.name = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.lastNotifiedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.watchedLesson = const Value.absent(),
    this.readNotes = const Value.absent(),
    this.didHomework = const Value.absent(),
    this.didExam = const Value.absent(),
    this.reviewedNotes = const Value.absent(),
  });
  LessonsCompanion.insert({
    this.id = const Value.absent(),
    required int chapterId,
    required String name,
    this.lastReviewedAt = const Value.absent(),
    this.lastNotifiedAt = const Value.absent(),
    required DateTime createdAt,
    this.watchedLesson = const Value.absent(),
    this.readNotes = const Value.absent(),
    this.didHomework = const Value.absent(),
    this.didExam = const Value.absent(),
    this.reviewedNotes = const Value.absent(),
  }) : chapterId = Value(chapterId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<LessonRow> custom({
    Expression<int>? id,
    Expression<int>? chapterId,
    Expression<String>? name,
    Expression<DateTime>? lastReviewedAt,
    Expression<DateTime>? lastNotifiedAt,
    Expression<DateTime>? createdAt,
    Expression<bool>? watchedLesson,
    Expression<bool>? readNotes,
    Expression<bool>? didHomework,
    Expression<bool>? didExam,
    Expression<bool>? reviewedNotes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chapterId != null) 'chapter_id': chapterId,
      if (name != null) 'name': name,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (lastNotifiedAt != null) 'last_notified_at': lastNotifiedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (watchedLesson != null) 'watched_lesson': watchedLesson,
      if (readNotes != null) 'read_notes': readNotes,
      if (didHomework != null) 'did_homework': didHomework,
      if (didExam != null) 'did_exam': didExam,
      if (reviewedNotes != null) 'reviewed_notes': reviewedNotes,
    });
  }

  LessonsCompanion copyWith({
    Value<int>? id,
    Value<int>? chapterId,
    Value<String>? name,
    Value<DateTime?>? lastReviewedAt,
    Value<DateTime?>? lastNotifiedAt,
    Value<DateTime>? createdAt,
    Value<bool>? watchedLesson,
    Value<bool>? readNotes,
    Value<bool>? didHomework,
    Value<bool>? didExam,
    Value<bool>? reviewedNotes,
  }) {
    return LessonsCompanion(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      name: name ?? this.name,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
      createdAt: createdAt ?? this.createdAt,
      watchedLesson: watchedLesson ?? this.watchedLesson,
      readNotes: readNotes ?? this.readNotes,
      didHomework: didHomework ?? this.didHomework,
      didExam: didExam ?? this.didExam,
      reviewedNotes: reviewedNotes ?? this.reviewedNotes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<DateTime>(lastReviewedAt.value);
    }
    if (lastNotifiedAt.present) {
      map['last_notified_at'] = Variable<DateTime>(lastNotifiedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (watchedLesson.present) {
      map['watched_lesson'] = Variable<bool>(watchedLesson.value);
    }
    if (readNotes.present) {
      map['read_notes'] = Variable<bool>(readNotes.value);
    }
    if (didHomework.present) {
      map['did_homework'] = Variable<bool>(didHomework.value);
    }
    if (didExam.present) {
      map['did_exam'] = Variable<bool>(didExam.value);
    }
    if (reviewedNotes.present) {
      map['reviewed_notes'] = Variable<bool>(reviewedNotes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonsCompanion(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('name: $name, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('lastNotifiedAt: $lastNotifiedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('watchedLesson: $watchedLesson, ')
          ..write('readNotes: $readNotes, ')
          ..write('didHomework: $didHomework, ')
          ..write('didExam: $didExam, ')
          ..write('reviewedNotes: $reviewedNotes')
          ..write(')'))
        .toString();
  }
}

class $HomeworkEntriesTable extends HomeworkEntries
    with TableInfo<$HomeworkEntriesTable, HomeworkEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HomeworkEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lessons (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxScoreMeta = const VerificationMeta(
    'maxScore',
  );
  @override
  late final GeneratedColumn<int> maxScore = GeneratedColumn<int>(
    'max_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lessonId,
    score,
    maxScore,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'homework_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<HomeworkEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('max_score')) {
      context.handle(
        _maxScoreMeta,
        maxScore.isAcceptableOrUnknown(data['max_score']!, _maxScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_maxScoreMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HomeworkEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HomeworkEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      maxScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_score'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HomeworkEntriesTable createAlias(String alias) {
    return $HomeworkEntriesTable(attachedDatabase, alias);
  }
}

class HomeworkEntryRow extends DataClass
    implements Insertable<HomeworkEntryRow> {
  final int id;
  final int lessonId;
  final int score;
  final int maxScore;
  final DateTime createdAt;
  const HomeworkEntryRow({
    required this.id,
    required this.lessonId,
    required this.score,
    required this.maxScore,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lesson_id'] = Variable<int>(lessonId);
    map['score'] = Variable<int>(score);
    map['max_score'] = Variable<int>(maxScore);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HomeworkEntriesCompanion toCompanion(bool nullToAbsent) {
    return HomeworkEntriesCompanion(
      id: Value(id),
      lessonId: Value(lessonId),
      score: Value(score),
      maxScore: Value(maxScore),
      createdAt: Value(createdAt),
    );
  }

  factory HomeworkEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HomeworkEntryRow(
      id: serializer.fromJson<int>(json['id']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      score: serializer.fromJson<int>(json['score']),
      maxScore: serializer.fromJson<int>(json['maxScore']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lessonId': serializer.toJson<int>(lessonId),
      'score': serializer.toJson<int>(score),
      'maxScore': serializer.toJson<int>(maxScore),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HomeworkEntryRow copyWith({
    int? id,
    int? lessonId,
    int? score,
    int? maxScore,
    DateTime? createdAt,
  }) => HomeworkEntryRow(
    id: id ?? this.id,
    lessonId: lessonId ?? this.lessonId,
    score: score ?? this.score,
    maxScore: maxScore ?? this.maxScore,
    createdAt: createdAt ?? this.createdAt,
  );
  HomeworkEntryRow copyWithCompanion(HomeworkEntriesCompanion data) {
    return HomeworkEntryRow(
      id: data.id.present ? data.id.value : this.id,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      score: data.score.present ? data.score.value : this.score,
      maxScore: data.maxScore.present ? data.maxScore.value : this.maxScore,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HomeworkEntryRow(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('score: $score, ')
          ..write('maxScore: $maxScore, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lessonId, score, maxScore, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HomeworkEntryRow &&
          other.id == this.id &&
          other.lessonId == this.lessonId &&
          other.score == this.score &&
          other.maxScore == this.maxScore &&
          other.createdAt == this.createdAt);
}

class HomeworkEntriesCompanion extends UpdateCompanion<HomeworkEntryRow> {
  final Value<int> id;
  final Value<int> lessonId;
  final Value<int> score;
  final Value<int> maxScore;
  final Value<DateTime> createdAt;
  const HomeworkEntriesCompanion({
    this.id = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.score = const Value.absent(),
    this.maxScore = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  HomeworkEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int lessonId,
    required int score,
    required int maxScore,
    required DateTime createdAt,
  }) : lessonId = Value(lessonId),
       score = Value(score),
       maxScore = Value(maxScore),
       createdAt = Value(createdAt);
  static Insertable<HomeworkEntryRow> custom({
    Expression<int>? id,
    Expression<int>? lessonId,
    Expression<int>? score,
    Expression<int>? maxScore,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lessonId != null) 'lesson_id': lessonId,
      if (score != null) 'score': score,
      if (maxScore != null) 'max_score': maxScore,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  HomeworkEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? lessonId,
    Value<int>? score,
    Value<int>? maxScore,
    Value<DateTime>? createdAt,
  }) {
    return HomeworkEntriesCompanion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      score: score ?? this.score,
      maxScore: maxScore ?? this.maxScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (maxScore.present) {
      map['max_score'] = Variable<int>(maxScore.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HomeworkEntriesCompanion(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('score: $score, ')
          ..write('maxScore: $maxScore, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ExamEntriesTable extends ExamEntries
    with TableInfo<$ExamEntriesTable, ExamEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExamEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lessons (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _isReviewExamMeta = const VerificationMeta(
    'isReviewExam',
  );
  @override
  late final GeneratedColumn<bool> isReviewExam = GeneratedColumn<bool>(
    'is_review_exam',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_review_exam" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _totalPossiblePointsMeta =
      const VerificationMeta('totalPossiblePoints');
  @override
  late final GeneratedColumn<int> totalPossiblePoints = GeneratedColumn<int>(
    'total_possible_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctPointsMeta = const VerificationMeta(
    'correctPoints',
  );
  @override
  late final GeneratedColumn<int> correctPoints = GeneratedColumn<int>(
    'correct_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _percentageMeta = const VerificationMeta(
    'percentage',
  );
  @override
  late final GeneratedColumn<double> percentage = GeneratedColumn<double>(
    'percentage',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lessonId,
    isReviewExam,
    totalPossiblePoints,
    correctPoints,
    percentage,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exam_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExamEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('is_review_exam')) {
      context.handle(
        _isReviewExamMeta,
        isReviewExam.isAcceptableOrUnknown(
          data['is_review_exam']!,
          _isReviewExamMeta,
        ),
      );
    }
    if (data.containsKey('total_possible_points')) {
      context.handle(
        _totalPossiblePointsMeta,
        totalPossiblePoints.isAcceptableOrUnknown(
          data['total_possible_points']!,
          _totalPossiblePointsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPossiblePointsMeta);
    }
    if (data.containsKey('correct_points')) {
      context.handle(
        _correctPointsMeta,
        correctPoints.isAcceptableOrUnknown(
          data['correct_points']!,
          _correctPointsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctPointsMeta);
    }
    if (data.containsKey('percentage')) {
      context.handle(
        _percentageMeta,
        percentage.isAcceptableOrUnknown(data['percentage']!, _percentageMeta),
      );
    } else if (isInserting) {
      context.missing(_percentageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExamEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExamEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_id'],
      )!,
      isReviewExam: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_review_exam'],
      )!,
      totalPossiblePoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_possible_points'],
      )!,
      correctPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_points'],
      )!,
      percentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percentage'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExamEntriesTable createAlias(String alias) {
    return $ExamEntriesTable(attachedDatabase, alias);
  }
}

class ExamEntryRow extends DataClass implements Insertable<ExamEntryRow> {
  final int id;
  final int lessonId;
  final bool isReviewExam;
  final int totalPossiblePoints;
  final int correctPoints;

  /// Denormalised from the question groups at write time -- read on every
  /// dashboard and chart query, and must stay historically stable.
  final double percentage;
  final DateTime createdAt;
  const ExamEntryRow({
    required this.id,
    required this.lessonId,
    required this.isReviewExam,
    required this.totalPossiblePoints,
    required this.correctPoints,
    required this.percentage,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lesson_id'] = Variable<int>(lessonId);
    map['is_review_exam'] = Variable<bool>(isReviewExam);
    map['total_possible_points'] = Variable<int>(totalPossiblePoints);
    map['correct_points'] = Variable<int>(correctPoints);
    map['percentage'] = Variable<double>(percentage);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExamEntriesCompanion toCompanion(bool nullToAbsent) {
    return ExamEntriesCompanion(
      id: Value(id),
      lessonId: Value(lessonId),
      isReviewExam: Value(isReviewExam),
      totalPossiblePoints: Value(totalPossiblePoints),
      correctPoints: Value(correctPoints),
      percentage: Value(percentage),
      createdAt: Value(createdAt),
    );
  }

  factory ExamEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExamEntryRow(
      id: serializer.fromJson<int>(json['id']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      isReviewExam: serializer.fromJson<bool>(json['isReviewExam']),
      totalPossiblePoints: serializer.fromJson<int>(
        json['totalPossiblePoints'],
      ),
      correctPoints: serializer.fromJson<int>(json['correctPoints']),
      percentage: serializer.fromJson<double>(json['percentage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lessonId': serializer.toJson<int>(lessonId),
      'isReviewExam': serializer.toJson<bool>(isReviewExam),
      'totalPossiblePoints': serializer.toJson<int>(totalPossiblePoints),
      'correctPoints': serializer.toJson<int>(correctPoints),
      'percentage': serializer.toJson<double>(percentage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExamEntryRow copyWith({
    int? id,
    int? lessonId,
    bool? isReviewExam,
    int? totalPossiblePoints,
    int? correctPoints,
    double? percentage,
    DateTime? createdAt,
  }) => ExamEntryRow(
    id: id ?? this.id,
    lessonId: lessonId ?? this.lessonId,
    isReviewExam: isReviewExam ?? this.isReviewExam,
    totalPossiblePoints: totalPossiblePoints ?? this.totalPossiblePoints,
    correctPoints: correctPoints ?? this.correctPoints,
    percentage: percentage ?? this.percentage,
    createdAt: createdAt ?? this.createdAt,
  );
  ExamEntryRow copyWithCompanion(ExamEntriesCompanion data) {
    return ExamEntryRow(
      id: data.id.present ? data.id.value : this.id,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      isReviewExam: data.isReviewExam.present
          ? data.isReviewExam.value
          : this.isReviewExam,
      totalPossiblePoints: data.totalPossiblePoints.present
          ? data.totalPossiblePoints.value
          : this.totalPossiblePoints,
      correctPoints: data.correctPoints.present
          ? data.correctPoints.value
          : this.correctPoints,
      percentage: data.percentage.present
          ? data.percentage.value
          : this.percentage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExamEntryRow(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('isReviewExam: $isReviewExam, ')
          ..write('totalPossiblePoints: $totalPossiblePoints, ')
          ..write('correctPoints: $correctPoints, ')
          ..write('percentage: $percentage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lessonId,
    isReviewExam,
    totalPossiblePoints,
    correctPoints,
    percentage,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExamEntryRow &&
          other.id == this.id &&
          other.lessonId == this.lessonId &&
          other.isReviewExam == this.isReviewExam &&
          other.totalPossiblePoints == this.totalPossiblePoints &&
          other.correctPoints == this.correctPoints &&
          other.percentage == this.percentage &&
          other.createdAt == this.createdAt);
}

class ExamEntriesCompanion extends UpdateCompanion<ExamEntryRow> {
  final Value<int> id;
  final Value<int> lessonId;
  final Value<bool> isReviewExam;
  final Value<int> totalPossiblePoints;
  final Value<int> correctPoints;
  final Value<double> percentage;
  final Value<DateTime> createdAt;
  const ExamEntriesCompanion({
    this.id = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.isReviewExam = const Value.absent(),
    this.totalPossiblePoints = const Value.absent(),
    this.correctPoints = const Value.absent(),
    this.percentage = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ExamEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int lessonId,
    this.isReviewExam = const Value.absent(),
    required int totalPossiblePoints,
    required int correctPoints,
    required double percentage,
    required DateTime createdAt,
  }) : lessonId = Value(lessonId),
       totalPossiblePoints = Value(totalPossiblePoints),
       correctPoints = Value(correctPoints),
       percentage = Value(percentage),
       createdAt = Value(createdAt);
  static Insertable<ExamEntryRow> custom({
    Expression<int>? id,
    Expression<int>? lessonId,
    Expression<bool>? isReviewExam,
    Expression<int>? totalPossiblePoints,
    Expression<int>? correctPoints,
    Expression<double>? percentage,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lessonId != null) 'lesson_id': lessonId,
      if (isReviewExam != null) 'is_review_exam': isReviewExam,
      if (totalPossiblePoints != null)
        'total_possible_points': totalPossiblePoints,
      if (correctPoints != null) 'correct_points': correctPoints,
      if (percentage != null) 'percentage': percentage,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ExamEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? lessonId,
    Value<bool>? isReviewExam,
    Value<int>? totalPossiblePoints,
    Value<int>? correctPoints,
    Value<double>? percentage,
    Value<DateTime>? createdAt,
  }) {
    return ExamEntriesCompanion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      isReviewExam: isReviewExam ?? this.isReviewExam,
      totalPossiblePoints: totalPossiblePoints ?? this.totalPossiblePoints,
      correctPoints: correctPoints ?? this.correctPoints,
      percentage: percentage ?? this.percentage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (isReviewExam.present) {
      map['is_review_exam'] = Variable<bool>(isReviewExam.value);
    }
    if (totalPossiblePoints.present) {
      map['total_possible_points'] = Variable<int>(totalPossiblePoints.value);
    }
    if (correctPoints.present) {
      map['correct_points'] = Variable<int>(correctPoints.value);
    }
    if (percentage.present) {
      map['percentage'] = Variable<double>(percentage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExamEntriesCompanion(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('isReviewExam: $isReviewExam, ')
          ..write('totalPossiblePoints: $totalPossiblePoints, ')
          ..write('correctPoints: $correctPoints, ')
          ..write('percentage: $percentage, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ExamQuestionGroupsTable extends ExamQuestionGroups
    with TableInfo<$ExamQuestionGroupsTable, ExamQuestionGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExamQuestionGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _examIdMeta = const VerificationMeta('examId');
  @override
  late final GeneratedColumn<int> examId = GeneratedColumn<int>(
    'exam_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exam_entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pointsPerQuestionMeta = const VerificationMeta(
    'pointsPerQuestion',
  );
  @override
  late final GeneratedColumn<int> pointsPerQuestion = GeneratedColumn<int>(
    'points_per_question',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionCountMeta = const VerificationMeta(
    'questionCount',
  );
  @override
  late final GeneratedColumn<int> questionCount = GeneratedColumn<int>(
    'question_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    examId,
    pointsPerQuestion,
    questionCount,
    correctCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exam_question_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExamQuestionGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exam_id')) {
      context.handle(
        _examIdMeta,
        examId.isAcceptableOrUnknown(data['exam_id']!, _examIdMeta),
      );
    } else if (isInserting) {
      context.missing(_examIdMeta);
    }
    if (data.containsKey('points_per_question')) {
      context.handle(
        _pointsPerQuestionMeta,
        pointsPerQuestion.isAcceptableOrUnknown(
          data['points_per_question']!,
          _pointsPerQuestionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pointsPerQuestionMeta);
    }
    if (data.containsKey('question_count')) {
      context.handle(
        _questionCountMeta,
        questionCount.isAcceptableOrUnknown(
          data['question_count']!,
          _questionCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionCountMeta);
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExamQuestionGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExamQuestionGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      examId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exam_id'],
      )!,
      pointsPerQuestion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points_per_question'],
      )!,
      questionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_count'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
    );
  }

  @override
  $ExamQuestionGroupsTable createAlias(String alias) {
    return $ExamQuestionGroupsTable(attachedDatabase, alias);
  }
}

class ExamQuestionGroupRow extends DataClass
    implements Insertable<ExamQuestionGroupRow> {
  final int id;
  final int examId;
  final int pointsPerQuestion;
  final int questionCount;
  final int correctCount;
  const ExamQuestionGroupRow({
    required this.id,
    required this.examId,
    required this.pointsPerQuestion,
    required this.questionCount,
    required this.correctCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exam_id'] = Variable<int>(examId);
    map['points_per_question'] = Variable<int>(pointsPerQuestion);
    map['question_count'] = Variable<int>(questionCount);
    map['correct_count'] = Variable<int>(correctCount);
    return map;
  }

  ExamQuestionGroupsCompanion toCompanion(bool nullToAbsent) {
    return ExamQuestionGroupsCompanion(
      id: Value(id),
      examId: Value(examId),
      pointsPerQuestion: Value(pointsPerQuestion),
      questionCount: Value(questionCount),
      correctCount: Value(correctCount),
    );
  }

  factory ExamQuestionGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExamQuestionGroupRow(
      id: serializer.fromJson<int>(json['id']),
      examId: serializer.fromJson<int>(json['examId']),
      pointsPerQuestion: serializer.fromJson<int>(json['pointsPerQuestion']),
      questionCount: serializer.fromJson<int>(json['questionCount']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'examId': serializer.toJson<int>(examId),
      'pointsPerQuestion': serializer.toJson<int>(pointsPerQuestion),
      'questionCount': serializer.toJson<int>(questionCount),
      'correctCount': serializer.toJson<int>(correctCount),
    };
  }

  ExamQuestionGroupRow copyWith({
    int? id,
    int? examId,
    int? pointsPerQuestion,
    int? questionCount,
    int? correctCount,
  }) => ExamQuestionGroupRow(
    id: id ?? this.id,
    examId: examId ?? this.examId,
    pointsPerQuestion: pointsPerQuestion ?? this.pointsPerQuestion,
    questionCount: questionCount ?? this.questionCount,
    correctCount: correctCount ?? this.correctCount,
  );
  ExamQuestionGroupRow copyWithCompanion(ExamQuestionGroupsCompanion data) {
    return ExamQuestionGroupRow(
      id: data.id.present ? data.id.value : this.id,
      examId: data.examId.present ? data.examId.value : this.examId,
      pointsPerQuestion: data.pointsPerQuestion.present
          ? data.pointsPerQuestion.value
          : this.pointsPerQuestion,
      questionCount: data.questionCount.present
          ? data.questionCount.value
          : this.questionCount,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExamQuestionGroupRow(')
          ..write('id: $id, ')
          ..write('examId: $examId, ')
          ..write('pointsPerQuestion: $pointsPerQuestion, ')
          ..write('questionCount: $questionCount, ')
          ..write('correctCount: $correctCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, examId, pointsPerQuestion, questionCount, correctCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExamQuestionGroupRow &&
          other.id == this.id &&
          other.examId == this.examId &&
          other.pointsPerQuestion == this.pointsPerQuestion &&
          other.questionCount == this.questionCount &&
          other.correctCount == this.correctCount);
}

class ExamQuestionGroupsCompanion
    extends UpdateCompanion<ExamQuestionGroupRow> {
  final Value<int> id;
  final Value<int> examId;
  final Value<int> pointsPerQuestion;
  final Value<int> questionCount;
  final Value<int> correctCount;
  const ExamQuestionGroupsCompanion({
    this.id = const Value.absent(),
    this.examId = const Value.absent(),
    this.pointsPerQuestion = const Value.absent(),
    this.questionCount = const Value.absent(),
    this.correctCount = const Value.absent(),
  });
  ExamQuestionGroupsCompanion.insert({
    this.id = const Value.absent(),
    required int examId,
    required int pointsPerQuestion,
    required int questionCount,
    required int correctCount,
  }) : examId = Value(examId),
       pointsPerQuestion = Value(pointsPerQuestion),
       questionCount = Value(questionCount),
       correctCount = Value(correctCount);
  static Insertable<ExamQuestionGroupRow> custom({
    Expression<int>? id,
    Expression<int>? examId,
    Expression<int>? pointsPerQuestion,
    Expression<int>? questionCount,
    Expression<int>? correctCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (examId != null) 'exam_id': examId,
      if (pointsPerQuestion != null) 'points_per_question': pointsPerQuestion,
      if (questionCount != null) 'question_count': questionCount,
      if (correctCount != null) 'correct_count': correctCount,
    });
  }

  ExamQuestionGroupsCompanion copyWith({
    Value<int>? id,
    Value<int>? examId,
    Value<int>? pointsPerQuestion,
    Value<int>? questionCount,
    Value<int>? correctCount,
  }) {
    return ExamQuestionGroupsCompanion(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      pointsPerQuestion: pointsPerQuestion ?? this.pointsPerQuestion,
      questionCount: questionCount ?? this.questionCount,
      correctCount: correctCount ?? this.correctCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (examId.present) {
      map['exam_id'] = Variable<int>(examId.value);
    }
    if (pointsPerQuestion.present) {
      map['points_per_question'] = Variable<int>(pointsPerQuestion.value);
    }
    if (questionCount.present) {
      map['question_count'] = Variable<int>(questionCount.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExamQuestionGroupsCompanion(')
          ..write('id: $id, ')
          ..write('examId: $examId, ')
          ..write('pointsPerQuestion: $pointsPerQuestion, ')
          ..write('questionCount: $questionCount, ')
          ..write('correctCount: $correctCount')
          ..write(')'))
        .toString();
  }
}

class $DailyTasksTable extends DailyTasks
    with TableInfo<$DailyTasksTable, DailyTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<DateTime> day = GeneratedColumn<DateTime>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    day,
    title,
    done,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyTaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}day'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DailyTasksTable createAlias(String alias) {
    return $DailyTasksTable(attachedDatabase, alias);
  }
}

class DailyTaskRow extends DataClass implements Insertable<DailyTaskRow> {
  final int id;

  /// Midnight local. Day precision, so a task written at 23:59 and one at 00:01
  /// belong to different days rather than sorting next to each other.
  final DateTime day;
  final String title;
  final bool done;

  /// Manual position within its day. Dense (0, 1, 2 ...) and rewritten wholesale
  /// on reorder -- a day holds a handful of rows, so fractional indices would be
  /// cleverness bought with nothing.
  final int sortOrder;
  final DateTime createdAt;
  const DailyTaskRow({
    required this.id,
    required this.day,
    required this.title,
    required this.done,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day'] = Variable<DateTime>(day);
    map['title'] = Variable<String>(title);
    map['done'] = Variable<bool>(done);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DailyTasksCompanion toCompanion(bool nullToAbsent) {
    return DailyTasksCompanion(
      id: Value(id),
      day: Value(day),
      title: Value(title),
      done: Value(done),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory DailyTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyTaskRow(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<DateTime>(json['day']),
      title: serializer.fromJson<String>(json['title']),
      done: serializer.fromJson<bool>(json['done']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<DateTime>(day),
      'title': serializer.toJson<String>(title),
      'done': serializer.toJson<bool>(done),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DailyTaskRow copyWith({
    int? id,
    DateTime? day,
    String? title,
    bool? done,
    int? sortOrder,
    DateTime? createdAt,
  }) => DailyTaskRow(
    id: id ?? this.id,
    day: day ?? this.day,
    title: title ?? this.title,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  DailyTaskRow copyWithCompanion(DailyTasksCompanion data) {
    return DailyTaskRow(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      title: data.title.present ? data.title.value : this.title,
      done: data.done.present ? data.done.value : this.done,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyTaskRow(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, day, title, done, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyTaskRow &&
          other.id == this.id &&
          other.day == this.day &&
          other.title == this.title &&
          other.done == this.done &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class DailyTasksCompanion extends UpdateCompanion<DailyTaskRow> {
  final Value<int> id;
  final Value<DateTime> day;
  final Value<String> title;
  final Value<bool> done;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const DailyTasksCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.title = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DailyTasksCompanion.insert({
    this.id = const Value.absent(),
    required DateTime day,
    required String title,
    this.done = const Value.absent(),
    required int sortOrder,
    required DateTime createdAt,
  }) : day = Value(day),
       title = Value(title),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt);
  static Insertable<DailyTaskRow> custom({
    Expression<int>? id,
    Expression<DateTime>? day,
    Expression<String>? title,
    Expression<bool>? done,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (title != null) 'title': title,
      if (done != null) 'done': done,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DailyTasksCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? day,
    Value<String>? title,
    Value<bool>? done,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return DailyTasksCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      title: title ?? this.title,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<DateTime>(day.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyTasksCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SubjectsTable subjects = $SubjectsTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $LessonsTable lessons = $LessonsTable(this);
  late final $HomeworkEntriesTable homeworkEntries = $HomeworkEntriesTable(
    this,
  );
  late final $ExamEntriesTable examEntries = $ExamEntriesTable(this);
  late final $ExamQuestionGroupsTable examQuestionGroups =
      $ExamQuestionGroupsTable(this);
  late final $DailyTasksTable dailyTasks = $DailyTasksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    subjects,
    chapters,
    lessons,
    homeworkEntries,
    examEntries,
    examQuestionGroups,
    dailyTasks,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'subjects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('lessons', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lessons',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('homework_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lessons',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('exam_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'exam_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('exam_question_groups', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SubjectsTableCreateCompanionBuilder =
    SubjectsCompanion Function({
      Value<int> id,
      required String code,
      Value<String?> name,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      required int sortOrder,
    });
typedef $$SubjectsTableUpdateCompanionBuilder =
    SubjectsCompanion Function({
      Value<int> id,
      Value<String> code,
      Value<String?> name,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<int> sortOrder,
    });

final class $$SubjectsTableReferences
    extends BaseReferences<_$AppDatabase, $SubjectsTable, SubjectRow> {
  $$SubjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChaptersTable, List<ChapterRow>>
  _chaptersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.chapters,
    aliasName: 'subjects__id__chapters__subject_id',
  );

  $$ChaptersTableProcessedTableManager get chaptersRefs {
    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.subjectId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_chaptersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SubjectsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> chaptersRefs(
    Expression<bool> Function($$ChaptersTableFilterComposer f) f,
  ) {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> chaptersRefs<T extends Object>(
    Expression<T> Function($$ChaptersTableAnnotationComposer a) f,
  ) {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.subjectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectsTable,
          SubjectRow,
          $$SubjectsTableFilterComposer,
          $$SubjectsTableOrderingComposer,
          $$SubjectsTableAnnotationComposer,
          $$SubjectsTableCreateCompanionBuilder,
          $$SubjectsTableUpdateCompanionBuilder,
          (SubjectRow, $$SubjectsTableReferences),
          SubjectRow,
          PrefetchHooks Function({bool chaptersRefs})
        > {
  $$SubjectsTableTableManager(_$AppDatabase db, $SubjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => SubjectsCompanion(
                id: id,
                code: code,
                name: name,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String code,
                Value<String?> name = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required int sortOrder,
              }) => SubjectsCompanion.insert(
                id: id,
                code: code,
                name: name,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chaptersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (chaptersRefs) db.chapters],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (chaptersRefs)
                    await $_getPrefetchedData<
                      SubjectRow,
                      $SubjectsTable,
                      ChapterRow
                    >(
                      currentTable: table,
                      referencedTable: $$SubjectsTableReferences
                          ._chaptersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SubjectsTableReferences(db, table, p0).chaptersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.subjectId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectsTable,
      SubjectRow,
      $$SubjectsTableFilterComposer,
      $$SubjectsTableOrderingComposer,
      $$SubjectsTableAnnotationComposer,
      $$SubjectsTableCreateCompanionBuilder,
      $$SubjectsTableUpdateCompanionBuilder,
      (SubjectRow, $$SubjectsTableReferences),
      SubjectRow,
      PrefetchHooks Function({bool chaptersRefs})
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      required int subjectId,
      required String name,
      Value<DateTime?> masteredAt,
      required DateTime createdAt,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      Value<int> subjectId,
      Value<String> name,
      Value<DateTime?> masteredAt,
      Value<DateTime> createdAt,
    });

final class $$ChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $ChaptersTable, ChapterRow> {
  $$ChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SubjectsTable _subjectIdTable(_$AppDatabase db) =>
      db.subjects.createAlias('chapters__subject_id__subjects__id');

  $$SubjectsTableProcessedTableManager get subjectId {
    final $_column = $_itemColumn<int>('subject_id')!;

    final manager = $$SubjectsTableTableManager(
      $_db,
      $_db.subjects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subjectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LessonsTable, List<LessonRow>> _lessonsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.lessons,
    aliasName: 'chapters__id__lessons__chapter_id',
  );

  $$LessonsTableProcessedTableManager get lessonsRefs {
    final manager = $$LessonsTableTableManager(
      $_db,
      $_db.lessons,
    ).filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lessonsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get masteredAt => $composableBuilder(
    column: $table.masteredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SubjectsTableFilterComposer get subjectId {
    final $$SubjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableFilterComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> lessonsRefs(
    Expression<bool> Function($$LessonsTableFilterComposer f) f,
  ) {
    final $$LessonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableFilterComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get masteredAt => $composableBuilder(
    column: $table.masteredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SubjectsTableOrderingComposer get subjectId {
    final $$SubjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableOrderingComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get masteredAt => $composableBuilder(
    column: $table.masteredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SubjectsTableAnnotationComposer get subjectId {
    final $$SubjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subjectId,
      referencedTable: $db.subjects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.subjects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> lessonsRefs<T extends Object>(
    Expression<T> Function($$LessonsTableAnnotationComposer a) f,
  ) {
    final $$LessonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableAnnotationComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          ChapterRow,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (ChapterRow, $$ChaptersTableReferences),
          ChapterRow,
          PrefetchHooks Function({bool subjectId, bool lessonsRefs})
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime?> masteredAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                subjectId: subjectId,
                name: name,
                masteredAt: masteredAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int subjectId,
                required String name,
                Value<DateTime?> masteredAt = const Value.absent(),
                required DateTime createdAt,
              }) => ChaptersCompanion.insert(
                id: id,
                subjectId: subjectId,
                name: name,
                masteredAt: masteredAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subjectId = false, lessonsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (lessonsRefs) db.lessons],
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
                    if (subjectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subjectId,
                                referencedTable: $$ChaptersTableReferences
                                    ._subjectIdTable(db),
                                referencedColumn: $$ChaptersTableReferences
                                    ._subjectIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lessonsRefs)
                    await $_getPrefetchedData<
                      ChapterRow,
                      $ChaptersTable,
                      LessonRow
                    >(
                      currentTable: table,
                      referencedTable: $$ChaptersTableReferences
                          ._lessonsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ChaptersTableReferences(db, table, p0).lessonsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.chapterId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      ChapterRow,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (ChapterRow, $$ChaptersTableReferences),
      ChapterRow,
      PrefetchHooks Function({bool subjectId, bool lessonsRefs})
    >;
typedef $$LessonsTableCreateCompanionBuilder =
    LessonsCompanion Function({
      Value<int> id,
      required int chapterId,
      required String name,
      Value<DateTime?> lastReviewedAt,
      Value<DateTime?> lastNotifiedAt,
      required DateTime createdAt,
      Value<bool> watchedLesson,
      Value<bool> readNotes,
      Value<bool> didHomework,
      Value<bool> didExam,
      Value<bool> reviewedNotes,
    });
typedef $$LessonsTableUpdateCompanionBuilder =
    LessonsCompanion Function({
      Value<int> id,
      Value<int> chapterId,
      Value<String> name,
      Value<DateTime?> lastReviewedAt,
      Value<DateTime?> lastNotifiedAt,
      Value<DateTime> createdAt,
      Value<bool> watchedLesson,
      Value<bool> readNotes,
      Value<bool> didHomework,
      Value<bool> didExam,
      Value<bool> reviewedNotes,
    });

final class $$LessonsTableReferences
    extends BaseReferences<_$AppDatabase, $LessonsTable, LessonRow> {
  $$LessonsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('lessons__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager get chapterId {
    final $_column = $_itemColumn<int>('chapter_id')!;

    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HomeworkEntriesTable, List<HomeworkEntryRow>>
  _homeworkEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.homeworkEntries,
    aliasName: 'lessons__id__homework_entries__lesson_id',
  );

  $$HomeworkEntriesTableProcessedTableManager get homeworkEntriesRefs {
    final manager = $$HomeworkEntriesTableTableManager(
      $_db,
      $_db.homeworkEntries,
    ).filter((f) => f.lessonId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _homeworkEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExamEntriesTable, List<ExamEntryRow>>
  _examEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.examEntries,
    aliasName: 'lessons__id__exam_entries__lesson_id',
  );

  $$ExamEntriesTableProcessedTableManager get examEntriesRefs {
    final manager = $$ExamEntriesTableTableManager(
      $_db,
      $_db.examEntries,
    ).filter((f) => f.lessonId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_examEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LessonsTableFilterComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastNotifiedAt => $composableBuilder(
    column: $table.lastNotifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get watchedLesson => $composableBuilder(
    column: $table.watchedLesson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get readNotes => $composableBuilder(
    column: $table.readNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get didHomework => $composableBuilder(
    column: $table.didHomework,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get didExam => $composableBuilder(
    column: $table.didExam,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reviewedNotes => $composableBuilder(
    column: $table.reviewedNotes,
    builder: (column) => ColumnFilters(column),
  );

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> homeworkEntriesRefs(
    Expression<bool> Function($$HomeworkEntriesTableFilterComposer f) f,
  ) {
    final $$HomeworkEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.homeworkEntries,
      getReferencedColumn: (t) => t.lessonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HomeworkEntriesTableFilterComposer(
            $db: $db,
            $table: $db.homeworkEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> examEntriesRefs(
    Expression<bool> Function($$ExamEntriesTableFilterComposer f) f,
  ) {
    final $$ExamEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.examEntries,
      getReferencedColumn: (t) => t.lessonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamEntriesTableFilterComposer(
            $db: $db,
            $table: $db.examEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LessonsTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastNotifiedAt => $composableBuilder(
    column: $table.lastNotifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get watchedLesson => $composableBuilder(
    column: $table.watchedLesson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get readNotes => $composableBuilder(
    column: $table.readNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get didHomework => $composableBuilder(
    column: $table.didHomework,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get didExam => $composableBuilder(
    column: $table.didExam,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reviewedNotes => $composableBuilder(
    column: $table.reviewedNotes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableOrderingComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LessonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastNotifiedAt => $composableBuilder(
    column: $table.lastNotifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get watchedLesson => $composableBuilder(
    column: $table.watchedLesson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get readNotes =>
      $composableBuilder(column: $table.readNotes, builder: (column) => column);

  GeneratedColumn<bool> get didHomework => $composableBuilder(
    column: $table.didHomework,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get didExam =>
      $composableBuilder(column: $table.didExam, builder: (column) => column);

  GeneratedColumn<bool> get reviewedNotes => $composableBuilder(
    column: $table.reviewedNotes,
    builder: (column) => column,
  );

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> homeworkEntriesRefs<T extends Object>(
    Expression<T> Function($$HomeworkEntriesTableAnnotationComposer a) f,
  ) {
    final $$HomeworkEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.homeworkEntries,
      getReferencedColumn: (t) => t.lessonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HomeworkEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.homeworkEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> examEntriesRefs<T extends Object>(
    Expression<T> Function($$ExamEntriesTableAnnotationComposer a) f,
  ) {
    final $$ExamEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.examEntries,
      getReferencedColumn: (t) => t.lessonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.examEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LessonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonsTable,
          LessonRow,
          $$LessonsTableFilterComposer,
          $$LessonsTableOrderingComposer,
          $$LessonsTableAnnotationComposer,
          $$LessonsTableCreateCompanionBuilder,
          $$LessonsTableUpdateCompanionBuilder,
          (LessonRow, $$LessonsTableReferences),
          LessonRow,
          PrefetchHooks Function({
            bool chapterId,
            bool homeworkEntriesRefs,
            bool examEntriesRefs,
          })
        > {
  $$LessonsTableTableManager(_$AppDatabase db, $LessonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<DateTime?> lastNotifiedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> watchedLesson = const Value.absent(),
                Value<bool> readNotes = const Value.absent(),
                Value<bool> didHomework = const Value.absent(),
                Value<bool> didExam = const Value.absent(),
                Value<bool> reviewedNotes = const Value.absent(),
              }) => LessonsCompanion(
                id: id,
                chapterId: chapterId,
                name: name,
                lastReviewedAt: lastReviewedAt,
                lastNotifiedAt: lastNotifiedAt,
                createdAt: createdAt,
                watchedLesson: watchedLesson,
                readNotes: readNotes,
                didHomework: didHomework,
                didExam: didExam,
                reviewedNotes: reviewedNotes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int chapterId,
                required String name,
                Value<DateTime?> lastReviewedAt = const Value.absent(),
                Value<DateTime?> lastNotifiedAt = const Value.absent(),
                required DateTime createdAt,
                Value<bool> watchedLesson = const Value.absent(),
                Value<bool> readNotes = const Value.absent(),
                Value<bool> didHomework = const Value.absent(),
                Value<bool> didExam = const Value.absent(),
                Value<bool> reviewedNotes = const Value.absent(),
              }) => LessonsCompanion.insert(
                id: id,
                chapterId: chapterId,
                name: name,
                lastReviewedAt: lastReviewedAt,
                lastNotifiedAt: lastNotifiedAt,
                createdAt: createdAt,
                watchedLesson: watchedLesson,
                readNotes: readNotes,
                didHomework: didHomework,
                didExam: didExam,
                reviewedNotes: reviewedNotes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LessonsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                chapterId = false,
                homeworkEntriesRefs = false,
                examEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (homeworkEntriesRefs) db.homeworkEntries,
                    if (examEntriesRefs) db.examEntries,
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
                        if (chapterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.chapterId,
                                    referencedTable: $$LessonsTableReferences
                                        ._chapterIdTable(db),
                                    referencedColumn: $$LessonsTableReferences
                                        ._chapterIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (homeworkEntriesRefs)
                        await $_getPrefetchedData<
                          LessonRow,
                          $LessonsTable,
                          HomeworkEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$LessonsTableReferences
                              ._homeworkEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LessonsTableReferences(
                                db,
                                table,
                                p0,
                              ).homeworkEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lessonId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (examEntriesRefs)
                        await $_getPrefetchedData<
                          LessonRow,
                          $LessonsTable,
                          ExamEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$LessonsTableReferences
                              ._examEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LessonsTableReferences(
                                db,
                                table,
                                p0,
                              ).examEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lessonId == item.id,
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

typedef $$LessonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonsTable,
      LessonRow,
      $$LessonsTableFilterComposer,
      $$LessonsTableOrderingComposer,
      $$LessonsTableAnnotationComposer,
      $$LessonsTableCreateCompanionBuilder,
      $$LessonsTableUpdateCompanionBuilder,
      (LessonRow, $$LessonsTableReferences),
      LessonRow,
      PrefetchHooks Function({
        bool chapterId,
        bool homeworkEntriesRefs,
        bool examEntriesRefs,
      })
    >;
typedef $$HomeworkEntriesTableCreateCompanionBuilder =
    HomeworkEntriesCompanion Function({
      Value<int> id,
      required int lessonId,
      required int score,
      required int maxScore,
      required DateTime createdAt,
    });
typedef $$HomeworkEntriesTableUpdateCompanionBuilder =
    HomeworkEntriesCompanion Function({
      Value<int> id,
      Value<int> lessonId,
      Value<int> score,
      Value<int> maxScore,
      Value<DateTime> createdAt,
    });

final class $$HomeworkEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $HomeworkEntriesTable, HomeworkEntryRow> {
  $$HomeworkEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LessonsTable _lessonIdTable(_$AppDatabase db) =>
      db.lessons.createAlias('homework_entries__lesson_id__lessons__id');

  $$LessonsTableProcessedTableManager get lessonId {
    final $_column = $_itemColumn<int>('lesson_id')!;

    final manager = $$LessonsTableTableManager(
      $_db,
      $_db.lessons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lessonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HomeworkEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $HomeworkEntriesTable> {
  $$HomeworkEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxScore => $composableBuilder(
    column: $table.maxScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LessonsTableFilterComposer get lessonId {
    final $$LessonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableFilterComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HomeworkEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $HomeworkEntriesTable> {
  $$HomeworkEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxScore => $composableBuilder(
    column: $table.maxScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LessonsTableOrderingComposer get lessonId {
    final $$LessonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableOrderingComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HomeworkEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HomeworkEntriesTable> {
  $$HomeworkEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get maxScore =>
      $composableBuilder(column: $table.maxScore, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LessonsTableAnnotationComposer get lessonId {
    final $$LessonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableAnnotationComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HomeworkEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HomeworkEntriesTable,
          HomeworkEntryRow,
          $$HomeworkEntriesTableFilterComposer,
          $$HomeworkEntriesTableOrderingComposer,
          $$HomeworkEntriesTableAnnotationComposer,
          $$HomeworkEntriesTableCreateCompanionBuilder,
          $$HomeworkEntriesTableUpdateCompanionBuilder,
          (HomeworkEntryRow, $$HomeworkEntriesTableReferences),
          HomeworkEntryRow,
          PrefetchHooks Function({bool lessonId})
        > {
  $$HomeworkEntriesTableTableManager(
    _$AppDatabase db,
    $HomeworkEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HomeworkEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HomeworkEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HomeworkEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> maxScore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => HomeworkEntriesCompanion(
                id: id,
                lessonId: lessonId,
                score: score,
                maxScore: maxScore,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lessonId,
                required int score,
                required int maxScore,
                required DateTime createdAt,
              }) => HomeworkEntriesCompanion.insert(
                id: id,
                lessonId: lessonId,
                score: score,
                maxScore: maxScore,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HomeworkEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lessonId = false}) {
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
                    if (lessonId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.lessonId,
                                referencedTable:
                                    $$HomeworkEntriesTableReferences
                                        ._lessonIdTable(db),
                                referencedColumn:
                                    $$HomeworkEntriesTableReferences
                                        ._lessonIdTable(db)
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

typedef $$HomeworkEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HomeworkEntriesTable,
      HomeworkEntryRow,
      $$HomeworkEntriesTableFilterComposer,
      $$HomeworkEntriesTableOrderingComposer,
      $$HomeworkEntriesTableAnnotationComposer,
      $$HomeworkEntriesTableCreateCompanionBuilder,
      $$HomeworkEntriesTableUpdateCompanionBuilder,
      (HomeworkEntryRow, $$HomeworkEntriesTableReferences),
      HomeworkEntryRow,
      PrefetchHooks Function({bool lessonId})
    >;
typedef $$ExamEntriesTableCreateCompanionBuilder =
    ExamEntriesCompanion Function({
      Value<int> id,
      required int lessonId,
      Value<bool> isReviewExam,
      required int totalPossiblePoints,
      required int correctPoints,
      required double percentage,
      required DateTime createdAt,
    });
typedef $$ExamEntriesTableUpdateCompanionBuilder =
    ExamEntriesCompanion Function({
      Value<int> id,
      Value<int> lessonId,
      Value<bool> isReviewExam,
      Value<int> totalPossiblePoints,
      Value<int> correctPoints,
      Value<double> percentage,
      Value<DateTime> createdAt,
    });

final class $$ExamEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $ExamEntriesTable, ExamEntryRow> {
  $$ExamEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LessonsTable _lessonIdTable(_$AppDatabase db) =>
      db.lessons.createAlias('exam_entries__lesson_id__lessons__id');

  $$LessonsTableProcessedTableManager get lessonId {
    final $_column = $_itemColumn<int>('lesson_id')!;

    final manager = $$LessonsTableTableManager(
      $_db,
      $_db.lessons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lessonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ExamQuestionGroupsTable,
    List<ExamQuestionGroupRow>
  >
  _examQuestionGroupsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.examQuestionGroups,
        aliasName: 'exam_entries__id__exam_question_groups__exam_id',
      );

  $$ExamQuestionGroupsTableProcessedTableManager get examQuestionGroupsRefs {
    final manager = $$ExamQuestionGroupsTableTableManager(
      $_db,
      $_db.examQuestionGroups,
    ).filter((f) => f.examId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _examQuestionGroupsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExamEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ExamEntriesTable> {
  $$ExamEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReviewExam => $composableBuilder(
    column: $table.isReviewExam,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPossiblePoints => $composableBuilder(
    column: $table.totalPossiblePoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctPoints => $composableBuilder(
    column: $table.correctPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LessonsTableFilterComposer get lessonId {
    final $$LessonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableFilterComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> examQuestionGroupsRefs(
    Expression<bool> Function($$ExamQuestionGroupsTableFilterComposer f) f,
  ) {
    final $$ExamQuestionGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.examQuestionGroups,
      getReferencedColumn: (t) => t.examId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamQuestionGroupsTableFilterComposer(
            $db: $db,
            $table: $db.examQuestionGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExamEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExamEntriesTable> {
  $$ExamEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReviewExam => $composableBuilder(
    column: $table.isReviewExam,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPossiblePoints => $composableBuilder(
    column: $table.totalPossiblePoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctPoints => $composableBuilder(
    column: $table.correctPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LessonsTableOrderingComposer get lessonId {
    final $$LessonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableOrderingComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExamEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExamEntriesTable> {
  $$ExamEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isReviewExam => $composableBuilder(
    column: $table.isReviewExam,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPossiblePoints => $composableBuilder(
    column: $table.totalPossiblePoints,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctPoints => $composableBuilder(
    column: $table.correctPoints,
    builder: (column) => column,
  );

  GeneratedColumn<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LessonsTableAnnotationComposer get lessonId {
    final $$LessonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lessonId,
      referencedTable: $db.lessons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LessonsTableAnnotationComposer(
            $db: $db,
            $table: $db.lessons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> examQuestionGroupsRefs<T extends Object>(
    Expression<T> Function($$ExamQuestionGroupsTableAnnotationComposer a) f,
  ) {
    final $$ExamQuestionGroupsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.examQuestionGroups,
          getReferencedColumn: (t) => t.examId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExamQuestionGroupsTableAnnotationComposer(
                $db: $db,
                $table: $db.examQuestionGroups,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExamEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExamEntriesTable,
          ExamEntryRow,
          $$ExamEntriesTableFilterComposer,
          $$ExamEntriesTableOrderingComposer,
          $$ExamEntriesTableAnnotationComposer,
          $$ExamEntriesTableCreateCompanionBuilder,
          $$ExamEntriesTableUpdateCompanionBuilder,
          (ExamEntryRow, $$ExamEntriesTableReferences),
          ExamEntryRow,
          PrefetchHooks Function({bool lessonId, bool examQuestionGroupsRefs})
        > {
  $$ExamEntriesTableTableManager(_$AppDatabase db, $ExamEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExamEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExamEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExamEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<bool> isReviewExam = const Value.absent(),
                Value<int> totalPossiblePoints = const Value.absent(),
                Value<int> correctPoints = const Value.absent(),
                Value<double> percentage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExamEntriesCompanion(
                id: id,
                lessonId: lessonId,
                isReviewExam: isReviewExam,
                totalPossiblePoints: totalPossiblePoints,
                correctPoints: correctPoints,
                percentage: percentage,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lessonId,
                Value<bool> isReviewExam = const Value.absent(),
                required int totalPossiblePoints,
                required int correctPoints,
                required double percentage,
                required DateTime createdAt,
              }) => ExamEntriesCompanion.insert(
                id: id,
                lessonId: lessonId,
                isReviewExam: isReviewExam,
                totalPossiblePoints: totalPossiblePoints,
                correctPoints: correctPoints,
                percentage: percentage,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExamEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({lessonId = false, examQuestionGroupsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (examQuestionGroupsRefs) db.examQuestionGroups,
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
                        if (lessonId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.lessonId,
                                    referencedTable:
                                        $$ExamEntriesTableReferences
                                            ._lessonIdTable(db),
                                    referencedColumn:
                                        $$ExamEntriesTableReferences
                                            ._lessonIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (examQuestionGroupsRefs)
                        await $_getPrefetchedData<
                          ExamEntryRow,
                          $ExamEntriesTable,
                          ExamQuestionGroupRow
                        >(
                          currentTable: table,
                          referencedTable: $$ExamEntriesTableReferences
                              ._examQuestionGroupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExamEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).examQuestionGroupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.examId == item.id,
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

typedef $$ExamEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExamEntriesTable,
      ExamEntryRow,
      $$ExamEntriesTableFilterComposer,
      $$ExamEntriesTableOrderingComposer,
      $$ExamEntriesTableAnnotationComposer,
      $$ExamEntriesTableCreateCompanionBuilder,
      $$ExamEntriesTableUpdateCompanionBuilder,
      (ExamEntryRow, $$ExamEntriesTableReferences),
      ExamEntryRow,
      PrefetchHooks Function({bool lessonId, bool examQuestionGroupsRefs})
    >;
typedef $$ExamQuestionGroupsTableCreateCompanionBuilder =
    ExamQuestionGroupsCompanion Function({
      Value<int> id,
      required int examId,
      required int pointsPerQuestion,
      required int questionCount,
      required int correctCount,
    });
typedef $$ExamQuestionGroupsTableUpdateCompanionBuilder =
    ExamQuestionGroupsCompanion Function({
      Value<int> id,
      Value<int> examId,
      Value<int> pointsPerQuestion,
      Value<int> questionCount,
      Value<int> correctCount,
    });

final class $$ExamQuestionGroupsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ExamQuestionGroupsTable,
          ExamQuestionGroupRow
        > {
  $$ExamQuestionGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ExamEntriesTable _examIdTable(_$AppDatabase db) => db.examEntries
      .createAlias('exam_question_groups__exam_id__exam_entries__id');

  $$ExamEntriesTableProcessedTableManager get examId {
    final $_column = $_itemColumn<int>('exam_id')!;

    final manager = $$ExamEntriesTableTableManager(
      $_db,
      $_db.examEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_examIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExamQuestionGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ExamQuestionGroupsTable> {
  $$ExamQuestionGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointsPerQuestion => $composableBuilder(
    column: $table.pointsPerQuestion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  $$ExamEntriesTableFilterComposer get examId {
    final $$ExamEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.examId,
      referencedTable: $db.examEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamEntriesTableFilterComposer(
            $db: $db,
            $table: $db.examEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExamQuestionGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExamQuestionGroupsTable> {
  $$ExamQuestionGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointsPerQuestion => $composableBuilder(
    column: $table.pointsPerQuestion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$ExamEntriesTableOrderingComposer get examId {
    final $$ExamEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.examId,
      referencedTable: $db.examEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.examEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExamQuestionGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExamQuestionGroupsTable> {
  $$ExamQuestionGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pointsPerQuestion => $composableBuilder(
    column: $table.pointsPerQuestion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  $$ExamEntriesTableAnnotationComposer get examId {
    final $$ExamEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.examId,
      referencedTable: $db.examEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExamEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.examEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExamQuestionGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExamQuestionGroupsTable,
          ExamQuestionGroupRow,
          $$ExamQuestionGroupsTableFilterComposer,
          $$ExamQuestionGroupsTableOrderingComposer,
          $$ExamQuestionGroupsTableAnnotationComposer,
          $$ExamQuestionGroupsTableCreateCompanionBuilder,
          $$ExamQuestionGroupsTableUpdateCompanionBuilder,
          (ExamQuestionGroupRow, $$ExamQuestionGroupsTableReferences),
          ExamQuestionGroupRow,
          PrefetchHooks Function({bool examId})
        > {
  $$ExamQuestionGroupsTableTableManager(
    _$AppDatabase db,
    $ExamQuestionGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExamQuestionGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExamQuestionGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExamQuestionGroupsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> examId = const Value.absent(),
                Value<int> pointsPerQuestion = const Value.absent(),
                Value<int> questionCount = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
              }) => ExamQuestionGroupsCompanion(
                id: id,
                examId: examId,
                pointsPerQuestion: pointsPerQuestion,
                questionCount: questionCount,
                correctCount: correctCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int examId,
                required int pointsPerQuestion,
                required int questionCount,
                required int correctCount,
              }) => ExamQuestionGroupsCompanion.insert(
                id: id,
                examId: examId,
                pointsPerQuestion: pointsPerQuestion,
                questionCount: questionCount,
                correctCount: correctCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExamQuestionGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({examId = false}) {
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
                    if (examId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.examId,
                                referencedTable:
                                    $$ExamQuestionGroupsTableReferences
                                        ._examIdTable(db),
                                referencedColumn:
                                    $$ExamQuestionGroupsTableReferences
                                        ._examIdTable(db)
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

typedef $$ExamQuestionGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExamQuestionGroupsTable,
      ExamQuestionGroupRow,
      $$ExamQuestionGroupsTableFilterComposer,
      $$ExamQuestionGroupsTableOrderingComposer,
      $$ExamQuestionGroupsTableAnnotationComposer,
      $$ExamQuestionGroupsTableCreateCompanionBuilder,
      $$ExamQuestionGroupsTableUpdateCompanionBuilder,
      (ExamQuestionGroupRow, $$ExamQuestionGroupsTableReferences),
      ExamQuestionGroupRow,
      PrefetchHooks Function({bool examId})
    >;
typedef $$DailyTasksTableCreateCompanionBuilder =
    DailyTasksCompanion Function({
      Value<int> id,
      required DateTime day,
      required String title,
      Value<bool> done,
      required int sortOrder,
      required DateTime createdAt,
    });
typedef $$DailyTasksTableUpdateCompanionBuilder =
    DailyTasksCompanion Function({
      Value<int> id,
      Value<DateTime> day,
      Value<String> title,
      Value<bool> done,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

class $$DailyTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DailyTasksTable> {
  $$DailyTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyTasksTable> {
  $$DailyTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyTasksTable> {
  $$DailyTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DailyTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyTasksTable,
          DailyTaskRow,
          $$DailyTasksTableFilterComposer,
          $$DailyTasksTableOrderingComposer,
          $$DailyTasksTableAnnotationComposer,
          $$DailyTasksTableCreateCompanionBuilder,
          $$DailyTasksTableUpdateCompanionBuilder,
          (
            DailyTaskRow,
            BaseReferences<_$AppDatabase, $DailyTasksTable, DailyTaskRow>,
          ),
          DailyTaskRow,
          PrefetchHooks Function()
        > {
  $$DailyTasksTableTableManager(_$AppDatabase db, $DailyTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> day = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DailyTasksCompanion(
                id: id,
                day: day,
                title: title,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime day,
                required String title,
                Value<bool> done = const Value.absent(),
                required int sortOrder,
                required DateTime createdAt,
              }) => DailyTasksCompanion.insert(
                id: id,
                day: day,
                title: title,
                done: done,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyTasksTable,
      DailyTaskRow,
      $$DailyTasksTableFilterComposer,
      $$DailyTasksTableOrderingComposer,
      $$DailyTasksTableAnnotationComposer,
      $$DailyTasksTableCreateCompanionBuilder,
      $$DailyTasksTableUpdateCompanionBuilder,
      (
        DailyTaskRow,
        BaseReferences<_$AppDatabase, $DailyTasksTable, DailyTaskRow>,
      ),
      DailyTaskRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db, _db.subjects);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$LessonsTableTableManager get lessons =>
      $$LessonsTableTableManager(_db, _db.lessons);
  $$HomeworkEntriesTableTableManager get homeworkEntries =>
      $$HomeworkEntriesTableTableManager(_db, _db.homeworkEntries);
  $$ExamEntriesTableTableManager get examEntries =>
      $$ExamEntriesTableTableManager(_db, _db.examEntries);
  $$ExamQuestionGroupsTableTableManager get examQuestionGroups =>
      $$ExamQuestionGroupsTableTableManager(_db, _db.examQuestionGroups);
  $$DailyTasksTableTableManager get dailyTasks =>
      $$DailyTasksTableTableManager(_db, _db.dailyTasks);
}
