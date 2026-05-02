enum TableState { empty, serving, waitingPayment }

class DiningTable {
  const DiningTable({this.id, required this.name, required this.state, this.guests = 0});

  final String? id;
  final String name;
  final TableState state;
  final int guests;

  static DiningTable fromMap(Map<String, dynamic> map) {
    TableState state = TableState.empty;
    switch (map['status']) {
      case 'serving': state = TableState.serving; break;
      case 'waiting_payment': state = TableState.waitingPayment; break;
    }
    return DiningTable(
      id: map['id']?.toString(),
      name: map['name'] as String,
      state: state,
    );
  }
}

class KitchenTicket {
  const KitchenTicket({this.id, required this.table, required this.item, required this.qty, required this.status, this.note = '', this.price = 0});

  final String? id;
  final String table;
  final String item;
  final int qty;
  final String status;
  final String note;
  final int price;
}

class BillSummary {
  const BillSummary({required this.table, required this.total, required this.itemCount});

  final String table;
  final int total;
  final int itemCount;
}
