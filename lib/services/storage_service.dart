import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadReceipt(String localPath, String userId) async {
    final file = File(localPath);
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('receipts/$fileName');

    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await uploadTask.ref.getDownloadURL();
  }
}
