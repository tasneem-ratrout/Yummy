import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChefSocketService {
  static late IO.Socket socket;

  static void connect(String chefId) {
    socket = IO.io(
      'http://10.0.2.2:5000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print("✅ Socket Connected");

      socket.emit("joinChefRoom", chefId);
    });

    socket.onDisconnect((_) {
      print("❌ Socket Disconnected");
    });
  }

  static void disconnect() {
    socket.disconnect();
  }
}
