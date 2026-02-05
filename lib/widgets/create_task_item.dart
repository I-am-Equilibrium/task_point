import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:task_point/services/task_model.dart';
import 'package:task_point/widgets/alarm_item.dart';
import 'package:task_point/widgets/russian_calendar.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';
import 'package:flutter/services.dart';

class CreateTaskItem extends StatefulWidget {
  final VoidCallback onClose;
  final Color listColor;
  final Function(TaskModel) onTaskCreated;
  final String listId;
  final String currentUserId;
  final List<TaskModel> tasksInList;

  const CreateTaskItem({
    super.key,
    required this.onClose,
    required this.listColor,
    required this.onTaskCreated,
    required this.listId,
    required this.tasksInList,
    required this.currentUserId,
  });

  @override
  State<CreateTaskItem> createState() => _CreateTaskItemState();
}

class _CreateTaskItemState extends State<CreateTaskItem> {
  bool _isHoveringClose = false;
  bool _isSaveHover = false;

  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _utdController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _productsController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _executorController = TextEditingController();
  final TextEditingController _reminderController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  List<String> _allCompanies = [];
  List<String> _filteredCompanies = [];
  OverlayEntry? _companyOverlay;
  final LayerLink _companyFieldLink = LayerLink();

  DateTime? _selectedDate;
  DateTime _selectedReminderDate = DateTime.now();
  TimeOfDay _selectedReminderTime = TimeOfDay.now();

  OverlayEntry? _calendarOverlay;
  OverlayEntry? _reminderOverlay;
  List<Map<String, dynamic>> _listParticipants = [];
  int? _hoveredExecutorIndex;
  final LayerLink _executorFieldLink = LayerLink();
  OverlayEntry? _executorOverlay;
  String? _selectedExecutorId;

  void _showSmallCalendar() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _calendarOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeCalendar,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

