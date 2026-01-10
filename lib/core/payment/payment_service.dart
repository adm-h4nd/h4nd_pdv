import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'payment_config.dart';
import 'payment_provider.dart';
import 'payment_method_option.dart';
import 'payment_ui_notifier.dart'; // 🆕 Import do sistema de notificação
import '../../data/adapters/payment/payment_provider_registry.dart';
import '../../data/services/core/forma_pagamento_service.dart';
import '../../data/services/core/auth_service.dart';
import '../../data/models/core/caixa/forma_pagamento_disponivel_dto.dart';
import '../../data/models/core/caixa/tipo_forma_pagamento.dart';
import '../../data/adapters/payment/providers/manual_payment_adapter.dart';

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
    // No Windows, alguns providers podem não estar disponíveis
    try {
    await PaymentProviderRegistry.registerAll(_config!);
    } catch (e, stackTrace) {
      debugPrint('⚠️ Erro ao registrar payment providers: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      // Continua mesmo se houver erro (alguns providers podem não estar disponíveis no Windows)
    }
  }
  
  /// Retorna métodos de pagamento disponíveis para este dispositivo
  /// 
  /// **Parâmetros:**
  /// - [formaPagamentoService] - Service para buscar formas de pagamento do backend (obrigatório)
  /// - [authService] - Service para obter empresa selecionada (obrigatório)
  /// 
  /// **Fluxo:**
  /// 1. Busca formas de pagamento do backend para a empresa atual
  /// 2. Para cada forma:
  ///    - Se isIntegrada = true: procura provider SDK compatível
  ///    - Se isIntegrada = false ou não há provider: usa ManualPaymentAdapter
  /// 3. Cria PaymentMethodOption com TipoFormaPagamento do backend
  Future<List<PaymentMethodOption>> getAvailablePaymentMethods({
    required FormaPagamentoService formaPagamentoService,
    required AuthService authService,
  }) async {
    debugPrint('💳 [PaymentService] Buscando formas de pagamento do backend...');
    
    try {
      // 1. Obtém empresa selecionada
      final empresaId = await authService.getSelectedEmpresa();
      if (empresaId == null || empresaId.isEmpty) {
        debugPrint('⚠️ [PaymentService] Nenhuma empresa selecionada, retornando métodos padrão');
        return _getDefaultPaymentMethods();
      }
      
      // 2. Busca formas de pagamento do backend
      final response = await formaPagamentoService.getFormasPagamentoDisponiveisPorEmpresa(empresaId);
      
      if (!response.success || response.data == null || response.data!.isEmpty) {
        debugPrint('⚠️ [PaymentService] Nenhuma forma de pagamento encontrada, retornando métodos padrão');
        return _getDefaultPaymentMethods();
      }
      
      final formasPagamento = response.data!;
      debugPrint('✅ [PaymentService] ${formasPagamento.length} formas de pagamento encontradas');
      
      // 3. Ordena por ordemExibicao
      formasPagamento.sort((a, b) => a.ordemExibicao.compareTo(b.ordemExibicao));
      
      // 4. Converte formas de pagamento em PaymentMethodOption
      final methods = <PaymentMethodOption>[];
      
      for (final formaPagamento in formasPagamento) {
        // Apenas formas que devem ser exibidas no PDV
        if (!formaPagamento.exibirNoPDV) {
          continue;
        }
        
        // Encontra provider compatível (se integrada)
        PaymentProvider? provider;
        String providerKey;
        
        if (formaPagamento.isIntegrada) {
          // Busca provider SDK que suporta este tipo
          provider = _findProviderForPaymentType(formaPagamento.tipoBase);
          
          if (provider != null) {
            // Usa provider SDK
            providerKey = _getProviderKey(provider);
            debugPrint('✅ [PaymentService] Forma "${formaPagamento.nome}" usará SDK: ${provider.providerName}');
          } else {
            // SDK não disponível, usa manual
            providerKey = 'manual_${formaPagamento.tipoBase.toValue()}';
            debugPrint('⚠️ [PaymentService] Forma "${formaPagamento.nome}" é integrada mas SDK não disponível, usando manual');
          }
        } else {
          // Não integrada, sempre usa manual
          providerKey = 'manual_${formaPagamento.tipoBase.toValue()}';
          debugPrint('ℹ️ [PaymentService] Forma "${formaPagamento.nome}" não integrada, usando manual');
        }
        
        // Cria PaymentMethodOption
        final method = _createPaymentMethodOption(
          formaPagamento: formaPagamento,
          providerKey: providerKey,
          provider: provider,
        );
        
        methods.add(method);
      }
      
      debugPrint('✅ [PaymentService] ${methods.length} métodos de pagamento disponíveis');
      return methods;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [PaymentService] Erro ao buscar formas de pagamento: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return _getDefaultPaymentMethods();
    }
  }
  
  /// Retorna métodos de pagamento padrão (fallback)
  List<PaymentMethodOption> _getDefaultPaymentMethods() {
    final methods = <PaymentMethodOption>[];
    
    // Dinheiro sempre disponível
    if (_config?.canUseProvider('cash') ?? true) {
      methods.add(PaymentMethodOption.cash());
    }
    
    return methods;
  }
  
  /// Encontra provider SDK que suporta o tipo de pagamento
  PaymentProvider? _findProviderForPaymentType(TipoFormaPagamento tipo) {
    final registeredProviders = PaymentProviderRegistry.getRegisteredProviders();
    
    for (final providerKey in registeredProviders) {
      // Ignora cash (já tratado separadamente)
      if (providerKey == 'cash') continue;
      
      final provider = PaymentProviderRegistry.getProvider(providerKey);
      if (provider != null && 
          provider.isAvailable && 
          provider.supportedPaymentTypes.contains(tipo)) {
        return provider;
      }
    }
    
    return null;
  }
  
  /// Obtém a chave do provider para usar no registry
  String _getProviderKey(PaymentProvider provider) {
    // Mapeia provider para sua chave no registry
    if (provider.providerName.toLowerCase().contains('stone')) {
      return 'stone_pos';
    }
    // Adicionar outros mapeamentos conforme necessário
    
    // Fallback: usa nome do provider em lowercase
    return provider.providerName.toLowerCase().replaceAll(' ', '_');
  }
  
  /// Cria PaymentMethodOption a partir de FormaPagamentoDisponivelDto
  PaymentMethodOption _createPaymentMethodOption({
    required FormaPagamentoDisponivelDto formaPagamento,
    required String providerKey,
    PaymentProvider? provider,
  }) {
    // Determina PaymentType baseado no provider (técnico)
    PaymentType paymentType;
    if (provider != null) {
      paymentType = provider.paymentType;
    } else {
      // Para manuais, usa TEF como padrão
      paymentType = PaymentType.tef;
    }
    
    // Determina ícone e cor baseado no tipo
    IconData icon;
    Color color;
    
    switch (formaPagamento.tipoBase) {
      case TipoFormaPagamento.dinheiro:
        icon = Icons.money;
        color = Colors.green;
        break;
      case TipoFormaPagamento.cartaoCredito:
      case TipoFormaPagamento.cartaoDebito:
        icon = Icons.credit_card;
        color = Colors.blue.shade700;
        break;
      case TipoFormaPagamento.pix:
        icon = Icons.qr_code;
        color = Colors.orange.shade700;
        break;
      case TipoFormaPagamento.boleto:
        icon = Icons.receipt;
        color = Colors.purple.shade700;
        break;
      case TipoFormaPagamento.cheque:
        icon = Icons.description;
        color = Colors.grey.shade700;
        break;
      case TipoFormaPagamento.valeRefeicao:
      case TipoFormaPagamento.valeAlimentacao:
        icon = Icons.card_giftcard;
        color = Colors.red.shade700;
        break;
      case TipoFormaPagamento.outro:
        icon = Icons.payment;
        color = Colors.grey.shade600;
        break;
    }
    
    return PaymentMethodOption(
      type: paymentType,
      label: formaPagamento.nome,
      icon: icon,
      color: color,
      providerKey: providerKey,
      tipoFormaPagamento: formaPagamento.tipoBase, // 🎯 Tipo do backend
      formaPagamentoId: formaPagamento.formaPagamentoId, // 🎯 ID da forma de pagamento
    );
  }
  
  /// Obtém um provider específico
  /// 
  /// Se o providerKey começar com "manual_", cria um ManualPaymentAdapter dinamicamente
  Future<PaymentProvider?> getProvider(String providerKey) async {
    // Se for provider manual, cria dinamicamente
    if (providerKey.startsWith('manual_')) {
      final tipoValue = int.tryParse(providerKey.replaceFirst('manual_', ''));
      if (tipoValue != null) {
        final tipo = TipoFormaPagamento.fromValue(tipoValue);
        if (tipo != null) {
          debugPrint('🔧 [PaymentService] Criando ManualPaymentAdapter para tipo: $tipo');
          return ManualPaymentAdapter(tipoPagamento: tipo);
        }
      }
      debugPrint('⚠️ [PaymentService] Tipo de pagamento inválido para provider manual: $providerKey');
      return null;
    }
    
    // Provider SDK do registry
    final settings = _config?.providerSettings?[providerKey];
    final provider = PaymentProviderRegistry.getProvider(providerKey, settings: settings);
    
    if (provider != null && !provider.isAvailable) {
      debugPrint('⚠️ Provider $providerKey não está disponível');
      return null;
    }
    
    return provider;
  }
  
  /// Processa um pagamento
  /// 
  /// **Parâmetros:**
  /// - [providerKey] - Chave do provider (ex: 'stone_pos', 'cash')
  /// - [amount] - Valor a ser pago
  /// - [vendaId] - ID da venda
  /// - [additionalData] - Dados adicionais específicos do provider
  /// - [uiNotifier] - Notificador opcional para comunicar com UI
  /// 
  /// **Sobre uiNotifier:**
  /// - Se fornecido, será passado para o provider
  /// - PaymentService pode também usar para notificações gerais
  /// - Providers que requerem interação do usuário devem usar para
  ///   notificar UI sobre eventos (ex: mostrar/esconder dialogs)
  /// 
  /// **Fluxo:**
  /// 1. Obtém provider do registry
  /// 2. Inicializa provider
  /// 3. Se provider requer interação, pode notificar UI antecipadamente
  /// 4. Chama provider.processPayment() passando uiNotifier
  /// 5. Retorna resultado
  Future<PaymentResult> processPayment({
    required String providerKey,
    required double amount,
    required String vendaId,
    Map<String, dynamic>? additionalData,
    PaymentUINotifier? uiNotifier, // 🆕 Novo parâmetro opcional
  }) async {
    debugPrint('💳 [PaymentService] Iniciando processamento de pagamento');
    debugPrint('💳 Provider: $providerKey, Valor: R\$ ${amount.toStringAsFixed(2)}');
    
    // 1. Obtém provider do registry
    final provider = await getProvider(providerKey);
    
    if (provider == null) {
      debugPrint('❌ [PaymentService] Provider $providerKey não disponível');
      return PaymentResult(
        success: false,
        errorMessage: 'Provider $providerKey não disponível',
      );
    }
    
    debugPrint('✅ [PaymentService] Provider obtido: ${provider.providerName}');
    debugPrint('📋 [PaymentService] Provider requer interação: ${provider.requiresUserInteraction}');
    
    // 2. Inicializa provider se necessário
    try {
      debugPrint('🔧 [PaymentService] Inicializando provider...');
      await provider.initialize();
      debugPrint('✅ [PaymentService] Provider inicializado');
    } catch (e) {
      debugPrint('❌ [PaymentService] Erro ao inicializar provider: $e');
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao inicializar provider: ${e.toString()}',
      );
    }
    
    // 3. Se provider requer interação do usuário, pode notificar UI antecipadamente
    // (opcional - alguns providers preferem notificar internamente)
    // Aqui apenas logamos, mas o provider é quem decide quando notificar
    if (provider.requiresUserInteraction) {
      debugPrint('👤 [PaymentService] Provider requer interação do usuário');
      debugPrint('👤 [PaymentService] Provider será responsável por notificar UI');
    }
    
    // 4. Processa pagamento passando uiNotifier para o provider
    // O provider decide quando e como notificar UI
    debugPrint('💳 [PaymentService] Chamando provider.processPayment()...');
    try {
      final result = await provider.processPayment(
        amount: amount,
        vendaId: vendaId,
        additionalData: additionalData,
        uiNotifier: uiNotifier, // 🆕 Passa notificador para provider
      );
      
      if (result.success) {
        debugPrint('✅ [PaymentService] Pagamento processado com sucesso');
      } else {
        debugPrint('❌ [PaymentService] Pagamento falhou: ${result.errorMessage}');
      }
      
      return result;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [PaymentService] Exceção ao processar pagamento: $e');
      debugPrint('❌ [PaymentService] Stack trace: $stackTrace');
      
      // Em caso de exceção, garante que dialog seja escondido (se estava mostrando)
      if (provider.requiresUserInteraction) {
        uiNotifier?.notify(PaymentUINotification.hideWaitingCard());
        debugPrint('📢 [PaymentService] UI notificada: Esconder dialog (exceção)');
      }
      
      return PaymentResult(
        success: false,
        errorMessage: 'Erro ao processar pagamento: ${e.toString()}',
      );
    }
  }
  
}

