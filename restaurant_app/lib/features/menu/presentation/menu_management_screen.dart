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
    final descController = TextEditingController();
    final imageController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm món vào menu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên món')),
              const SizedBox(height: 12),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá bán')),
              const SizedBox(height: 12),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Mô tả (không bắt buộc)')),
              const SizedBox(height: 12),
              TextField(controller: imageController, decoration: const InputDecoration(labelText: 'Link hình ảnh (không bắt buộc)')),
            ],
          ),
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
                description: descController.text.trim(),
                imageUrl: imageController.text.trim(),
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
                      leading: item.imageUrl.isNotEmpty
                        ? Image.network(item.imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood))
                        : const Icon(Icons.fastfood),
                      title: Text(item.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.description.isNotEmpty) Text(item.description, style: const TextStyle(fontSize: 12)),
                          Text('Nhập bởi: ${item.createdBy}', style: const TextStyle(fontSize: 10)),
                        ],
                      ),
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

