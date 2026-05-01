import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/store/restaurant_store.dart';

class TableDetailScreen extends StatelessWidget {
  const TableDetailScreen({super.key, required this.tableName, required this.api, required this.restaurantName});

  final String tableName;
  final HttpApiService api;
  final String restaurantName;

  String _formatMoney(int value) => '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';

  Future<void> _openAddOrderSheet(BuildContext context) async {
    MenuItemData? selected;
    final qtyController = TextEditingController(text: '1');
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final menu = RestaurantStore.instance.menuItems.value;
          selected ??= menu.isNotEmpty ? menu.first : null;
          return Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Thêm món cho bàn', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                DropdownButtonFormField<MenuItemData>(
                  initialValue: selected,
                  items: menu.map((e) => DropdownMenuItem(value: e, child: Text('${e.name} - ${_formatMoney(e.price)}'))).toList(),
                  onChanged: (value) => setModalState(() => selected = value),
                  decoration: const InputDecoration(labelText: 'Chọn món'),
                ),
                const SizedBox(height: 12),
                TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số lượng')),
                const SizedBox(height: 12),
                TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Ghi chú')),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () {
                          final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                          if (qty <= 0) return;
                          RestaurantStore.instance.addOrder(tableName, OrderedItem(name: selected!.name, qty: qty, price: selected!.price, note: noteController.text.trim()));
                          Navigator.pop(context);
                        },
                  child: const Text('Thêm vào bàn'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chi tiết $tableName')),
      body: ValueListenableBuilder<Map<String, List<OrderedItem>>>(
        valueListenable: RestaurantStore.instance.tableOrders,
        builder: (context, orders, _) {
          final items = orders[tableName] ?? [];
          final total = items.fold<int>(0, (sum, e) => sum + e.total);

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text('${item.name} x${item.qty}'),
                        subtitle: Text(item.note.isEmpty ? 'Không ghi chú' : item.note),
                        trailing: Text(_formatMoney(item.total)),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng tạm tính', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(_formatMoney(total), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: FilledButton(
                  onPressed: items.isEmpty
                      ? null
                      : () async {
                          await api.addBill(restaurantName: restaurantName, tableName: tableName, total: total, itemCount: items.length);
                          final current = Map<String, List<OrderedItem>>.from(RestaurantStore.instance.tableOrders.value);
                          current[tableName] = <OrderedItem>[];
                          RestaurantStore.instance.tableOrders.value = current;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu bill vào lịch sử.')));
                          }
                        },
                  child: const Text('Chốt bill và lưu lịch sử'),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openAddOrderSheet(context), icon: const Icon(Icons.add), label: const Text('Thêm món')),
    );
  }
}

