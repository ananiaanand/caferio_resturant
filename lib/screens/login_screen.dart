import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../providers/cart_provider.dart';
import 'main_screen.dart';
import 'kitchen_main_screen.dart';
import 'manager_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email == 'manager@gmail.com' && password == 'manager') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ManagerMainScreen()),
      );
    } else if (email == 'kitchen@gmail.com' && password == 'kitchen') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const KitchenMainScreen()),
      );
    } else if (email == 'user@gmail.com' && password == 'user') {
      // Load persisted orders for this user before navigating
      final cartProvider = context.read<CartProvider>();
      await cartProvider.loadOrdersForUser(email);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email or password')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Section
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surfaceContainer,
                        width: 4,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuD0W5Vm6nWXGv4oHgSwPsxJ8HZ8Dxs3s1mNqhmDzqfUmQR8XiEilmZnTTY81DgsKfpREJziTPg8W76BsMs-dZ8ihhabT8yee9l9UKBG4tvBQdjuNkpqNfuNrNxeuB__ih9zMxl292evQGBNqvibz2icSq-gK9UDSEPYtuKF2FDyWiP_6cg_c5E6t6DnJfLaSPXbqN8QwZL_-RHVGwZPf3Kzz7tuo-m8KM_DO_KpeYNhEb-GZBt1eIh1iE7jrki_BtmkjBU',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.restaurant_menu, size: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Caferio',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // Headline
                  Text(
                    'Welcome to Caferio',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to order your favorite flavors',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // Email / Phone Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Email or Phone',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                      ),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'Enter your email or phone',
                          prefixIcon: const Icon(Icons.person, color: AppColors.onSurfaceVariant),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Password Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Password',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                'Forgot Password?',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock, color: AppColors.onSurfaceVariant),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Login',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.surfaceContainer, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                                letterSpacing: 1.5,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.surfaceContainer, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Social Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.surfaceContainerLowest,
                            side: const BorderSide(color: AppColors.surfaceContainer),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          label: Text(
                            'Google',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.onSurface,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.surfaceContainerLowest,
                            side: const BorderSide(color: AppColors.surfaceContainer),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.facebook, color: Colors.blue),
                          label: Text(
                            'Facebook',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Text(
                          'Create an Account',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
