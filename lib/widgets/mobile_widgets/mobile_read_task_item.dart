import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../services/appwrite_service.dart';
import '../../services/notifications_service.dart';
import '../../widgets/mobile_widgets/mobile_russian_calendar.dart';
import '../../widgets/mobile_widgets/mobile_alarm_item.dart';
import '../../services/task_model.dart';

class MobileReadTaskScreen extends StatefulWidget {
  final TaskModel task;
  final Color listColor;
  final String currentUserId;
  final Function(TaskModel) onTaskUpdated;
  final VoidCallback onTaskDeleted;
  final bool isReadOnly;
  final bool showGoToTaskButton;
  final VoidCallback? onNavigateToOriginalList;

  const MobileReadTaskScreen({
    super.key,
    required this.task,
    required this.listColor,
    required this.currentUserId,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
    this.isReadOnly = false,
    this.showGoToTaskButton = false,
    this.onNavigateToOriginalList,
  });

  @override
  State<MobileReadTaskScreen> createState() => _MobileReadTaskScreenState();
}

class _MobileReadTaskScreenState extends State<MobileReadTaskScreen> {
  late TextEditingController _invoiceController;
  late TextEditingController _utdController;
  late TextEditingController _companyController;
  late TextEditingController _productsController;
  late TextEditingController _dateController;
  late TextEditingController _addressController;
  late TextEditingController _executorController;
  late TextEditingController _reminderController;
  late TextEditingController _commentController;

  bool _isAdmin = false;

  DateTime? _selectedDate;
  DateTime? _selectedReminderDate;
  String? _selectedExecutorId;
  String? _previousExecutorId;
  List<Map<String, dynamic>> _listParticipants = [];

  final LayerLink _companyFieldLink = LayerLink();
  OverlayEntry? _companyOverlay;
  List<String> _allCompanies = [];
  List<String> _filteredCompanies = [];

  @override
  void initState() {
    super.initState();

    _invoiceController = TextEditingController(text: widget.task.invoice ?? "");
    _utdController = TextEditingController(text: widget.task.utd ?? "");
    _companyController = TextEditingController(text: widget.task.company ?? "");
    _productsController = TextEditingController(
      text: widget.task.products ?? "",
    );
    _addressController = TextEditingController(text: widget.task.address ?? "");
    _commentController = TextEditingController(text: widget.task.comment ?? "");
    _executorController = TextEditingController(text: "Загрузка...");

    if (widget.task.date != null && widget.task.date!.isNotEmpty) {
      _selectedDate = DateTime.parse(widget.task.date!);
      _dateController = TextEditingController(
        text: DateFormat('dd.MM.yyyy').format(_selectedDate!),
      );
    } else {
      _dateController = TextEditingController();
    }

    if (widget.task.reminder != null && widget.task.reminder!.isNotEmpty) {
      _selectedReminderDate = DateTime.parse(widget.task.reminder!);
      _reminderController = TextEditingController(
        text:
            "${DateFormat('dd.MM.yyyy').format(_selectedReminderDate!)} в ${DateFormat('HH:mm').format(_selectedReminderDate!)}",
      );
    } else {
      _reminderController = TextEditingController();
    }

    _selectedExecutorId = widget.task.executor;
    _previousExecutorId = widget.task.executor;

    _loadParticipants();
    _loadCompanies();
  }

