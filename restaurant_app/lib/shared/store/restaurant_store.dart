import 'package:flutter/foundation.dart';

class MenuItemData {
  const MenuItemData({required this.name, required this.price});

  final String name;
  final int price;
}

class OrderedItem {
  const OrderedItem({required this.name, required this.qty, required this.price, this.note = ''});

  final String name;
  final int qty;
  final int price;
  final String note;

  int get total => qty * price;
}

class RestaurantStore {
  RestaurantStore._();

  static final RestaurantStore instance = RestaurantStore._();

  final ValueNotifier<List<MenuItemData>> menuItems = ValueNotifier<List<MenuItemData>>(
    const [
      MenuItemData(name: 'Bún b?', price: 55000),
      MenuItemData(name: 'Cõm gà', price: 45000),
      MenuItemData(name: 'Trà ðào', price: 30000),
    ],
  );

  final ValueNotifier<Map<String, List<OrderedItem>>> tableOrders = ValueNotifier<Map<String, List<OrderedItem>>>(
    const {
      'Bàn 01': [OrderedItem(name: 'Bún b?', qty: 2, price: 55000)],
      'Bàn 03': [OrderedItem(name: 'Cõm gà', qty: 1, price: 45000, note: 'Ít cõm')],
    },
  );

  void addMenuItem(MenuItemData item) {
    menuItems.value = <MenuItemData>[...menuItems.value, item];
  }

  void addOrder(String tableName, OrderedItem item) {
    final current = Map<String, List<OrderedItem>>.from(tableOrders.value);
    final existing = current[tableName] ?? <OrderedItem>[];
    current[tableName] = <OrderedItem>[...existing, item];
    tableOrders.value = current;
  }
}
