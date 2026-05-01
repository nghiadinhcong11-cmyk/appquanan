import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: 'Bàn 01',
          items: const [
            DropdownMenuItem(value: 'Bàn 01', child: Text('Bàn 01')),
            DropdownMenuItem(value: 'Bàn 04', child: Text('Bàn 04')),
          ],
          onChanged: (_) {},
          decoration: const InputDecoration(labelText: 'Chọn bàn'),
        ),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: 'Món')),
        const SizedBox(height: 12),
        const TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Số lượng')),
        const SizedBox(height: 12),
        const TextField(maxLines: 2, decoration: InputDecoration(labelText: 'Ghi chú')),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.sync), label: const Text('Gửi xuống bếp')),
      ],
    );
  }
}
