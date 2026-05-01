import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/business_models.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, required this.api, required this.restaurantName});

  final HttpApiService api;
  final String restaurantName;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late Future<TodayStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.api.getTodayStats(widget.restaurantName);
  }

  String _formatMoney(int value) => '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _OverviewButton(icon: Icons.storefront, label: 'Tạo đơn tại chỗ', color: Color(0xFFC92E37)),
                  _OverviewButton(icon: Icons.delivery_dining, label: 'Tạo đơn mang đi', color: Color(0xFFE5A532)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<TodayStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final stats = snapshot.data ?? const TodayStats(billCount: 0, revenue: 0);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Thống kê trong ngày', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Text('Số bill: ${stats.billCount}'),
                      const SizedBox(height: 6),
                      Text('Doanh thu: ${_formatMoney(stats.revenue)}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewButton extends StatelessWidget {
  const _OverviewButton({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }
}

