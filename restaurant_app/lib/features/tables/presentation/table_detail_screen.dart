import 'package:flutter/material.dart';
import '../../../core/api/http_api_service.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/business_models.dart';
import '../../../shared/models/domain_models.dart';

class TableDetailScreen extends StatefulWidget {
  const TableDetailScreen({
    super.key,
    required this.tableName,
    this.tableId,
    required this.api,
    required this.restaurantName,
    required this.restaurantId,
    required this.user,
  });

  final String tableName;
  final String? tableId;
  final HttpApiService api;
  final String restaurantName;
  final String restaurantId;
  final UserAccount user;

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  List<MenuItemRecord> _menu = [];
  final List<Map<String, dynamic>> _currentOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getMenuItems(restaurantId: widget.restaurantId),
        if (widget.tableId != null)
          widget.api.getOrderItems(widget.restaurantId, tableId: widget.tableId)
        else
          Future.value(<KitchenTicket>[]),
      ]);

      final menuItems = results[0] as List<MenuItemRecord>;
      final activeItems = results[1] as List<KitchenTicket>;

      setState(() {
        _menu = menuItems;
        _currentOrders.clear();
        for (var item in activeItems) {
          _currentOrders.add({
            'id': item.id,
            'name': item.item,
            'qty': item.qty,
            'price': item.price,
            'total': item.price * item.qty,
            'note': item.note,
            'status': item.status,
          });
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _formatMoney(int value) => '${value.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ".")} đ';

  Future<void> _openAddOrderSheet() async {
    MenuItemRecord? selected;
    final qtyController = TextEditingController(text: '1');
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          selected ??= _menu.isNotEmpty ? _menu.first : null;
          return Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text('Thêm món cho bàn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<MenuItemRecord>(
                  value: selected,
                  items: _menu.map((e) => DropdownMenuItem(value: e, child: Text('${e.name} - ${_formatMoney(e.price)}'))).toList(),
                  onChanged: (value) => setModalState(() => selected = value),
                  decoration: const InputDecoration(labelText: 'Chọn món', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số lượng', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder())),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selected == null
                        ? null
                        : () async {
                            final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                            if (qty <= 0) return;

                            setState(() {
                              _currentOrders.add({
                                'name': selected!.name,
                                'qty': qty,
                                'price': selected!.price,
                                'total': selected!.price * qty,
                                'note': noteController.text.trim(),
                                'menuItemId': selected!.id.toString(),
                              });
                            });

                            // Gửi order xuống backend ngay lập tức nếu có tableId
                            if (widget.tableId != null) {
                              await widget.api.addOrderItem(
                                restaurantId: widget.restaurantId,
                                tableId: widget.tableId!,
                                menuItemId: selected!.id.toString(),
                                quantity: qty,
                                note: noteController.text.trim(),
                              );
                            }

                            // Cập nhật trạng thái bàn thành Đang phục vụ nếu là món đầu tiên
                            if (_currentOrders.length == 1 && widget.tableId != null) {
                              widget.api.updateTableStatus(widget.restaurantId, widget.tableId!, TableState.serving);
                            }

                            Navigator.pop(context);
                          },
                    child: const Text('Thêm vào bàn'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _currentOrders.fold<int>(0, (sum, e) => sum + (e['total'] as int));

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết ${widget.tableName}'),
        backgroundColor: const Color(0xFFE30D25),
        foregroundColor: Colors.white,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: _currentOrders.isEmpty
                    ? const Center(child: Text('Bàn trống. Nhấn + để thêm món.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _currentOrders.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = _currentOrders[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${item['name']} x${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(item['note'].toString().isEmpty ? 'Không ghi chú' : item['note']),
                            trailing: Text(_formatMoney(item['total'])),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng tiền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(_formatMoney(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE30D25))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (widget.user.canSeeBills)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE30D25)),
                          onPressed: _currentOrders.isEmpty
                              ? null
                              : () async {
                                  await widget.api.addBill(
                                    restaurantId: widget.restaurantId,
                                    tableName: widget.tableName,
                                    total: total,
                                    itemCount: _currentOrders.length,
                                    tableId: widget.tableId,
                                  );

                                  if (widget.tableId != null) {
                                    await widget.api.updateTableStatus(widget.restaurantId, widget.tableId!, TableState.empty);
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thanh toán và lưu hóa đơn.')));
                                    Navigator.pop(context);
                                  }
                                },
                          child: const Text('THANH TOÁN & TRẢ BÀN', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddOrderSheet,
        backgroundColor: const Color(0xFFE30D25),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
