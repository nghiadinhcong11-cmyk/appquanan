import '../models/domain_models.dart';

const tables = <DiningTable>[
  DiningTable(name: 'Bàn 01', state: TableState.serving, guests: 4),
  DiningTable(name: 'Bàn 02', state: TableState.empty, guests: 0),
  DiningTable(name: 'Bàn 03', state: TableState.waitingPayment, guests: 2),
  DiningTable(name: 'Bàn 04', state: TableState.serving, guests: 6),
  DiningTable(name: 'Bàn 05', state: TableState.empty, guests: 0),
  DiningTable(name: 'Bàn 06', state: TableState.serving, guests: 3),
];

const kitchenTickets = <KitchenTicket>[
  KitchenTicket(table: 'Bàn 01', item: 'Bàn b?', qty: 2, status: 'ang n?u'),
  KitchenTicket(table: 'Bàn 04', item: 'Cm g', qty: 1, status: 'Ch? ra mn'),
  KitchenTicket(table: 'Bàn 06', item: 'Tr o', qty: 3, status: 'ang pha'),
];

const bills = <BillSummary>[
  BillSummary(table: 'Bàn 03', total: 420000, itemCount: 5),
  BillSummary(table: 'Bàn 01', total: 265000, itemCount: 4),
];
