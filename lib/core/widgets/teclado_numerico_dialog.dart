import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../adaptive_layout/adaptive_layout.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Componente reutilizável para entrada numérica com teclado numérico
/// Pode ser usado para números de mesa, comanda, quantidades, valores, etc.
class TecladoNumericoDialog extends StatefulWidget {
  final String titulo;
  final String? valorInicial;
  final String? hint;
  final IconData? icon;
  final Color? cor;
  final bool permiteDecimal;
  final Function(String)? onConfirmar;
  final VoidCallback? onCancelar;

  const TecladoNumericoDialog({
    super.key,
    required this.titulo,
    this.valorInicial,
    this.hint,
    this.icon,
    this.cor,
    this.permiteDecimal = false,
    this.onConfirmar,
    this.onCancelar,
  });

  /// Mostra o dialog/tela de entrada numérica
  /// Retorna o valor digitado ou null se cancelado
  static Future<String?> show(
    BuildContext context, {
    required String titulo,
    String? valorInicial,
    String? hint,
    IconData? icon,
    Color? cor,
    bool permiteDecimal = false,
  }) async {
    String? resultado;
    
    final adaptive = AdaptiveLayoutProvider.of(context);
    final isMobile = adaptive?.isMobile ?? true;
    
    if (isMobile) {
      // Em mobile: tela cheia
      resultado = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => AdaptiveLayout(
            child: TecladoNumericoDialog(
              titulo: titulo,
              valorInicial: valorInicial,
              hint: hint,
              icon: icon,
              cor: cor ?? AppTheme.primaryColor,
              permiteDecimal: permiteDecimal,
            ),
          ),
          fullscreenDialog: true,
        ),
      );
    } else {
      // Em desktop: modal grande mas não tela cheia
      resultado = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AdaptiveLayout(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(40),
            child: Container(
              width: 600,
              height: 700,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TecladoNumericoDialog(
                titulo: titulo,
                valorInicial: valorInicial,
                hint: hint,
                icon: icon,
                cor: cor ?? AppTheme.primaryColor,
                permiteDecimal: permiteDecimal,
              ),
            ),
          ),
        ),
      );
    }
    
    return resultado;
  }

  @override
  State<TecladoNumericoDialog> createState() => _TecladoNumericoDialogState();
}

class _TecladoNumericoDialogState extends State<TecladoNumericoDialog> {
  String _valor = '';

  @override
  void initState() {
    super.initState();
    _valor = widget.valorInicial ?? '';
  }

  void _adicionarDigito(String digito) {
    if (widget.permiteDecimal && digito == '.' && _valor.contains('.')) {
      return; // Não permite dois pontos decimais
    }
    setState(() {
      _valor += digito;
    });
  }

  void _removerUltimoDigito() {
    if (_valor.isNotEmpty) {
      setState(() {
        _valor = _valor.substring(0, _valor.length - 1);
      });
    }
  }

  void _limpar() {
    setState(() {
      _valor = '';
    });
  }

  void _confirmar() {
    if (widget.onConfirmar != null) {
      widget.onConfirmar!(_valor);
    } else {
      Navigator.of(context).pop(_valor.isEmpty ? null : _valor);
    }
  }

  void _cancelar() {
    if (widget.onCancelar != null) {
      widget.onCancelar!();
    } else {
      Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) return const SizedBox.shrink();

    final isMobile = adaptive.isMobile;
    final cor = widget.cor ?? AppTheme.primaryColor;

    if (isMobile) {
      // Mobile: Scaffold (tela cheia)
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textPrimary),
            onPressed: _cancelar,
          ),
          title: Text(
            widget.titulo,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildConteudo(adaptive, cor),
      );
    } else {
      // Desktop: conteúdo do Dialog
      return Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: _cancelar,
                ),
              ],
            ),
          ),
          // Conteúdo
          Expanded(child: _buildConteudo(adaptive, cor)),
        ],
      );
    }
  }

  Widget _buildConteudo(AdaptiveLayoutProvider adaptive, Color cor) {
    return Padding(
      padding: EdgeInsets.all(adaptive.isMobile ? 24 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Campo de exibição do valor
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.isMobile ? 20 : 24,
              vertical: adaptive.isMobile ? 20 : 24,
            ),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 20),
              border: Border.all(color: cor, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: cor,
                    size: adaptive.isMobile ? 32 : 36,
                  ),
                  SizedBox(width: adaptive.isMobile ? 16 : 20),
                ],
                Flexible(
                  child: Text(
                    _valor.isEmpty ? (widget.hint ?? 'Digite...') : _valor,
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 24 : 28,
                      fontWeight: FontWeight.w600,
                      color: _valor.isEmpty ? Colors.grey.shade500 : cor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: adaptive.isMobile ? 40 : 48),
          
          // Teclado numérico
          Expanded(
            child: _buildTecladoNumerico(adaptive, cor),
          ),
          
          SizedBox(height: adaptive.isMobile ? 24 : 32),
          
          // Botões de ação
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelar,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: adaptive.isMobile ? 16 : 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: adaptive.isMobile ? 16 : 20),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _valor.isEmpty ? null : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: adaptive.isMobile ? 16 : 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(adaptive.isMobile ? 12 : 14),
                    ),
                  ),
                  child: Text(
                    'Confirmar',
                    style: GoogleFonts.inter(
                      fontSize: adaptive.isMobile ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTecladoNumerico(AdaptiveLayoutProvider adaptive, Color cor) {
    return Container(
      padding: EdgeInsets.all(adaptive.isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 16 : 20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Linhas 1-3, 4-6, 7-9
          Expanded(
            flex: 3,
            child: Column(
              children: [
                for (int linha = 0; linha < 3; linha++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: linha < 2 ? (adaptive.isMobile ? 8 : 10) : 0,
                      ),
                      child: Row(
                        children: [
                          for (int coluna = 0; coluna < 3; coluna++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: adaptive.isMobile ? 6 : 8),
                                child: _buildBotaoTeclado(
                                  adaptive,
                                  '${linha * 3 + coluna + 1}',
                                  onTap: () => _adicionarDigito('${linha * 3 + coluna + 1}'),
                                  cor: cor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Espaçamento entre linhas numéricas e linha de ações
          SizedBox(height: adaptive.isMobile ? 8 : 10),
          
          // Linha 0, ponto decimal (se permitido), backspace, limpar
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: adaptive.isMobile ? 6 : 8),
                    child: _buildBotaoTeclado(
                      adaptive,
                      '0',
                      onTap: () => _adicionarDigito('0'),
                      cor: cor,
                    ),
                  ),
                ),
                if (widget.permiteDecimal)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: adaptive.isMobile ? 6 : 8),
                      child: _buildBotaoTeclado(
                        adaptive,
                        '.',
                        onTap: () => _adicionarDigito('.'),
                        cor: cor,
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: adaptive.isMobile ? 6 : 8),
                    child: _buildBotaoTeclado(
                      adaptive,
                      '⌫',
                      onTap: _removerUltimoDigito,
                      cor: AppTheme.warningColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: adaptive.isMobile ? 6 : 8),
                    child: _buildBotaoTeclado(
                      adaptive,
                      '✕',
                      onTap: _limpar,
                      cor: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoTeclado(
    AdaptiveLayoutProvider adaptive,
    String texto, {
    required VoidCallback onTap,
    required Color cor,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.isMobile ? 14 : 16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            texto,
            style: GoogleFonts.inter(
              fontSize: adaptive.isMobile ? 28 : 32,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

