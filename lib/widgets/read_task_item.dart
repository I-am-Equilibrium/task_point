import 'package:flutter/material.dart';
import 'package:task_point/constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:task_point/services/notifications_service.dart';
import 'package:task_point/services/task_model.dart';
import 'package:task_point/widgets/alarm_item.dart';
import 'package:task_point/widgets/russian_calendar.dart';
import 'package:task_point/services/appwrite_service.dart';

class ReadTaskItem extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onGoToTask;
  final String currentUserId;

  final Color listColor;
  final Function(TaskModel) onTaskCreated;
  final Function(TaskModel)? onTaskUpdated;
  final String listId;
  final List<TaskModel> tasksInList;
  final TaskModel? editingTask;
  final bool isOwner;
  final bool isAdmin;
  final bool isReadOnly;

  const ReadTaskItem({
    super.key,
    required this.onClose,
    required this.listColor,
    required this.onTaskCreated,
    required this.listId,
    required this.tasksInList,
    this.editingTask,
    this.onTaskUpdated,
    required this.isOwner,
    required this.isAdmin,
    required this.isReadOnly,
    this.onGoToTask,
    required this.currentUserId,
  });

  @override
  State<ReadTaskItem> createState() => ReadTaskItemState();
}

class ReadTaskItemState extends State<ReadTaskItem> {
  bool _isHoveringClose = false;
  bool _isSaveHover = false;
  bool _isDeleteHover = false;
  String? _previousExecutorId;

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
  final LayerLink _executorFieldLink = LayerLink();
  OverlayEntry? _executorOverlay;
  String? _selectedExecutorId;
  List<Map<String, dynamic>> _listParticipants = [];

  DateTime? _selectedDate;
  DateTime _selectedReminderDate = DateTime.now();
  TimeOfDay _selectedReminderTime = TimeOfDay.now();

  String? _executorName;
  String? _executorAvatarUrl;

  Color _getUserColor(String name) {
    if (name.isEmpty) return AppColors.grey;

    final List<Color> allowedColors = [
      AppColors.green,
      AppColors.skyBlue,
      AppColors.lavendar,
      AppColors.cheese,
      AppColors.red,
    ];

    final int index = name.hashCode.abs() % allowedColors.length;
    return allowedColors[index];
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _formatInvoiceNumber(String value) {
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 6) {
      digits = digits.substring(0, 6);
    }

    String result = "";
    if (digits.length <= 2) {
      result = digits;
    } else {
      final prefix = digits.substring(0, 2);
      final suffix = digits.substring(2);
      result = "$prefix-$suffix";
    }

    _invoiceController.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }

  void _formatUtdNumber(String value) {
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 7) digits = digits.substring(0, 7);

