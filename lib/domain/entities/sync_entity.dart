/// Base model for entities that participate in multi-device sync.
///
/// Each syncable entity carries metadata for conflict resolution and tracking:
/// - id: unique identifier across devices (UUID string)
/// - entityType: discriminator for the Firestore collection path
/// - updatedAt: server timestamp for last-write-wins resolution
/// - version: monotonic counter for same-timestamp tie-breaking
/// - deleted: soft deletion flag, synced like any other change
///
/// Firestore document structure:
/// users/{uid}/sync/{entityType}/{entityId}
final class SyncEntity {
  const SyncEntity({
    required this.id,
    required this.entityType,
    required this.updatedAt,
    required this.version,
    required this.deleted,
  });

  /// Unique identifier across all devices. UUIDs ensure no collisions when
  /// two devices create entities offline and later sync.
  final String id;

  /// Discriminator for routing to the correct Firestore collection and
  /// deserializing back to the right entity type. Values: 'subject',
  /// 'chapter', 'lesson', 'exam', 'homework', 'task'.
  final String entityType;

  /// Server timestamp of the last modification. Used for last-write-wins
  /// conflict resolution: a newer timestamp always overrides an older one,
  /// regardless of which device made the change.
  ///
  /// Stored as epoch milliseconds (UTC) to match the backup format and avoid
  /// timezone or locale misparsing on restore.
  final DateTime updatedAt;

  /// Monotonic version counter, incremented on every local modification.
  /// Breaks ties when two devices write at the exact same millisecond: the
  /// higher version wins. Starts at 1 on creation.
  final int version;

  /// Soft deletion flag. A deleted entity syncs like any other change rather
  /// than being removed from Firestore: this ensures the deletion propagates
  /// to all devices, even ones that were offline when it happened.
  ///
  /// A deleted entity remains in Firestore but is filtered out of the local
  /// database on sync. It can be permanently removed later by a cleanup job.
  final bool deleted;

  SyncEntity copyWith({
    DateTime? updatedAt,
    int? version,
    bool? deleted,
  }) {
    return SyncEntity(
      id: id,
      entityType: entityType,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
    );
  }

  /// Serializes to Firestore-compatible JSON. DateTime is stored as epoch
  /// milliseconds (not ISO strings) to match the backup format and avoid
  /// locale-dependent parsing errors.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'entityType': entityType,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'version': version,
        'deleted': deleted,
      };

  /// Deserializes from Firestore JSON. Throws if required fields are missing
  /// or have the wrong type — a malformed sync document should fail loudly
  /// rather than half-applying and corrupting local state.
  static SyncEntity fromJson(Map<String, Object?> json) {
    return SyncEntity(
      id: json['id']! as String,
      entityType: json['entityType']! as String,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']! as int),
      version: json['version']! as int,
      deleted: (json['deleted'] ?? false) as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncEntity &&
      other.id == id &&
      other.entityType == entityType &&
      other.updatedAt == updatedAt &&
      other.version == version &&
      other.deleted == deleted;

  @override
  int get hashCode =>
      Object.hash(id, entityType, updatedAt, version, deleted);
}
