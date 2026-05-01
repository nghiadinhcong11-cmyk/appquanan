import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/models/domain_models.dart';
import 'table_detail_screen.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key, required this.api, required this.restaurantName});

  final HttpApiService api;
  final String restaurantName;

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
    return Column(
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Chip(text: 'Bàn ngoài', selected: true),
                    _Chip(text: 'Tầng 1'),
                    _Chip(text: 'VIP'),
                    _Chip(text: 'Tầng 2'),
                    _Chip(text: 'Tầng 3'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              itemCount: tables.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final table = tables[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TableDetailScreen(tableName: table.name, api: api, restaurantName: restaurantName),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _statusColor(table.state),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF949494),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          child: Text(table.name.replaceAll('Bàn ', 'N'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        const Spacer(),
                        Text(_statusText(table.state), style: const TextStyle(fontWeight: FontWeight.w600)),
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
      child: Text(text, style: TextStyle(color: selected ? Colors.white : const Color(0xFFE30D25))),
    );
  }
}

