import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadReceipt(String localPath, String userId, {String userName = '', String purpose = ''}) async {
    final file = File(localPath);
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    final safeName = userName.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '');
    final safePurpose = purpose.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '');
    final fileName = '${safeName}_${date}_$safePurpose.jpg';
    final ref = _storage.ref().child('receipts/$fileName');

    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await uploadTask.ref.getDownloadURL();
  }
}
