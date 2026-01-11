import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message_helper.dart';
import '../../../widgets/app_header.dart';
import '../../../data/repositories/configuracao_pdv_caixa_repository.dart';
import '../../../presentation/providers/services_provider.dart';

/// Tela para abrir um ciclo de caixa
class AbrirCaixaScreen extends StatefulWidget {
  const AbrirCaixaScreen({super.key});

  @override
  State<AbrirCaixaScreen> createState() => _AbrirCaixaScreenState();
}

class _AbrirCaixaScreenState extends State<AbrirCaixaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _configRepo = ConfiguracaoPdvCaixaRepository();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _abrirCaixa() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final valorInicial = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0;
    if (valorInicial < 0) {
      setState(() {
        _errorMessage = 'O valor inicial não pode ser negativo';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final cicloCaixaService = servicesProvider.cicloCaixaService;

      final config = _configRepo.carregar();
      if (config == null) {
        setState(() {
          _errorMessage = 'PDV e Caixa não configurados';
          _isSaving = false;
        });
        return;
      }

      final response = await cicloCaixaService.abrirCicloCaixa(
        caixaId: config.caixaId,
        valorInicial: valorInicial,
        pdvId: config.pdvId,
      );

      if (!mounted) return;

      if (!response.success || response.data == null) {
        setState(() {
          _errorMessage = ErrorMessageHelper.getErrorMessage(
            response,
            defaultMessage: 'Erro ao abrir caixa',
          );
          _isSaving = false;
        });
        return;
      }

      // Sucesso - voltar para home
      if (mounted) {
        Navigator.of(context).pop(true); // Retorna true para indicar sucesso
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao abrir caixa: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppHeader(
        title: 'Abrir Caixa',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título
                    Text(
                      'Abertura de Caixa',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Informe o valor inicial para abertura do caixa',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Mensagem de erro
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.errorColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppTheme.errorColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                      // Campo Valor Inicial
                      Text(
                        'Valor Inicial *',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _valorController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          hintText: '0,00',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe o valor inicial';
                          }
                          final valor = double.tryParse(value.replaceAll(',', '.'));
                          if (valor == null) {
                            return 'Valor inválido';
                          }
                          if (valor < 0) {
                            return 'O valor não pode ser negativo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                      // Botão Abrir Caixa
                      ElevatedButton(
                        onPressed: _isSaving ? null : _abrirCaixa,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Abrir Caixa',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),

                      // Botão Cancelar
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

