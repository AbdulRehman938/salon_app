import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

Future<bool> downloadReceiptBytes({
  required String fileName,
  required Uint8List bytes,
  required MimeType mimeType,
}) async {
  final normalized = fileName.trim().isEmpty ? 'receipt.bin' : fileName.trim();
  final dotIndex = normalized.lastIndexOf('.');

  final baseName = dotIndex > 0
      ? normalized.substring(0, dotIndex)
      : normalized;
  final ext = dotIndex > 0 && dotIndex < normalized.length - 1
      ? normalized.substring(dotIndex + 1)
      : 'bin';

  await FileSaver.instance.saveFile(
    name: baseName,
    bytes: bytes,
    ext: ext,
    mimeType: mimeType,
  );

  return true;
}

Future<bool> downloadReceiptFile({
  required String fileName,
  required String content,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  return downloadReceiptBytes(
    fileName: fileName,
    bytes: bytes,
    mimeType: MimeType.text,
  );
}
