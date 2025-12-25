import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/adaptive_layout/adaptive_layout.dart';
import '../../../core/config/server_config_service.dart';
import '../../../core/network/health_check_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/preferences_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import '../../../main.dart' as main_app;

/// Tela de configuração do servidor
/// Aparece quando não há configuração salva ou quando o usuário quer trocar servidor
class ServerConfigScreen extends StatefulWidget {
  final bool allowBack;
  
  const ServerConfigScreen({
    super.key,
    this.allowBack = false,
  });

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  bool _isValidating = false;
  bool _isValid = false;
  String? _errorMessage;
  String? _currentServerUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final currentUrl = ServerConfigService.getServerUrl();
    setState(() {
      _currentServerUrl = currentUrl;
      if (currentUrl != null) {
        _serverUrlController.text = currentUrl;
      }
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _isValid = false;
    });

    final url = _serverUrlController.text.trim();
    
    // Validar healthcheck
    final healthResult = await HealthCheckService.checkHealth(url);
    
    setState(() {
      _isValidating = false;
      _isValid = healthResult.success;
      _errorMessage = healthResult.message;
    });

    if (healthResult.success) {
      // Salvar configuração
      final saved = await ServerConfigService.saveServerUrl(url);
      
      if (saved && mounted) {
        // Se estava trocando servidor, fazer logout
        if (_currentServerUrl != null && _currentServerUrl != url) {
          await _handleServerChange();
        } else {
          // Primeira configuração - reiniciar app para carregar providers
          // Isso garante que todos os serviços sejam inicializados corretamente
          if (mounted) {
            // Reinicializar o app completamente
            await main_app.initializeApp();
          }
        }
      }
    }
  }

  Future<void> _handleServerChange() async {
    // Fazer logout e limpar tokens
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    
    // Limpar storage seguro também
    final secureStorage = SecureStorageService();
    await secureStorage.delete(StorageKeys.token);
    await secureStorage.delete(StorageKeys.refreshToken);
    await secureStorage.delete(StorageKeys.user);
    
    // Limpar empresas selecionadas
    await PreferencesService.remove(StorageKeys.empresas);
    await PreferencesService.remove(StorageKeys.selectedEmpresa);
    
    if (mounted) {
      // Mostrar mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Servidor alterado com sucesso. Faça login novamente.'),
          backgroundColor: const Color(0xFF10B981), // successColor
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Navegar para login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AdaptiveLayout(
            child: LoginScreen(),
          ),
        ),
        (route) => false,
      );
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
      appBar: widget.allowBack
          ? AppBar(
              title: const Text('Configuração do Servidor'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo ou ícone
                      Icon(
                        Icons.dns_outlined,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 24),
                      
                      // Título
                      Text(
                        'Configuração do Servidor',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      
                      // Subtítulo
                      Text(
                        _currentServerUrl != null
                            ? 'Altere o endereço do servidor para conectar'
                            : 'Configure o endereço do servidor para começar',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      
                      // Card de formulário
                      Container(
                        padding: EdgeInsets.all(adaptive.isMobile ? 24 : 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Campo de URL
                            TextFormField(
                              controller: _serverUrlController,
                              decoration: InputDecoration(
                                labelText: 'Endereço do Servidor',
                                hintText: 'Ex: http://192.168.1.100:5101',
                                prefixIcon: const Icon(Icons.link),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _validateAndSave(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Digite o endereço do servidor';
                                }
                                final url = value.trim();
                                if (!url.contains('://') && !url.contains('.')) {
                                  return 'Digite um endereço válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            
                            // Status de validação
                            if (_isValidating)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_isValid)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.successColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: const Color(0xFF10B981), // successColor
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Servidor acessível e funcionando!',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF10B981), // successColor
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.errorColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        style: GoogleFonts.inter(
                                          color: AppTheme.errorColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 24),
                            
                            // Botão de salvar
                            ElevatedButton(
                              onPressed: _isValidating ? null : _validateAndSave,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(0xFF6366F1), // primaryColor
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isValidating
                                    ? 'Validando...'
                                    : _currentServerUrl != null
                                        ? 'Salvar e Trocar Servidor'
                                        : 'Validar e Continuar',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            
                            // Informações adicionais
                            if (_currentServerUrl != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Servidor atual: $_currentServerUrl',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF6B7280), // textSecondary
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '⚠️ Ao trocar o servidor, você será desconectado e precisará fazer login novamente.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFFF59E0B), // warningColor
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

