import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'payment_config.dart';
import 'payment_provider.dart';
import 'payment_method_option.dart';
import '../../data/adapters/payment/payment_provider_registry.dart';

/// Serviço principal de pagamento
class PaymentService {
  PaymentConfig? _config;
  static PaymentService? _instance;
  
  static Future<PaymentService> getInstance() async {
    _instance ??= PaymentService._();
    await _instance!._initialize();
    return _instance!;
  }
  
  PaymentService._();
  
  Future<void> _initialize() async {
    // Carrega configuração
    _config = await PaymentConfig.load();
    
    debugPrint('💳 Payment Service inicializado');
    debugPrint('📱 Providers disponíveis: ${_config!.availableProviders}');
    
    // Registra providers baseado na configuração
    await PaymentProviderRegistry.registerAll(_config!);
  }
  
  /// Retorna métodos de pagamento disponíveis para este dispositivo
  List<PaymentMethodOption> getAvailablePaymentMethods() {
    if (_config == null) {
      return [PaymentMethodOption.cash()];
    }
    
    final methods = <PaymentMethodOption>[];
    
    // Dinheiro sempre disponível
    if (_config!.canUseProvider('cash')) {
      methods.add(PaymentMethodOption.cash());
    }
    
    // Stone POS SDK - Crédito (se disponível)
    if (_config!.canUseProvider('stone_pos')) {
      methods.add(PaymentMethodOption(
        type: PaymentType.pos,
        label: 'Cartão Crédito',
        icon: Icons.credit_card,
        color: Colors.blue.shade700,
        providerKey: 'stone_pos',
      ));
      
      // Stone POS SDK - Débito (se disponível)
      methods.add(PaymentMethodOption(
        type: PaymentType.pos,
        label: 'Cartão Débito',
        icon: Icons.credit_card,
        color: Colors.blue.shade600,
        providerKey: 'stone_pos',
      ));
    }
    
    // Adicionar outros providers conforme necessário
    
    return methods;
  }
  
  /// Obtém um provider específico
  Future<PaymentProvider?> getProvider(String providerKey) async {
    final settings = _config?.providerSettings?[providerKey];
    final provider = PaymentProviderRegistry.getProvider(providerKey, settings: settings);
    
    if (provider != null && !provider.isAvailable) {
      debugPrint('⚠️ Provider $providerKey não está disponível');
      return null;
    }
    
    return provider;
  }
  
  /// Processa um pagamento
  Future<PaymentResult> processPayment({
    required String providerKey,
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
  }) async {
    final provider = await getProvider(providerKey);
    
    if (provider == null) {
      return PaymentResult(
        success: false,
        errorMessage: 'Provider $providerKey não disponível',
      );
    }
    
    // Inicializa se necessário
    try {
      await provider.initialize();
    } catch (e) {
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao inicializar provider: ${e.toString()}',
      );
    }
    
    // Processa pagamento
    return await provider.processPayment(
      amount: amount,
      vendaId: vendaId,
      additionalData: additionalData,
    );
  }
  
}

