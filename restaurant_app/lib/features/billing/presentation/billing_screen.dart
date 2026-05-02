import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/business_models.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, required this.api, required this.restaurantName, required this.restaurantId});

  final HttpApiService api;
  final String restaurantName;
  final String restaurantId;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late Future<List<BillRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getBills(restaurantId: widget.restaurantId);
  }

  String _formatMoney(int value) => '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.getBills(restaurantId: widget.restaurantId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BillRecord>>(
      future: _future,
      builder: (context, snapshot) {
        final bills = snapshot.data ?? const <BillRecord>[];
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final bill = bills[index];
              return Card(
                child: ListTile(
                  title: Text(bill.tableName),
                  subtitle: Text('${bill.itemCount} món • ${bill.createdAt.hour.toString().padLeft(2, '0')}:${bill.createdAt.minute.toString().padLeft(2, '0')}'),
                  trailing: Text(_formatMoney(bill.total), style: Theme.of(context).textTheme.titleMedium),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: bills.length,
          ),
        );
      },
    );
  }
}

