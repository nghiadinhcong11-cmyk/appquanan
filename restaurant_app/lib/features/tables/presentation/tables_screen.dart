import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/domain_models.dart';
import 'table_detail_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({
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
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRestaurantId;
  String _selectedRestaurantName = '';
  List<DiningTable> _tables = [];
  bool _isLoading = true;
  String _selectedFloor = 'all';

  @override
  void initState() {
    super.initState();
    _selectedRestaurantId = widget.restaurantId.isNotEmpty ? widget.restaurantId : null;
    _selectedRestaurantName = widget.restaurantName;
    _loadTables();
  }

  int _floorNumber(DiningTable table) => table.floor;

  String _floorLabel(int floor) => 'Tầng $floor';

  Future<void> _saveLocalDrafts() async {
    final drafts = _tables.where((t) => t.isTemporary).toList();
    final restaurantId = _selectedRestaurantId ?? widget.restaurantId;
    if (drafts.isEmpty || restaurantId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      for (final t in drafts) {
        await widget.api.addTable(
          restaurantId: restaurantId,
          tableName: t.name,
          floor: t.floor,
          isTemporary: false,
        );
      }
      await _loadTables();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu ${drafts.length} bàn local lên hệ thống')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lưu bản nháp: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTables() async {
    final restaurantId = _selectedRestaurantId ?? widget.restaurantId;
    if (restaurantId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final list = await widget.api.getTables(restaurantId);
      setState(() {
        _tables = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tables: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddTableSheet() async {
    final restaurantId = _selectedRestaurantId ?? widget.restaurantId;
    if (restaurantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn cơ sở')),
      );
      return;
    }

    final nameController = TextEditingController();
    final floorController = TextEditingController(text: '1');

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
                const Icon(Icons.add_circle_outline, color: Color(0xFFE30D25)),
                const SizedBox(width: 8),
                const Text('Thêm bàn mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Tên bàn',
                hintText: 'VD: Bàn 10, VIP 1...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.table_restaurant),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: floorController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tầng / Khu vực',
                hintText: 'Nhập số tầng (VD: 1, 2)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.layers),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final floor = int.tryParse(floorController.text.trim()) ?? 1;
                      if (name.isEmpty) return;
                      setState(() {
                        _tables = [
                          DiningTable(
                            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            state: TableState.empty,
                            floor: floor,
                            isTemporary: true,
                          ),
                          ..._tables,
                        ];
                      });
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Lưu tạm'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final floor = int.tryParse(floorController.text.trim()) ?? 1;
                      if (name.isEmpty) return;
                      await widget.api.addTable(
                        restaurantId: restaurantId,
                        tableName: name,
                        floor: floor,
                        isTemporary: false,
                      );
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      await _loadTables();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE30D25),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Lưu hệ thống'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRestaurant() async {
    final list = await widget.api.getPublicRestaurants(search: '');
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final r = list[i];
          return ListTile(
            title: Text((r['name'] ?? '').toString()),
            subtitle: Text('ID: ${(r['id'] ?? '').toString()}'),
            onTap: () {
              setState(() {
                _selectedRestaurantId = (r['id'] ?? '').toString();
                _selectedRestaurantName = (r['name'] ?? '').toString();
              });
              Navigator.pop(ctx);
              _loadTables();
            },
          );
        },
      ),
    );
  }

  Color _statusColor(TableState state) {
    switch (state) {
      case TableState.empty:
        return const Color(0xFFE7E7E7);
      case TableState.serving:
        return const Color(0xFFF35A66);
      case TableState.waitingPayment:
        return const Color(0xFF9FA2A8);
    }
  }

  String _statusText(TableState state) {
    switch (state) {
      case TableState.empty:
        return 'Trống';
      case TableState.serving:
        return 'Đang phục vụ';
      case TableState.waitingPayment:
        return 'Chờ thanh toán';
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchController.text.trim().toLowerCase();
    final floorSet = _tables.map(_floorNumber).toSet().toList()..sort();

    final filtered = _tables.where((t) {
      final passKeyword = keyword.isEmpty || t.name.toLowerCase().contains(keyword);
      final passFloor = _selectedFloor == 'all' || _floorLabel(_floorNumber(t)) == _selectedFloor;
      return passKeyword && passFloor;
    }).toList();
    final draftCount = _tables.where((t) => t.isTemporary).length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if ((_selectedRestaurantId ?? widget.restaurantId).isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _pickRestaurant,
                      icon: const Icon(Icons.storefront),
                      label: const Text('Chọn cơ sở để quản lý bàn'),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cơ sở: ${_selectedRestaurantName.isEmpty ? widget.restaurantName : _selectedRestaurantName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên bàn',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip(
                        text: 'Tất cả',
                        selected: _selectedFloor == 'all',
                        onTap: () => setState(() => _selectedFloor = 'all'),
                      ),
                      ...floorSet.map((f) {
                        final label = _floorLabel(f);
                        return _Chip(
                          text: label,
                          selected: _selectedFloor == label,
                          onTap: () => setState(() => _selectedFloor = label),
                        );
                      }),
                      if (widget.user.canManageInventory)
                        IconButton(
                          onPressed: _openAddTableSheet,
                          icon: const Icon(Icons.add_circle, color: Color(0xFFE30D25)),
                          tooltip: 'Thêm bàn',
                        ),
                      if (widget.user.canManageInventory && draftCount > 0)
                        TextButton(
                          onPressed: _saveLocalDrafts,
                          child: Text('Lưu $draftCount bản nháp'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTables,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('Chưa có bàn nào. Nhấn + để thêm.'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final table = filtered[index];
                            return InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TableDetailScreen(
                                      tableName: table.name,
                                      tableId: table.id,
                                      api: widget.api,
                                      restaurantName: widget.restaurantName,
                                      restaurantId: _selectedRestaurantId ?? widget.restaurantId,
                                      user: widget.user,
                                    ),
                                  ),
                                );
                                _loadTables();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _statusColor(table.state),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      decoration: BoxDecoration(
                                        color: table.state == TableState.empty
                                            ? const Color(0xFF949494)
                                            : const Color(0xFFE30D25),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                      ),
                                      child: Text(
                                        table.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.table_restaurant_outlined,
                                      size: 18,
                                      color: table.state == TableState.empty ? Colors.black26 : Colors.white70,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _statusText(table.state),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                        color: table.state == TableState.empty ? Colors.black54 : Colors.white,
                                      ),
                                    ),
                                    Text(
                                      table.isTemporary ? 'Draft' : _floorLabel(_floorNumber(table)),
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: table.state == TableState.empty ? Colors.black38 : Colors.white70,
                                      ),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.selected = false, this.onTap});

  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE30D25) : Colors.white,
          border: Border.all(color: const Color(0xFFE30D25)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFE30D25),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
