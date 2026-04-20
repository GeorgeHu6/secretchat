import 'dart:io';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'path_utils.dart';

class FileUtils {
  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'svg',
  ];

  static const List<String> documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
  ];

  static bool isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return imageExtensions.contains(ext);
  }

  static bool isDocumentFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return documentExtensions.contains(ext);
  }

  static String getFileType(String path) {
    if (isImageFile(path)) return 'image';
    if (isDocumentFile(path)) return 'document';
    return 'file';
  }

  static bool isValidFileSize(int size) {
    return size <= 50 * 1024 * 1024;
  }

  static Future<String> getFileName(String path) async {
    return path.split('/').last;
  }

  static Future<int> getFileSize(String path) async {
    final file = File(path);
    return await file.length();
  }

  static Future<XFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result != null && result.files.single.path != null) {
      return XFile(result.files.single.path!);
    }
    return null;
  }

  static Future<XFile?> pickImage() async {
    final picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.gallery);
  }

  static Future<String?> saveFile(Uint8List data, String fileName) async {
    final tempDir = await PathUtils.getTempDir();
    final filePath = '$tempDir/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(data);
    return filePath;
  }

  static Future<bool> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}
