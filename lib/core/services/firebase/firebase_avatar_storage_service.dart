import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

class FirebaseAvatarStorageService {
  static const int _maxDimension = 1080;
  static const int _targetJpegBytes = 700 * 1024;

  static Future<String> uploadAdminAvatar({
    required String uid,
    required Uint8List imageBytes,
    required String contentType,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('uid must not be empty');
    }

    final ref = FirebaseStorage.instance.ref().child(
      'users/$normalizedUid/avatar',
    );

    final preparedImage = _prepareAvatarForUpload(
      imageBytes: imageBytes,
      contentType: contentType,
    );

    await ref.putData(
      preparedImage.bytes,
      SettableMetadata(contentType: preparedImage.contentType),
    );

    final downloadUrl = await ref.getDownloadURL();
    final version = DateTime.now().millisecondsSinceEpoch;
    final separator = downloadUrl.contains('?') ? '&' : '?';
    return '$downloadUrl${separator}v=$version';
  }

  static _PreparedAvatarData _prepareAvatarForUpload({
    required Uint8List imageBytes,
    required String contentType,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return _PreparedAvatarData(
        bytes: imageBytes,
        contentType: _normalizeContentType(contentType),
      );
    }

    final resized = _resizeIfNeeded(decoded);
    final normalizedContentType = _normalizeContentType(contentType);

    final bool shouldKeepPng =
        normalizedContentType == 'image/png' && resized.hasAlpha;

    final _PreparedAvatarData candidate = shouldKeepPng
        ? _encodeAsPng(resized)
        : _encodeAsJpeg(resized);

    if (candidate.bytes.length >= imageBytes.length) {
      return _PreparedAvatarData(
        bytes: imageBytes,
        contentType: normalizedContentType,
      );
    }

    return candidate;
  }

  static img.Image _resizeIfNeeded(img.Image source) {
    final longestSide = source.width > source.height
        ? source.width
        : source.height;
    if (longestSide <= _maxDimension) {
      return source;
    }

    final ratio = _maxDimension / longestSide;
    final targetWidth = (source.width * ratio).round().clamp(1, _maxDimension);
    final targetHeight = (source.height * ratio).round().clamp(
      1,
      _maxDimension,
    );

    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
  }

  static _PreparedAvatarData _encodeAsPng(img.Image image) {
    final bytes = Uint8List.fromList(img.encodePng(image, level: 6));
    return _PreparedAvatarData(bytes: bytes, contentType: 'image/png');
  }

  static _PreparedAvatarData _encodeAsJpeg(img.Image image) {
    int quality = 88;
    Uint8List encoded = Uint8List.fromList(
      img.encodeJpg(image, quality: quality),
    );

    while (encoded.length > _targetJpegBytes && quality > 58) {
      quality -= 8;
      encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    return _PreparedAvatarData(bytes: encoded, contentType: 'image/jpeg');
  }

  static String _normalizeContentType(String contentType) {
    final normalized = contentType.trim().toLowerCase();
    if (normalized == 'image/jpg') return 'image/jpeg';
    if (normalized == 'image/png') return 'image/png';
    if (normalized == 'image/webp') return 'image/webp';
    return 'image/jpeg';
  }
}

class _PreparedAvatarData {
  const _PreparedAvatarData({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}
