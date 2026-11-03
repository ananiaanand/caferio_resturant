import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:caferio/providers/app_provider.dart';
import 'package:caferio/models/order.dart';
import 'package:caferio/models/menu_item.dart';
import 'package:caferio/utils/theme.dart';
import 'package:intl/intl.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  OrderStatus? _selectedStatus; // null means 'All'

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final allPending = provider.allOrders
        .where((o) => o.status.index < OrderStatus.served.index)
        .toList();

    // Counts for filter chips
    final receivedCount = allPending.where((o) => o.status == OrderStatus.received).length;
    final preparingCount = allPending.where((o) => o.status == OrderStatus.preparing).length;
    final halfDoneCount = allPending.where((o) => o.status == OrderStatus.halfDone).length;
    final completedCount = allPending.where((o) => o.status == OrderStatus.completed).length;

    // Filtered list
    final filteredOrders = _selectedStatus == null
        ? List<Order>.from(allPending)
        : allPending.where((o) => o.status == _selectedStatus).toList();

    // Sort by createdAt ascending (FIFO kitchen order: oldest tickets first)
    filteredOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final isPhone = MediaQuery.of(context).size.width < 650;

    return RefreshIndicator(
      onRefresh: () async => await provider.refreshOrders(),
      color: AppTheme.primaryColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 12.0 : 24.0,
          vertical: isPhone ? 12.0 : 20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPhone ? 'Active Tickets' : 'Pending Orders',
                        style: TextStyle(
                          fontSize: isPhone ? 20 : 30,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live kitchen preparation queue',
                        style: TextStyle(
                          fontSize: isPhone ? 12 : 15,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),

              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Status Filter Chips for Phone & Desktop
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All (${allPending.length})',
                    isSelected: _selectedStatus == null,
                    onTap: () => setState(() => _selectedStatus = null),
                    activeColor: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Received ($receivedCount)',
                    isSelected: _selectedStatus == OrderStatus.received,
                    onTap: () => setState(() => _selectedStatus = OrderStatus.received),
                    activeColor: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Preparing ($preparingCount)',
                    isSelected: _selectedStatus == OrderStatus.preparing,
                    onTap: () => setState(() => _selectedStatus = OrderStatus.preparing),
                    activeColor: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Half Done ($halfDoneCount)',
                    isSelected: _selectedStatus == OrderStatus.halfDone,
                    onTap: () => setState(() => _selectedStatus = OrderStatus.halfDone),
                    activeColor: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Ready ($completedCount)',
                    isSelected: _selectedStatus == OrderStatus.completed,
                    onTap: () => setState(() => _selectedStatus = OrderStatus.completed),
                    activeColor: Colors.green.shade700,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Orders list or grid
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedStatus == null ? Icons.check_circle_outline : Icons.filter_alt_off,
                              size: isPhone ? 60 : 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedStatus == null
                                  ? 'No pending orders! Kitchen is all caught up'
                                  : 'No orders in this stage',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isPhone ? 16 : 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pull down or tap refresh to check for new tickets',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : isPhone
                      // On phone: Natural dynamic-height list without nested scroll traps!
                      ? ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filteredOrders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            return _OrderTicketCard(
                              order: filteredOrders[index],
                              provider: provider,
                              isPhone: true,
                            );
                          },
                        )
                      // On tablet / desktop: Responsive Grid
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 440,
                            mainAxisExtent: 400,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            return _OrderTicketCard(
                              order: filteredOrders[index],
                              provider: provider,
                              isPhone: false,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }
}

class _OrderTicketCard extends StatefulWidget {
  final Order order;
  final AppProvider provider;
  final bool isPhone;

  const _OrderTicketCard({
    required this.order,
    required this.provider,
    required this.isPhone,
  });

  @override
  State<_OrderTicketCard> createState() => _OrderTicketCardState();
}

