import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:task_point/constants/colors.dart';
import 'package:task_point/services/appwrite_service.dart';
import 'package:task_point/services/notifications_service.dart';
import 'package:task_point/widgets/mobile_widgets/mobile_russian_calendar.dart';
import 'package:task_point/widgets/mobile_widgets/mobile_alarm_item.dart';
import 'package:task_point/services/task_model.dart';

class MobileCreateTaskScreen extends StatefulWidget {
  final String listId;
  final Color listColor;
  final String currentUserId;
  final List<TaskModel> tasksInList;
  final Function(TaskModel) onTaskCreated;

  const MobileCreateTaskScreen({
    super.key,
    required this.listId,
    required this.listColor,
    required this.currentUserId,
    required this.tasksInList,
    required this.onTaskCreated,
  });

  @override
  State<MobileCreateTaskScreen> createState() => _MobileCreateTaskScreenState();
}

class _MobileCreateTaskScreenState extends State<MobileCreateTaskScreen> {
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _utdController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _productsController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _executorController = TextEditingController();
  final TextEditingController _reminderController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  DateTime? _selectedDate;
  DateTime? _selectedReminderDate;
  String? _selectedExecutorId;
  List<Map<String, dynamic>> _listParticipants = [];
  final LayerLink _companyFieldLink = LayerLink();
  OverlayEntry? _companyOverlay;
  List<String> _allCompanies = [];
  List<String> _filteredCompanies = [];

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    _loadCompanies();
    _dateController.addListener(() => setState(() {}));
    _addressController.addListener(() => setState(() {}));
    _executorController.addListener(() => setState(() {}));
    _reminderController.addListener(() => setState(() {}));
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
            shadowColor: AppColors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.darkWhite,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkWhite,
                borderRadius: BorderRadius.circular(10),
              ),
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
      setState(() => _listParticipants = loaded);
    } catch (e) {
      debugPrint("Error loading participants: $e");
    }
  }

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
    DateTime tempDate = DateTime.now();
    TimeOfDay tempTime = TimeOfDay.now();

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
    VoidCallback? onTap,
    required VoidCallback onClear,
    bool isFilled = false,
    bool readOnly = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
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
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Image.asset(
              'assets/icons/$iconPath',
              width: 20,
              height: 20,
              color: isFilled ? AppColors.black : AppColors.grey,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 25,
            minHeight: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: Image.asset(
                    'assets/icons/close.png',
                    width: 20,
                    height: 20,
                    color: AppColors.black,
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 20,
            minHeight: 20,
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

  Future<void> _saveTask() async {
    if (_productsController.text.isEmpty) return;

    int newOrder = widget.tasksInList.isEmpty
        ? 0
        : widget.tasksInList
                  .map((t) => t.order ?? 0)
                  .reduce((a, b) => a > b ? a : b) +
              1;

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
      comment: _commentController.text,
      reminder: _selectedReminderDate?.toIso8601String(),
    );

    try {
      final savedTask = await AppwriteService().createTask(task);
      widget.onTaskCreated(savedTask);

      if (_selectedExecutorId != null &&
          _selectedExecutorId != widget.currentUserId) {
        await NotificationsService().createNotification(
          senderId: widget.currentUserId,
          receiverId: _selectedExecutorId!,
          type: 'task_assigned',
          text: 'Вам назначена задача',
          listId: widget.listId,
          taskId: savedTask.id,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error saving task: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Создать Задачу",
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
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel(
                    "Номер накладной",
                    color: widget.listColor,
                    topPadding: 30,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 8.0,
                    ), // Небольшой отступ
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildUnderlinedTextField(
                            controller: _invoiceController,
                            hintText: "Счет",
                            keyboardType: TextInputType.number,
                            inputFormatters: [InvoiceInputFormatter()],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildUnderlinedTextField(
                            controller: _utdController,
                            hintText: "упд",
                            keyboardType: TextInputType.number,
                            inputFormatters: [UtdInputFormatter()],
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
                      hintText: "Введите название компании",
                      onChanged: _onCompanyChanged,
                    ),
                  ),
                  _buildSectionLabel("Список Товаров", topPadding: 10),
                  _buildUnderlinedTextField(
                    controller: _productsController,
                    hintText: "Введите список товаров",
                    isMultiline: true,
                  ),
                  _buildSectionLabel("Дополнительно", topPadding: 10),
                  const SizedBox(height: 5),
                  _buildIconTextField(
                    controller: _dateController,
                    hintText: "Введите дату выполнения",
                    iconPath: "date.png",
                    onTap: _selectDate,
                    onClear: () => setState(() {
                      _selectedDate = null;
                      _dateController.clear();
                    }),
                    isFilled: _selectedDate != null,
                  ),
                  const SizedBox(height: 15),
                  _buildIconTextField(
                    controller: _addressController,
                    hintText: "Введите адрес",
                    iconPath: "address.png",
                    readOnly: false,
                    onClear: () => setState(() => _addressController.clear()),
                    isFilled: _addressController.text.isNotEmpty,
                  ),
                  const SizedBox(height: 15),
                  _buildIconTextField(
                    controller: _executorController,
                    hintText: "Передать Исполнителю",
                    iconPath: "for_user.png",
                    onTap: _showExecutorPopup,
                    onClear: () => setState(() {
                      _selectedExecutorId = null;
                      _executorController.clear();
                    }),
                    isFilled: _selectedExecutorId != null,
                  ),
                  const SizedBox(height: 15),
                  _buildIconTextField(
                    controller: _reminderController,
                    hintText: "Напомнить",
                    iconPath: "remind.png",
                    onTap: _selectReminder,
                    onClear: () => setState(() => _reminderController.clear()),
                    isFilled: _reminderController.text.isNotEmpty,
                  ),
                  _buildSectionLabel(
                    "Дополнительно",
                    fontSize: 18,
                    topPadding: 8,
                  ),
                  _buildUnderlinedTextField(
                    controller: _commentController,
                    hintText: "Добавить комментарий",
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 50),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.listColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
        ],
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
    final text = newValue.text.replaceAll('-', '');
    if (text.length > 7) return oldValue;

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
    final text = newValue.text
        .replaceAll('/', '')
        .replaceAll(RegExp(r'\D'), '');

    if (text.length > 7) return oldValue;

    String newString = '';
    for (int i = 0; i < text.length; i++) {
      newString += text[i];
      if (i == 5 && text.length > 6) {
        newString += '/';
      }
    }

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}
