import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:task_point/services/task_model.dart';

class AppwriteService {
  // ---------- Константы ----------
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';
  static const String projectId = '68f628940017cbb1a756';
  static const String databaseId = '68fbb16d000f676ccba9';
  static const String usersCollectionId = 'users';
  static const String avatarBucketId = '68ffb42300070f894c6c';
  static const String listsCollectionId = 'lists';
  static const String tasksCollectionId = 'tasks';
  static const String notificationsCollectionId = 'notifications';

  // ---------- Singleton ----------
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;

  AppwriteService._internal() {
    _initializeClient();
  }

  // ---------- Клиенты ----------
  final Client client = Client();
  late final Account account;
  late final Databases databases;
  late final Storage storage;

  void _initializeClient() {
    client.setEndpoint(endpoint).setProject(projectId);

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
  }

  void _ensureInitialized() {
    try {
      account.get();
    } catch (_) {
      print(
        '⚠️ Appwrite client не инициализирован, выполняется повторная инициализация...',
      );
      _initializeClient();
    }
  }

  // ---------- AUTH ----------
  Future<User?> registerAndReturnUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      print('✅ Пользователь зарегистрирован: ${user.$id}');
      return user;
    } on AppwriteException catch (e) {
      print('❌ Ошибка регистрации: ${e.message}');
      return null;
    }
  }

  Future<Session?> login({
    required String email,
    required String password,
  }) async {
    try {
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      print('✅ Вход выполнен');
      return session;
    } on AppwriteException catch (e) {
      print('❌ Ошибка входа: ${e.message}');
      return null;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      return await account.get();
    } on AppwriteException catch (e) {
      print('❌ Ошибка получения current user: ${e.message}');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await account.deleteSessions();
      print('✅ Выход выполнен');
    } on AppwriteException catch (e) {
      print('❌ Ошибка выхода: ${e.message}');
    }
  }

  // ---------- USERS ----------
  Future<bool> createUserDocument({
    required String userId,
    required String email,
    required String name,
  }) async {
    try {
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
        data: {
          'name': name,
          'email': email,
          'avatar_url': '',
          'team_contacts': <String>[],
          'tasks_assigned_count': 0,
        },
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
      print('✅ Документ пользователя создан');
      return true;
    } on AppwriteException catch (e) {
      print('❌ Ошибка создания пользователя: ${e.message}');
      return false;
    }
  }

  // ---------- PROFILE ----------
  Future<bool> updateUserProfile({
    required String userId,
    required String name,
    required String email,
    String? avatarUrl,
    String? currentPasswordForEmailChange,
  }) async {
    try {
      final dbData = {'name': name, 'email': email};
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        dbData['avatar_url'] = avatarUrl;
      }

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
        data: dbData,
      );

      try {
        await account.updateName(name: name);
      } on AppwriteException catch (e) {
        print('⚠️ Имя не обновлено: ${e.message}');
      }

      final currentAuthUser = await getCurrentUser();
      final authEmail = currentAuthUser?.email ?? '';
      if (email != authEmail) {
        if (currentPasswordForEmailChange == null ||
            currentPasswordForEmailChange.isEmpty) {
          print('⚠️ Для смены email нужен пароль');
          return false;
        }

        await account.updateEmail(
          email: email,
          password: currentPasswordForEmailChange,
        );
      }

      return true;
    } on AppwriteException catch (e) {
      print('❌ Ошибка профиля: ${e.message}');
      return false;
    }
  }

  // ---------- AVATAR ----------
  Future<String?> uploadAvatarFromBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final uploaded = await storage.createFile(
        bucketId: avatarBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: bytes, filename: filename),
      );

      final fileUrl =
          '$endpoint/storage/buckets/$avatarBucketId/files/${uploaded.$id}/view?project=$projectId';
      return fileUrl;
    } on AppwriteException catch (e) {
      print('❌ Ошибка загрузки аватарки: ${e.message}');
      return null;
    }
  }

  Future<bool> uploadAvatarAndSaveToUser({
    required String userId,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final uploaded = await storage.createFile(
        bucketId: avatarBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: bytes, filename: filename),
      );

      final fileUrl =
          '$endpoint/storage/buckets/$avatarBucketId/files/${uploaded.$id}/view?project=$projectId';

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
        data: {'avatar_url': fileUrl},
      );

      return true;
    } on AppwriteException catch (e) {
      print('❌ Ошибка аватарки: ${e.message}');
      return false;
    }
  }

  // ---------- LISTS ----------

  Future<List<Map<String, dynamic>>> getUserLists({
    required String userId,
  }) async {
    _ensureInitialized();

    try {
      final allLists = await getAllLists();

      final visibleLists = allLists.where((list) {
        final ownerId = list['owner_id'];
        final members = List<String>.from(list['members'] ?? []);
        final admins = List<String>.from(list['admins'] ?? []);

        return ownerId == userId ||
            members.contains(userId) ||
            admins.contains(userId);
      }).toList();

      print(
        '✅ Загружено списков для пользователя $userId: ${visibleLists.length}',
      );
      return visibleLists;
    } catch (e) {
      print('❌ Ошибка getUserLists: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllLists() async {
    _ensureInitialized();
    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: listsCollectionId,
      );

      return result.documents.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);
        return {
          'id': doc.$id,
          'name': data['name'] ?? '',
          'color': data['color'] ?? '#000000',
          'owner_id': data['owner_id'] ?? '',
          'members': List<String>.from(data['members'] ?? []),
          'admins': List<String>.from(data['admins'] ?? []),
        };
      }).toList();
    } catch (e) {
      print('❌ Ошибка при получении всех списков: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createList({
    required String userId,
    required String name,
    required String color,
  }) async {
    try {
      final doc = await databases.createDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: ID.unique(),
        data: {
          'name': name,
          'color': color,
          'owner_id': userId,
          'members': <String>[],
          'admins': <String>[],
        },
      );

      print('✅ Список успешно создан пользователем $userId');

      return {'id': doc.$id, 'name': name, 'color': color};
    } on AppwriteException catch (e) {
      print('❌ Ошибка при создании списка: ${e.message}');
      return null;
    }
  }

  Future<bool> updateList({
    required String listId,
    required String userId,
    required String name,
    required String color,
  }) async {
    _ensureInitialized();

    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      final ownerId = doc.data['owner_id'];
      if (ownerId != userId) {
        print('⛔ Нет прав на редактирование этого списка');
        return false;
      }

      final updatedData = <String, dynamic>{'name': name, 'color': color};

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
        data: updatedData,
      );

      print('✅ Список успешно обновлён');
      return true;
    } on AppwriteException catch (e) {
      print('❌ Ошибка при обновлении списка: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Неизвестная ошибка при обновлении списка: $e');
      return false;
    }
  }

  Future<bool> deleteList({
    required String listId,
    required String userId,
  }) async {
    _ensureInitialized();
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      final ownerId = doc.data['owner_id'];
      final admins = List<String>.from(doc.data['admins'] ?? []);

      if (ownerId != userId && !admins.contains(userId)) {
        print('⛔ У пользователя $userId нет прав на удаление списка $listId');
        return false;
      }

      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      print('✅ Список $listId успешно удалён пользователем $userId');
      return true;
    } on AppwriteException catch (e) {
      print('❌ Ошибка при удалении списка: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Непредвиденная ошибка при удалении списка: $e');
      return false;
    }
  }

  Future<bool> duplicateList({
    required String userId,
    required String name,
    required String color,
  }) async {
    _ensureInitialized();
    try {
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: ID.unique(),
        data: {'name': name, 'color': color, 'owner_id': userId},
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
      print('✅ Список успешно дублирован');
      return true;
    } on AppwriteException catch (e) {
      print('❌ Ошибка при дублировании списка: ${e.message}');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    await Future.delayed(const Duration(seconds: 3));

    try {
      final byName = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [Query.search('name', query)],
      );

      final byEmail = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [Query.search('email', query)],
      );

      final Map<String, Map<String, dynamic>> resultsMap = {};

      for (final doc in byName.documents) {
        final data = Map<String, dynamic>.from(doc.data);
        resultsMap[doc.$id] = {
          'id': doc.$id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'avatar_url': data['avatar_url'] ?? '',
        };
      }

      for (final doc in byEmail.documents) {
        if (!resultsMap.containsKey(doc.$id)) {
          final data = Map<String, dynamic>.from(doc.data);
          resultsMap[doc.$id] = {
            'id': doc.$id,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'avatar_url': data['avatar_url'] ?? '',
          };
        }
      }

      return resultsMap.values.toList();
    } catch (e) {
      print('❌ Ошибка поиска пользователей: $e');
      return [];
    }
  }

  Future<bool> addUserToTeamContacts({
    required String ownerId,
    required String contactId,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: ownerId,
      );

      final contacts = List<String>.from(doc.data['team_contacts'] ?? []);

      if (!contacts.contains(contactId)) {
        contacts.add(contactId);
      }

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: ownerId,
        data: {'team_contacts': contacts},
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchFullUser(String userId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
      );

      final data = Map<String, dynamic>.from(doc.data);

      return {
        'id': doc.$id,
        'name': data['name'] ?? '',
        'email': data['email'] ?? '',
        'avatar_url': data['avatar_url'] ?? '',
        'tasks_assigned_count': data['tasks_assigned_count'] ?? 0,
      };
    } on AppwriteException catch (e) {
      print('❌ Ошибка загрузки пользователя $userId: ${e.message}');
      return null;
    }
  }

  Future<bool> removeUserFromTeamContacts({
    required String ownerId,
    required String contactId,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: ownerId,
      );

      final contacts = List<String>.from(doc.data['team_contacts'] ?? []);
      if (!contacts.contains(contactId)) return true;

      contacts.remove(contactId);

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: ownerId,
        data: {'team_contacts': contacts},
      );

      print("✅ Контакт $contactId удалён из команды пользователя $ownerId");
      return true;
    } catch (e) {
      print("❌ Ошибка удаления: $e");
      return false;
    }
  }

  Future<int> getAssignedTasksCount(String userId) async {
    final res = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: tasksCollectionId,
      queries: [
        Query.equal('assigned_to', userId),
        Query.equal('is_done', false),
        Query.limit(1),
      ],
    );

    return res.total;
  }

  Future<List<Map<String, dynamic>>> getManageableLists() async {
    final current = await getCurrentUser();
    if (current == null) return [];

    final res = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: listsCollectionId,
      queries: [
        Query.or([
          Query.equal('owner_id', current.$id),
          Query.contains('admins', current.$id),
        ]),
      ],
    );

    return res.documents.map((d) {
      return {
        'id': d.$id,
        'title': d.data['title'] ?? d.data['name'] ?? 'Без названия',
        'owner_id': d.data['owner_id']?.toString(),
        'admins': List<String>.from(d.data['admins'] ?? []),
        'members': List<String>.from(d.data['members'] ?? []),
        'color': d.data['color'],
      };
    }).toList();
  }

  Future<bool> addUserToList({
    required String listId,
    required String userId,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      final members = List<String>.from(doc.data['members'] ?? []);

      if (members.contains(userId)) return true;

      members.add(userId);

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
        data: {'members': members},
      );

      return true;
    } catch (e) {
      print('❌ addUserToList error: $e');
      return false;
    }
  }

  Future<TaskModel> createTask(TaskModel task) async {
    try {
      final result = await databases.createDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: ID.unique(),
        data: task.toJson(),
      );

      return TaskModel.fromJson(result.data);
    } catch (e, st) {
      print("🔥 Appwrite createTask error: $e");
      print(st);
      rethrow;
    }
  }

  Future<void> updateTaskStatus({
    required String taskId,
    bool? isDone,
    bool? isImportant,
    String? executor,
  }) async {
    try {
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: taskId,
        data: {
          if (isDone != null) "is_done": isDone,
          if (isImportant != null) "is_important": isImportant,
          if (executor != null) "assigned_to": executor,
        },
      );
    } catch (e, st) {
      print("🔥 Appwrite updateTaskStatus error: $e");
      print(st);
      rethrow;
    }
  }

  Future<List<TaskModel>> getAllUserTasks(String userId) async {
    try {
      final userLists = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        queries: [Query.equal('owner_id', userId)],
      );

      if (userLists.documents.isEmpty) return [];

      final listIds = userLists.documents.map((d) => d.$id).toList();

      final tasksResult = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        queries: [Query.contains('list_id', listIds)],
      );

      return tasksResult.documents.map((doc) {
        final json = Map<String, dynamic>.from(doc.data);
        json['id'] = doc.$id;
        return TaskModel.fromJson(json);
      }).toList();
    } catch (e) {
      print("❌ Ошибка getAllUserTasks: $e");
      return [];
    }
  }

  Future<List<TaskModel>> getAllAccessibleTasks(String userId) async {
    _ensureInitialized();

    final allLists = await getAllLists();

    final Set<String> accessibleListIds = {};

    for (final list in allLists) {
      final ownerId = list['owner_id'];
      final members = List<String>.from(list['members'] ?? []);
      final admins = List<String>.from(list['admins'] ?? []);

      if (ownerId == userId ||
          members.contains(userId) ||
          admins.contains(userId)) {
        accessibleListIds.add(list['id']);
      }
    }

    if (accessibleListIds.isEmpty) return [];

    final tasksDocs = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: tasksCollectionId,
    );

    return tasksDocs.documents
        .map((doc) {
          final json = Map<String, dynamic>.from(doc.data);
          json['id'] = doc.$id;
          return TaskModel.fromJson(json);
        })
        .where(
          (task) =>
              task.listId != null && accessibleListIds.contains(task.listId),
        )
        .toList();
  }

  Future<TaskModel> updateTask(TaskModel task) async {
    try {
      final response = await databases.updateDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: task.id,
        data: {
          'invoice_number': task.invoice,
          'company_name': task.company,
          'products': task.products,
          'delivery_date': task.date,
          'address': task.address,
          'assigned_to': task.executor,
          'reminder_time': task.reminder,
          'comments': task.comment,
        },
      );

      return TaskModel.fromJson(response.data);
    } on AppwriteException catch (e) {
      print('❌ Ошибка обновления задачи: ${e.message}');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: taskId,
      );
    } catch (e) {
      print("Ошибка удаления задачи: $e");
      rethrow;
    }
  }

  Future<void> moveTask({
    required String taskId,
    required String targetListId,
  }) async {
    _ensureInitialized();

    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: taskId,
      );
      final data = Map<String, dynamic>.from(doc.data);

      data['list_id'] = targetListId;

      await databases.createDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: ID.unique(),
        data: data,
      );

      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: taskId,
      );

      print("✅ Задача перемещена (создана и удалена) в список $targetListId");
    } on AppwriteException catch (e) {
      print("❌ Ошибка moveTask: ${e.message}");
    } catch (e) {
      print("❌ Неизвестная ошибка moveTask: $e");
    }
  }

  Future<void> duplicateTask({
    required String taskId,
    required String targetListId,
  }) async {
    _ensureInitialized();

    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: taskId,
      );

      final data = Map<String, dynamic>.from(doc.data);

      data.removeWhere((key, value) => key.startsWith('\$'));

      data['list_id'] = targetListId;

      await databases.createDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: ID.unique(),
        data: data,
      );

      print("✅ Задача успешно дублирована в список $targetListId");
    } on AppwriteException catch (e) {
      print("❌ Ошибка duplicateTask: ${e.message}");
    } catch (e) {
      print("❌ Неизвестная ошибка при дублировании: $e");
    }
  }

  Future<bool> addMemberToList({
    required String listId,
    required String memberId,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      final members = List<String>.from(doc.data['members'] ?? []);
      if (!members.contains(memberId)) members.add(memberId);

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
        data: {'members': members},
      );

      await addUserListReference(memberId: memberId, listDoc: doc);

      print('✅ Участник $memberId добавлен в список $listId');
      return true;
    } catch (e) {
      print('❌ Ошибка добавления участника в список: $e');
      return false;
    }
  }

  Future<void> addUserListReference({
    required String memberId,
    required Document listDoc,
  }) async {}

  Future<List<String>> getAllCompaniesForUser(String userId) async {
    try {
      final allLists = await getAllLists();

      final userLists = allLists.where((list) {
        final ownerId = list['owner_id'];
        final members = List<String>.from(list['members'] ?? []);
        return ownerId == userId || members.contains(userId);
      }).toList();

      if (userLists.isEmpty) return [];

      final Set<String> companies = {};

      for (var list in userLists) {
        final listId = list['id'];

        final tasksResult = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: tasksCollectionId,
          queries: [Query.equal('list_id', listId)],
        );

        for (final doc in tasksResult.documents) {
          final data = Map<String, dynamic>.from(doc.data);
          final company = data['company_name'];

          if (company is String && company.trim().isNotEmpty) {
            companies.add(company.trim());
          }
        }
      }

      return companies.toList();
    } catch (e) {
      print('❌ Ошибка getAllCompaniesForUser: $e');
      return [];
    }
  }

  Future<void> removeMemberFromList({
    required String listId,
    required String memberId,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      final data = Map<String, dynamic>.from(doc.data);
      final members = List<String>.from(data['members'] ?? []);

      members.remove(memberId);

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
        data: {'members': members},
      );

      print('✅ Участник $memberId удалён из списка $listId');
    } catch (e) {
      print("❌ Ошибка при удалении участника из списка: $e");
      rethrow;
    }
  }

  Future<void> clearAssigneeFromTasks({
    required String listId,
    required String userId,
  }) async {
    final tasks = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: tasksCollectionId,
      queries: [Query.equal('list_id', listId)],
    );

    for (final task in tasks.documents) {
      final assignedTo = task.data['assigned_to'];

      if (assignedTo == userId) {
        await databases.updateDocument(
          databaseId: databaseId,
          collectionId: tasksCollectionId,
          documentId: task.$id,
          data: {'assigned_to': null},
        );
      }
    }
  }

  Future<void> promoteMemberToAdmin({
    required String listId,
    required String userId,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      final data = Map<String, dynamic>.from(doc.data);

      final members = List<String>.from(data['members'] ?? []);
      final admins = List<String>.from(data['admins'] ?? []);

      members.remove(userId);

      if (!admins.contains(userId)) {
        admins.add(userId);
      }

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
        data: {'members': members, 'admins': admins},
      );

      print('✅ Пользователь $userId назначен администратором списка $listId');
    } catch (e) {
      print('❌ Ошибка назначения администратора: $e');
      rethrow;
    }
  }

  Future<bool> removeAdminFromList({
    required String listId,
    required String userId,
  }) async {
    try {
      final listDoc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      final data = Map<String, dynamic>.from(listDoc.data);
      final admins = List<String>.from(data['admins'] ?? []);

      admins.remove(userId);

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
        data: {'admins': admins},
      );

      return true;
    } catch (e) {
      print('Ошибка при удалении администратора: $e');
      return false;
    }
  }

  Future<bool> demoteAdminToMember({
    required String listId,
    required String userId,
  }) async {
    try {
      final doc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
      );

      List<String> admins = List<String>.from(doc.data['admins'] ?? []);
      List<String> members = List<String>.from(doc.data['members'] ?? []);

      admins.remove(userId);

      if (!members.contains(userId)) {
        members.add(userId);
      }

      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: listsCollectionId,
        documentId: listId,
        data: {'admins': admins, 'members': members},
      );

      return true;
    } catch (e) {
      print("Ошибка при понижении администратора: $e");
      return false;
    }
  }

  Future<String?> getTaskAssigner(String taskId) async {
    final result = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: notificationsCollectionId,
      queries: [
        Query.equal('task_id', taskId),
        Query.equal('type', 'task_assigned'),
        Query.orderDesc('\$createdAt'),
        Query.limit(1),
      ],
    );

    if (result.documents.isEmpty) return null;

    return result.documents.first.data['sender_id'] as String?;
  }

  Future<Map<String, String>> getUserNamesByIds(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final result = await databases.listDocuments(
      databaseId: AppwriteService.databaseId,
      collectionId: 'users',
      queries: [Query.equal('\$id', userIds)],
    );

    return {
      for (final doc in result.documents)
        doc.$id: doc.data['name'] as String? ?? 'Пользователь',
    };
  }

  /// Получение email пользователя по его userId
  Future<String?> getUserEmailById(String userId) async {
    try {
      final userDoc = await databases.getDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
      );

      final data = Map<String, dynamic>.from(userDoc.data);
      final email = data['email'] as String?;
      return email;
    } catch (e) {
      print('❌ Ошибка получения email пользователя $userId: $e');
      return null;
    }
  }

  Future<int> getActiveTasksCount({
    String? listId,
    String? userId,
    List<String>? adminListIds,
    bool isImportant = false,
    bool isAssigned = false,
  }) async {
    try {
      List<String> queries = [Query.equal('is_done', false)];

      if (listId != null) {
        queries.add(Query.equal('list_id', listId));
      }

      if (isImportant) {
        queries.add(Query.equal('is_important', true));
      }

      if (userId != null) {
        if (isAssigned) {
          queries.add(Query.equal('assigned_to', userId));
        } else if (listId == null) {
          List<String> orConditions = [Query.equal('assigned_to', userId)];

          if (adminListIds != null && adminListIds.isNotEmpty) {
            orConditions.add(Query.equal('list_id', adminListIds));
          }
          queries.add(Query.or(orConditions));
        }
      }

      final result = await databases.listDocuments(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.tasksCollectionId,
        queries: queries,
      );

      return result.total;
    } catch (e) {
      debugPrint('❌ Ошибка при подсчете задач: $e');
      return 0;
    }
  }
}
