import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Usa bytes en vez de `File` para que funcione en web.
  Future<String> uploadPackagePhoto({
    required String restaurantId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final extension = contentType.split('/').last;
    final name = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref('restaurants/$restaurantId/packages/$name');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
