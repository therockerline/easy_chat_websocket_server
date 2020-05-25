import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
const _hostname = 'localhost';
List<User> users = [];

void main(List<String> args) async {
  var parser = ArgParser()..addOption('port', abbr: 'p');
  var result = parser.parse(args);

  // For Google Cloud Run, we respect the PORT environment variable
  var portStr = result['port'] ?? Platform.environment['PORT'] ?? '8080';
  var port = int.tryParse(portStr);


  if (port == null) {
    stdout.writeln('Could not parse port value "$portStr" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }


  /*var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(_echoRequest);

  var server = await io.serve(handler, _hostname, port);
  print('Serving at http://${server.address.host}:${server.port}');
*/



  var handler = webSocketHandler((webSocket) {
    webSocket.stream.listen((message) {
      //webSocket.sink.add(message);
      var sm = SocketMessage.fromJson(jsonDecode(message) as Map<String, dynamic>);
      if(sm!=null) {
        switch (sm.type) {
          case 'login': {
            sm.user.websocket = webSocket;
            users.add(sm.user);
            Future.delayed(Duration(seconds: 3), () {
              users.remove(sm.user);
              notifyNewUser();
            });
            notifyNewUser();
          }break;
          case 'message': {
            var socket = users.firstWhere((element) => element.nickname == sm.user.nickname).websocket;
            var from = users.firstWhere((element) => element.websocket == webSocket);
            sm.user = from;
            var message = {
              'type': 'message',
              'user': from.toJson(),
              'message': sm.message
            };
            socket.sink.add(jsonEncode(message));
          }break;
        }
      }else {
        print(message);
        //webSocket.sink.add('unable to parse message');
      }
    });
  },pingInterval: Duration(milliseconds: 1000));

  await io.serve(handler, 'localhost', 8080).then((server) {
    print('Serving at ws://${server.address.host}:${server.port}');
  });
}

void notifyNewUser() {
  var message = {
    'type': 'userUpdate',
    'userCollection': users.map((e) => e.toJson()).toList()
  };
  users.forEach((element) {
    element.websocket.sink.add(jsonEncode(message));
  });
}

shelf.Response _echoRequest(shelf.Request request) =>
    shelf.Response.ok('Request for "${request.url}"');

class User {
    dynamic websocket;
    String nickname;
    int port;

    User({this.nickname, this.port});

    factory User.fromJson(Map<String, dynamic> json) {
        return User(
            nickname: json['nickname'],
            port: json['port'],
        );
    }

    Map<String, dynamic> toJson() {
        final Map<String, dynamic> data = new Map<String, dynamic>();
        data['nickname'] = this.nickname;
        data['port'] = this.port;
        return data;
    }
}

class SocketMessage {
    String type;
    User user;
    String message;
    SocketMessage({this.type, this.user, this.message});

    factory SocketMessage.fromJson(Map<String, dynamic> json) {
      print(json);
      switch (json['type'] as String){
        case 'login': return SocketMessage.fromLoginJson(json);
        case 'message': return SocketMessage.fromMessageJson(json);
        default: return null;
      }
    }

    factory SocketMessage.fromLoginJson(Map<String, dynamic> json){
      return SocketMessage(
          type: json['type'],
          user: User.fromJson(json['user'] as Map<String, dynamic>)
      );
    }

    factory SocketMessage.fromMessageJson(Map<String, dynamic> json){
      print([json['message'], json['type'], json['target']]);
      var sm = SocketMessage(
          type: json['type'],
          message: json['message'],
          user: User.fromJson(json['target'] as Map<String, dynamic>),
      );
      print(sm.message);
      return sm;
    }

    Map<String, dynamic> toJson() {
        final Map<String, dynamic> data = Map<String, dynamic>();
        data['type'] = type;
        return data;
    }
}