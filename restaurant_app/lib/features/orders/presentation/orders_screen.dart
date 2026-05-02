import 'package:flutter/material.dart';
import '../../../core/api/http_api_service.dart';
import '../../../shared/models/domain_models.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.api, required this.restaurantId});

  final HttpApiService api;
  final String restaurantId;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<KitchenTicket> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await widget.api.getOrderItems(widget.restaurantId);
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _updateStatus(KitchenTicket item, String newStatus) async {
    if (item.id == null) return;
    try {
      await widget.api.updateOrderItemStatus(widget.restaurantId, item.id!, newStatus);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'preparing': return Colors.blue;
      case 'ready': return Colors.green;
      case 'served': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.black;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Chờ duyệt';
      case 'preparing': return 'Đang chế biến';
      case 'ready': return 'Chờ cung ứng';
      case 'served': return 'Đã phục vụ';
      case 'cancelled': return 'Đã hủy';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Order / Bếp'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Không có order nào.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      child: ListTile(
                        title: Text('${item.table}: ${item.item} x${item.qty}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.note.isNotEmpty) Text('Ghi chú: ${item.note}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(item.status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusText(item.status),
                                style: TextStyle(color: _getStatusColor(item.status), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) => _updateStatus(item, val),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'preparing', child: Text('Bắt đầu làm')),
                            const PopupMenuItem(value: 'ready', child: Text('Xong (Chờ bưng)')),
                            const PopupMenuItem(value: 'served', child: Text('Đã bưng')),
                            const PopupMenuItem(value: 'cancelled', child: Text('Hủy món')),
                          ],
                          icon: const Icon(Icons.more_vert),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