            Positioned(
              left: offset.dx + size.width - 280,
              top: offset.dy + 380,
              child: Material(
                color: Colors.transparent,
                child: AnimatedScale(
                  scale: 1,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RussianCalendar(
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        onDateChanged: (date) {
                          setState(() {
                            _selectedDate = date;
                            _dateController.text = DateFormat(
                              'dd.MM.yyyy',
                            ).format(date);
                          });
                          _closeCalendar();
                        },
                        listColor: widget.listColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_calendarOverlay!);
  }

  void _showReminderOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _reminderOverlay = OverlayEntry(
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final containerHeight = 400.0;
        final bottomMargin = 150.0;

        double topPosition = offset.dy + 420;
        if (topPosition + containerHeight + bottomMargin > screenHeight) {
          topPosition = screenHeight - containerHeight - bottomMargin;
        }

        bool isHovering = false;

        return StatefulBuilder(
          builder: (context, setOverlayState) {
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeReminderOverlay,
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  left: offset.dx + size.width - 280,
                  top: topPosition,
                  child: Material(
                    color: Colors.transparent,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RussianCalendar(
                              initialDate: _selectedReminderDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              listColor: widget.listColor,
                              onDateChanged: (date) {
                                setState(() => _selectedReminderDate = date);
                              },
                            ),
                            const SizedBox(height: 12),
                            AlarmItem(
                              onTimeSelected: (time) {
                                setState(() => _selectedReminderTime = time);
                              },
                            ),
                            const SizedBox(height: 12),
                            MouseRegion(
                              onEnter: (_) =>
                                  setOverlayState(() => isHovering = true),
                              onExit: (_) =>
                                  setOverlayState(() => isHovering = false),
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  final formattedDate = DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(_selectedReminderDate);
                                  final formattedTime = DateFormat('HH:mm')
                                      .format(
                                        DateTime(
                                          0,
                                          0,
                                          0,
                                          _selectedReminderTime.hour,
                                          _selectedReminderTime.minute,
                                        ),
                                      );
                                  setState(() {
                                    _reminderController.text =
                                        "$formattedDate, $formattedTime";
                                  });
                                  _closeReminderOverlay();
                                },
                                child: AnimatedScale(
                                  scale: isHovering ? 1.05 : 1.0,
                                  duration: const Duration(milliseconds: 120),
                                  child: Container(
                                    height: 42,
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isHovering
                                          ? widget.listColor.withOpacity(0.85)
                                          : widget.listColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "Напомнить",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_reminderOverlay!);
  }

  void _closeReminderOverlay() {
    if (_reminderOverlay != null) {
      final entry = _reminderOverlay!;
      _reminderOverlay = null;
      Future.delayed(const Duration(milliseconds: 80), () {
        entry.remove();
      });
    }
  }

  void _closeCalendar() {
    if (_calendarOverlay != null) {
      final entry = _calendarOverlay!;
      _calendarOverlay = null;

      Future.delayed(const Duration(milliseconds: 120), () {
        entry.remove();
      });
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final listDoc = await AppwriteService().databases.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.listsCollectionId,
        documentId: widget.listId,
      );

      final listData = Map<String, dynamic>.from(listDoc.data);
      final ownerId = listData['owner_id'];
      final membersRaw = List<String>.from(listData['members'] ?? []);
      final adminsRaw = List<String>.from(listData['admins'] ?? []);

      final Set<String> allUserIds = {
        if (ownerId != null) ownerId,
        ...membersRaw,
        ...adminsRaw,
      };

      final List<Map<String, dynamic>> loaded = [];

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

      loaded.sort((a, b) {
        if (a["id"] == ownerId) return -1;
        if (b["id"] == ownerId) return 1;

        final aIsAdmin = adminsRaw.contains(a["id"]);
        final bIsAdmin = adminsRaw.contains(b["id"]);

        if (aIsAdmin && !bIsAdmin) return -1;
        if (!aIsAdmin && bIsAdmin) return 1;

        return 0;
      });

      setState(() {
        _listParticipants = loaded;
      });
    } catch (e) {
      print("Ошибка загрузки участников: $e");
    }
  }

  Map<String, dynamic>? _getSelectedExecutorData() {
    if (_selectedExecutorId == null) return null;
    return _listParticipants.firstWhere(
      (user) => user["id"] == _selectedExecutorId,
      orElse: () => {},
    );
  }

  void _showExecutorOverlay() {
    _hideExecutorOverlay();
    if (_listParticipants.isEmpty) {
      _loadParticipants().then((_) => _showExecutorOverlay());
      return;
    }
    final overlay = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _hideExecutorOverlay,
          child: Stack(
            children: [
              Positioned(
                width: 270,
                child: CompositedTransformFollower(
                  link: _executorFieldLink,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 50),
                  child: Material(
                    elevation: 6,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: _listParticipants.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(15),
                              child: Text(
                                "Загрузка участников...",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _listParticipants.length,
                              itemBuilder: (_, index) {
                                final user = _listParticipants[index];
                                return InkWell(
                                  onTap: () {
                                    _executorController.text = user["name"];
                                    _selectedExecutorId = user["id"];
                                    _hideExecutorOverlay();
                                    setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundImage:
                                              (user["avatar_url"] != null &&
                                                  user["avatar_url"]
                                                      .toString()
                                                      .isNotEmpty)
                                              ? NetworkImage(user["avatar_url"])
                                              : null,
                                          child:
                                              (user["avatar_url"] == null ||
                                                  user["avatar_url"]
                                                      .toString()
                                                      .isEmpty)
                                              ? Text(
                                                  user["name"]
                                                      .toString()[0]
                                                      .toUpperCase(),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          user["name"],
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
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    _executorOverlay = overlay;
    Overlay.of(context).insert(overlay);
  }

  void _hideExecutorOverlay() {
    _executorOverlay?.remove();
    _executorOverlay = null;
  }

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadParticipants();
  }

  Future<void> _loadCompanies() async {
    final user = await AppwriteService().getCurrentUser();
    if (user == null) return;

    final companies = await AppwriteService().getAllCompaniesForUser(user.$id);

    setState(() {
      _allCompanies = companies
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
    });
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
      builder: (context) {
        final itemHeight = 32.0;
        final verticalPadding = 15.0 * 2;
        final containerHeight =
            (_filteredCompanies.length * itemHeight) + verticalPadding;

        return Positioned(
          width: 300 - 30,
          child: CompositedTransformFollower(
            link: _companyFieldLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 40),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxHeight: containerHeight > 200 ? 200 : containerHeight,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 15),
                  shrinkWrap: true,
                  itemCount: _filteredCompanies.length,
                  itemBuilder: (context, index) {
                    final company = _filteredCompanies[index];

                    return InkWell(
                      onTap: () {
                        _companyController.text = company;
                        _hideCompanyOverlay();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          company,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    _companyOverlay = overlay;
    Overlay.of(context).insert(overlay);
  }

  void _hideCompanyOverlay() {
    if (_companyOverlay != null) {
      _companyOverlay!.remove();
      _companyOverlay = null;
    }
  }

  void _resetFields() {
    _invoiceController.clear();
    _utdController.clear();
    _companyController.clear();
    _productsController.clear();
    _dateController.clear();
    _addressController.clear();
    _executorController.clear();
    _reminderController.clear();
    _commentController.clear();
    _hideCompanyOverlay();
    _hideExecutorOverlay();
    _selectedExecutorId = null;
    _selectedDate = null;
    _selectedReminderDate = DateTime.now();
    _selectedReminderTime = TimeOfDay.now();

    setState(() {});
  }

  Future<void> _saveTask() async {
    if (_invoiceController.text.isEmpty &&
        _utdController.text.isEmpty &&
        _companyController.text.isEmpty &&
        _productsController.text.isEmpty) {
      return;
    }

    String? reminder;
    if (_reminderController.text.isNotEmpty) {
      final date = _selectedReminderDate;
      final time = _selectedReminderTime;

      reminder = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toIso8601String();
    }

    int newOrder = 0;
    if (widget.tasksInList.isNotEmpty) {
      newOrder =
          widget.tasksInList
              .map((t) => t.order)
              .reduce((a, b) => a > b ? a : b) +
          1;
    }

    final task = TaskModel(
      id: "",
      listId: widget.listId,
      order: newOrder,
      invoice: _invoiceController.text,
      utd: _utdController.text,
      company: _companyController.text,
      products: _productsController.text,
      date: _selectedDate?.toIso8601String(),
      address: _addressController.text,
      executor: _selectedExecutorId,
      reminder: reminder,
      comment: _commentController.text,
    );

    final savedTask = await AppwriteService().createTask(task);

    widget.onTaskCreated(savedTask);

    if (_selectedExecutorId != null &&
        _selectedExecutorId!.isNotEmpty &&
        _selectedExecutorId != widget.currentUserId) {
      try {
        final listDoc = await AppwriteService().databases.getDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.listsCollectionId,
          documentId: widget.listId,
        );

        final listName = listDoc.data['name'] ?? 'Список';

        final currentUser = await AppwriteService().fetchFullUser(
          widget.currentUserId,
        );
        final senderAvatarUrl = currentUser != null
            ? currentUser['avatar_url']
            : null;

        final notificationText = 'Вам назначена задача в списке «$listName»';

        await NotificationsService().createNotification(
          senderId: widget.currentUserId,
          senderAvatarUrl: senderAvatarUrl,
          receiverId: _selectedExecutorId!,
          type: 'task_assigned',
          text: notificationText,
          listId: widget.listId,
          taskId: savedTask.id,
        );
      } catch (e) {
        debugPrint('Ошибка создания уведомления: $e');
      }
    }

    _resetFields();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.15),
            offset: const Offset(-4, 2),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 20,
                      left: 15,
                      right: 15,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MouseRegion(
                            onEnter: (_) =>
                                setState(() => _isHoveringClose = true),
                            onExit: (_) =>
                                setState(() => _isHoveringClose = false),
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: widget.onClose,
                              child: AnimatedScale(
                                scale: _isHoveringClose ? 1.12 : 1.0,
                                duration: const Duration(milliseconds: 120),
                                child: AnimatedOpacity(
                                  opacity: _isHoveringClose ? 0.7 : 1.0,
                                  duration: const Duration(milliseconds: 120),
                                  child: Image.asset(
                                    "assets/icons/close.png",
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          "Создать Задачу",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Счет",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                              ),
                              TextField(
                                controller: _invoiceController,
                                inputFormatters: [InvoiceFormatter()],
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _inputDecoration("11111-11"),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "УПД",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                              ),
                              TextField(
                                controller: _utdController,
                                inputFormatters: [UtdFormatter()],
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _inputDecoration("123456/1"),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Padding(
                    padding: EdgeInsets.only(left: 15),
                    child: Text(
                      "Название Компании",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: CompositedTransformTarget(
                      link: _companyFieldLink,
                      child: TextField(
                        controller: _companyController,
                        onChanged: _onCompanyChanged,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.black,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Введите название компании",
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.grey,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.black,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Padding(
                    padding: EdgeInsets.only(left: 15),
                    child: Text(
                      "Список Товаров",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: TextField(
                            controller: _productsController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.black,
                            ),
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: "Введите список товаров",
                              hintStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.grey,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.black),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.black),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Padding(
                    padding: EdgeInsets.only(left: 15),
                    child: Text(
                      "Дополнительно",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _showSmallCalendar,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Введите дату выполнения",
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.grey,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 28,
                          right: 0,
                          top: 15,
                        ),
                        prefixIcon: GestureDetector(
                          onTap: _showSmallCalendar,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              "assets/icons/date.png",
                              width: 18,
                              height: 18,
                              color: _selectedDate == null
                                  ? AppColors.grey
                                  : AppColors.black,
                            ),
                          ),
                        ),
                        suffixIcon: _dateController.text.isEmpty
                            ? null
                            : GestureDetector(
                                onTap: () {
                                  _dateController.clear();
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.asset(
                                    "assets/icons/close.png",
                                    width: 20,
                                    height: 20,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.black),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.black),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.black,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _addressController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Введите адрес",
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.grey,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 28,
                          right: 0,
                          top: 15,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            "assets/icons/address.png",
                            width: 18,
                            height: 18,
                            color: AppColors.grey,
                          ),
                        ),
                        suffixIcon: _addressController.text.isEmpty
                            ? null
                            : GestureDetector(
                                onTap: () {
                                  _addressController.clear();
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.asset(
                                    "assets/icons/close.png",
                                    width: 20,
                                    height: 20,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.black),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.black),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.black,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: CompositedTransformTarget(
                      link: _executorFieldLink,
                      child: TextField(
                        controller: _executorController,
                        readOnly: true,
                        onTap: _showExecutorOverlay,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: "Передать Исполнителю",
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.grey,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.only(
                            left: 28,
                            right: 0,
                            top: 15,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(10),
                            child: _selectedExecutorId == null
                                ? Image.asset(
                                    "assets/icons/for_user.png",
                                    width: 18,
                                    height: 18,
                                    color: AppColors.grey,
                                  )
                                : (() {
                                    final user = _getSelectedExecutorData();
                                    final hasAvatar =
                                        user != null &&
                                        user["avatar_url"] != null &&
                                        user["avatar_url"]
                                            .toString()
                                            .isNotEmpty;

                                    return Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.skyBlue,
                                      ),
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.transparent,
                                        backgroundImage: hasAvatar
                                            ? NetworkImage(user["avatar_url"])
                                            : null,
                                        child: !hasAvatar && user != null
                                            ? Text(
                                                user["name"]
                                                        .toString()
                                                        .isNotEmpty
                                                    ? user["name"]
                                                          .toString()[0]
                                                          .toUpperCase()
                                                    : "",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.black,
                                                ),
                                              )
                                            : null,
                                      ),
                                    );
                                  })(),
                          ),
                          suffixIcon: _executorController.text.isEmpty
                              ? null
                              : GestureDetector(
                                  onTap: () {
                                    _executorController.clear();
                                    _selectedExecutorId = null;
                                    setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Image.asset(
                                      "assets/icons/close.png",
                                      width: 20,
                                      height: 20,
                                      color: AppColors.black,
                                    ),
                                  ),
                                ),
                          border: const UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black),
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.black,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _reminderController,
                      readOnly: true,
                      onTap: _showReminderOverlay,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Напомнить",
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.grey,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 28,
                          right: 0,
                          top: 15,
                        ),
                        prefixIcon: GestureDetector(
                          onTap: _showReminderOverlay,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              "assets/icons/remind.png",
                              width: 18,
                              height: 18,
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                        suffixIcon: _reminderController.text.isEmpty
                            ? null
                            : GestureDetector(
                                onTap: () {
                                  _reminderController.clear();
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.asset(
                                    "assets/icons/close.png",
                                    width: 20,
                                    height: 20,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.black),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.black),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.black,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Padding(
                    padding: EdgeInsets.only(left: 15),
                    child: Text(
                      "Комментарий",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 80),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: TextField(
                            maxLines: null,
                            maxLength: 200,
                            controller: _commentController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.black,
                            ),
                            decoration: const InputDecoration(
                              counterText: "",
                              hintText: "Добавить Комментарий",
                              hintStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.grey,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.black),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.black),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 40,
              right: 40,
              bottom: 20,
              top: 12,
            ),
            child: MouseRegion(
              onEnter: (_) => setState(() => _isSaveHover = true),
              onExit: (_) => setState(() => _isSaveHover = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _saveTask,
                child: AnimatedScale(
                  scale: _isSaveHover ? 1.03 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: _isSaveHover
                          ? widget.listColor.withOpacity(0.8)
                          : widget.listColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Создать",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: AppColors.grey),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.black),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.black, width: 1),
    ),
  );
}

class InvoiceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 7) text = text.substring(0, 7);

    String newText = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 5) newText += '-';
      newText += text[i];
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class UtdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 7) text = text.substring(0, 7);

    String newText = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 6) newText += '/'; // Ставим слэш после 6-й цифры
      newText += text[i];
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
