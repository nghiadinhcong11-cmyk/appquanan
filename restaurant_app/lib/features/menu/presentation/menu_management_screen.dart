import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/business_models.dart';
import '../../../shared/store/restaurant_store.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key, required this.api, required this.restaurantName, required this.username});

  final HttpApiService api;
  final String restaurantName;
  final String username;

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  late Future<List<MenuItemRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getMenuItems(widget.restaurantName);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.getMenuItems(widget.restaurantName);
    });
  }

  String _formatMoney(int value) => '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';

  Future<void> _openAddMenuDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm món vào menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên món')),
            const SizedBox(height: 12),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá bán')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = int.tryParse(priceController.text.trim());
              if (name.isEmpty || price == null || price <= 0) return;
              await widget.api.addMenuItem(
                restaurantName: widget.restaurantName,
                name: name,
                price: price,
                createdBy: widget.username,
              );
              if (!mounted) return;
              Navigator.pop(context);
              await _reload();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MenuItemRecord>>(
      future: _future,
      builder: (context, snapshot) {
        final menu = snapshot.data ?? const <MenuItemRecord>[];
        RestaurantStore.instance.menuItems.value = menu.map((e) => MenuItemData(name: e.name, price: e.price)).toList();
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: menu.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = menu[index];
                  return Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text('Nhập bởi: ${item.createdBy}'),
                      trailing: Text(_formatMoney(item.price)),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _openAddMenuDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Thêm món'),
              ),
            ),
          ],
        );
      },
    );
  }
}

