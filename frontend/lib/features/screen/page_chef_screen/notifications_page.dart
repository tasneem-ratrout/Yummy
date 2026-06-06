import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  bool _isWebLayout(BuildContext context) {
    return kIsWeb && MediaQuery.of(context).size.width >= 900;
  }

  Future<void> loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/notifications/my-notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(res.body);

      if (!mounted) return;

      setState(() {
        notifications = data['notifications'] ?? [];
        loading = false;
      });
    } catch (e) {
      print(e);

      if (!mounted) return;

      setState(() => loading = false);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      await http.patch(
        Uri.parse('${AppConfig.baseUrl}/notifications/read/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      setState(() {
        notifications.removeWhere((n) => n['_id'] == id);
      });
    } catch (e) {
      print(e);
    }
  }

  IconData getIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'recipe_review':
        return Icons.restaurant_menu_rounded;
      case 'order_status':
        return Icons.delivery_dining_rounded;
      case 'global':
        return Icons.notifications_active;
      default:
        return Icons.notifications;
    }
  }

  Color getColor(String type) {
    switch (type) {
      case 'order':
        return Colors.orange;
      case 'review':
        return Colors.amber;
      case 'recipe_review':
        return Colors.green;
      case 'order_status':
        return Colors.blue;
      case 'global':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = _isWebLayout(context);

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? const Center(
                  child: Text(
                    'No notifications yet 🔔',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadNotifications,
                  child: isWeb
                      ? GridView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: notifications.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 520,
                                mainAxisExtent: 150,
                                crossAxisSpacing: 18,
                                mainAxisSpacing: 18,
                              ),
                          itemBuilder: (context, index) {
                            return _notificationCard(notifications[index]);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            return _notificationCard(
                              notifications[index],
                              isMobile: true,
                            );
                          },
                        ),
                ),
        ),
      ),
    );
  }

  Widget _notificationCard(dynamic n, {bool isMobile = false}) {
    final type = n['type'] ?? '';
    final color = getColor(type);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        await markAsRead(n['_id']);
      },
      child: Container(
        margin: isMobile ? const EdgeInsets.only(bottom: 14) : EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(getIcon(type), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n['body'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Spacer(),
                  if ((n['actorName'] ?? '').toString().isNotEmpty)
                    Text(
                      n['actorName'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
