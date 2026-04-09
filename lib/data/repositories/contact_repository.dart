import 'package:chat_messenger_app/data/services/base_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/user_model.dart';

class ContactRepository extends BaseRepository {
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  Future<bool> requestContextPermission() async {
    return await FlutterContacts.requestPermission();
  }

  Future<List<Map<String, dynamic>>> getRegisteredContacts() async {
    try {
      // ✅ Ask for permission first
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) {
        print("Permission denied to read contacts.");
        return [];
      }

      // ✅ Get Device Contacts With Phone Number
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      // ✅ Extract and normalize phone numbers
      final phoneNumbers =
          contacts
              .where((contact) => contact.phones.isNotEmpty)
              .map(
                (contact) => {
                  'name': contact.displayName,
                  'phoneNumber': contact.phones.first.number.replaceAll(
                    RegExp(r'[^\d+]'),
                    '',
                  ),
                  'photo': contact.photo,
                },
              )
              .toList();

      // ✅ Get All Users From Firestore
      final usersSnapShot = await firestore.collection("users").get();
      final registeredUsers =
          usersSnapShot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .toList();

      // ✅ Match Contacts With Registered Users
      final matchedContacts =
          phoneNumbers
              .where((contact) {
                final phoneNumber = contact["phoneNumber"];
                return registeredUsers.any(
                  (user) =>
                      user.phoneNumber == phoneNumber &&
                      user.uid != currentUserId,
                );
              })
              .map((contact) {
                final registeredUser = registeredUsers.firstWhere(
                  (user) => user.phoneNumber == contact["phoneNumber"],
                );
                return {
                  'id': registeredUser.uid,
                  'name': contact['name'],
                  'phoneNumber': contact['phoneNumber'],
                  'photo': contact['photo'],
                };
              })
              .toList();

      return matchedContacts;
    } catch (e, stacktrace) {
      print("Error getting registered contacts: $e");
      print(stacktrace);
      return [];
    }
  }
}
