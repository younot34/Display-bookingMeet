import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/media.dart';


class MediaService {
  final CollectionReference mediaCollection =
  FirebaseFirestore.instance.collection('mediaLibrary');

  Future<List<Media>> getAllMedia() async {
    final snapshot = await mediaCollection.get();
    return snapshot.docs.map((doc) => Media.fromFirestore(doc)).toList();
  }

  // Ubah uploadImage supaya simpan base64 di Firestore
  Future<String> uploadImage(File file, String fileName) async {
    try {
      if (fileName.trim().isEmpty) {
        throw Exception("Filename tidak boleh kosong");
      }

      print("📤 Uploading file: ${file.path}");

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Simpan ke dokumen sementara di Firestore untuk mendapatkan URL (opsional)
      final docRef = await mediaCollection.add({
        'fileName': fileName,
        'imageData': base64Image,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ Upload success: docId=${docRef.id}");
      // Return docId sebagai "URL" sementara untuk akses nanti
      return docRef.id;
    } catch (e) {
      print("❌ Upload error: $e");
      rethrow;
    }
  }

  Future<Media> createMedia(Media media) async {
    final docRef = await mediaCollection.add(media.toMap());
    final newMedia = Media(
      id: docRef.id,
      logoUrl: media.logoUrl,
      subLogoUrl: media.subLogoUrl,
    );
    await docRef.update(newMedia.toMap()); // simpan dengan id yang benar
    return newMedia;
  }

  Future<void> updateMedia(Media media) async {
    if (media.id.isEmpty) throw Exception("Media id tidak boleh kosong");
    await mediaCollection.doc(media.id).update(media.toMap());
  }

  Future<void> deleteMedia(String id) async {
    await mediaCollection.doc(id).delete();
  }
}
