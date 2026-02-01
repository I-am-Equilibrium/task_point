import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/notification_model.dart';

class MobileNotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final String senderName;
  final String? senderAvatarUrl;

  const MobileNotificationCard({
    super.key,
    required this.notification,
    required this.senderName,
    this.senderAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(notification.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 20,
            color: AppColors.black.withOpacity(0.15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(senderName, senderAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      createdAt,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                notification.isRead ? 'seen' : 'new',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: notification.isRead
                      ? AppColors.grey
                      : AppColors.skyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            notification.text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, String? url) {
    final bool hasImage = url != null && url.isNotEmpty;
    final List<Color> randomColors = [
      AppColors.lavendar,
      AppColors.skyBlue,
      AppColors.green,
      AppColors.cheese,
      AppColors.red,
    ];
    final Color randomBgColor =
        randomColors[name.hashCode % randomColors.length];

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? Colors.transparent : randomBgColor,
        image: hasImage
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: !hasImage
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            )
          : null,
    );
  }
}
