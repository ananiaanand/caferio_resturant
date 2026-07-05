import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../theme/colors.dart';
import '../providers/cart_provider.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const ProductCard({
    Key? key,
    required this.product,
    required this.onTap,
    required this.onAdd,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovered = false;

  void _increment() {
    context.read<CartProvider>().addItem(widget.product);
    widget.onAdd();
  }

  void _decrement() {
    context.read<CartProvider>().decrementItem(widget.product.id);
  }
  Widget _buildImage(String url) {
    if (url.startsWith('asset:')) {
      final name = url.replaceFirst('asset:', '');
      return Image.asset(
        'assets/images/$name.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItem = context.watch<CartProvider>().items[widget.product.id];
    final int currentQuantity = cartItem?.quantity ?? 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.04),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 96,
                  height: 96,
                  color: AppColors.surfaceContainerLow,
                  child: _buildImage(widget.product.imageUrl),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${widget.product.price.toInt()}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        // Toggle between Add button and quantity stepper
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) => ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                          child: currentQuantity == 0
                              ? GestureDetector(
                                  key: const ValueKey('add_btn'),
                                  onTap: _increment,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Add',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.onSecondaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                )
                              : Container(
                                  key: const ValueKey('quantity_stepper'),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Minus button
                                      GestureDetector(
                                        onTap: _decrement,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.remove,
                                            size: 16,
                                            color: AppColors.onPrimary,
                                          ),
                                        ),
                                      ),
                                      // Count
                                      Container(
                                        constraints:
                                            const BoxConstraints(minWidth: 28),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$currentQuantity',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: AppColors.onPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                        ),
                                      ),
                                      // Plus button
                                      GestureDetector(
                                        onTap: _increment,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.add,
                                            size: 16,
                                            color: AppColors.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
