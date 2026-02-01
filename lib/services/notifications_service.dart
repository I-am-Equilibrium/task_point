import 'package:task_point/services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';
import 'package:task_point/services/notification_model.dart';
import 'dart:convert';

class NotificationsService {
  final Databases _databases = AppwriteService().databases;
  // Инициализируем сервис функций через ваш AppwriteService
  final Functions _functions = Functions(AppwriteService().client);

  final String _notificationsCollectionId = 'notifications';
  final AppwriteService _appwriteService = AppwriteService();

  /// Создание уведомления и отправка email пользователю
  Future<void> createNotification({
    String? listId,
    String? taskId,
    required String senderId,
    required String receiverId,
    String? senderAvatarUrl,
    required String text,
    required String type,
  }) async {
    try {
      await _databases.createDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: _notificationsCollectionId,
        documentId: ID.unique(),
        data: {
          'list_id': listId ?? '',
          'task_id': taskId ?? '',
          'sender_id': senderId,
          'receiver_id': receiverId,
          'sender_avatar_url': senderAvatarUrl ?? '',
          'text': text,
          'is_read': false,
          'type': type,
        },
      );
      print('✅ Уведомление создано в базе');

      final email = await _appwriteService.getUserEmailById(receiverId);
      if (email == null || email.isEmpty) {
        print(
          '⚠️ У пользователя $receiverId нет email, пропуск отправки письма',
        );
        return;
      }

      final emailBody =
          '''
<div style="font-family: Arial, sans-serif;">
  <h2>Новое уведомление</h2>
  <p>$text</p>
</div>
''';

      final Map<String, dynamic> payload = {
        'receiverEmail': email,
        'subject': 'Новое уведомление на TaskPoint',
        'body': emailBody,
      };

      final execution = await _functions.createExecution(
        functionId: '6963a0dd0026e64db19b',
        body: jsonEncode(payload),
        xasync: false,
      );

      if (execution.status == 'completed') {
        print('✅ Email успешно отправлен. Ответ: ${execution.responseBody}');
      } else {
        print(
          '❌ Ошибка выполнения функции. Статус: ${execution.status}, Ошибка: ${execution.errors}',
        );
      }
    } catch (e) {
      print('❌ Ошибка в createNotification: $e');
    }
  }

  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: _notificationsCollectionId,
        queries: [
          Query.equal('receiver_id', userId),
          Query.orderDesc('\$createdAt'),
        ],
      );

      return result.documents
          .map((doc) => NotificationModel.fromMap(doc.data, doc.$id))
          .toList();
    } catch (e) {
      print('❌ Ошибка при загрузке уведомлений: $e');
      return [];
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final result = await _databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: _notificationsCollectionId,
        queries: [
          Query.equal('receiver_id', userId),
          Query.equal('is_read', false),
        ],
      );

      for (final doc in result.documents) {
        await _databases.updateDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: _notificationsCollectionId,
          documentId: doc.$id,
          data: {'is_read': true},
        );
      }
      print('✅ Уведомления помечены как прочитанные');
    } catch (e) {
      print('❌ Ошибка при пометке уведомлений: $e');
    }
  }
}
