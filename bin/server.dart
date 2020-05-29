import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chat/char_service.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
const _hostname = 'localhost';

enum SocketMessageTypes {
  login,
  logout,
  userUpdate,
  message,
  received
}

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



  var handler = webSocketHandler((WebSocketChannel webSocket) {
    webSocket.stream.listen((message) {
      var sm = SocketMessage.fromJson(jsonDecode(message) as Map<String, dynamic>);
      var received = {
        'type':SocketMessageTypes.received.index,
        'responseForType': sm.type.index
      };
      webSocket.sink.add(jsonEncode(received));
      if(sm!=null) {
        switch (sm.type) {
          case SocketMessageTypes.login: {
            ChatService.userLogin(webSocket, sm.user);
          }break;
          case SocketMessageTypes.message: {
            ChatService.sendMessage(webSocket, sm);
          }break;
          case SocketMessageTypes.userUpdate:
            // TODO: Handle this case.
            break;
          case SocketMessageTypes.received:
            // TODO: Handle this case.
            break;
          case SocketMessageTypes.logout:
            // TODO: Handle this case.
            ChatService.userLogout(webSocket, sm.user);
            break;
        }
      }else {
        print(message);
        //webSocket.sink.add('unable to parse message');
      }
    });
    Timer.periodic(Duration(seconds: 5), (timer) {
      ChatService.notifyLoggedUsersToAll();
    });
  }
  );

  await io.serve(handler, '127.0.0.1', 8080).then((server) {
    print('Serving at ws://${server.address.host}:${server.port}');
  });
}

shelf.Response _echoRequest(shelf.Request request) =>
    shelf.Response.ok('Request for "${request.url}"');

class User {
    WebSocketChannel websocket;
    String nickname;
    int port;
    bool isOnline;

    User({this.nickname, this.isOnline});

    factory User.fromJson(Map<String, dynamic> json) {
        return User(
          nickname: json['nickname'],
          isOnline: json['isOnline'] as bool,
        );
    }

    Map<String, dynamic> toJson() {
        final Map<String, dynamic> data = new Map<String, dynamic>();
        data['nickname'] = nickname;
        data['isOnline'] = isOnline;
        return data;
    }
}

class SocketMessage {
    SocketMessageTypes type;
    User user;
    String message;
    WebSocketChannel channel;
    SocketMessage({this.type, this.user, this.message, this.channel});

    factory SocketMessage.fromJson(Map<String, dynamic> json) {
      print(json);
      switch (SocketMessageTypes.values[json['type']]){
        case SocketMessageTypes.logout:
        case SocketMessageTypes.login: return SocketMessage.fromLoginJson(json);
        case SocketMessageTypes.message: return SocketMessage.fromMessageJson(json);
        default: return null;
      }
    }

    factory SocketMessage.fromLoginJson(Map<String, dynamic> json){
      return SocketMessage(
          type: SocketMessageTypes.values[json['type']],
          channel: json['channel'],
          user: User.fromJson(json['user'] as Map<String, dynamic>)
      );
    }

    factory SocketMessage.fromMessageJson(Map<String, dynamic> json){
      print([json['message'], json['type'], json['target']]);
      var sm = SocketMessage(
          type: SocketMessageTypes.values[json['type']],
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