  Future<void> _deleteTask() async {
    try {
      if (widget.task.id != null) {
        await AppwriteService().deleteTask(widget.task.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Задача успешно удалена")),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Error deleting task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка при удалении задачи")),
        );
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: const Text("Удаление задачи"),
          content: const Text("Вы уверены, что хотите удалить эту задачу?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Отмена",
                style: TextStyle(color: AppColors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteTask();
              },
              child: const Text(
                "Удалить",
                style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadCompanies() async {
    try {
      final user = await AppwriteService().getCurrentUser();
      if (user != null) {
        final companies = await AppwriteService().getAllCompaniesForUser(
          user.$id,
        );
        setState(() {
          _allCompanies = companies
              .where((c) => c.trim().isNotEmpty)
              .toSet()
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading companies: $e");
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final currentListId = widget.task.listId;

      final listDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: currentListId,
      );

      final listData = Map<String, dynamic>.from(listDoc.data);
      final ownerId = listData['owner_id'];
      final membersRaw = List<String>.from(listData['members'] ?? []);
      final adminsRaw = List<String>.from(listData['admins'] ?? []);

      bool isAdminOrOwner =
          ownerId == widget.currentUserId ||
          adminsRaw.contains(widget.currentUserId);

      final Set<String> allUserIds = {
        if (ownerId != null) ownerId,
        ...membersRaw,
        ...adminsRaw,
      };

      List<Map<String, dynamic>> loaded = [];
      for (var id in allUserIds) {
        final user = await AppwriteService().fetchFullUser(id);
        if (user != null) {
          loaded.add({
            "id": user["id"],
            "name": user["name"],
            "avatar_url": user["avatar_url"],
          });
        }
      }

      if (mounted) {
        setState(() {
          _listParticipants = loaded;

          if (widget.isReadOnly) {
            _isAdmin = false;
          } else {
            _isAdmin = isAdminOrOwner;
          }

          if (_selectedExecutorId != null && _selectedExecutorId!.isNotEmpty) {
            final executor = _listParticipants.firstWhere(
              (u) => u['id'] == _selectedExecutorId,
              orElse: () => {'name': 'Неизвестный'},
            );
            _executorController.text = executor['name'];
          } else {
            _executorController.text = "";
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading participants: $e");
      if (mounted) {
        setState(() => _executorController.text = "");
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getAvailableLists() async {
    try {
      final manageableLists = await AppwriteService().getManageableLists();
      return manageableLists;
    } catch (e) {
      debugPrint("Error fetching lists: $e");
      return [];
    }
  }

  void _showListSelectionDialog({required bool isMove}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    final allLists = await _getAvailableLists();
    Navigator.pop(context);

    if (!mounted) return;

    final filteredLists = allLists.where((list) {
      if (isMove && list['id'] == widget.task.listId) {
        return false;
      }
      return true;
    }).toList();

    if (filteredLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Нет доступных списков для действия")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text(
            isMove ? "Переместить в..." : "Дублировать в...",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filteredLists.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final list = filteredLists[index];

                String colorString = list['color'] ?? '0xFF000000';
                Color itemColor = Color(int.parse(colorString));

                return ListTile(
                  title: Text(
                    list['title'] ?? 'Без названия',
                    style: TextStyle(
                      color: itemColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isMove) {
                      _moveTaskToList(list['id']);
                    } else {
                      _duplicateTaskToList(list['id']);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendExecutorNotificationIfNeeded(TaskModel task) async {
    final newExecutorId = task.executor;

    if (newExecutorId == null || newExecutorId.isEmpty) return;
    if (newExecutorId == _previousExecutorId) return;
    if (newExecutorId == widget.currentUserId) return;

    try {
      final listDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: task.listId,
      );

      final listName = listDoc.data['name'] ?? 'Список';
      final text = 'Вам назначена задача в списке «$listName»';

      String? senderAvatarUrl;
      final currentUser = await AppwriteService().fetchFullUser(
        widget.currentUserId,
      );
      if (currentUser != null) {
        senderAvatarUrl = currentUser['avatar_url'] as String?;
      }

      await NotificationsService().createNotification(
        senderId: widget.currentUserId,
        senderAvatarUrl: senderAvatarUrl,
        receiverId: newExecutorId,
        type: 'task_assigned',
        text: text,
        listId: task.listId,
        taskId: task.id,
      );

      _previousExecutorId = newExecutorId;
    } catch (e) {
      debugPrint('Ошибка создания уведомления: $e');
    }
  }

  Future<void> _moveTaskToList(String targetListId) async {
    try {
      final newTask = widget.task.copyWith(id: '', listId: targetListId);

      await AppwriteService().createTask(newTask);
      await AppwriteService().deleteTask(widget.task.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Задача успешно перемещена")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error moving task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка при перемещении задачи")),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _duplicateTaskToList(String targetListId) async {
    try {
      final manualTask = TaskModel(
        id: '',
        listId: targetListId,
        invoice: widget.task.invoice,
        company: widget.task.company,
        products: widget.task.products,
        date: widget.task.date,
        address: widget.task.address,
        executor: null,
        reminder: widget.task.reminder,
        comment: widget.task.comment,
        isDone: widget.task.isDone,
        order: widget.task.order,
      );

      await AppwriteService().createTask(manualTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Задача успешно продублирована")),
        );
      }
    } catch (e) {
      debugPrint("Error duplicating task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка при дублировании")),
        );
      }
    }
  }

  void _onCompanyChanged(String text) {
    if (text.isEmpty) {
      _hideCompanyOverlay();
      return;
    }
    _filteredCompanies = _allCompanies
        .where((name) => name.toLowerCase().startsWith(text.toLowerCase()))
        .toList();
    if (_filteredCompanies.isEmpty) {
      _hideCompanyOverlay();
    } else {
      _showCompanyOverlay();
    }
  }

  void _showCompanyOverlay() {
    _hideCompanyOverlay();
    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 40,
        child: CompositedTransformFollower(
          link: _companyFieldLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 45),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            color: AppColors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredCompanies.length,
                itemBuilder: (context, index) {
                  final company = _filteredCompanies[index];
                  return InkWell(
                    onTap: () {
                      _companyController.text = company;
                      _hideCompanyOverlay();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        company,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    _companyOverlay = overlay;
    Overlay.of(context).insert(overlay);
  }

  void _hideCompanyOverlay() => {
    _companyOverlay?.remove(),
    _companyOverlay = null,
  };

  Future<void> _selectDate() async {
    DateTime tempDate = _selectedDate ?? DateTime.now();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            MobileRussianCalendar(
              initialDate: tempDate,
              accentColor: widget.listColor,
              onDateChanged: (date) => tempDate = date,
            ),
            const SizedBox(height: 5),
            _buildDialogButton("Выбрать", () {
              setState(() {
                _selectedDate = tempDate;
                _dateController.text = DateFormat(
                  'dd.MM.yyyy',
                ).format(tempDate);
              });
              Navigator.pop(context);
            }),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Future<void> _selectReminder() async {
    DateTime tempDate = _selectedReminderDate ?? DateTime.now();
    TimeOfDay tempTime = _selectedReminderDate != null
        ? TimeOfDay.fromDateTime(_selectedReminderDate!)
        : TimeOfDay.now();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            MobileRussianCalendar(
              initialDate: tempDate,
              accentColor: widget.listColor,
              onDateChanged: (date) => tempDate = date,
            ),
            const SizedBox(height: 5),
            const Divider(color: AppColors.paper, thickness: 1),
            const SizedBox(height: 10),
            MobileAlarmItem(
              accentColor: widget.listColor,
              initialTime: tempTime,
              onTimeSelected: (time) => tempTime = time,
            ),
            const SizedBox(height: 20),
            _buildDialogButton("Установить напоминание", () {
              setState(() {
                _selectedReminderDate = DateTime(
                  tempDate.year,
                  tempDate.month,
                  tempDate.day,
                  tempTime.hour,
                  tempTime.minute,
                );
                _reminderController.text =
                    "${DateFormat('dd.MM.yyyy').format(tempDate)} в ${tempTime.format(context)}";
              });
              Navigator.pop(context);
            }),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTask() async {
    if (_productsController.text.isEmpty) return;

    debugPrint("Сохраняю УПД: ${_utdController.text}");

    final updatedTask = widget.task.copyWith(
      invoice: _invoiceController.text,
      utd: _utdController.text,
      company: _companyController.text,
      products: _productsController.text,
      date: _selectedDate?.toIso8601String(),
      address: _addressController.text,
      executor: _selectedExecutorId,
      comment: _commentController.text,
      reminder: _selectedReminderDate?.toIso8601String(),
    );

    try {
      await AppwriteService().updateTask(updatedTask);
      await _sendExecutorNotificationIfNeeded(updatedTask);
      widget.onTaskUpdated(updatedTask);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error updating task: $e");
    }
  }

  Widget? _buildExecutorAvatar() {
    if (_selectedExecutorId == null || _selectedExecutorId!.isEmpty)
      return null;

    final participant = _listParticipants.firstWhere(
      (u) => u['id'] == _selectedExecutorId,
      orElse: () => {},
    );

    if (participant.isEmpty) return null;

    final String name = participant['name'] ?? "";
    final String? avatarUrl = participant['avatar_url'];

    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.skyBlue,
      ),
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitials(name),
              )
            : _buildInitials(name),
      ),
    );
  }

  Widget _buildInitials(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Просмотр Задачи",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isAdmin)
            PopupMenuButton<String>(
              icon: Image.asset(
                'assets/icons/more.png',
                width: 26,
                height: 26,
                color: AppColors.black,
              ),
              onSelected: (value) {
                if (value == 'move') {
                  _showListSelectionDialog(isMove: true);
                } else if (value == 'duplicate') {
                  _showListSelectionDialog(isMove: false);
                }
              },
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'move',
                  child: Row(
                    children: [
                      Icon(
                        Icons.drive_file_move_outlined,
                        color: AppColors.black,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Переместить",
                        style: TextStyle(color: AppColors.black),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(
                        Icons.copy_outlined,
                        color: AppColors.black,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Дублировать",
                        style: TextStyle(color: AppColors.black),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel(
                                "Счет",
                                color: widget.listColor,
                              ),
                              _buildUnderlinedTextField(
                                controller: _invoiceController,
                                hintText: "11-11111",
                                readOnly: !_isAdmin,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [InvoiceInputFormatter()],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel(
                                "УПД",
                                color: widget.listColor,
                              ),
                              _buildUnderlinedTextField(
                                controller: _utdController,
                                hintText: "111111/1",
                                readOnly: !_isAdmin,
                                keyboardType: TextInputType.number,
                                inputFormatters: [UtdInputFormatter()],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionLabel("Компания", topPadding: 10),
                  CompositedTransformTarget(
                    link: _companyFieldLink,
                    child: _buildUnderlinedTextField(
                      controller: _companyController,
                      hintText: "Название компании",
                      readOnly: !_isAdmin,
                      onChanged: _isAdmin ? _onCompanyChanged : null,
                    ),
                  ),
                  _buildSectionLabel("Список Товаров", topPadding: 10),
                  _buildUnderlinedTextField(
                    controller: _productsController,
                    hintText: "Товары",
                    isMultiline: true,
                    readOnly: !_isAdmin,
                  ),
                  _buildSectionLabel("Дополнительно", topPadding: 10),
                  const SizedBox(height: 5),
                  _buildIconTextField(
                    controller: _dateController,
                    hintText: "Дата выполнения",
                    iconPath: "date.png",
                    onTap: _isAdmin ? _selectDate : null,
                    onClear: () => setState(() {
                      _selectedDate = null;
                      _dateController.clear();
                    }),
                    isFilled: _selectedDate != null,
                    showClearIcon: _isAdmin,
                  ),
                  const SizedBox(height: 15),
                  _buildIconTextField(
                    controller: _addressController,
                    hintText: "Адрес",
                    iconPath: "address.png",
                    readOnly: !_isAdmin,
                    onClear: () => setState(() => _addressController.clear()),
                    isFilled: _addressController.text.isNotEmpty,
                    showClearIcon: _isAdmin,
                  ),
                  const SizedBox(height: 15),
                  _buildIconTextField(
                    controller: _executorController,
                    hintText: "Исполнитель",
                    iconPath: "for_user.png",
                    customLeading: _buildExecutorAvatar(),
                    onTap: _isAdmin ? _showExecutorPopup : null,
                    onClear: () => setState(() {
                      _selectedExecutorId = null;
                      _executorController.clear();
                    }),
                    isFilled: _selectedExecutorId != null,
                    showClearIcon: _isAdmin,
                  ),
                  const SizedBox(height: 15),
                  _buildIconTextField(
                    controller: _reminderController,
                    hintText: "Напомнить",
                    iconPath: "remind.png",
                    onTap: _isAdmin ? _selectReminder : null,
                    onClear: () => setState(() => _reminderController.clear()),
                    isFilled: _reminderController.text.isNotEmpty,
                    showClearIcon: _isAdmin,
                  ),
                  _buildSectionLabel(
                    "Дополнительно",
                    fontSize: 18,
                    topPadding: 8,
                  ),
                  _buildUnderlinedTextField(
                    controller: _commentController,
                    hintText: "Комментарий",
                    readOnly: !_isAdmin,
                  ),

                  if (widget.showGoToTaskButton)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (widget.onNavigateToOriginalList != null) {
                              widget.onNavigateToOriginalList!();
                            } else {
                              Navigator.pop(context, {
                                'action': 'navigate_to_task',
                                'taskId': widget.task.id,
                                'listId': widget.task.listId,
                              });
                            }
                          },
                          icon: const Icon(Icons.directions_outlined, size: 20),
                          label: const Text(
                            "Перейти к задаче",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.listColor,
                            side: BorderSide(
                              color: widget.listColor,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 50),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _updateTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.listColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Сохранить",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _confirmDelete,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/icons/delete.png',
                          width: 32,
                          height: 32,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDialogButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.listColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(
    String text, {
    Color? color,
    double fontSize = 20,
    double topPadding = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 20, top: topPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildUnderlinedTextField({
    required TextEditingController controller,
    required String hintText,
    Function(String)? onChanged,
    bool isMultiline = false,
    bool readOnly = false,
    double topPadding = 8,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: isMultiline ? const BoxConstraints(maxHeight: 70) : null,
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          onChanged: onChanged,
          maxLines: isMultiline ? null : 1,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.black,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.grey,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.black),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.black, width: 1.5),
            ),
            contentPadding: EdgeInsets.only(top: topPadding, bottom: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildIconTextField({
    required TextEditingController controller,
    required String hintText,
    required String iconPath,
    Widget? customLeading,
    VoidCallback? onTap,
    required VoidCallback onClear,
    bool isFilled = false,
    bool readOnly = true,
    bool showClearIcon = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.black,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: UnconstrainedBox(
              child:
                  customLeading ??
                  Image.asset(
                    'assets/icons/$iconPath',
                    width: 24,
                    height: 24,
                    color: AppColors.grey,
                  ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIcon: (showClearIcon && controller.text.isNotEmpty)
              ? GestureDetector(
                  onTap: onClear,
                  child: UnconstrainedBox(
                    child: Image.asset(
                      'assets/icons/close.png',
                      width: 20,
                      height: 20,
                      color: AppColors.black,
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.black),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.black),
          ),
        ),
      ),
    );
  }

  void _showExecutorPopup() {
    if (_listParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Список участников загружается...")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text(
          "Выберите исполнителя",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _listParticipants.length,
            itemBuilder: (context, index) {
              final user = _listParticipants[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['avatar_url']?.isNotEmpty == true
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  child: user['avatar_url']?.isEmpty == true
                      ? Text(user['name'][0])
                      : null,
                ),
                title: Text(user['name']),
                onTap: () {
                  setState(() {
                    _selectedExecutorId = user['id'];
                    _executorController.text = user['name'];
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class InvoiceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (text.length > 6) return oldValue;

    String newString = '';
    for (int i = 0; i < text.length; i++) {
      newString += text[i];
      if (i == 1 && text.length > 2) {
        newString += '-';
      }
    }

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}

class UtdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (text.length > 7) return oldValue;

    String newString = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 6) {
        newString += '/';
      }
      newString += text[i];
    }

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}
