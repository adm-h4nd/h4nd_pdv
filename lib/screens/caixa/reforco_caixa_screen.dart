import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/app_header.dart';
import '../../../data/models/core/caixa/ciclo_caixa_dto.dart';
import '../../../data/services/core/ciclo_caixa_service.dart';
import '../../../data/repositories/configuracao_pdv_caixa_repository.dart';
import '../../../presentation/providers/services_provider.dart';

/// Tela para adicionar reforço (crédito) ao caixa
class ReforcoCaixaScreen extends StatefulWidget {
  final CicloCaixaDto cicloCaixa;

  const ReforcoCaixaScreen({
    super.key,
    required this.cicloCaixa,
  });

  @override
  State<ReforcoCaixaScreen> createState() => _ReforcoCaixaScreenState();
}

class _ReforcoCaixaScreenState extends State<ReforcoCaixaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _observacoesController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _valorController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  double? _parseValor(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = _parseValor(_valorController.text);
    if (valor == null || valor <= 0) {
      setState(() {
        _errorMessage = 'Valor deve ser maior que zero';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final configRepo = ConfiguracaoPdvCaixaRepository();
      final config = configRepo.carregar();
      
      if (config == null) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'PDV e Caixa não configurados';
        });
        return;
      }

      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final cicloCaixaService = CicloCaixaService(
        apiClient: servicesProvider.authService.apiClient,
      );

      final response = await cicloCaixaService.reforcoCicloCaixa(
        cicloCaixaId: widget.cicloCaixa.id,
        valor: valor,
        pdvId: config.pdvId,
        observacoes: _observacoesController.text.isEmpty ? null : _observacoesController.text,
      );

      if (!response.success) {
        setState(() {
          _isSaving = false;
          _errorMessage = response.message;
        });
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reforço adicionado com sucesso!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop(true); // Retorna true para indicar sucesso
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppHeader(
        title: 'Reforço de Caixa',
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Informações do ciclo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Informações do Caixa',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Caixa: ${widget.cicloCaixa.caixaNome}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Conta Origem: ${widget.cicloCaixa.contaOrigemNome}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Campo de valor
              Text(
                'Valor do Reforço',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _valorController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.-]')),
                ],
                decoration: InputDecoration(
                  hintText: '0,00',
                  prefixIcon: Icon(Icons.attach_money, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Valor é obrigatório';
                  }
                  final valor = _parseValor(value);
                  if (valor == null || valor <= 0) {
                    return 'Valor deve ser maior que zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Campo de observações
              Text(
                'Observações (opcional)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _observacoesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Adicione observações sobre este reforço...',
                  prefixIcon: Icon(Icons.note, color: AppTheme.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Mensagem de erro
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Botão de salvar
              ElevatedButton(
                onPressed: _isSaving ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline),
                          const SizedBox(width: 8),
                          Text(
                            'Adicionar Reforço',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

