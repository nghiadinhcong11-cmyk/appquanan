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
  List<DiningTable> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    if (widget.restaurantId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final list = await widget.api.getTables(widget.restaurantId);
      setState(() {
        _tables = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tables: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTable() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm bàn mới'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Tên bàn (vd: Bàn 10)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await widget.api.addTable(widget.restaurantId, name);
        _loadTables();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
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
                      const _Chip(text: 'Tất cả', selected: true),
                      const _Chip(text: 'Tầng 1'),
                      const _Chip(text: 'Sân vườn'),
                      if (widget.user.canManageInventory)
                        IconButton(
                          onPressed: _addTable,
                          icon: const Icon(Icons.add_circle, color: Color(0xFFE30D25)),
                          tooltip: 'Thêm bàn',
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
                  : _tables.isEmpty
                      ? const Center(child: Text('Chưa có bàn nào. Nhấn + để thêm.'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _tables.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                          itemBuilder: (context, index) {
                            final table = _tables[index];
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
                                      restaurantId: widget.restaurantId,
                                      user: widget.user,
                                    ),
                                  ),
                                );
                                _loadTables(); // Refresh khi quay lại
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _statusColor(table.state),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: table.state == TableState.empty
                                            ? const Color(0xFF949494)
                                            : const Color(0xFFE30D25),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                      ),
                                      child: Text(
                                        table.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _statusText(table.state),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: table.state == TableState.empty ? Colors.black54 : Colors.white,
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
  const _Chip({required this.text, this.selected = false});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
