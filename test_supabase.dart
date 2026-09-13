import 'package:supabase/supabase.dart';
import 'package:caferio/models/order.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://etgnpwntblbobdlkvflz.supabase.co',
    'sb_publishable_Dqq56CpA3ZZDRcvcsFo_SQ_s_0Mm3vP',
  );

  try {
    final response = await supabase.from('orders').select();
    print('Total rows: ' + response.length.toString());
    for (var row in response) {
      try {
        final order = Order.fromJson(row);
        print('Parsed successfully: ' + order.id);
      } catch (e, stack) {
        print('Parse Error for row: ' + e.toString());
        print(stack);
      }
    }
  } catch (e) {
    print('DB Error: ' + e.toString());
  }
}
