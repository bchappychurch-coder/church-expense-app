import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadReceipt(String localPath, String userId, {String userName = '', String purpose = '', XFile? xFile}) async {
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    final safeName = userName.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '');
    final safePurpose = purpose.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '');
    final ts = now.millisecondsSinceEpoch;
    final fileName = '${safeName}_${date}_${ts}_$safePurpose.jpg';
    final ref = _storage.ref().child('receipts/$fileName');

    UploadTask uploadTask;
    if (kIsWeb && xFile != null) {
      final bytes = await xFile.readAsBytes();
      uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      uploadTask = ref.putFile(File(localPath), SettableMetadata(contentType: 'image/jpeg'));
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
