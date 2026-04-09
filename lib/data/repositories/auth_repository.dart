import 'dart:developer';
import 'package:chat_messenger_app/data/models/user_model.dart';
import 'package:chat_messenger_app/data/services/base_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository extends BaseRepository {
  Stream<User?> get authStateChanges => auth.authStateChanges();
  Future<UserModel> signUp({
    required String fullName,
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final formattedPhoneNumber = phoneNumber.replaceAll(
        RegExp(r'\s+'),
        "".trim(),
      );

      final emailExists = await checkEmailExists(email);
      if (emailExists) {
        throw "An account with the same email already exists";
      }
      final phoneNumberExists = await checkPhoneNumberExists(
        formattedPhoneNumber,
      );
      if (phoneNumberExists) {
        throw "An account with the same phone number already exists";
      }
      final userNameExists = await checkUsernameExists(username);
      if (userNameExists) {
        throw "An account with the same username already exists";
      }

      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user == null) {
        throw "Failed to create user";
      }
      //create user model and save the user in the db firestore

      final user = UserModel(
        uid: userCredential.user!.uid,
        username: username,
        fullName: fullName,
        email: email,
        phoneNumber: formattedPhoneNumber,
      );
      await saveUserData(user);
      return user;
    } catch (e) {
      log(e.toString());
      rethrow;
    }
  }

  Future<void> saveUserData(UserModel user) async {
    try {
      await firestore.collection("users").doc(user.uid).set(user.toMap());
    } catch (e) {
      throw "Failed to save user data";
    }
  }

  Future<void> signOut() async {
    auth.signOut();
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      final methods = await auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print("Error checking email: $email");
      return false;
    }
  }

  Future<bool> checkPhoneNumberExists(String phoneNumber) async {
    try {
      final formattedNumber = phoneNumber.replaceAll(RegExp(r'\s+'), "".trim());
      final querySnapshot =
          await firestore
              .collection("users")
              .where("phoneNumber", isEqualTo: formattedNumber)
              .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking phoneNumber: $phoneNumber");
      return false;
    }
  }

  Future<bool> checkUsernameExists(String username) async {
    try {
      final querySnapshot =
          await firestore
              .collection("users")
              .where("username", isEqualTo: username.trim())
              .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking username: $username");
      return false;
    }
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user == null) {
        throw "User not found";
      }
      final userData = await getUserData(userCredential.user!.uid);
      return userData;
    } catch (e) {
      log(e.toString());
      rethrow;
    }
  }

  Future<UserModel> getUserData(String uid) async {
    try {
      final doc = await firestore.collection("users").doc(uid).get();
      if (!doc.exists) {
        throw "User data not found";
      }
      log(doc.id);
      return UserModel.fromFirestore(doc);
    } catch (e) {
      throw "Failed to save user data";
    }
  }
}
