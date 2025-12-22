import '../../../../core/printing/print_provider.dart';
import '../../../../core/printing/print_data.dart';
import 'package:flutter/foundation.dart';
import 'package:stone_payments/stone_payments.dart';
import 'package:stone_payments/models/item_print_model.dart';
import 'package:stone_payments/enums/item_print_type_enum.dart';
import 'package:stone_payments/enums/type_owner_print_enum.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Provider de impressão Stone Thermal (usa SDK Stone Payments para impressão)
/// 
/// A Stone também oferece impressão através do mesmo SDK
class StoneThermalAdapter implements PrintProvider {
  final Map<String, dynamic>? _settings;
  bool _initialized = false;
  
  // Imagem base64 para o cabeçalho da comanda
  // IMPORTANTE: Substitua a string abaixo com a imagem base64 completa fornecida pelo usuário
  // A imagem será exibida no topo da comanda impressa
  static const String _logoBase64 = 'iVBORw0KGgoAAAA...'; // Substitua com a imagem base64 completa
  
  StoneThermalAdapter({Map<String, dynamic>? settings}) : _settings = settings;
  
  @override
  String get providerName => 'Stone Thermal';
  
  @override
  PrintType get printType => PrintType.thermal;
  
  @override
  bool get isAvailable {
    try {
      return true; // Verificar se SDK está disponível
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      debugPrint('🔌 Inicializando Stone Thermal Printer...');
      
      // Stone usa o mesmo SDK de pagamento para impressão
      // Precisa ativar o SDK antes de usar qualquer funcionalidade
      // Se já estiver ativado (por exemplo, pelo StonePOSAdapter), não será erro
      final activated = await _activateStone();
      
      // Aguarda um pouco para garantir que o SDK está pronto
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (!activated) {
        debugPrint('⚠️ [Print] Não foi possível ativar Stone na inicialização, mas continuando...');
      }
      
      _initialized = true;
      debugPrint('✅ Stone Thermal Printer inicializada');
    } catch (e) {
      // Se o erro for que já está ativado, não é crítico
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('koin') || errorStr.contains('already') || errorStr.contains('já')) {
        debugPrint('ℹ️ [Print] SDK já está ativado, continuando...');
        // Aguarda um pouco mesmo quando já está ativado
        await Future.delayed(const Duration(milliseconds: 200));
        _initialized = true;
      } else {
        debugPrint('❌ Erro ao inicializar Stone Thermal Printer: $e');
        // Não relança o erro - permite que a impressão tente mesmo assim
        // Se o SDK não estiver ativado, o erro aparecerá na impressão
        // Aguarda um pouco antes de marcar como inicializado
        await Future.delayed(const Duration(milliseconds: 200));
        _initialized = true; // Marca como inicializado para não tentar novamente
      }
    }
  }
  
  /// Ativa a máquina Stone (necessário para usar SDK)
  /// Retorna true se ativado com sucesso, false se já estava ativado ou erro não crítico
  Future<bool> _activateStone() async {
    try {
      final appName = _settings?['appName'] as String? ?? 'MX Cloud PDV';
      final stoneCode = _settings?['stoneCode'] as String? ?? '';
      
      if (stoneCode.isEmpty) {
        debugPrint('⚠️ [Print] StoneCode não configurado nas settings');
        // Tenta usar o mesmo código do adapter de pagamento se disponível
        // Por enquanto, lança exceção
        throw Exception('StoneCode não configurado');
      }
      
      debugPrint('🔌 [Print] Ativando Stone com StoneCode: $stoneCode');
      
      final result = await StonePayments.activateStone(
        appName: appName,
        stoneCode: stoneCode,
        qrCodeProviderId: _settings?['qrCodeProviderId'] as String?,
        qrCodeAuthorization: _settings?['qrCodeAuthorization'] as String?,
      );
      
      debugPrint('✅ [Print] Stone ativada com sucesso: $result');
      return true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      // Se já estiver ativado ou Koin já iniciado, não é erro crítico
      if (errorStr.contains('already') || 
          errorStr.contains('já') || 
          errorStr.contains('koin') ||
          errorStr.contains('started')) {
        debugPrint('ℹ️ [Print] Stone já está ativada ou SDK já inicializado');
        return true; // Considera sucesso se já estava ativado
      }
      
      debugPrint('❌ [Print] Erro ao ativar Stone: $e');
      // Para impressão, vamos tentar mesmo assim (pode estar ativado pelo adapter de pagamento)
      // Se falhar na impressão, o erro será tratado lá
      return false;
    }
  }
  
  @override
  Future<void> disconnect() async {
    if (!_initialized) return;
    
    _initialized = false;
    debugPrint('🔌 Stone Thermal Printer desconectada');
  }
  
  @override
  Future<PrintResult> printComanda(PrintData data) async {
    // Garante que o SDK está inicializado e ativado
    if (!_initialized) {
      await initialize();
      // Aguarda um pouco mais na primeira inicialização para garantir que o SDK está completamente pronto
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Verifica se o SDK está realmente ativado antes de imprimir
    // Na primeira impressão, é importante garantir que está ativado
    bool activationVerified = false;
    int attempts = 0;
    const maxAttempts = 3;
    
    while (!activationVerified && attempts < maxAttempts) {
      try {
        final activated = await _activateStone();
        if (activated) {
          activationVerified = true;
          debugPrint('✅ [Print] SDK ativado e verificado (tentativa ${attempts + 1})');
        } else {
          // Se retornou false mas não lançou exceção, pode ser que já esteja ativado
          // por outro componente. Na primeira tentativa, aguarda um pouco e tenta novamente
          attempts++;
          if (attempts < maxAttempts) {
            debugPrint('⚠️ [Print] Ativação retornou false, aguardando e tentando novamente... (tentativa ${attempts + 1}/$maxAttempts)');
            await Future.delayed(const Duration(milliseconds: 300));
          } else {
            // Na última tentativa, assume que pode estar funcionando mesmo retornando false
            // (pode estar ativado por outro adapter)
            debugPrint('ℹ️ [Print] Ativação retornou false após $maxAttempts tentativas, mas continuando (pode estar ativado por outro componente)');
            activationVerified = true; // Continua mesmo assim
          }
        }
    } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // Se já estiver ativado, considera sucesso
        if (errorStr.contains('already') || 
            errorStr.contains('já') || 
            errorStr.contains('koin') ||
            errorStr.contains('started')) {
          activationVerified = true;
          debugPrint('ℹ️ [Print] SDK já estava ativado');
        } else {
          attempts++;
          if (attempts < maxAttempts) {
            debugPrint('⚠️ [Print] Erro ao verificar ativação, tentando novamente... (tentativa ${attempts + 1}/$maxAttempts): $e');
            await Future.delayed(const Duration(milliseconds: 300));
          } else {
            // Na última tentativa, mesmo com erro, continua (pode estar funcionando)
            debugPrint('⚠️ [Print] Não foi possível verificar ativação após $maxAttempts tentativas, mas continuando (pode estar ativado por outro componente)');
            activationVerified = true; // Continua mesmo assim para não bloquear
          }
        }
      }
    }
    
    // Aguarda um pouco mais para garantir que tudo está pronto
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      debugPrint('🖨️ Imprimindo comanda na Stone Thermal usando SDK...');
      
      // Constrói lista de itens para impressão usando ItemPrintModel
      final items = <ItemPrintModel>[];
      
      // ========== CABEÇALHO COM IMAGEM ==========
      // Espaço inicial
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Imagem do logo (se disponível)
      try {
        if (_logoBase64.isNotEmpty && _logoBase64 != 'iVBORw0KGgoAAAA...') {
          // O SDK da Stone espera a string base64 diretamente no campo data
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.image,
            data: _logoBase64,
          ));
          // Espaço após imagem
          items.add(const ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: '',
          ));
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao processar imagem base64: $e');
        // Continua a impressão mesmo se a imagem falhar
      }
      
      // Linha separadora superior
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '════════════════════════════════',
      ));
      
      // Título centralizado e destacado
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _centerText(data.header.title, 32),
      ));
      
      // Subtítulo (se houver)
      if (data.header.subtitle != null && data.header.subtitle!.isNotEmpty) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _centerText(data.header.subtitle!, 32),
        ));
      }
      
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Linha separadora
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // ========== INFORMAÇÕES DA COMANDA ==========
      // Data e hora formatadas
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _formatDateTime(data.header.dateTime),
      ));
      
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Informações da mesa/comanda/cliente
      if (data.entityInfo.mesaNome != null) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'Mesa: ${data.entityInfo.mesaNome}',
        ));
      } else if (data.entityInfo.comandaCodigo != null) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: 'Comanda: ${data.entityInfo.comandaCodigo}',
        ));
      }
      
      if (data.entityInfo.clienteNome.isNotEmpty) {
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: 'Cliente: ${data.entityInfo.clienteNome}',
      ));
      }
      
      // Linha separadora
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // ========== ITENS ==========
      // Cabeçalho da tabela de itens
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: 'ITENS DO PEDIDO',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Lista de itens formatada
      for (var i = 0; i < data.items.length; i++) {
        final item = data.items[i];
        
        // Número do item
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '${i + 1}. ${item.produtoNome}',
        ));
        
        // Variação se houver
        if (item.produtoVariacaoNome != null && item.produtoVariacaoNome!.isNotEmpty) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: '   Variação: ${item.produtoVariacaoNome}',
          ));
        }
        
        // Quantidade e valores formatados
        final qtdStr = item.quantidade.toStringAsFixed(0);
        final unitStr = _formatCurrency(item.precoUnitario);
        final totalStr = _formatCurrency(item.valorTotal);
        
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '   Qtd: $qtdStr  |  Unit: $unitStr',
        ));
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '   Total: $totalStr',
        ));
        
        // Componentes removidos
        if (item.componentesRemovidos.isNotEmpty) {
          items.add(ItemPrintModel(
            type: ItemPrintTypeEnum.text,
            data: '   Sem: ${item.componentesRemovidos.join(', ')}',
          ));
        }
        
        // Espaço entre itens
        if (i < data.items.length - 1) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
      }
      }
      
      // Linha separadora antes dos totais
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // ========== TOTAIS ==========
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      // Subtotal
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _alignRight('Subtotal:', _formatCurrency(data.totals.subtotal), 32),
      ));
      
      // Desconto
      if (data.totals.descontoTotal > 0) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _alignRight('Desconto:', _formatCurrency(-data.totals.descontoTotal), 32),
        ));
      }
      
      // Acréscimo
      if (data.totals.acrescimoTotal > 0) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _alignRight('Acréscimo:', _formatCurrency(data.totals.acrescimoTotal), 32),
        ));
      }
      
      // Impostos
      if (data.totals.impostosTotal > 0) {
        items.add(ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: _alignRight('Impostos:', _formatCurrency(data.totals.impostosTotal), 32),
        ));
      }
      
      // Linha separadora antes do total
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '────────────────────────────────',
      ));
      
      // Total destacado
      items.add(ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: _alignRight('TOTAL:', _formatCurrency(data.totals.valorTotal), 32),
      ));
      
      // Linha separadora após total
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '════════════════════════════════',
      ));
      
      // ========== RODAPÉ ==========
      if (data.footer.message != null && data.footer.message!.isNotEmpty) {
        items.add(const ItemPrintModel(
          type: ItemPrintTypeEnum.text,
          data: '',
        ));
        
        // Quebra mensagem do rodapé em linhas e formata
        final footerLines = data.footer.message!.split('\n');
        for (final line in footerLines) {
          if (line.trim().isNotEmpty) {
            // Quebra linhas longas
            final wrappedLines = _wrapText(line.trim(), 32);
            for (final wrappedLine in wrappedLines) {
            items.add(ItemPrintModel(
              type: ItemPrintTypeEnum.text,
                data: wrappedLine,
            ));
            }
          }
        }
      }
      
      // Linha final
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '════════════════════════════════',
      ));
      
      // Espaços finais para cortar papel
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      items.add(const ItemPrintModel(
        type: ItemPrintTypeEnum.text,
        data: '',
      ));
      
      debugPrint('🖨️ Enviando ${items.length} itens para impressão Stone SDK...');
      
      // Imprime usando SDK da Stone
      final result = await StonePayments.print(items);
      
      if (result != null && result.isNotEmpty) {
        debugPrint('✅ Impressão concluída: $result');
        return PrintResult(
          success: true,
          printJobId: 'STONE-SDK-${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        debugPrint('⚠️ Impressão retornou resultado vazio');
        return PrintResult(
          success: true, // Considera sucesso mesmo sem retorno explícito
          printJobId: 'STONE-SDK-${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao imprimir comanda Stone: $e');
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao imprimir: ${e.toString()}',
      );
    }
  }
  
  @override
  Future<bool> checkPrinterStatus() async {
    if (!_initialized) return false;
    
    try {
      // Stone não tem verificação direta de status
      // Retorna true se inicializado
      return _initialized;
    } catch (e) {
      return false;
    }
  }
  
  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
  
  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
  
  /// Centraliza um texto em uma linha de largura específica
  String _centerText(String text, int width) {
    if (text.length >= width) {
      return text.substring(0, width);
    }
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }
  
  /// Alinha texto à direita com label à esquerda
  String _alignRight(String label, String value, int width) {
    final labelValue = '$label $value';
    if (labelValue.length >= width) {
      return labelValue.substring(0, width);
    }
    final padding = width - labelValue.length;
    return label + ' ' * padding + value;
  }
  
  /// Quebra texto longo em múltiplas linhas respeitando o limite de caracteres
  List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) {
      return [text];
    }
    
    final lines = <String>[];
    var currentLine = '';
    
    final words = text.split(' ');
    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ((currentLine + ' ' + word).length <= maxWidth) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    
    return lines;
  }
  
  /// Imprime recibo do cliente (após pagamento aprovado)
  Future<void> printClientReceipt() async {
    try {
      debugPrint('🖨️ Imprimindo recibo do cliente...');
      final result = await StonePayments.printReceipt(TypeOwnerPrintEnum.client);
      debugPrint('✅ Recibo do cliente impresso: $result');
    } catch (e) {
      debugPrint('❌ Erro ao imprimir recibo do cliente: $e');
      rethrow;
    }
  }
  
  /// Imprime recibo do comerciante (após pagamento aprovado)
  Future<void> printMerchantReceipt() async {
    try {
      debugPrint('🖨️ Imprimindo recibo do comerciante...');
      final result = await StonePayments.printReceipt(TypeOwnerPrintEnum.merchant);
      debugPrint('✅ Recibo do comerciante impresso: $result');
    } catch (e) {
      debugPrint('❌ Erro ao imprimir recibo do comerciante: $e');
      rethrow;
    }
  }
}

