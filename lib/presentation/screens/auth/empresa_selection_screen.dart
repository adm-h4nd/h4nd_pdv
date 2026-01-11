import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/services_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../data/models/auth/empresa.dart';
import '../../../data/services/core/auth_service.dart';
import '../../widgets/common/h4nd_logo.dart';
import '../../../core/validators/configuracao_pdv_caixa_validator.dart';
import '../../../screens/configuracao/pdv_caixa_config_screen.dart';
import '../../widgets/common/home_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tela de seleção de empresa após login
/// Exibida quando o usuário tem acesso a múltiplas empresas
class EmpresaSelectionScreen extends StatefulWidget {
  const EmpresaSelectionScreen({super.key});

  @override
  State<EmpresaSelectionScreen> createState() => _EmpresaSelectionScreenState();
}

class _EmpresaSelectionScreenState extends State<EmpresaSelectionScreen> {
  List<Empresa> _empresas = [];
  String? _selectedEmpresaId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadEmpresas();
  }

  Future<void> _loadEmpresas() async {
    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final authService = servicesProvider.authService;
      
      final empresas = await authService.getEmpresas();
      
      if (mounted) {
        setState(() {
          _empresas = empresas;
          _isLoading = false;
          
          // Se houver apenas uma empresa, seleciona automaticamente
          if (_empresas.length == 1) {
            _selectedEmpresaId = _empresas[0].id;
            _continue();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar empresas: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _continue() async {
    if (_selectedEmpresaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma empresa'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      final authService = servicesProvider.authService;
      
      await authService.setSelectedEmpresa(_selectedEmpresaId!);
      
      if (!mounted) return;
      
      // Navegar para a próxima etapa (validação de configuração)
      final configValida = await _validarConfiguracao(authService, servicesProvider);
      
      if (!mounted) return;
      
      if (!configValida) {
        // Se configuração não é válida, mostrar tela de configuração
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdaptiveLayout(
              child: PdvCaixaConfigScreen(allowBack: false),
            ),
          ),
        );
      } else {
        // Se configuração é válida, ir para home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdaptiveLayout(
              child: HomeNavigation(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar seleção: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<bool> _validarConfiguracao(
    AuthService authService,
    ServicesProvider servicesProvider,
  ) async {
    try {
      return await ConfiguracaoPdvCaixaValidator.validarConfiguracao(
        authService: authService,
        servicesProvider: servicesProvider,
      );
    } catch (e) {
      debugPrint('Erro ao validar configuração: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveLayoutProvider.of(context);
    if (adaptive == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E3A8A),
              const Color(0xFF2563EB),
              const Color(0xFF1E3A8A).withOpacity(0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.isMobile ? 24 : 48,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo H4ND
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.isMobile ? 24 : 32,
                        vertical: adaptive.isMobile ? 16 : 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: H4NDLogo(
                          fontSize: adaptive.isMobile ? 48 : 56,
                          showPdv: true,
                        ),
                      ),
                    ),
                    SizedBox(height: adaptive.isMobile ? 24 : 32),

                    // Card de seleção
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Título
                            Text(
                              'Selecione a Empresa',
                              style: GoogleFonts.inter(
                                fontSize: adaptive.isMobile ? 26 : 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E3A8A),
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Você tem acesso a múltiplas empresas.\nSelecione qual deseja utilizar:',
                              style: GoogleFonts.inter(
                                fontSize: adaptive.isMobile ? 14 : 15,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Divisor
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.grey[300]!,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Lista de empresas
                            if (_isLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_empresas.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Text(
                                    'Nenhuma empresa disponível',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._empresas.map((empresa) {
                                final isSelected = _selectedEmpresaId == empresa.id;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    onTap: _isSaving
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedEmpresaId = empresa.id;
                                            });
                                          },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor.withOpacity(0.1)
                                            : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Ícone de empresa
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primaryColor
                                                  : Colors.grey.shade300,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.business,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.grey.shade600,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Nome da empresa
                                          Expanded(
                                            child: Text(
                                              empresa.nome,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? AppTheme.primaryColor
                                                    : AppTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          // Indicador de seleção
                                          if (isSelected)
                                            Icon(
                                              Icons.check_circle,
                                              color: AppTheme.primaryColor,
                                              size: 24,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),

                            const SizedBox(height: 24),

                            // Botão de continuar
                            ElevatedButton(
                              onPressed: _isSaving || _selectedEmpresaId == null
                                  ? null
                                  : _continue,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                disabledBackgroundColor: Colors.grey.shade300,
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
                                      'Continuar',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
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
            ),
          ),
        ),
      ),
    );
  }
}

