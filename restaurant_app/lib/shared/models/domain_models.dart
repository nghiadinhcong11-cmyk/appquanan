enum TableState { empty, serving, waitingPayment }

class DiningTable {
  const DiningTable({required this.name, required this.state, required this.guests});

  final String name;
  final TableState state;
  final int guests;
}

class KitchenTicket {
  const KitchenTicket({required this.table, required this.item, required this.qty, required this.status});

  final String table;
  final String item;
  final int qty;
  final String status;
}

class BillSummary {
  const BillSummary({required this.table, required this.total, required this.itemCount});

  final String table;
  final int total;
  final int itemCount;
}
