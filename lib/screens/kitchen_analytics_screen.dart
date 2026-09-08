import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/cart_provider.dart';
import '../providers/ingredient_provider.dart';
import '../services/ingredient_prediction_service.dart';

class KitchenAnalyticsScreen extends StatelessWidget {
  const KitchenAnalyticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final today = DateTime.now();
    final todayOrdersCount = cartProvider.orders.where((order) => 
      order.date.year == today.year && 
      order.date.month == today.month && 
      order.date.day == today.day
    ).length;
    final ingredientProvider = context.watch<IngredientProvider>();
    final predictions = ingredientProvider.predictions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuDRCgacgSyKS-jwG7gEfq-lX__B7GNkIJJvnpJT08YxTALE_x9AiYQ05m86k9u0njHcLAVozAS0kNFTIiHh8ueUf5hiqWMnbOwtR95ag2FpDrgIEK0Zd5ERaIrMCqNOIEAmwKzCssMeA_QId5siQ_UteuJRZhlHVAErZAvv7eBj6UohmapjmXktMBYyKD4UjiQ5V29CfIK_ZOBa7F1dvo7c3fEjP6aSfMF1q0q2lqlmP3w2LTGPNQFxYA',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Caferio',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome & Date
            const Text(
              'Live Kitchen Stats',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Daily Performance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // High Level Metrics
            _buildMetricCard(
              context: context,
              icon: Icons.restaurant,
              iconColor: AppColors.primary,
              iconBg: AppColors.primaryFixed,
              title: 'Total Orders Today',
              value: todayOrdersCount.toString(),
              change: 'Live',
              changeColor: AppColors.primary,
            ),
            const SizedBox(height: 16),

            // Most Popular Dish (Spans full width)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Most Popular Dish',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nadan Beef Roast',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '412 orders today',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryContainer,
                            foregroundColor: AppColors.onSecondaryContainer,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('View Recipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Transform.scale(
                      scale: 1.5,
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCJlMZkJ2kbz8lEWcSsB3c0bBxdrTXB2xy4lqF6EBShH5hC6vEGgNJHtJBL4np2ltTEkjGhvaUecYyfnUp6jTecdBdDrCIBymvbiF1oNPWbfD1jTIlDtCm0DkKSM1a0OtSjwbnjJxW8LFcm8oEHzvaTSeaWl5ew5yf0H4bKDFsSMsoMckCRxSskpWfN05Ocd74WLF0Q0mw3lx67CWgAQS5lFr7aIoeBXl0QZ-I43oZLvgUt_pti82oNIg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Order Trends Chart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Order Peak Times', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Text('Live Updates', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildChartBar(0.4, false),
                  _buildChartBar(0.65, false),
                  _buildChartBar(0.95, true),
                  _buildChartBar(0.7, false),
                  _buildChartBar(0.55, false),
                  _buildChartBar(0.45, false),
                  _buildChartBar(0.85, false),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('11 AM', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                Text('1 PM', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                Text('3 PM', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                Text('5 PM', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                Text('7 PM', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                Text('9 PM', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                Text('11 PM', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 40),

            // Predictive Insights
            Text('Live Exhaustion Forecast', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (predictions.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ...predictions.take(5).map((pred) {
                IconData icon;
                Color iconColor;
                Color iconBg;
                Widget action;

                switch (pred.riskLevel) {
                  case IngredientRisk.critical:
                    icon = Icons.warning_amber_rounded;
                    iconColor = AppColors.error;
                    iconBg = AppColors.errorContainer;
                    action = TextButton(
                      onPressed: () => ingredientProvider.restock(pred.ingredientId, pred.suggestedRestockAmount),
                      child: const Text('RESTOCK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    );
                    break;
                  case IngredientRisk.warning:
                    icon = Icons.info_outline;
                    iconColor = AppColors.onSecondaryContainer;
                    iconBg = AppColors.secondaryContainer;
                    action = const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant);
                    break;
                  case IngredientRisk.ok:
                    icon = Icons.check_circle_outline;
                    iconColor = AppColors.tertiary;
                    iconBg = AppColors.tertiaryFixed;
                    action = const SizedBox.shrink();
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildInsightCard(
                    icon: icon,
                    iconColor: iconColor,
                    iconBg: iconBg,
                    title: '${pred.ingredientName} (${pred.riskLabel})',
                    subtitle: 'Depletes in: ${pred.exhaustionLabel} | Pace: ${pred.consumptionRatePerHour.toStringAsFixed(1)}${pred.unit}/hr',
                    action: action,
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String change,
    required Color changeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                change,
                style: TextStyle(color: changeColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 24)),
        ],
      ),
    );
  }

  Widget _buildChartBar(double fillPercentage, bool isActive) {
    return Flexible(
      child: FractionallySizedBox(
        heightFactor: fillPercentage,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.primaryFixed,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}
