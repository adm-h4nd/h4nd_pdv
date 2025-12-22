import '../../../../core/printing/print_provider.dart';
import '../../../../core/printing/print_data.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

/// Provider de impressão via DeepLink específico para Stone P2
/// 
/// Usa o padrão encontrado no projeto app_restaurante_kotlin:
/// printer-app://print?SHOW_FEEDBACK_SCREEN=true&SCHEME_RETURN=deeplinkprinter&PRINTABLE_CONTENT=[...]
class StoneP2DeepLinkPrintAdapter implements PrintProvider {
  @override
  String get providerName => 'Stone P2 DeepLink Print';
  
  @override
  PrintType get printType => PrintType.thermal;
  
  @override
  bool get isAvailable => true; // Sempre disponível
  
  @override
  Future<void> initialize() async {
    // DeepLink não precisa inicializar
  }
  
  @override
  Future<void> disconnect() async {
    // Nada a fazer
  }
  
  @override
  Future<PrintResult> printComanda(PrintData data) async {
    try {
      debugPrint('🖨️ [Stone P2] Preparando impressão via DeepLink...');
      
      // Constrói o conteúdo JSON para impressão no formato Stone P2
      final printableContent = _buildStoneP2PrintableContent(data);
      
      // Constrói o DeepLink específico do Stone P2
      final deepLink = _buildStoneP2DeepLink(printableContent);
      
      debugPrint('🔗 [Stone P2] Abrindo DeepLink de impressão: $deepLink');
      
      final uri = Uri.parse(deepLink);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // DeepLink não retorna resultado imediatamente
        // O app externo processa e pode retornar via callback (deeplinkprinter://print)
        // O resultado será tratado pelo handler de deeplink do app
        
        return PrintResult(
          success: true,
          printJobId: 'STONE-P2-DEEPLINK-PRINT-${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        return PrintResult(
          success: false,
          errorMessage: 'Não foi possível abrir o app de impressão Stone P2',
        );
      }
    } catch (e) {
      debugPrint('❌ [Stone P2] Erro ao imprimir via DeepLink: $e');
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao processar DeepLink Stone P2: ${e.toString()}',
      );
    }
  }
  
  @override
  Future<bool> checkPrinterStatus() async {
    // DeepLink não tem verificação de status direta
    return true;
  }
  
  /// Constrói o conteúdo JSON para impressão no formato esperado pelo Stone P2
  List<Map<String, dynamic>> _buildStoneP2PrintableContent(PrintData data) {
    final content = <Map<String, dynamic>>[];
    
    // Cabeçalho
    content.add({
      'type': 'text',
      'content': data.header.title,
      'align': 'center',
      'size': 'big',
    });
    
    if (data.header.subtitle != null && data.header.subtitle!.isNotEmpty) {
      content.add({
        'type': 'text',
        'content': data.header.subtitle!,
        'align': 'center',
        'size': 'medium',
      });
    }
    
    // Data/hora
    content.add({
      'type': 'text',
      'content': _formatDateTime(data.header.dateTime),
      'align': 'center',
      'size': 'medium',
    });
    
    // Linha separadora
    content.add({
      'type': 'line',
      'content': '________________________________',
    });
    
    // Informações da mesa/comanda
    if (data.entityInfo.mesaNome != null) {
      content.add({
        'type': 'text',
        'content': 'MESA ${data.entityInfo.mesaNome}',
        'align': 'center',
        'size': 'big',
      });
    } else if (data.entityInfo.comandaCodigo != null) {
      content.add({
        'type': 'text',
        'content': 'COMANDA ${data.entityInfo.comandaCodigo}',
        'align': 'center',
        'size': 'big',
      });
    }
    
    content.add({
      'type': 'text',
      'content': 'Cliente: ${data.entityInfo.clienteNome}',
      'align': 'left',
      'size': 'medium',
    });
    
    // Linha separadora
    content.add({
      'type': 'line',
      'content': '________________________________',
    });
    
    // Título dos itens
    content.add({
      'type': 'text',
      'content': 'ITENS',
      'align': 'center',
      'size': 'medium',
    });
    
    // Linha separadora
    content.add({
      'type': 'line',
      'content': '________________________________',
    });
    
    // Itens
    for (final item in data.items) {
      // Nome do produto
      content.add({
        'type': 'text',
        'content': item.produtoNome,
        'align': 'left',
        'size': 'medium',
      });
      
      // Variação se houver
      if (item.produtoVariacaoNome != null && item.produtoVariacaoNome!.isNotEmpty) {
        content.add({
          'type': 'text',
          'content': '  ${item.produtoVariacaoNome}',
          'align': 'left',
          'size': 'small',
        });
      }
      
      // Quantidade e valores
      final qtdStr = item.quantidade.toStringAsFixed(0);
      final unitStr = _formatCurrency(item.precoUnitario);
      final totalStr = _formatCurrency(item.valorTotal);
      content.add({
        'type': 'text',
        'content': '$qtdStr x $unitStr = $totalStr',
        'align': 'left',
        'size': 'medium',
      });
      
      // Componentes removidos
      if (item.componentesRemovidos.isNotEmpty) {
        content.add({
          'type': 'text',
          'content': '  Sem: ${item.componentesRemovidos.join(', ')}',
          'align': 'left',
          'size': 'small',
        });
      }
      
      // Espaço entre itens
      content.add({
        'type': 'text',
        'content': '',
        'align': 'left',
        'size': 'small',
      });
    }
    
    // Linha separadora
    content.add({
      'type': 'line',
      'content': '________________________________',
    });
    
    // Totais
    content.add({
      'type': 'text',
      'content': 'SUBTOTAL: ${_formatCurrency(data.totals.subtotal)}',
      'align': 'left',
      'size': 'medium',
    });
    
    if (data.totals.descontoTotal > 0) {
      content.add({
        'type': 'text',
        'content': 'DESCONTO: ${_formatCurrency(-data.totals.descontoTotal)}',
        'align': 'left',
        'size': 'medium',
      });
    }
    
    if (data.totals.acrescimoTotal > 0) {
      content.add({
        'type': 'text',
        'content': 'ACRÉSCIMO: ${_formatCurrency(data.totals.acrescimoTotal)}',
        'align': 'left',
        'size': 'medium',
      });
    }
    
    if (data.totals.impostosTotal > 0) {
      content.add({
        'type': 'text',
        'content': 'IMPOSTOS: ${_formatCurrency(data.totals.impostosTotal)}',
        'align': 'left',
        'size': 'medium',
      });
    }
    
    content.add({
      'type': 'text',
      'content': 'TOTAL: ${_formatCurrency(data.totals.valorTotal)}',
      'align': 'left',
      'size': 'big',
    });
    
    // Rodapé
    if (data.footer.message != null && data.footer.message!.isNotEmpty) {
      // Linha separadora
      content.add({
        'type': 'line',
        'content': '________________________________',
      });
      
      // Quebra mensagem do rodapé em linhas
      final footerLines = data.footer.message!.split('\n');
      for (final line in footerLines) {
        if (line.trim().isNotEmpty) {
          content.add({
            'type': 'text',
            'content': line.trim(),
            'align': 'center',
            'size': 'medium',
          });
        }
      }
    }
    
    // Linha final
    content.add({
      'type': 'line',
      'content': '________________________________',
    });
    
    return content;
  }
  
  /// Constrói o DeepLink específico do Stone P2 para impressão
  /// 
  /// Padrão: printer-app://print?SHOW_FEEDBACK_SCREEN=true&SCHEME_RETURN=deeplinkprinter&PRINTABLE_CONTENT=[...]
  String _buildStoneP2DeepLink(List<Map<String, dynamic>> printableContent) {
    // Converte o conteúdo para JSON string
    final jsonContent = jsonEncode(printableContent);
    
    final uri = Uri(
      scheme: 'printer-app',
      host: 'print',
      queryParameters: {
        'SHOW_FEEDBACK_SCREEN': 'true',
        'SCHEME_RETURN': 'deeplinkprinter',
        'PRINTABLE_CONTENT': jsonContent,
      },
    );
    
    return uri.toString();
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
}

