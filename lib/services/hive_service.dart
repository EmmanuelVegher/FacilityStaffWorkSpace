// import 'dart:typed_data';
//
// import 'package:attendanceapp/services/database_adapter.dart';
// import 'package:hive_flutter/hive_flutter.dart';
//
// class HiveService extends DatabaseAdapter {
//   @override
//   Future<List<Uint8List>> getImages() async {
//     var box = await Hive.openBox('imageBox');
//
//     List<dynamic>? result = box.get('images');
//     if (result != null) {
//       return result.cast<Uint8List>();
//     } else {
//       return [];
//     }
//   }
//
//   @override
//   Future<void> storeImage(Uint8List imageBytes) async {
//     List<Uint8List> images = [];
//     var box = await Hive.openBox('imageBox');
//     List<dynamic>? allImages = box.get("images");
//     if (allImages != null) {
//       images.addAll(allImages.cast<Uint8List>());
//     }
//     images.clear();
//     images.add(imageBytes);
//     print("images ==== $images");
//     box.put("images", images);
//   }
//
//   Future<void> clearImages() async {
//     var box = await Hive.openBox('imageBox');
//     await box.delete('images');
//   }
//
//
//
//   // Store Signature Images
//
//   @override
//   Future<List<Uint8List>> getSignatureImages() async {
//     var box = await Hive.openBox('imageSignatureBox');
//
//     List<dynamic>? result = box.get('imagesSignature');
//     if (result != null) {
//       return result.cast<Uint8List>();
//     } else {
//       return [];
//     }
//   }
//
//   @override
//   Future<void> storeSignatureImage(Uint8List imageBytes) async {
//     List<Uint8List> imagesSignature = [];
//     var box = await Hive.openBox('imageSignatureBox');
//     List<dynamic>? allImages = box.get("imagesSignature");
//     if (allImages != null) {
//       imagesSignature.addAll(allImages.cast<Uint8List>());
//     }
//     imagesSignature.clear();
//     imagesSignature.add(imageBytes);
//     print("imagesSignature ==== $imagesSignature");
//     box.put("imagesSignature", imagesSignature);
//   }
//
//   Future<void> clearSignatureImages() async {
//     var box = await Hive.openBox('imageSignatureBox');
//     await box.delete('imagesSignature');
//   }
//
//   @override
//   Future<void> clearSignatureImages1() async {
//     var box = await Hive.openBox('imageSignatureBox');
//     await box.clear();
//   }
// }
