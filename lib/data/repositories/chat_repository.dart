import 'package:chat_messenger_app/data/models/chat_message.dart';
import 'package:chat_messenger_app/data/models/chat_room_model.dart';
import 'package:chat_messenger_app/data/models/user_model.dart';
import 'package:chat_messenger_app/data/services/base_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRepository extends BaseRepository {
  CollectionReference get _chatRooms => firestore.collection("chatRooms");

  CollectionReference getChatRoomMessages(String chatRoomId) {
    return _chatRooms.doc(chatRoomId).collection("messages");
  }

  Future<ChatRoomModel> getOrCreateChatRoom(
    String currentUserId,
    String otherUserId,
  ) async {
    final users = [currentUserId, otherUserId]..sort();
    final roomId = users.join("_");

    final roomDoc = await _chatRooms.doc(roomId).get();

    if (roomDoc.exists) {
      return ChatRoomModel.fromFirestore(roomDoc);
    }

    final currentUserData =
        await firestore.collection("users").doc(currentUserId).get();
    final otherUserData =
        await firestore.collection("users").doc(otherUserId).get();

    print("👤 Current user full name: ${currentUserData['fullName']}");
    print("👤 Other user full name: ${otherUserData['fullName']}");

    final participantsName = {
      currentUserId: currentUserData['fullName']?.toString() ?? "",
      otherUserId: otherUserData['fullName']?.toString() ?? "",
    };

    final newRoom = ChatRoomModel(
      id: roomId,
      participants: users,
      participantsName: participantsName,
      lastReadTime: {
        currentUserId: Timestamp.now(),
        otherUserId: Timestamp.now(),
      },
      lastMessageTime: Timestamp.now(),
    );

    await _chatRooms.doc(roomId).set(newRoom.toMap());
    return newRoom;
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    //Batch
    final batch = firestore.batch();

    //Get Message Sub Collection
    final messageRef = getChatRoomMessages(chatRoomId);
    final messageDoc = messageRef.doc();

    //Chat Message
    final message = ChatMessage(
      id: messageDoc.id,
      chatRoomId: chatRoomId,
      type: type,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      timestamp: Timestamp.now(),
      readBy: [senderId],
    );

    //Add Message To Sub Collection
    batch.set(messageDoc, message.toMap());

    //Update ChatRoom
    batch.update(_chatRooms.doc(chatRoomId), {
      "lastMessage": content,
      "lastMessageSenderId": senderId,
      "lastMessageTime": message.timestamp,
    });
    await batch.commit();
  }

  Stream<List<ChatMessage>> getMessage(
    String roomId, {
    DocumentSnapshot? lastDocument,
  }) {
    var query = getChatRoomMessages(
      roomId,
    ).orderBy('timestamp', descending: true).limit(20);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList(),
    );
  }

  Future<List<ChatMessage>> getMoreMessage(
    String roomId, {
    required DocumentSnapshot lastDocument,
  }) async {
    final query = getChatRoomMessages(roomId)
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDocument)
        .limit(20);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }

  Stream<List<ChatRoomModel>> getChatRooms(String userId) {
    return _chatRooms
        .where("participants", arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatRoomModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Stream<int> getUnreadCount(String chatRoomId, String userId) {
    return getChatRoomMessages(chatRoomId)
        .where("receiverId", isEqualTo: userId)
        .where('status', isEqualTo: MessageStatus.sent.toString())
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markMessageAsRead(String chatRoomId, String userId) async {
    try {
      final batch = firestore.batch();

      //Get all unread messages where user is receiver

      final unreadMessages =
          await getChatRoomMessages(chatRoomId)
              .where("receiverId", isEqualTo: userId)
              .where('status', isEqualTo: MessageStatus.sent.toString())
              .get();
      print("found ${unreadMessages.docs.length} unread messages");

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
          'status': MessageStatus.read.toString(),
        });

        await batch.commit();

        print("Marked messages as read for user $userId");
      }
    } catch (e) {}
  }

  Stream<Map<String, dynamic>> getUserOnlineStatus(String userId) {
    return firestore.collection("users").doc(userId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      return {
        'isOnline': data?['isOnline'] ?? false,
        'lastSeen': data?['lastSeen'],
      };
    });
  }

  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await firestore.collection("users").doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': Timestamp.now(),
    });
  }

  Future<void> updateTypingStatus(
    String chatRomId,
    String userId,
    bool isTyping,
  ) async {
    try {
      final doc = await _chatRooms.doc(chatRomId).get();
      if (!doc.exists) {
        print("chat room does not exits");
        return;
      }
      await _chatRooms.doc(chatRomId).update({
        'isTyping': isTyping,
        'typingUserId': isTyping ? userId : null,
      });
    } catch (e) {
      print("error updating typing status");
    }
  }

  Stream<Map<String, dynamic>> getTypingStatus(String chatRoomId) {
    return _chatRooms.doc(chatRoomId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return {'isTyping': false, 'typingUserId': null};
      }
      final data = snapshot.data() as Map<String, dynamic>;
      return {
        'isTyping': data['isTyping'] ?? false,
        'typingUserId': data['typingUserId'],
      };
    });
  }
  Future<void> blockUser(String currentUserId, String blockedUsersId) async {
    final userRef = firestore.collection("users").doc(currentUserId);
    await userRef.update({
      'blockedUsers' : FieldValue.arrayUnion([blockedUsersId])
    });
  }

  Future<void> unBlockUser(String currentUserId, String blockedUsersId) async {
    final userRef = firestore.collection("users").doc(currentUserId);
    await userRef.update({
      'blockedUsers' : FieldValue.arrayRemove([blockedUsersId])
    });
  }

  Stream<bool> isUserBlocked(String currentUserId, String otherUserId) {
    return firestore.collection("users").doc(currentUserId).snapshots().map((doc) {
      final userData = UserModel.fromFirestore(doc);
      return userData.blockedUser.contains(otherUserId);

    });
  }

  Stream<bool> amIBlocked(String currentUserId, String otherUserId) {
    return firestore.collection("users").doc(otherUserId).snapshots().map((doc) {
      final userData = UserModel.fromFirestore(doc);
      return userData.blockedUser.contains(currentUserId);

    });
  }


}
