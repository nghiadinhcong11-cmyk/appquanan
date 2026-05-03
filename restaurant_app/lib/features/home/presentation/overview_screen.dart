import 'package:flutter/material.dart';

import '../../../core/api/http_api_service.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/business_models.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
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
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late Future<TodayStats>? _statsFuture;

  @override
  void initState() {
    super.initState();
    if (widget.user.canSeeReports) {
      _statsFuture = widget.api.getTodayStats(restaurantId: widget.restaurantId);
    } else {
      _statsFuture = null;
    }
  }

  String _formatMoney(int value) => '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')} đ';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final stats = snapshot.data ?? const TodayStats(billCount: 0, revenue: 0);
              return Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Thống kê trong ngày', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Số bill: ${stats.billCount}'),
                              Text('Doanh thu: ${_formatMoney(stats.revenue)}',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (stats.hourlyRevenue.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Doanh thu theo giờ', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 150,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: stats.hourlyRevenue.map((h) {
                                  final double maxRev = stats.hourlyRevenue
                                      .map((e) => e.total)
                                      .reduce((a, b) => a > b ? a : b)
                                      .toDouble();
                                  final double heightFactor = maxRev > 0 ? h.total / maxRev : 0;
                                  return Tooltip(
                                    message: '${h.hour}h: ${_formatMoney(h.total)}',
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 100 * heightFactor,
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('${h.hour}h', style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (stats.popularItems.isNotEmpty)
                    Card( 
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Món bán chạy nhất (Hôm nay)', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            ...stats.popularItems.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(item.name)),
                                      Text('${item.quantity} phần', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                ],
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