    if (digits.length <= 6) {
      _utdController.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    } else {
      final result = "${digits.substring(0, 6)}/${digits.substring(6)}";
      _utdController.value = TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  OverlayEntry? _calendarOverlay;
  OverlayEntry? _reminderOverlay;

  bool get _isSpecialList => widget.isReadOnly;

  bool get _hasDate => _selectedDate != null;

  bool get _hasAddress => _addressController.text.trim().isNotEmpty;

  bool get _hasExecutor =>
      _selectedExecutorId != null && _selectedExecutorId!.isNotEmpty;

  bool get _hasReminder => _reminderController.text.trim().isNotEmpty;

  Color _fieldColor(bool hasValue) {
    return hasValue ? AppColors.black : AppColors.grey;
  }

  UnderlineInputBorder _underline(bool hasValue) {
    return UnderlineInputBorder(
      borderSide: BorderSide(color: _fieldColor(hasValue), width: 1),
    );
  }

  DateTime? _parseDateSafe(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    try {
      return DateFormat('dd.MM.yyyy').parse(dateStr);
    } catch (_) {}

    try {
      return DateFormat('dd.MM.yyyy HH:mm').parse(dateStr);
    } catch (_) {}

    try {
      final timestamp = int.parse(dateStr);
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (_) {}

    return null;
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

  void _showExecutorOverlay() {
    if (!(widget.isOwner || widget.isAdmin)) return;
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
                                final String userId = user["id"].toString();
                                final String userName = user["name"].toString();
                                final String? avatarUrl = user["avatar_url"];
                                final bool hasAvatar =
                                    avatarUrl != null && avatarUrl.isNotEmpty;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedExecutorId = userId;
                                      _executorName = userName;
                                      _executorAvatarUrl = avatarUrl;
                                      _executorController.text = userName;
                                    });
                                    _hideExecutorOverlay();
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
                                          backgroundColor: hasAvatar
                                              ? Colors.transparent
                                              : _getUserColor(userName),
                                          backgroundImage: hasAvatar
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child: !hasAvatar
                                              ? Text(
                                                  _getInitials(userName),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.black,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          userName,
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

  Widget _BottomAction() {
    final bool isSpecial = _isSpecialList;
    bool isHovering = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovering = true),
          onExit: (_) => setState(() => isHovering = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              if (isSpecial) {
                widget.onGoToTask?.call();
                widget.onClose();
              } else {
                _showDeleteConfirmation();
              }
            },
            child: AnimatedOpacity(
              opacity: isHovering ? 0.8 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedScale(
                scale: isHovering ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Перейти к задаче",
                      style: TextStyle(
                        color: AppColors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Image.asset(
                      "assets/icons/arrow.png",
                      width: 20,
                      height: 20,
                      color: AppColors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text("Удаление задачи"),
          content: const Text("Вы действительно хотите удалить эту задачу?"),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Отмена",
                style: TextStyle(color: AppColors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
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

  @override
  void initState() {
    super.initState();
    _loadCompanies();

    if (widget.editingTask != null) {
      final t = widget.editingTask!;
      _invoiceController.text = t.invoice ?? '';
      _utdController.text = t.utd ?? '';
      _companyController.text = t.company ?? '';
      _productsController.text = t.products ?? '';
      _dateController.text = _parseDateSafe(t.date) != null
          ? DateFormat('dd.MM.yyyy').format(_parseDateSafe(t.date)!)
          : '';
      _addressController.text = t.address ?? '';
      _selectedExecutorId = t.executor;
      _loadExecutorName();
      _reminderController.text = _parseDateSafe(t.reminder) != null
          ? DateFormat('dd.MM.yyyy, HH:mm').format(_parseDateSafe(t.reminder)!)
          : '';
      _commentController.text = t.comment ?? '';

      _selectedDate = _parseDateSafe(t.date);
      final reminder = _parseDateSafe(t.reminder);
      if (reminder != null) {
        _selectedReminderDate = reminder;
        _selectedReminderTime = TimeOfDay(
          hour: reminder.hour,
          minute: reminder.minute,
        );
      }
      _selectedExecutorId = t.executor;
      _executorName = null;

      if (_selectedExecutorId != null) {
        _loadExecutorName();
      }

      if (widget.editingTask != null) {
        _previousExecutorId = widget.editingTask!.executor;
      }
    }
  }

  Future<void> _loadExecutorName() async {
    if (_selectedExecutorId == null || _selectedExecutorId!.isEmpty) return;

    final user = await AppwriteService().fetchFullUser(_selectedExecutorId!);
    if (!mounted) return;

    setState(() {
      _executorName = user?["name"];
      _executorAvatarUrl = user?["avatar_url"];
      _executorController.text = _executorName ?? '';
    });
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

    _selectedDate = null;
    _selectedReminderDate = DateTime.now();
    _selectedReminderTime = TimeOfDay.now();

    setState(() {});
  }

  Future<void> _deleteTask() async {
    if (widget.isReadOnly) return;
    if (widget.editingTask == null) return;
    if (!(widget.isOwner || widget.isAdmin)) return;

    try {
      await AppwriteService().deleteTask(widget.editingTask!.id);

      widget.tasksInList.removeWhere((t) => t.id == widget.editingTask!.id);
      widget.onClose();
    } catch (e) {
      debugPrint("Ошибка удаления задачи: $e");
    }
  }

  Future<void> _saveTask() async {
    if (widget.isReadOnly) return;
    if (!(widget.isOwner || widget.isAdmin)) return;

    if (_invoiceController.text.isEmpty &&
        _companyController.text.isEmpty &&
        _productsController.text.isEmpty)
      return;

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

    TaskModel task;
    if (widget.editingTask != null) {
      task = widget.editingTask!;
      task.invoice = _invoiceController.text;

      task.utd = _utdController.text;

      task.company = _companyController.text;
      task.products = _productsController.text;
      task.date = _selectedDate?.toIso8601String();
      task.address = _addressController.text;
      task.executor = _selectedExecutorId;

      task.reminder = reminder;
      task.comment = _commentController.text;

      try {
        task = await AppwriteService().updateTask(task);
        await _sendExecutorNotificationIfNeeded(task);
      } catch (e) {
        debugPrint("Ошибка обновления задачи на сервере: $e");
      }

      if (widget.onTaskUpdated != null) {
        widget.onTaskUpdated!(task);
      }
    } else {
      int newOrder = 0;
      if (widget.tasksInList.isNotEmpty) {
        newOrder =
            widget.tasksInList
                .map((t) => t.order)
                .reduce((a, b) => a > b ? a : b) +
            1;
      }

      task = TaskModel(
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

      task = await AppwriteService().createTask(task);
      await _sendExecutorNotificationIfNeeded(task);

      widget.onTaskCreated(task);
    }

    _resetFields();
    widget.onClose();
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
        documentId: widget.listId,
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
        listId: widget.listId,
        taskId: task.id,
      );

      _previousExecutorId = newExecutorId;
    } catch (e) {
      debugPrint('Ошибка создания уведомления: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit =
        !widget.isReadOnly && (widget.isOwner || widget.isAdmin);

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
                          "Просмотр Задачи",
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

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 15),
                              child: Text(
                                "Счет",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 15,
                                right: 7.5,
                              ),
                              child: TextField(
                                controller: _invoiceController,
                                onChanged: canEdit
                                    ? _formatInvoiceNumber
                                    : null,
                                enabled: canEdit,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.black,
                                ),
                                decoration: _inputDecoration("11-1111"),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 7.5),
                              child: Text(
                                "УПД",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 7.5,
                                right: 15,
                              ),
                              child: TextField(
                                controller: _utdController,
                                onChanged: canEdit ? _formatUtdNumber : null,
                                enabled: canEdit,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.black,
                                ),
                                decoration: _inputDecoration("111111/1"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                        onChanged: canEdit ? _onCompanyChanged : null,
                        enabled: canEdit,
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
                            onChanged: canEdit ? (_) {} : null,

                            enabled: canEdit,
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
                      enabled: canEdit,
                      onTap: canEdit ? _showSmallCalendar : null,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Введите дату выполнения",
                        isDense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 28,
                          right: 0,
                          top: 15,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            "assets/icons/date.png",
                            width: 18,
                            height: 18,
                            color: _fieldColor(_hasDate),
                          ),
                        ),
                        suffixIcon: canEdit && _hasDate
                            ? GestureDetector(
                                onTap: () {
                                  _dateController.clear();
                                  _selectedDate = null;
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
                              )
                            : null,
                        border: _underline(_hasDate),
                        enabledBorder: _underline(_hasDate),
                        focusedBorder: _underline(_hasDate),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: _addressController,
                      onChanged: canEdit ? (_) {} : null,

                      enabled: canEdit,
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
                            color: _fieldColor(_hasAddress),
                          ),
                        ),
                        border: _underline(_hasAddress),
                        enabledBorder: _underline(_hasAddress),
                        focusedBorder: _underline(_hasAddress),
                        suffixIcon:
                            canEdit && _addressController.text.isNotEmpty
                            ? GestureDetector(
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
                              )
                            : null,
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
                        onTap: canEdit ? _showExecutorOverlay : null,
                        textAlignVertical: TextAlignVertical.center,
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 45,
                            minHeight: 30,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8, left: 0),
                            child: _selectedExecutorId == null
                                ? Image.asset(
                                    "assets/icons/for_user.png",
                                    width: 18,
                                    height: 18,
                                    color: _fieldColor(_hasExecutor),
                                  )
                                : Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          (_executorAvatarUrl == null ||
                                              _executorAvatarUrl!.isEmpty)
                                          ? _getUserColor(_executorName ?? "")
                                          : Colors.transparent,
                                    ),
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.transparent,
                                      backgroundImage:
                                          (_executorAvatarUrl != null &&
                                              _executorAvatarUrl!.isNotEmpty)
                                          ? NetworkImage(_executorAvatarUrl!)
                                          : null,
                                      child:
                                          (_executorAvatarUrl == null ||
                                                  _executorAvatarUrl!
                                                      .isEmpty) &&
                                              _executorName != null
                                          ? Text(
                                              _getInitials(_executorName!),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.black,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                          ),
                          border: _underline(_hasExecutor),
                          enabledBorder: _underline(_hasExecutor),
                          focusedBorder: _underline(_hasExecutor),
                          suffixIcon:
                              canEdit && _executorController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _executorController.clear();
                                      _selectedExecutorId = null;
                                      _executorName = null;
                                      _executorAvatarUrl = null;
                                    });
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
                                )
                              : null,
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
                      enabled: canEdit,
                      onTap: canEdit ? _showReminderOverlay : null,
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
                              color: _fieldColor(_hasReminder),
                            ),
                          ),
                        ),
                        suffixIcon:
                            canEdit && _reminderController.text.isNotEmpty
                            ? GestureDetector(
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
                              )
                            : null,

                        border: _underline(_hasReminder),
                        enabledBorder: _underline(_hasReminder),
                        focusedBorder: _underline(_hasReminder),
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
                            onChanged: canEdit ? (_) {} : null,

                            enabled: canEdit,
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

                  const SizedBox(height: 12),
                  if (canEdit || _isSpecialList)
                    Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: _BottomAction(),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 20,
                top: 12,
              ),
              child: Row(
                children: [
                  Expanded(
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
                            decoration: BoxDecoration(
                              color: _isSaveHover
                                  ? widget.listColor.withOpacity(0.8)
                                  : widget.listColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Изменить",
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

                  const SizedBox(width: 10),

                  MouseRegion(
                    onEnter: (_) => setState(() => _isDeleteHover = true),
                    onExit: (_) => setState(() => _isDeleteHover = false),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _showDeleteConfirmation,
                      child: AnimatedScale(
                        scale: _isDeleteHover ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isDeleteHover
                                ? AppColors.red.withOpacity(0.8)
                                : AppColors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            "assets/icons/delete.png",
                            width: 22,
                            height: 22,
                            color: AppColors.white,
                          ),
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
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.grey,
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.black),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.black, width: 1),
    ),
    disabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.grey),
    ),
  );
}
