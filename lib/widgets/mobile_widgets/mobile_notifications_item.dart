import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/router/app_router.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';
import 'package:task_point/services/notification_model.dart';
import 'package:task_point/utils/mobile_utils/mobile_notification_card.dart';

class MobileNotificationsItem extends StatefulWidget {
  const MobileNotificationsItem({super.key});

  @override
  State<MobileNotificationsItem> createState() =>
      _MobileNotificationsItemState();
}

class _MobileNotificationsItemState extends State<MobileNotificationsItem> {
  final NotificationsService _notificationsService = NotificationsService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  final Map<String, Map<String, String?>> _usersCache = {};

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final user = authState.currentUser;
    if (user == null) return;

    try {
      final data = await _notificationsService.getNotifications(user.$id);
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, String?>> _getSenderData(String senderId) async {
    if (_usersCache.containsKey(senderId)) {
      return _usersCache[senderId]!;
    }

    try {
      final doc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.usersCollectionId,
        documentId: senderId,
      );

      final data = {
        'name': doc.data['name'] as String? ?? 'Пользователь',
        'avatar_url': doc.data['avatar_url'] as String?,
      };

      _usersCache[senderId] = data;
      return data;
    } catch (e) {
      return {'name': 'Пользователь', 'avatar_url': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Уведомления',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.skyBlue),
            )
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: AppColors.skyBlue,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 15, bottom: 55),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final n = _notifications[index];

                  return FutureBuilder<Map<String, String?>>(
                    future: _getSenderData(n.senderId),
                    builder: (context, snapshot) {
                      final senderName =
                          snapshot.data?['name'] ?? 'Загрузка...';
                      final senderAvatar = snapshot.data?['avatar_url'];

                      return MobileNotificationCard(
                        notification: n,
                        senderName: senderName,
                        senderAvatarUrl: senderAvatar,
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 64,
            color: AppColors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'У вас пока нет уведомлений',
            style: TextStyle(color: AppColors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
