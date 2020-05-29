import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../server.dart';

class ChatService{
  static List<User> users = [];

  static void userLogin(WebSocketChannel webSocket, User user){
    user.websocket = webSocket;
    user.isOnline = true;
    int indexOf = users.isNotEmpty ? users.indexWhere((element) => element.nickname == user.nickname) : null;
    if(indexOf==null || indexOf == -1) {
      users.add(user);
    }else{
      users[indexOf] = user;
    }
    print(['login found at $indexOf', user.nickname, webSocket.hashCode]);
    notifyLoggedUsersToAll();
  }

  static void sendMessage(WebSocketChannel webSocket, SocketMessage sm){
    var targetSocket = users.firstWhere((element) => element.nickname == sm.user.nickname).websocket;
    var sender = users.firstWhere((element) => element.websocket.hashCode == webSocket.hashCode);
    var message = {
      'type': SocketMessageTypes.message.index,
      'user': sender.toJson(),
      'message': sm.message
    };
    print(['send', sm.message,  'from ${sender.nickname}', 'to ${sm.user.nickname}',]);
    targetSocket.sink.add(jsonEncode(message));
    /*targetSocket.sink.done.then((value) {
      var transferCompletedMessage = {
        'type': 'message',
        'user': sender.toJson(),
        'message': sm.message
      }
    });*/
  }

  static void notifyLoggedUsersToAll(){
    users.forEach((element) {
      notifyLoggedUserTo(element);
    });
  }

  static void notifyLoggedUserTo(User user){
    var message = {
      'type': SocketMessageTypes.userUpdate.index,
      'userCollection': users.map((e) => e.toJson()).toList()
    };
    print(['notify to',user.nickname, user.websocket.hashCode, message]);
    user.websocket.sink.add(jsonEncode(message));
  }

  static void userLogout(WebSocketChannel webSocket, User user) {
    int indexOf = users.isNotEmpty ? users.indexWhere((element) => element.nickname == user.nickname) : null;
    if(!(indexOf==null || indexOf == -1)) {
      users[indexOf].isOnline=false;
    }
    print(['logout', user.nickname, webSocket.hashCode]);
    notifyLoggedUsersToAll();
  }

}