class _OrderTicketCardState extends State<_OrderTicketCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final provider = widget.provider;
    final isPhone = widget.isPhone;

    final shortId = order.id.length > 4
        ? order.id.substring(order.id.length - 4)
        : order.id;

    // Elapsed time calculation
    final diff = DateTime.now().difference(order.createdAt);
    final String elapsedText;
    final bool isDelayed;
    if (diff.inMinutes < 1) {
      elapsedText = 'Just now';
      isDelayed = false;
    } else if (diff.inMinutes < 60) {
      elapsedText = '${diff.inMinutes}m ago';
      isDelayed = diff.inMinutes >= 15;
    } else {
      elapsedText = '${diff.inHours}h ${diff.inMinutes % 60}m ago';
      isDelayed = true;
    }

    // Customer display
    final customerDisplay = (order.customerId != null && order.customerId!.isNotEmpty)
        ? order.customerId!.replaceFirst('usr_', '@')
        : null;

    final statusColor = _getStatusColor(order.status);
    final itemsToShow = (isPhone && !_expanded && order.items.length > 4)
        ? order.items.take(4).toList()
        : order.items;

    Widget cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: isPhone ? MainAxisSize.min : MainAxisSize.max,
      children: [
        // Top row: Order # & Status Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Order #$shortId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  if (customerDisplay != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          customerDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getStatusIcon(order.status), size: 14, color: statusColor),
                  const SizedBox(width: 5),
                  Text(
                    _getStatusText(order.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Time, elapsed chip & items count
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              DateFormat('hh:mm a').format(order.createdAt),
              style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDelayed ? Colors.red.shade50 : Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDelayed ? Icons.alarm_on : Icons.access_time,
                    size: 13,
                    color: isDelayed ? Colors.red.shade700 : AppTheme.textLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    elapsedText,
                    style: TextStyle(
                      color: isDelayed ? Colors.red.shade700 : AppTheme.textLight,
                      fontSize: 12,
                      fontWeight: isDelayed ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '• ${order.items.length} ${order.items.length == 1 ? "dish" : "dishes"}',
              style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Mini Step Progress Bar
        _buildProgressBar(order.status),

        const Divider(height: 20),

        // Items list: on phone, direct column so no scroll clashing!
        if (isPhone) ...[
          ...itemsToShow.map((item) => _buildItemRow(item)),
          if (order.items.length > 4)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded
                          ? 'Show fewer items'
                          : '+${order.items.length - 4} more items',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
        ] else ...[
          Expanded(
            child: ListView.builder(
              itemCount: order.items.length,
              itemBuilder: (context, idx) => _buildItemRow(order.items[idx]),
            ),
          ),
        ],

        const Divider(height: 20),

        // Action button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => provider.advanceOrderStatus(order.id),
            icon: Icon(_getNextActionIcon(order.status), size: 20),
            label: Text(
              _getNextActionText(order.status),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getActionBtnColor(order.status),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: cardBody,
      ),
    );
  }

  Widget _buildItemRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.menuItem.name,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(OrderStatus status) {
    final steps = [
      OrderStatus.received,
      OrderStatus.preparing,
      OrderStatus.halfDone,
      OrderStatus.completed,
    ];
    final currentIndex = steps.indexOf(status);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepBefore = i ~/ 2;
          final isPassed = currentIndex > stepBefore;
          return Expanded(
            child: Container(
              height: 3,
              color: isPassed ? AppTheme.primaryColor : Colors.grey.shade200,
            ),
          );
        } else {
          final stepIndex = i ~/ 2;
          final isCurrent = stepIndex == currentIndex;
          final isPassed = stepIndex <= currentIndex;
          return Container(
            width: isCurrent ? 12 : 8,
            height: isCurrent ? 12 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? AppTheme.primaryColor
                  : (isPassed ? AppTheme.primaryColor.withValues(alpha: 0.6) : Colors.grey.shade300),
            ),
          );
        }
      }),
    );
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.received: return Icons.receipt;
      case OrderStatus.preparing: return Icons.soup_kitchen;
      case OrderStatus.halfDone: return Icons.timelapse;
      case OrderStatus.completed: return Icons.check_circle;
      case OrderStatus.served: return Icons.done_all;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.received: return Colors.blue.shade700;
      case OrderStatus.preparing: return Colors.orange.shade800;
      case OrderStatus.halfDone: return Colors.amber.shade900;
      case OrderStatus.completed: return Colors.green.shade700;
      case OrderStatus.served: return Colors.grey;
    }
  }

  Color _getActionBtnColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.received: return Colors.orange.shade800;
      case OrderStatus.preparing: return Colors.amber.shade900;
      case OrderStatus.halfDone: return Colors.green.shade700;
      case OrderStatus.completed: return Colors.teal.shade700;
      case OrderStatus.served: return Colors.grey;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.received: return 'Received';
      case OrderStatus.preparing: return 'Preparing';
      case OrderStatus.halfDone: return 'Half Done';
      case OrderStatus.completed: return 'Ready';
      case OrderStatus.served: return 'Served';
    }
  }

  IconData _getNextActionIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.received: return Icons.soup_kitchen;
      case OrderStatus.preparing: return Icons.hourglass_bottom;
      case OrderStatus.halfDone: return Icons.check_circle_outline;
      case OrderStatus.completed: return Icons.done_all;
      case OrderStatus.served: return Icons.check;
    }
  }

  String _getNextActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.received: return 'Start Preparing';
      case OrderStatus.preparing: return 'Mark Half Done';
      case OrderStatus.halfDone: return 'Mark Ready to Serve';
      case OrderStatus.completed: return 'Mark as Served';
      case OrderStatus.served: return '';
    }
  }
}
