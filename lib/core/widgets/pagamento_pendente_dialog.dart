import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../../data/models/local/pagamento_pendente_local.dart';

/// Dialog bloqueante para registro de pagamento pendente
/// 
/// Não permite fechar até que o pagamento seja registrado ou cancelado.
/// Aparece automaticamente quando há um pagamento pendente.
class PagamentoPendenteDialog extends StatefulWidget {
  final PagamentoPendenteLocal pagamento;
  final Future<bool> Function() onTentarRegistrar;
  final Future<void> Function() onCancelar;
  final VoidCallback? onSucesso; // Callback quando pagamento é registrado com sucesso

  const PagamentoPendenteDialog({
    super.key,
    required this.pagamento,
    required this.onTentarRegistrar,
    required this.onCancelar,
    this.onSucesso,
  });

  @override
  State<PagamentoPendenteDialog> createState() => _PagamentoPendenteDialogState();

  /// Mostra o dialog bloqueante
  static Future<void> show({
    required BuildContext context,
    required PagamentoPendenteLocal pagamento,
    required Future<bool> Function() onTentarRegistrar,
    required Future<void> Function() onCancelar,
    VoidCallback? onSucesso,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Bloqueante - não pode fechar
      builder: (context) => PagamentoPendenteDialog(
        pagamento: pagamento,
        onTentarRegistrar: onTentarRegistrar,
        onCancelar: onCancelar,
        onSucesso: onSucesso,
      ),
    );
  }
}

class _PagamentoPendenteDialogState extends State<PagamentoPendenteDialog> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _showErrorOptions = false;

  @override
  void initState() {
    super.initState();
    // Tenta registrar automaticamente ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tentarRegistrar();
    });
  }

  Future<void> _tentarRegistrar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showErrorOptions = false;
    });

    try {
      final sucesso = await widget.onTentarRegistrar();
      
      if (sucesso) {
        // Sucesso - fecha o dialog e chama callback
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSucesso?.call();
        }
      } else {
        // Erro - mostra opções
        setState(() {
          _isLoading = false;
          _showErrorOptions = true;
          _errorMessage = widget.pagamento.ultimoErro ?? 'Erro ao registrar pagamento';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showErrorOptions = true;
        _errorMessage = 'Erro: ${e.toString()}';
      });
    }
  }

  Future<void> _cancelar() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Pagamento'),
        content: const Text(
          'Você precisará estornar este pagamento na máquina Stone P2.\n\n'
          'Deseja realmente cancelar o registro deste pagamento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await widget.onCancelar();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Impede fechar com botão voltar
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _showErrorOptions 
                      ? Colors.red.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showErrorOptions ? Icons.error_outline : Icons.payment,
                  size: 32,
                  color: _showErrorOptions ? Colors.red : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // Título
              Text(
                _showErrorOptions 
                    ? 'Erro ao Registrar Pagamento'
                    : 'Registrando Pagamento',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Mensagem
              Text(
                _showErrorOptions
                    ? _errorMessage ?? 'Não foi possível registrar o pagamento no servidor.'
                    : 'Aguarde enquanto registramos o pagamento no servidor...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              if (!_showErrorOptions) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],

              if (_showErrorOptions) ...[
                const SizedBox(height: 8),
                Text(
                  'Tentativas: ${widget.pagamento.tentativas}/3',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Botões de ação
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelar,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.pagamento.atingiuLimiteTentativas 
                            ? null 
                            : _tentarRegistrar,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Tentar Novamente',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
