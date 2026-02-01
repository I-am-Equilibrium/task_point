import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/notifications_service.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/utils/notification_card.dart';
import 'package:task_point/services/notification_model.dart';

class NotificationsItem extends StatefulWidget {
  final VoidCallback onClose;

  const NotificationsItem({Key? key, required this.onClose}) : super(key: key);

  @override
  State<NotificationsItem> createState() => _NotificationsItemState();
}

class _NotificationsItemState extends State<NotificationsItem> {
  late Future<List<NotificationModel>> _notificationsFuture;
  final _service = NotificationsService();

  Map<String, String> _senderNames = {};

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<NotificationModel>> _loadNotifications() async {
    final user = await AppwriteService().account.get();
    final notifications = await _service.getNotifications(user.$id);

    final senderIds = notifications.map((n) => n.senderId).toSet().toList();

    _senderNames = await AppwriteService().getUserNamesByIds(senderIds);

    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.darkWhite,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(-4, 2),
            blurRadius: 20,
            color: AppColors.black.withOpacity(0.15),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Header(onClose: widget.onClose),
          ),

          Expanded(
            child: FutureBuilder<List<NotificationModel>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Уведомлений пока нет',
                      style: TextStyle(fontSize: 14, color: AppColors.grey),
                    ),
                  );
                }

                final notifications = snapshot.data!;

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];

                    final senderName =
                        _senderNames[notification.senderId] ?? 'Пользователь';

                    return NotificationCard(
                      notification: notification,
                      senderName: senderName,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          const SizedBox(width: 15),
          GestureDetector(
            onTap: onClose,
            child: Image.asset(
              'assets/icons/close.png',
              width: 24,
              height: 24,
              color: AppColors.black,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Center(
              child: Text(
                'Уведомления',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 39),
        ],
      ),
    );
  }
}
