import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.navOrders)),
      body: EmptyState(title: l.ordersEmptyTitle, body: l.ordersEmptyBody),
    );
  }
}
