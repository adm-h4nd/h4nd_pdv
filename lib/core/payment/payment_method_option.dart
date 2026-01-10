import 'package:flutter/material.dart';
import 'payment_provider.dart';
import '../../data/models/core/caixa/tipo_forma_pagamento.dart';

/// Opção de método de pagamento disponível
class PaymentMethodOption {
  final PaymentType type; // Classificação técnica (cash, pos, tef)
  final String label;
  final IconData icon;
  final Color color;
  final String providerKey; // Ex: 'stone_pos', 'cash', etc.
  final TipoFormaPagamento tipoFormaPagamento; // 🆕 Tipo do backend (dinheiro, cartaoCredito, etc.)
  final String formaPagamentoId; // 🆕 ID da forma de pagamento no backend (Guid)
  
  PaymentMethodOption({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.providerKey,
    required this.tipoFormaPagamento, // 🆕 Obrigatório
    required this.formaPagamentoId, // 🆕 Obrigatório
  });
  
  // Métodos pré-definidos (mantidos para compatibilidade, mas devem ser substituídos)
  // NOTA: Estes métodos não devem ser usados mais, pois não têm formaPagamentoId
  // Eles são mantidos apenas para compatibilidade com código legado
  static PaymentMethodOption cash() {
    return PaymentMethodOption(
      type: PaymentType.cash,
      label: 'Dinheiro',
      icon: Icons.money,
      color: Colors.green,
      providerKey: 'cash',
      tipoFormaPagamento: TipoFormaPagamento.dinheiro,
      formaPagamentoId: '', // ⚠️ Vazio - não deve ser usado em produção
    );
  }
  
  static PaymentMethodOption cardPOS(String provider) {
    return PaymentMethodOption(
      type: PaymentType.pos,
      label: 'Cartão (POS)',
      icon: Icons.credit_card,
      color: Colors.blue,
      providerKey: '${provider}_pos',
      tipoFormaPagamento: TipoFormaPagamento.cartaoCredito,
      formaPagamentoId: '', // ⚠️ Vazio - não deve ser usado em produção
    );
  }
  
  static PaymentMethodOption cardTEF(String provider) {
    return PaymentMethodOption(
      type: PaymentType.tef,
      label: 'Cartão (TEF)',
      icon: Icons.payment,
      color: Colors.blue,
      providerKey: '${provider}_tef',
      tipoFormaPagamento: TipoFormaPagamento.cartaoCredito,
      formaPagamentoId: '', // ⚠️ Vazio - não deve ser usado em produção
    );
  }
}

