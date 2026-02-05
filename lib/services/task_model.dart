class TaskModel {
  String id;
  String listId;
  String? invoice;
  String? utd;
  String? company;
  String? products;
  String? date;
  String? address;
  String? executor;
  String? reminder;
  String? comment;
  bool isDone;
  bool isImportant;
  int order;

  TaskModel({
    required this.id,
    required this.listId,
    required this.order,
    this.invoice,
    this.utd,
    this.company,
    this.products,
    this.date,
    this.address,
    this.executor,
    this.reminder,
    this.comment,
    this.isDone = false,
    this.isImportant = false,
  });

  TaskModel copyWith({
    String? id,
    String? listId,
    String? invoice,
    String? utd,
    String? company,
    String? products,
    String? date,
    String? address,
    String? executor,
    String? reminder,
    String? comment,
    bool? isDone,
    bool? isImportant,
    int? order,
  }) {
    return TaskModel(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      invoice: invoice ?? this.invoice,
      utd: utd ?? this.utd, // <-- 4.
      company: company ?? this.company,
      products: products ?? this.products,
      date: date ?? this.date,
      address: address ?? this.address,
      executor: executor ?? this.executor,
      reminder: reminder ?? this.reminder,
      comment: comment ?? this.comment,
      isDone: isDone ?? this.isDone,
      isImportant: isImportant ?? this.isImportant,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
    "invoice_number": invoice,
    "utd": utd,
    "company_name": company,
    "products": products,
    "address": address,
    "delivery_date": date,
    "list_id": listId,
    "assigned_to": executor,
    "reminder_time": reminder,
    "comments": comment,
    "is_done": isDone,
    "is_important": isImportant,
    "order": order,
  };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json["\$id"],
    listId: json["list_id"],
    invoice: json["invoice_number"],
    utd: json["utd"],
    company: json["company_name"],
    products: json["products"],
    date: json["delivery_date"],
    address: json["address"],
    executor: json["assigned_to"],
    reminder: json["reminder_time"],
    comment: json["comments"],
    isDone: json["is_done"] ?? false,
    isImportant: json["is_important"] ?? false,
    order: (json["order"] ?? 0) is int
        ? json["order"]
        : (json["order"] as num).toInt(),
  );
}
