import 'package:chat_messenger_app/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';

import '../../data/models/chat_room_model.dart';
import '../../data/services/service_locator.dart';

class ChatListTile extends StatelessWidget {
  final ChatRoomModel chat;
  final String currentUserId;
  final VoidCallback onTap;
  const ChatListTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  String _getOtherUsername() {
    final otherUserId = chat.participants.firstWhere(
      (id) => id != currentUserId,
    );
    return chat.participantsName[otherUserId] ?? "Unknow";
  }

  @override
  Widget build(BuildContext context) {
    final username = _getOtherUsername();

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Text((username.isNotEmpty) ? username[0].toUpperCase() : '?'),
      ),
      title: Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessage ?? "",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
      trailing: StreamBuilder<int>(
        stream: getIt<ChatRepository>().getUnreadCount(chat.id, currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == 0) {
            return SizedBox();
          }
          return Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              snapshot.data.toString(),
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      ),
     );
  }
}
