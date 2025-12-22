import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/services_provider.dart';
import '../../../screens/home/home_unified_screen.dart';
import '../../../screens/mesas/mesas_screen.dart';
import '../../../screens/comandas/comandas_screen.dart';
import '../../../screens/pedidos/pedidos_screen.dart';
import '../../../screens/patio/patio_screen.dart';
import '../../../screens/profile/profile_screen.dart';

/// Widget principal de navegação com bottom navigation bar
class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int _currentIndex = 0;
  int? _setor;
  bool _isLoadingSetor = true;

  @override
  void initState() {
    super.initState();
    // Usa WidgetsBinding para garantir que o contexto está pronto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSetor();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Garante que configuração do restaurante está carregada se for setor restaurante
    if (_setor == 2) {
      final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
      if (!servicesProvider.configuracaoRestauranteCarregada) {
        servicesProvider.carregarConfiguracaoRestaurante().catchError((e) {
          debugPrint('⚠️ Erro ao carregar configuração do restaurante: $e');
        });
      }
    }
  }

  Future<void> _loadSetor() async {
    // Pequeno delay para garantir que o contexto está pronto
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Adiciona timeout para evitar travamento
      final setor = await authProvider.getSetorOrganizacao()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              print('Timeout ao carregar setor, usando padrão (Varejo)');
              return null;
            },
          );
      
      if (mounted) {
        setState(() {
          _setor = setor;
          _isLoadingSetor = false;
        });
        
        // Se for restaurante, carrega configuração
        if (setor == 2) {
          final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
          if (!servicesProvider.configuracaoRestauranteCarregada) {
            servicesProvider.carregarConfiguracaoRestaurante().catchError((e) {
              debugPrint('⚠️ Erro ao carregar configuração do restaurante: $e');
            });
          }
        }
      }
    } catch (e) {
      // Em caso de erro, usa o padrão (Varejo) e continua
      print('Erro ao carregar setor: $e');
      if (mounted) {
        setState(() {
          _setor = null; // Default para Varejo
          _isLoadingSetor = false;
        });
      }
    }
  }

  List<NavigationItem> _getNavigationItems() {
    // Home unificada para todos os setores
    final homeItem = NavigationItem(
      icon: Icons.home,
      label: 'Home',
      screen: const HomeUnifiedScreen(),
    );

    if (_setor == null) {
      // Default: Varejo
      return [
        homeItem,
        NavigationItem(
          icon: Icons.receipt_long,
          label: 'Pedidos',
          screen: const PedidosScreen(),
        ),
        NavigationItem(
          icon: Icons.person,
          label: 'Perfil',
          screen: const ProfileScreen(),
        ),
      ];
    }

    switch (_setor) {
      case 2: // Restaurante
        // Verifica configuração do restaurante para decidir se mostra comandas
        // Usa listen: false para não rebuildar quando configuração mudar
        final servicesProvider = Provider.of<ServicesProvider>(context, listen: false);
        final configRestaurante = servicesProvider.configuracaoRestaurante;
        // Se configuração não foi carregada ainda, assume que mostra comandas (padrão seguro)
        final mostraComandas = configRestaurante == null || configRestaurante.controlePorComanda;
        
        final items = [
          homeItem,
          NavigationItem(
            icon: Icons.table_restaurant,
            label: 'Mesas',
            screen: const MesasScreen(hideAppBar: true),
          ),
        ];
        
        // Só adiciona comandas se configuração permitir
        if (mostraComandas) {
          items.add(
            NavigationItem(
              icon: Icons.receipt_long,
              label: 'Comandas',
              screen: const ComandasScreen(hideAppBar: true),
            ),
          );
        }
        
        items.add(
          NavigationItem(
            icon: Icons.person,
            label: 'Perfil',
            screen: const ProfileScreen(),
          ),
        );
        
        return items;
      case 3: // Oficina
        return [
          homeItem,
          NavigationItem(
            icon: Icons.directions_car,
            label: 'Pátio',
            screen: const PatioScreen(),
          ),
          NavigationItem(
            icon: Icons.person,
            label: 'Perfil',
            screen: const ProfileScreen(),
          ),
        ];
      default: // Varejo (1 ou null)
        return [
          homeItem,
          NavigationItem(
            icon: Icons.receipt_long,
            label: 'Pedidos',
            screen: const PedidosScreen(),
          ),
          NavigationItem(
            icon: Icons.person,
            label: 'Perfil',
            screen: const ProfileScreen(),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se ainda está carregando, mostra loading
    if (_isLoadingSetor) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Carregando...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Usa Consumer para reagir a mudanças na configuração do restaurante
    return Consumer<ServicesProvider>(
      builder: (context, servicesProvider, _) {
        final navigationItems = _getNavigationItems();

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: navigationItems.map((item) => item.screen).toList(),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SafeArea(  
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: navigationItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isActive = _currentIndex == index;

                    return Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.08)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Ícone simples
                                Icon(
                                  item.icon,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade500,
                                  size: isActive ? 26 : 24,
                                ),
                                const SizedBox(height: 4),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    fontSize: isActive ? 12 : 11,
                                    color: isActive
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade600,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    height: 1.2,
                                  ),
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final Widget screen;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
