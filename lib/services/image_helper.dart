import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

/// Lets the admin pick a photo and shrinks it to a small JPEG thumbnail,
/// returned as base64 (typically 20–60 KB, well under Firestore's 1 MB limit).
Future<String?> pickThumbnailBase64({int maxSide = 480}) async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image file.');
  final resized = decoded.width >= decoded.height
      ? (decoded.width > maxSide ? img.copyResize(decoded, width: maxSide) : decoded)
      : (decoded.height > maxSide ? img.copyResize(decoded, height: maxSide) : decoded);
  return base64Encode(img.encodeJpg(resized, quality: 72));
}
