import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../server.dart';

class ChatService{
  static List<User> users = [];

  static void userLogin(WebSocketChannel webSocket, User user){
    user.websocket = webSocket;
    int indexOf = users.isNotEmpty ? users.indexWhere((element) => element.nickname == user.nickname) : null;
    if(indexOf==null || indexOf == -1) {
      users.add(user);
    }else{
      users[indexOf].websocket = webSocket;
    }
    print(['login', user.nickname, webSocket.hashCode]);
    notifyNewUserConnection();
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

  static void notifyNewUserConnection(){
    var message = {
      'type': SocketMessageTypes.userUpdate.index,
      'userCollection': users.map((e) => e.toJson()).toList()
    };
    users.forEach((element) {
      print(['notify to',element.nickname, element.websocket.hashCode, message]);
      element.websocket.sink.add(jsonEncode(message));
    });
  }

}