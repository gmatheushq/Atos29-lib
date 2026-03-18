import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ignore: avoid_print
  print('BG MESSAGE: ${message.messageId} data=${message.data}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  bool _refreshListenerAttached = false;
  bool _tapSetupAttached = false;

  void Function(Map<String, dynamic>)? _onTap;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _fcm.setAutoInitEnabled(true);

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ignore: avoid_print
    print('NOTIF PERMISSION: ${settings.authorizationStatus}');

    // Foreground (só log)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // ignore: avoid_print
      print('FG MESSAGE: ${message.messageId} '
          'title=${message.notification?.title} '
          'body=${message.notification?.body} '
          'data=${message.data}');
    });
  }

  Future<void> setupOnNotificationTap(void Function(Map<String, dynamic>) onTap) async {
    _onTap = onTap;

    if (_tapSetupAttached) return;
    _tapSetupAttached = true;

    final initialMsg = await _fcm.getInitialMessage();
    if (initialMsg != null) {
      // ignore: avoid_print
      print('INITIAL FROM NOTIF: data=${initialMsg.data}');
      _onTap?.call(Map<String, dynamic>.from(initialMsg.data));
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // ignore: avoid_print
      print('OPENED FROM NOTIF: data=${message.data}');
      _onTap?.call(Map<String, dynamic>.from(message.data));
    });
  }

  Future<String?> getToken() => _fcm.getToken();

  Future<void> syncTokenToUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  void listenTokenRefresh() {
    if (_refreshListenerAttached) return;
    _refreshListenerAttached = true;

    _fcm.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': newToken,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> syncTopicSubscriptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    final role = (data['role'] ?? 'user').toString().trim().toLowerCase();
    final isVerified = user.emailVerified == true;

    if (isVerified) {
      await _fcm.subscribeToTopic('all');
      await _fcm.unsubscribeFromTopic('pending');
    } else {
      await _fcm.unsubscribeFromTopic('all');
      await _fcm.subscribeToTopic('pending');
    }

    final isAdmin = role == 'owner' || role == 'admin';
    if (isAdmin) {
      await _fcm.subscribeToTopic('admins');
    } else {
      await _fcm.unsubscribeFromTopic('admins');
    }

    // ignore: avoid_print
    print('TOPICS OK: role=$role verified=$isVerified');
  }
}
