import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../shell/app_shell.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabHeader(l.navOrders),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: navClearance(context)),
              child: EmptyState(
                icon: Icons.local_shipping_outlined,
                title: l.ordersEmptyTitle,
                body: l.ordersEmptyBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
