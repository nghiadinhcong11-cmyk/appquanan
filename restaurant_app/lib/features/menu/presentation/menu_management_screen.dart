import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/business_models.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({
    super.key,
    required this.api,
    required this.restaurantName,
    required this.restaurantId,
    required this.user,
  });

  final HttpApiService api;
  final String restaurantName;
  final String restaurantId;
  final UserAccount user;

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _keywordController = TextEditingController();
  final _searchRestaurantController = TextEditingController();

  List<Map<String, dynamic>> _restaurants = const [];
  List<MenuItemRecord> _menu = const [];
  bool _loadingRestaurants = false;
  bool _loadingMenu = false;
  String? _error;

  String? _selectedRestaurantId;
  String _selectedRestaurantName = '';

  bool get _canManageMenu => widget.user.canManageInventory;

  String? get _effectiveRestaurantId {
    if (widget.restaurantId.isNotEmpty) return widget.restaurantId;
    return _selectedRestaurantId;
  }

  @override
  void initState() {
    super.initState();
    _selectedRestaurantId = widget.restaurantId.isNotEmpty ? widget.restaurantId : null;
    _selectedRestaurantName = widget.restaurantName;
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (_effectiveRestaurantId == null || _effectiveRestaurantId!.isEmpty) {
      await _loadRestaurants();
      return;
    }
    await _loadMenu();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _loadingRestaurants = true;
      _error = null;
    });
    try {
      final data = await widget.api.getPublicRestaurants(search: _searchRestaurantController.text.trim());
      setState(() => _restaurants = data);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingRestaurants = false);
    }
  }

  Future<void> _loadMenu() async {
    final restaurantId = _effectiveRestaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      setState(() => _error = 'Vui lòng chọn cơ sở');
      return;
    }

    setState(() {
      _loadingMenu = true;
      _error = null;
    });

    try {
      final items = await widget.api.getMenuByContext(
        restaurantId: restaurantId,
        user: widget.user,
        keyword: _keywordController.text.trim(),
      );
      setState(() => _menu = items);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingMenu = false);
    }
  }

  String _formatMoney(int value) => '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';

  Future<void> _openAddOrEditDialog({MenuItemRecord? editItem}) async {
    final nameController = TextEditingController(text: editItem?.name ?? '');
    final priceController = TextEditingController(text: editItem?.price.toString() ?? '');
    final descController = TextEditingController(text: editItem?.description ?? '');
    final imageController = TextEditingController(text: editItem?.imageUrl ?? '');

    final restaurantId = _effectiveRestaurantId;
    if (restaurantId == null || restaurantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn cơ sở')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(editItem == null ? Icons.add_circle_outline : Icons.edit_note, color: const Color(0xFFE30D25)),
                const SizedBox(width: 8),
                Text(
                  editItem == null ? 'Thêm món mới' : 'Chỉnh sửa món ăn',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Tên món ăn',
                hintText: 'VD: Phở bò, Cơm tấm...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.restaurant),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Giá bán (VNĐ)',
                hintText: 'VD: 35000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Mô tả ngắn',
                hintText: 'Thành phần, hương vị...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: imageController,
              decoration: InputDecoration(
                labelText: 'Link hình ảnh',
                hintText: 'https://...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = int.tryParse(priceController.text.trim());
                if (name.isEmpty || price == null || price <= 0) return;

                if (editItem == null) {
                  await widget.api.createPrivateMenuItem(
                    restaurantId: restaurantId,
                    name: name,
                    price: price,
                    description: descController.text.trim(),
                    imageUrl: imageController.text.trim(),
                  );
                } else {
                  await widget.api.updatePrivateMenuItem(
                    restaurantId: restaurantId,
                    menuId: editItem.id.toString(),
                    name: name,
                    price: price,
                    description: descController.text.trim(),
                    imageUrl: imageController.text.trim(),
                  );
                }

                if (!mounted) return;
                Navigator.pop(ctx);
                await _loadMenu();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE30D25),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu thông tin', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(MenuItemRecord item) async {
    final restaurantId = _effectiveRestaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;

    await widget.api.deletePrivateMenuItem(
      restaurantId: restaurantId,
      menuId: item.id.toString(),
    );
    await _loadMenu();
  }

  @override
  Widget build(BuildContext context) {
    final restaurantId = _effectiveRestaurantId;
    final requireSelectRestaurant = restaurantId == null || restaurantId.isEmpty;

    if (requireSelectRestaurant) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Vui lòng chọn cơ sở', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchRestaurantController,
              decoration: InputDecoration(
                labelText: 'Tìm nhà hàng',
                suffixIcon: IconButton(onPressed: _loadRestaurants, icon: const Icon(Icons.search)),
              ),
              onSubmitted: (_) => _loadRestaurants(),
            ),
            const SizedBox(height: 12),
            if (_loadingRestaurants) const LinearProgressIndicator(),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _restaurants.length,
                itemBuilder: (context, index) {
                  final r = _restaurants[index];
                  return ListTile(
                    title: Text((r['name'] ?? '').toString()),
                    subtitle: Text('ID: ${(r['id'] ?? '').toString()}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      setState(() {
                        _selectedRestaurantId = (r['id'] ?? '').toString();
                        _selectedRestaurantName = (r['name'] ?? '').toString();
                      });
                      await _loadMenu();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cơ sở: ${_selectedRestaurantName.isEmpty ? widget.restaurantName : _selectedRestaurantName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.restaurantId.isEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedRestaurantId = null;
                          _selectedRestaurantName = '';
                          _menu = const [];
                        });
                        _loadRestaurants();
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Đổi cơ sở'),
                    ),
                ],
              ),
              TextField(
                controller: _keywordController,
                decoration: InputDecoration(
                  hintText: 'Tìm món theo tên',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(onPressed: _loadMenu, icon: const Icon(Icons.send)),
                ),
                onSubmitted: (_) => _loadMenu(),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _canManageMenu ? 'Private Menu (có quyền quản lý)' : 'Public Menu (chỉ xem)',
                  style: TextStyle(
                    color: _canManageMenu ? Colors.green[700] : Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_loadingMenu) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _menu.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _menu[index];
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
                  trailing: _canManageMenu
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _openAddOrEditDialog(editItem: item);
                            } else if (value == 'delete') {
                              await _deleteItem(item);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Sửa')),
                            PopupMenuItem(value: 'delete', child: Text('Xóa')),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(_formatMoney(item.price)),
                          ),
                        )
                      : Text(_formatMoney(item.price)),
                ),
              );
            },
          ),
        ),
        if (_canManageMenu)
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _openAddOrEditDialog,
              icon: const Icon(Icons.add),
              label: const Text('Thêm món'),
            ),
          ),
      ],
    );
  }
}
