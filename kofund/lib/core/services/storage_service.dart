// Firebase Storage Service 
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';


class StorageService {
final FirebaseStorage _storage = FirebaseStorage.instance;


Future<String> uploadCommunityLogo(String communityId, File file) async {
final ref = _storage.ref().child('communities/$communityId/logo.jpg');
await ref.putFile(file);
return await ref.getDownloadURL();
}
}