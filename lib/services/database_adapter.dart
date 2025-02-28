import 'dart:typed_data';

abstract class DatabaseAdapter {
  Future<void> storeImage(Uint8List imageBytes);
  Future<List<Uint8List>> getImages();

  Future<void> storeSignatureImage(Uint8List imageBytes);
  Future<List<Uint8List>> getSignatureImages();

  Future<void> clearSignatureImages1(); // Add the clear method here
}
