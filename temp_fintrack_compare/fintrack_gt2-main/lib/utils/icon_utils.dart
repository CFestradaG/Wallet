import 'package:flutter/material.dart';

class AppIcons {
  static IconData getIcon(String name) {
    switch (name) {
      case 'home': return Icons.home_rounded;
      case 'credit_card': return Icons.credit_card_rounded;
      case 'school': return Icons.school_rounded;
      case 'person': return Icons.person_rounded;
      case 'phone_android': return Icons.phone_android_rounded;
      case 'bolt': return Icons.bolt_rounded;
      case 'water_drop': return Icons.water_drop_rounded;
      case 'shopping_cart': return Icons.shopping_cart_rounded;
      case 'storefront': return Icons.storefront_rounded;
      case 'local_gas_station': return Icons.local_gas_station_rounded;
      case 'two_wheeler': return Icons.two_wheeler_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'bakery_dining': return Icons.bakery_dining_rounded;
      case 'directions_bus': return Icons.directions_bus_rounded;
      case 'credit_score': return Icons.credit_score_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'payments': return Icons.payments_rounded;
      case 'swap_horiz': return Icons.swap_horiz_rounded;
      case 'directions_car': return Icons.directions_car_rounded;
      case 'receipt_long': return Icons.receipt_long_rounded;
      case 'track_changes': return Icons.track_changes_rounded;
      case 'straighten': return Icons.straighten_rounded;
      case 'speed': return Icons.speed_rounded;
      case 'category': return Icons.category_rounded;
      default: return Icons.category_rounded;
    }
  }
}
