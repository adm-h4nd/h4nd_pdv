import 'package:flutter/material.dart';
import 'payment_provider.dart';

/// Opção de método de pagamento disponível
class PaymentMethodOption {
  final PaymentType type;
  final String label;
  final IconData icon;
  final Color color;
  final String providerKey; // Ex: 'stone_pos', 'cash', etc.
  
  PaymentMethodOption({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.providerKey,
  });
  
  // Métodos pré-definidos
  static PaymentMethodOption cash() {
    return PaymentMethodOption(
      type: PaymentType.cash,
      label: 'Dinheiro',
      icon: Icons.money,
      color: Colors.green,
      providerKey: 'cash',
    );
  }
  
  static PaymentMethodOption cardPOS(String provider) {
    return PaymentMethodOption(
      type: PaymentType.pos,
      label: 'Cartão (POS)',
      icon: Icons.credit_card,
      color: Colors.blue,
      providerKey: '${provider}_pos',
    );
  }
  
  static PaymentMethodOption cardTEF(String provider) {
    return PaymentMethodOption(
      type: PaymentType.tef,
      label: 'Cartão (TEF)',
      icon: Icons.payment,
      color: Colors.blue,
      providerKey: '${provider}_tef',
    );
  }
}

