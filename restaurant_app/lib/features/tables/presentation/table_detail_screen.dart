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

  @override
  // ignore: unused_element
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getMenuItems(restaurantId: widget.restaurantId),
        if (widget.tableId != null)
          widget.api.getOrderItems(widget.restaurantId, tableId: widget.tableId, includeBilled: true)
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          selected ??= _menu.isNotEmpty ? _menu.first : null;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_shopping_cart, color: Color(0xFFE30D25)),
                    const SizedBox(width: 8),
                    const Text('Thêm món vào bàn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                DropdownButtonFormField<MenuItemRecord>(
                  value: selected,
                  items: _menu.map((e) => DropdownMenuItem(value: e, child: Text('${e.name} - ${_formatMoney(e.price)}'))).toList(),
                  onChanged: (value) => setModalState(() => selected = value),
                  decoration: InputDecoration(
                    labelText: 'Chọn món',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.restaurant_menu),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số lượng',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.exposure_plus_1),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.note_add_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
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

                          if (widget.tableId != null) {
                            await widget.api.addOrderItem(
                              restaurantId: widget.restaurantId,
                              tableId: widget.tableId!,
                              menuItemId: selected!.id.toString(),
                              quantity: qty,
                              note: noteController.text.trim(),
                            );
                          }

                          if (_currentOrders.length == 1 && widget.tableId != null) {
                            widget.api.updateTableStatus(widget.restaurantId, widget.tableId!, TableState.serving);
                          }

                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE30D25),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Thêm vào bàn', style: TextStyle(fontWeight: FontWeight.bold)),
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
