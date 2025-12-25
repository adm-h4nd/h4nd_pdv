import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/config/env_config.dart';
import 'core/config/server_config_service.dart';
import 'core/storage/preferences_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'data/services/core/auth_service.dart';
import 'data/database/app_database.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/services_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/pedido_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/adaptive_layout/adaptive_layout.dart';
import 'screens/splash/splash_screen.dart';
import 'presentation/screens/server_config/server_config_screen.dart';
import 'core/deeplink/deeplink_manager.dart';
import 'core/deeplink/deeplink_handler.dart';
import 'core/payment/payment_service.dart';
import 'core/payment/pagamento_pendente_manager.dart';
import 'core/payment/pagamento_pendente_service.dart';
import 'data/repositories/pagamento_pendente_repository.dart';
import 'package:flutter/foundation.dart';

// NavigatorKey global para acessar context em qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeApp();
}

/// Função helper para inicializar o app (pode ser chamada novamente após configurar servidor)
Future<void> initializeApp() async {
  // Remove a splash screen branca do Flutter
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  
  // Inicializa serviços
  await PreferencesService.init();
  
  // Verifica se o servidor está configurado
  final isServerConfigured = ServerConfigService.isConfigured();
  
  // Se não estiver configurado, inicia direto na tela de configuração
  if (!isServerConfigured) {
    runApp(
      MaterialApp(
        title: 'MX Cloud PDV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const AdaptiveLayout(
          child: ServerConfigScreen(allowBack: false),
        ),
      ),
    );
    return;
  }
  
  // Inicializa Hive (banco de dados local)
  await AppDatabase.init();
  
  // Cria instâncias dos serviços primeiro (para ter acesso ao ApiClient)
  final config = Environment.config;
  final secureStorage = SecureStorageService();
  final authService = AuthService(
    config: config,
    secureStorage: secureStorage,
  );
  
  // Cria ServicesProvider temporário para obter serviços
  final tempServicesProvider = ServicesProvider(authService);
  
  // Configura PaymentService com VendaService (para callbacks de deeplink)
  await PaymentService.getInstance();
  PaymentService.setVendaService(tempServicesProvider.vendaService);
  
  // Configura PagamentoPendenteManager
  final pagamentoPendenteRepo = PagamentoPendenteRepository();
  final pagamentoPendenteService = PagamentoPendenteService(
    repository: pagamentoPendenteRepo,
    vendaService: tempServicesProvider.vendaService,
  );
  
  PagamentoPendenteManager.instance.initialize(
    service: pagamentoPendenteService,
    navigatorKey: navigatorKey,
    vendaService: tempServicesProvider.vendaService,
    mesaService: tempServicesProvider.mesaService,
    comandaService: tempServicesProvider.comandaService,
  );
  
  // Inicializa DeepLinkManager (escuta callbacks de pagamento/impressão)
  // O callback de pagamento salva localmente e abre dialog bloqueante
  await DeepLinkManager.instance.initialize(
    onPaymentResult: (result) async {
      debugPrint('💳 [DeepLink] Resultado de pagamento recebido: ${result.success ? "Sucesso" : "Erro"}');
      
      if (result.success && result.orderId != null && result.amount != null) {
        // Processa pagamento aprovado: salva localmente e abre dialog bloqueante
        await PagamentoPendenteManager.instance.processarPagamentoAprovado(
          vendaId: result.orderId!, // Já é o GUID original (recuperado do mapeamento)
          valor: result.amount!,
          paymentType: result.paymentType,
          brand: result.brand,
          installments: result.installments,
          transactionId: result.transactionId,
        );
      } else {
        debugPrint('⚠️ [DeepLink] Pagamento não aprovado ou dados incompletos');
      }
    },
    onPrintResult: (result) {
      debugPrint('🖨️ [DeepLink] Resultado de impressão recebido: ${result.success ? "Sucesso" : "Erro"}');
      // Impressão não precisa registrar no backend, apenas log
    },
  );
  
  runApp(
    MXCloudPDVApp(
      authService: authService,
    ),
  );
}

class MXCloudPDVApp extends StatelessWidget {
  final AuthService authService;

  const MXCloudPDVApp({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final servicesProvider = ServicesProvider(authService);
    
    // Inicializar repositories após criar o provider
    servicesProvider.initRepositories();
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider.value(
          value: servicesProvider,
        ),
        ChangeNotifierProxyProvider<ServicesProvider, SyncProvider>(
          create: (_) => servicesProvider.syncProvider,
          update: (_, services, __) => services.syncProvider,
        ),
        ChangeNotifierProxyProvider<ServicesProvider, PedidoProvider>(
          create: (_) => PedidoProvider(),
          update: (_, services, previous) {
            final provider = previous ?? PedidoProvider();
            provider.mesaService = services.mesaService;
            provider.comandaService = services.comandaService;
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // NavigatorKey global para dialogs
        title: 'MX Cloud PDV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        // Remove a splash screen branca do Flutter
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
            child: child!,
          );
        },
        home: const AdaptiveLayout(
          child: SplashScreen(),
        ),
      ),
    );
  }
}
