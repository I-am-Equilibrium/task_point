import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/notification_model.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final String senderName;

  const NotificationCard({
    Key? key,
    required this.notification,
    required this.senderName,
  }) : super(key: key);

  Color _getRandomAvatarColor(String seed) {
    final colors = [
      AppColors.lavendar,
      AppColors.skyBlue,
      AppColors.green,
      AppColors.cheese,
      AppColors.red,
    ];
    return colors[seed.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(notification.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
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
                _Avatar(
                  avatarUrl: notification.senderAvatarUrl,
                  name: senderName,
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  notification.isRead ? 'seen' : 'new',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: notification.isRead
                        ? AppColors.grey
                        : AppColors.skyBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

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
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;

  const _Avatar({required this.avatarUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }

    final color = [
      AppColors.lavendar,
      AppColors.skyBlue,
      AppColors.green,
      AppColors.cheese,
      AppColors.red,
    ][name.hashCode % 5];

    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
    );
  }
}
