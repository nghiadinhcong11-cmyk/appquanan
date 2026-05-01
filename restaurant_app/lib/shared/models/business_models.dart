class MenuItemRecord {
  const MenuItemRecord({required this.id, required this.name, required this.price, required this.createdBy});

  final int id;
  final String name;
  final int price;
  final String createdBy;
}

class BillRecord {
  const BillRecord({
    required this.id,
    required this.tableName,
    required this.total,
    required this.itemCount,
    required this.createdAt,
  });

  final int id;
  final String tableName;
  final int total;
  final int itemCount;
  final DateTime createdAt;
}

class TodayStats {
  const TodayStats({required this.billCount, required this.revenue});

  final int billCount;
  final int revenue;
}
