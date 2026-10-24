import 'barcode_enums.dart';

/// One selectable camera or other video input source.
class CameraInputSource {
  /// Creates a [CameraInputSource].
  const CameraInputSource({
    required this.id,
    required this.label,
    required this.facing,
  });

  /// Platform identifier used to reopen this exact device.
  final String id;

  /// Human-readable name shown in the input-source menu.
  final String label;

  /// Lens direction used to keep torch, mirroring, and [CameraFacing] in sync.
  final CameraFacing facing;

  /// Parses a method-channel map. Returns `null` when [id] is missing.
  static CameraInputSource? fromChannel(Map<Object?, Object?> map) {
    final String id = map['id']?.toString() ?? '';
    if (id.isEmpty) {
      return null;
    }
    final String rawLabel = map['label']?.toString().trim() ?? '';
    return CameraInputSource(
      id: id,
      label: rawLabel.isEmpty ? id : rawLabel,
      facing: facingFromName(map['facing']?.toString()),
    );
  }

  /// Parses a method-channel list of camera maps.
  static List<CameraInputSource> listFromChannel(Object? raw) {
    if (raw is! List) {
      return const <CameraInputSource>[];
    }
    final List<CameraInputSource> sources = <CameraInputSource>[];
    for (final Object? item in raw) {
      if (item is! Map) {
        continue;
      }
      final CameraInputSource? source = CameraInputSource.fromChannel(
        Map<Object?, Object?>.from(item),
      );
      if (source != null) {
        sources.add(source);
      }
    }
    return sources;
  }

  /// Maps a platform facing name onto [CameraFacing].
  static CameraFacing facingFromName(String? name) {
    switch (name) {
      case 'front':
        return CameraFacing.front;
      case 'external':
        return CameraFacing.external;
      default:
        return CameraFacing.back;
    }
  }
}
