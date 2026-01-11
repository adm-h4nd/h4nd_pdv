import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../core/services/device_id_service.dart';
import '../../../data/services/core/pdv_service.dart';
import '../../../data/services/core/caixa_service.dart';
import '../../../data/repositories/configuracao_pdv_caixa_repository.dart';
import '../../../data/models/core/caixa/pdv_dto.dart';
import '../../../data/models/core/caixa/caixa_dto.dart';
import '../../../presentation/providers/services_provider.dart';
import '../../../presentation/widgets/common/home_navigation.dart';
import '../../../presentation/widgets/common/h4nd_logo.dart';
import '../../../widgets/app_header.dart';

/// Tela de configuração de PDV e Caixa
/// Aparece após login se não houver configuração válida
/// Também pode ser acessada via menu para alteração
class PdvCaixaConfigScreen extends StatefulWidget {
  final bool allowBack;
  final VoidCallback? onConfigSaved;

  const PdvCaixaConfigScreen({
    super.key,
    this.allowBack = false,
    this.onConfigSaved,
  });

  @override
  State<PdvCaixaConfigScreen> createState() => _PdvCaixaConfigScreenState();
}

class _PdvCaixaConfigScreenState extends State<PdvCaixaConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _configRepo = ConfiguracaoPdvCaixaRepository();
  final _observacoesController = TextEditingController();

  List<PDVListItemDto> _pdvs = [];
  List<CaixaListItemDto> _caixas = [];
  PDVListItemDto? _pdvSelecionado;
  CaixaListItemDto? _caixaSelecionado;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    // Aguarda o frame estar pronto para garantir que os providers estejam disponíveis
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _carregarDeviceId();
        _carregarDados();
      }
    });
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _carregarDeviceId() async {
    try {
      final deviceId = await DeviceIdService.getDeviceId();
      setState(() {
        _deviceId = deviceId;
      });
      debugPrint('📱 Device ID carregado: ${deviceId.substring(0, 8)}...');
    } catch (e) {
      debugPrint('❌ Erro ao carregar Device ID: $e');
      // Não bloquear a tela se não conseguir obter o device ID
    }
  }

  Future<void> _carregarDados() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final authService = servicesProvider.authService;
      final empresaId = await authService.getSelectedEmpresa();

      if (empresaId == null || empresaId.isEmpty) {
        // Não exibir erro técnico - apenas tratar como listas vazias
        setState(() {
          _pdvs = [];
          _caixas = [];
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }

      // Criar serviços
      final pdvService = PDVService(apiClient: servicesProvider.authService.apiClient);
      final caixaService = CaixaService(apiClient: servicesProvider.authService.apiClient);

      // Buscar PDVs disponíveis (não vinculados) e Caixas em paralelo
      // Nota: O filtro de empresa é automático via header X-Company-Id
      // Passa o DeviceId para incluir também o PDV vinculado ao dispositivo atual
      final pdvResponse = await pdvService.getPDVsDisponiveis(deviceId: _deviceId);
      final caixaResponse = await caixaService.getCaixasPorEmpresa();

      if (!mounted) return;

      // Processar cada lista independentemente
      // Priorizar dados quando disponíveis, mesmo se success for false
      // Se houver dados, usar. Se não, usar lista vazia (sem exibir erro)
      final pdvs = pdvResponse.data != null && pdvResponse.data!.isNotEmpty
          ? pdvResponse.data!
          : <PDVListItemDto>[];
      
      final caixas = caixaResponse.data != null && caixaResponse.data!.isNotEmpty
          ? caixaResponse.data!
          : <CaixaListItemDto>[];
      
      // Log para debug
      if (!pdvResponse.success && pdvResponse.data == null) {
        debugPrint('⚠️ [PdvCaixaConfig] Erro ao buscar PDVs (tratado como lista vazia): ${pdvResponse.message}');
      }
      if (!caixaResponse.success && caixaResponse.data == null) {
        debugPrint('⚠️ [PdvCaixaConfig] Erro ao buscar Caixas (tratado como lista vazia): ${caixaResponse.message}');
      }
      
      debugPrint('📊 [PdvCaixaConfig] Processamento:');
      debugPrint('  - PDV Response: success=${pdvResponse.success}, data=${pdvResponse.data != null ? pdvResponse.data!.length : "null"}');
      debugPrint('  - Caixa Response: success=${caixaResponse.success}, data=${caixaResponse.data != null ? caixaResponse.data!.length : "null"}');
      debugPrint('  - PDVs processados: ${pdvs.length}');
      debugPrint('  - Caixas processados: ${caixas.length}');

      if (pdvs.isNotEmpty) {
        debugPrint('  ✅ Primeiro PDV: ${pdvs.first.nome} (ID: ${pdvs.first.id})');
      }
      if (caixas.isNotEmpty) {
        debugPrint('  ✅ Primeiro Caixa: ${caixas.first.nome} (ID: ${caixas.first.id})');
      }

      setState(() {
        _pdvs = pdvs;
        _caixas = caixas;
        _isLoading = false;
        _errorMessage = null; // Limpar erro - as mensagens de lista vazia serão mostradas na UI
      });

      debugPrint('📊 [PdvCaixaConfig] Estado atualizado: ${_pdvs.length} PDVs, ${_caixas.length} Caixas');

      // Carregar configuração salva se existir
      _carregarConfiguracaoSalva();
    } catch (e) {
      // Erro genérico - apenas logar, não zerar listas que já foram carregadas
      // Se houver erro antes de processar as respostas, as listas já estarão vazias
      debugPrint('❌ Erro ao carregar dados: $e');
      if (!mounted) return;
      setState(() {
        // Manter as listas que já foram processadas (se houver)
        // Se chegou aqui, significa que houve erro antes de processar, então já estão vazias
        _isLoading = false;
        _errorMessage = null; // Não exibir mensagem de erro técnica
      });
    }
  }

  void _carregarConfiguracaoSalva() {
    final config = _configRepo.carregar();
    if (config != null) {
      // Tentar encontrar PDV e Caixa salvos nas listas
      final pdv = _pdvs.firstWhere(
        (p) => p.id == config.pdvId,
        orElse: () => _pdvs.isNotEmpty ? _pdvs.first : throw StateError('No PDV'),
      );
      final caixa = _caixas.firstWhere(
        (c) => c.id == config.caixaId,
        orElse: () => _caixas.isNotEmpty ? _caixas.first : throw StateError('No Caixa'),
      );

      setState(() {
        _pdvSelecionado = pdv;
        _caixaSelecionado = caixa;
      });
    }
  }

  Future<void> _salvarConfiguracao() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_pdvSelecionado == null || _caixaSelecionado == null) {
      setState(() {
        _errorMessage = 'Por favor, selecione um PDV e um Caixa';
      });
      return;
    }

    if (_deviceId == null || _deviceId!.isEmpty) {
      setState(() {
        _errorMessage = 'Não foi possível identificar o dispositivo. Por favor, tente novamente.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final pdvService = PDVService(apiClient: servicesProvider.authService.apiClient);

      // Vincular dispositivo ao PDV
      final observacoes = _observacoesController.text.trim();
      final vincularResponse = await pdvService.vincularDispositivo(
        pdvId: _pdvSelecionado!.id,
        deviceId: _deviceId!,
        observacoesVinculacao: observacoes.isNotEmpty ? observacoes : null,
      );

      if (!vincularResponse.success) {
        if (!mounted) return;
        setState(() {
          // Mensagem amigável ao invés de erro técnico
          _errorMessage = vincularResponse.message.isNotEmpty
              ? vincularResponse.message
              : 'Não foi possível vincular o dispositivo ao PDV. Por favor, tente novamente.';
          _isSaving = false;
        });
        return;
      }

      // Salvar configuração local
      final config = ConfiguracaoPdvCaixa(
        pdvId: _pdvSelecionado!.id,
        pdvNome: _pdvSelecionado!.nome,
        caixaId: _caixaSelecionado!.id,
        caixaNome: _caixaSelecionado!.nome,
      );

      await _configRepo.salvar(config);

      if (!mounted) return;

      // Callback de sucesso
      if (widget.onConfigSaved != null) {
        widget.onConfigSaved!();
      } else if (widget.allowBack) {
        // Se permitir voltar, apenas fecha a tela
        Navigator.of(context).pop();
      } else {
        // Se não permitir voltar, navega para home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdaptiveLayout(
              child: HomeNavigation(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar configuração: $e');
      if (!mounted) return;
      setState(() {
        // Mensagem amigável ao invés de erro técnico
        _errorMessage = 'Não foi possível salvar a configuração. Por favor, tente novamente.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: widget.allowBack
          ? AppHeader(
              title: 'Configuração PDV/Caixa',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    if (!widget.allowBack) ...[
                      const H4NDLogo(fontSize: 80),
                      const SizedBox(height: 32),
                    ],

                    // Título
                    Text(
                      widget.allowBack
                          ? 'Configuração PDV e Caixa'
                          : 'Configuração Inicial',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecione o PDV e o Caixa que você utilizará',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Exibir configuração atual (se houver)
                    Builder(
                      builder: (context) {
                        final config = _configRepo.carregar();
                        if (config != null) {
                          final pdvNome = config.pdvNome;
                          final caixaNome = config.caixaNome;
                          
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Configuração Atual',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'PDV: $pdvNome',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Caixa: $caixaNome',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (_deviceId != null && _deviceId!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Código: $_deviceId',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 24),

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

                    // Loading
                    if (_isLoading) ...[
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Carregando PDVs e Caixas...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      // Verificar se há PDVs disponíveis
                      if (_pdvs.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.warningColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.warningColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                      'Nenhum PDV disponível foi localizado.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.warningColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Não há PDVs disponíveis para vinculação nesta empresa. Tente atualizar a lista.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _carregarDados,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Atualizar Lista'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Dropdown PDV
                        Text(
                          'PDV *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PDVListItemDto>(
                          value: _pdvSelecionado,
                          decoration: InputDecoration(
                            hintText: 'Selecione um PDV',
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
                          items: _pdvs.map((pdv) {
                            // Exibir nome e código (se houver) do PDV
                            final displayText = pdv.codigo != null && pdv.codigo!.isNotEmpty
                                ? '${pdv.nome} (${pdv.codigo})'
                                : pdv.nome;
                            
                            return DropdownMenuItem<PDVListItemDto>(
                              value: pdv,
                              child: Text(
                                displayText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        onChanged: (pdv) {
                          setState(() {
                            _pdvSelecionado = pdv;
                            _errorMessage = null;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor, selecione um PDV';
                          }
                          return null;
                        },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Campo de observações (opcional)
                      Text(
                        'Observações de Localização',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _observacoesController,
                        decoration: InputDecoration(
                          hintText: 'Ex: Balcão Principal - Loja Centro, PDV Móvel - Entregas',
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
                        maxLines: 3,
                        maxLength: 500,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Verificar se há Caixas disponíveis
                      if (_caixas.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.warningColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.warningColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                      'Nenhum Caixa disponível foi localizado.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.warningColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Não há Caixas disponíveis nesta empresa. Tente atualizar a lista.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _carregarDados,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Atualizar Lista'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Dropdown Caixa
                        Text(
                          'Caixa *',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<CaixaListItemDto>(
                          value: _caixaSelecionado,
                          decoration: InputDecoration(
                            hintText: 'Selecione um Caixa',
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
                          items: _caixas.map((caixa) {
                            return DropdownMenuItem<CaixaListItemDto>(
                              value: caixa,
                              child: Text(
                                caixa.nome,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        onChanged: (caixa) {
                          setState(() {
                            _caixaSelecionado = caixa;
                            _errorMessage = null;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Por favor, selecione um Caixa';
                          }
                          return null;
                        },
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Botão Salvar
                      ElevatedButton(
                        onPressed: _isSaving ? null : _salvarConfiguracao,
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
                                widget.allowBack ? 'Salvar' : 'Salvar e Continuar',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),

                      // Botão Voltar (se permitido)
                      if (widget.allowBack) ...[
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
                    ],
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

