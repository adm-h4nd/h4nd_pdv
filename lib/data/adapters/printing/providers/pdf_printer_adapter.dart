import '../../../../core/printing/print_provider.dart';
import '../../../../core/printing/print_data.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

/// Provider de impressão PDF (sempre disponível)
class PDFPrinterAdapter implements PrintProvider {
  @override
  String get providerName => 'PDF';
  
  @override
  PrintType get printType => PrintType.pdf;
  
  @override
  bool get isAvailable => true; // Sempre disponível
  
  @override
  Future<void> initialize() async {
    // PDF não precisa inicializar
  }
  
  @override
  Future<void> disconnect() async {
    // Nada a fazer
  }
  
  @override
  Future<PrintResult> printComanda(PrintData data) async {
    try {
      debugPrint('📄 Gerando PDF da comanda...');
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        data.header.title,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (data.header.subtitle != null)
                        pw.Text(
                          data.header.subtitle!,
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        _formatDateTime(data.header.dateTime),
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 8),
                
                // Informações
                if (data.entityInfo.mesaNome != null)
                  pw.Text('Mesa: ${data.entityInfo.mesaNome}', style: pw.TextStyle(fontSize: 10)),
                if (data.entityInfo.comandaCodigo != null)
                  pw.Text('Comanda: ${data.entityInfo.comandaCodigo}', style: pw.TextStyle(fontSize: 10)),
                pw.Text('Cliente: ${data.entityInfo.clienteNome}', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                
                // Itens
                ...data.items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.produtoNome,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      if (item.produtoVariacaoNome != null)
                        pw.Text(
                          '  Variação: ${item.produtoVariacaoNome}',
                          style: pw.TextStyle(fontSize: 9),
                        ),
                      pw.Text(
                        '${item.quantidade.toStringAsFixed(0)}x ${_formatCurrency(item.precoUnitario)} = ${_formatCurrency(item.valorTotal)}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      if (item.componentesRemovidos.isNotEmpty)
                        pw.Text(
                          '  Sem: ${item.componentesRemovidos.join(', ')}',
                          style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                        ),
                    ],
                  ),
                )),
                
                pw.Divider(),
                pw.SizedBox(height: 8),
                
                // Totais
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SUBTOTAL:', style: pw.TextStyle(fontSize: 10)),
                    pw.Text(_formatCurrency(data.totals.subtotal), style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
                if (data.totals.descontoTotal > 0)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('DESCONTO:', style: pw.TextStyle(fontSize: 10)),
                        pw.Text(_formatCurrency(-data.totals.descontoTotal), style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _formatCurrency(data.totals.valorTotal),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Rodapé
                if (data.footer.message != null) ...[
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    data.footer.message!,
                    style: pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      );
      
      // Compartilhar/abrir o PDF
      final pdfBytes = await pdf.save();
      
      // Printing.layoutPdf funciona em todas as plataformas:
      // - Web: abre visualizador do navegador com opção de download
      // - Mobile: abre visualizador nativo com opção de compartilhar
      // - Desktop: abre visualizador de PDF padrão
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      
      debugPrint('✅ PDF gerado e compartilhado com sucesso');
      
      return PrintResult(
        success: true,
        printJobId: 'PDF-${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao gerar PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      return PrintResult(
        success: false,
        errorMessage: 'Erro ao gerar PDF: ${e.toString()}',
      );
    }
  }
  
  @override
  Future<bool> checkPrinterStatus() async {
    return true; // PDF sempre disponível
  }
  
  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

