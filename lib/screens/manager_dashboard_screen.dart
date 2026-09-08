import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  int _selectedPeriod = 0; // 0=Today, 1=Weekly, 2=Monthly

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuBfQYX0SJdOj7DceRrF0MHGZM4kU_aq_L2saruo481BQB7hpc8opXdB8bAfxfToD-3bb1QuFbAbkR1QsOcj6Jb6o_3rd83ub2W4eNsjLPhoCWLK4kGQhcdlN2S-ZpD-COIkrWjJJ34b8sz50H7PhPuOTbw_7uqgPj8WuOiZn0X5AZ7VeXGN0UGs49e_ctsIMAf6dB4MxxocdJ-s9fdadW_PkCbYzeOHLBwfc5cwPprpy5j3n5l-2LXOT1eN7iG47oiOBGk',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.onSurfaceVariant),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Manager Dashboard',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Real-time Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // ── Profit Analysis Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceContainer),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profit Analysis',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text('Real-time financial performance', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                      // Period selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: ['Today', 'Weekly', 'Monthly'].asMap().entries.map((e) {
                            final isSelected = _selectedPeriod == e.key;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedPeriod = e.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                      : [],
                                ),
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPeriod == 0
                                  ? '₹0'
                                  : _selectedPeriod == 1
                                      ? '₹0'
                                      : '₹0',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.trending_up, color: AppColors.primary, size: 16),
                                const SizedBox(width: 4),
                                const Text('+12.4% vs yesterday',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildMiniChart(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Expected Profit Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.insights, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 16),
                  const Text('Expected Profit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const Text('Next Month Forecast', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('₹0.00',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.0,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFEBB0B)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('0% Confidence Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Most Sold Items ───────────────────────────────────────────
            Text('Most Sold Items', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceContainer),
              ),
              child: Column(
                children: [
                  _buildSalesBar(context, 'Nadan Beef Roast', 0, 0.0),
                  const SizedBox(height: 20),
                  _buildSalesBar(context, 'Kerala Parotta', 0, 0.0),
                  const SizedBox(height: 20),
                  _buildSalesBar(context, 'Chicken 65', 0, 0.0),
                  const SizedBox(height: 20),
                  _buildSalesBar(context, 'Fish Curry', 0, 0.0),
                  const SizedBox(height: 20),
                  _buildSalesBar(context, 'Egg Fried Rice', 0, 0.0),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Critical Stock ────────────────────────────────────────────
            Text('Critical Stock Alerts', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildCriticalStockCard('Shallots', 'Only 0kg left',
                'https://lh3.googleusercontent.com/aida-public/AB6AXuBJiPYKNH7BE7ZgpWQUtDyS91KTpXMSYMXNtb7KgIVIsPS_JBjgGJVABRzvS4xErOG2VntTQkViBdhaFcuQwgbAYM6KH8xAxcX8immF8mn9mdsaiGvYRV2pHEtBTfZOsPhF_bJixbw9gi92zjrp6ueeUdYM5aOPibM7cXRG8qwUD8h0VCvUPLVAhBCwj4-FqyvpUPlENA-dkZhWjgAm9rhedAtYahhPHwmmU7plqEA-hkLer_TO8AVX5A'),
            const SizedBox(height: 12),
            _buildCriticalStockCard('Coconut Oil', 'Only 0L left',
                'https://lh3.googleusercontent.com/aida-public/AB6AXuCXH26fRifRDKEap2s9Qa7NMVXUlT1fq4hair0m_tuFbayek2htQNty8EARG-uGd0wA8PXq4aCAdNYWzld_cdkhhQkPHfsNQRJGcN5mrwmFiTlrkN9wRgilU2ahLWKLAosKjsblUVleINEn65dl1K4jft3-KwKlp5FvEa2bSAqabWZn7eoc7oT-s-ANKZHUntoEnXiWOfp3-lEdeseTm8ffv65eV7GnTVT1kybY6f19ETi7YTCf5u2RVA'),
            const SizedBox(height: 24),

            // ── Likely to Run Out ─────────────────────────────────────────
            Text('Likely to Run Out', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRunOutChip('Rice', '0 Days Left'),
                  const SizedBox(width: 12),
                  _buildRunOutChip('Dry Spices', '0 Days Left'),
                  const SizedBox(width: 12),
                  _buildRunOutChip('Milk', '0 Days Left'),
                  const SizedBox(width: 12),
                  _buildRunOutChip('Fresh Cream', '0 Days Left'),
                ],
              ),
            ),
            const SizedBox(height: 24),

          ],
        ),
      ),
    );
  }

  Widget _buildMiniChart() {
    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _MiniChartPainter(),
        child: Container(),
      ),
    );
  }

  Widget _buildSalesBar(BuildContext context, String name, int sold, double fraction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('$sold Sold', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: AppColors.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCriticalStockCard(String name, String detail, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorContainer),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(detail, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Refill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildRunOutChip(String name, String days) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(days, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryContainer
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primaryContainer.withOpacity(0.3), AppColors.primaryContainer.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final points = [0.6, 0.3, 0.7, 0.4, 0.8, 0.35, 0.1];
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = size.height - (points[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        final prevX = ((i - 1) / (points.length - 1)) * size.width;
        final prevY = size.height - (points[i - 1] * size.height);
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
