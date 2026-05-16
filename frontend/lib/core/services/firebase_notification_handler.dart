import 'package:firebase_messaging/firebase_messaging.dart';

/// Background message handler — called when app is in background or terminated
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 [Background] Received FCM message: ${message.messageId}');
  print('🔔 [Background] Title: ${message.notification?.title}');
  print('🔔 [Background] Body: ${message.notification?.body}');
}

/// Initialize Firebase notifications handlers
Future<void> setupFirebaseNotifications() async {
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Handle foreground messages (when app is open)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('🔔 [Foreground] Received FCM message: ${message.messageId}');
    print('🔔 [Foreground] Title: ${message.notification?.title}');
    print('🔔 [Foreground] Body: ${message.notification?.body}');
    print('🔔 [Foreground] Data: ${message.data}');
  });

  // Handle notification tap (when user clicks the notification)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🔔 [Tap] User tapped notification: ${message.messageId}');
    print('🔔 [Tap] Title: ${message.notification?.title}');
    print('🔔 [Tap] Body: ${message.notification?.body}');
  });

  // Get initial message (if app was opened from notification while closed)
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print(
      '🔔 [Init] App opened from notification: ${initialMessage.messageId}',
    );
  }
}
