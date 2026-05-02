class MenuItemRecord {
  const MenuItemRecord({
    required this.id,
    required this.name,
    required this.price,
    this.description = '',
    this.imageUrl = '',
    required this.createdBy,
  });

  final int id;
  final String name;
  final int price;
  final String description;
  final String imageUrl;
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
  const TodayStats({
    required this.billCount,
    required this.revenue,
    this.hourlyRevenue = const [],
    this.popularItems = const [],
  });

  final int billCount;
  final int revenue;
  final List<HourlyRevenue> hourlyRevenue;
  final List<PopularItem> popularItems;
}

class HourlyRevenue {
  const HourlyRevenue({required this.hour, required this.total});
  final int hour;
  final int total;
}

class PopularItem {
  const PopularItem({required this.name, required this.quantity});
  final String name;
  final int quantity;
}
