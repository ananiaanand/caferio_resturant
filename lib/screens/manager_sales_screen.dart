import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ManagerSalesScreen extends StatefulWidget {
  const ManagerSalesScreen({Key? key}) : super(key: key);

  @override
  State<ManagerSalesScreen> createState() => _ManagerSalesScreenState();
}

class _ManagerSalesScreenState extends State<ManagerSalesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPeriod = 0;

  final List<Map<String, dynamic>> _topItems = [
    {'name': 'Nadan Beef Roast', 'sold': 342, 'revenue': '₹68,400', 'fraction': 0.92},
    {'name': 'Kerala Parotta', 'sold': 285, 'revenue': '₹34,200', 'fraction': 0.80},
    {'name': 'Chicken 65', 'sold': 210, 'revenue': '₹42,000', 'fraction': 0.65},
    {'name': 'Fish Curry', 'sold': 178, 'revenue': '₹35,600', 'fraction': 0.52},
    {'name': 'Egg Fried Rice', 'sold': 145, 'revenue': '₹21,750', 'fraction': 0.43},
    {'name': 'Mutton Biryani', 'sold': 118, 'revenue': '₹35,400', 'fraction': 0.35},
    {'name': 'Prawn Masala', 'sold': 97, 'revenue': '₹29,100', 'fraction': 0.29},
  ];

  final List<Map<String, dynamic>> _transactions = [
    {'id': '#4821', 'time': '12:34 PM', 'items': 'Beef Roast, Parotta x2', 'amount': '₹485', 'status': 'paid'},
    {'id': '#4820', 'time': '12:18 PM', 'items': 'Chicken 65, Rice', 'amount': '₹320', 'status': 'paid'},
    {'id': '#4819', 'time': '12:02 PM', 'items': 'Fish Curry, Naan x3', 'amount': '₹560', 'status': 'paid'},
    {'id': '#4818', 'time': '11:47 AM', 'items': 'Mutton Biryani', 'amount': '₹300', 'status': 'paid'},
    {'id': '#4817', 'time': '11:30 AM', 'items': 'Prawn Masala, Rice', 'amount': '₹420', 'status': 'pending'},
    {'id': '#4816', 'time': '11:15 AM', 'items': 'Parotta x4, Egg Curry', 'amount': '₹380', 'status': 'paid'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Sales',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined, color: AppColors.primary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.onSurfaceVariant), onPressed: () {}),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Performance'),
            Tab(text: 'Transactions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPerformanceTab(),
          _buildTransactionsTab(),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['Today', 'This Week', 'This Month'].asMap().entries.map((e) {
                final sel = _selectedPeriod == e.key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPeriod = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        e.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sel ? Colors.white : AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // KPI cards
          Row(
            children: [
              Expanded(child: _buildKpiCard('Total Revenue', _selectedPeriod == 0 ? '₹42,850' : _selectedPeriod == 1 ? '₹2.94L' : '₹12.85L', Icons.payments_outlined, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Orders', _selectedPeriod == 0 ? '148' : _selectedPeriod == 1 ? '1,036' : '4,440', Icons.receipt_long_outlined, AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildKpiCard('Avg Order', '₹289', Icons.shopping_basket_outlined, const Color(0xFF575757))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Growth', '+12.4%', Icons.trending_up, Colors.green)),
            ],
          ),
          const SizedBox(height: 28),

          // Bar chart
          Text('Peak Sales Hours', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceContainer),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBar(0.4, '11AM', false),
                      _buildBar(0.6, '12PM', false),
                      _buildBar(1.0, '1PM', true),
                      _buildBar(0.75, '2PM', false),
                      _buildBar(0.5, '5PM', false),
                      _buildBar(0.85, '7PM', false),
                      _buildBar(0.7, '9PM', false),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Top selling items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Top Selling Items', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: const Text('Full Report', style: TextStyle(color: AppColors.primary))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceContainer),
            ),
            child: Column(
              children: _topItems.asMap().entries.map((e) {
                final item = e.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: e.key < _topItems.length - 1 ? 18 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.2), shape: BoxShape.circle),
                                child: Center(child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary))),
                              ),
                              const SizedBox(width: 8),
                              Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(item['revenue'] as String, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${item['sold']} sold', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (item['fraction'] as double),
                          backgroundColor: AppColors.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 28),

          // Inventory turnover & supplier reliability
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Inv. Turnover', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Icon(Icons.trending_up, color: AppColors.primary, size: 18),
                      ]),
                      const SizedBox(height: 12),
                      const Text('842kg / week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: 0.75, backgroundColor: AppColors.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary), minHeight: 6, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 6),
                      const Text('+12% vs last week', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Icon(Icons.verified, color: Color(0xFF7b5800), size: 18),
                      ]),
                      const SizedBox(height: 12),
                      const Text('94% Reliable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: 0.94, backgroundColor: AppColors.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7b5800)), minHeight: 6, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 6),
                      const Text('On-time deliveries', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${_transactions.length} orders today', style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 16),
        ..._transactions.map((t) => _buildTransactionRow(t)).toList(),
      ],
    );
  }

  Widget _buildTransactionRow(Map<String, dynamic> t) {
    final isPaid = t['status'] == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.15), shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.receipt_long, color: AppColors.primary, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(t['id'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(t['amount'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                ]),
                const SizedBox(height: 3),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(t['items'] as String, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.shade50 : AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isPaid ? 'Paid' : 'Pending',
                        style: TextStyle(color: isPaid ? Colors.green.shade700 : AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(t['time'] as String, style: const TextStyle(color: AppColors.outline, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: color, size: 20),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        ],
      ),
    );
  }

  Widget _buildBar(double fraction, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: FractionallySizedBox(
                  heightFactor: fraction,
                  child: Container(
                    width: 28,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : AppColors.primaryContainer.withOpacity(0.4),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
