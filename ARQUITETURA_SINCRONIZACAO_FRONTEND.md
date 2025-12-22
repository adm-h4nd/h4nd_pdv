# 📱 Arquitetura de Sincronização - Frontend (Flutter)

## 🎯 Visão Geral

Sistema de sincronização offline que permite:
1. **Sincronizar produtos** do servidor para armazenamento local
2. **Sincronizar grupos de exibição** para navegação
3. **Armazenar vendas offline** e sincronizar quando houver conexão
4. **Gerenciar estado de sincronização** (última sync, pendências, etc.)

---

## 🏗️ Estrutura de Arquivos

```
lib/
├── data/
│   ├── database/                    # Hive Database
│   │   ├── app_database.dart        # Configuração do Hive
│   │   └── adapters/                 # Type Adapters do Hive
│   │       ├── produto_local_adapter.dart
│   │       ├── exibicao_produto_local_adapter.dart
│   │       └── pedido_local_adapter.dart
│   │
│   ├── models/
│   │   ├── local/                    # Modelos locais (Hive)
│   │   │   ├── produto_local.dart
│   │   │   ├── exibicao_produto_local.dart
│   │   │   └── pedido_local.dart
│   │   │
│   │   └── sync/                     # DTOs de sincronização (da API)
│   │       ├── produto_pdv_sync_dto.dart
│   │       └── exibicao_produto_pdv_sync_dto.dart
│   │
│   ├── repositories/
│   │   ├── produto_local_repository.dart
│   │   ├── exibicao_produto_local_repository.dart
│   │   └── pedido_local_repository.dart
│   │
│   └── services/
│       ├── sync/
│       │   ├── sync_service.dart      # Serviço principal de sincronização
│       │   ├── produto_sync_service.dart
│       │   └── pedido_sync_service.dart
│       │
│       └── local/
│           ├── produto_local_service.dart
│           └── pedido_local_service.dart
│
└── presentation/
    └── providers/
        └── sync_provider.dart         # Provider para gerenciar estado de sync
```

---

## 📦 1. Modelos Locais (Hive)

### 1.1. ProdutoLocal

```dart
@HiveType(typeId: 0)
class ProdutoLocal extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String nome;
  
  @HiveField(2)
  String? descricao;
  
  @HiveField(3)
  String? sku;
  
  @HiveField(4)
  double? precoVenda;
  
  @HiveField(5)
  String? grupoId;
  
  @HiveField(6)
  String? grupoNome;
  
  @HiveField(7)
  String? subgrupoId;
  
  @HiveField(8)
  String? subgrupoNome;
  
  @HiveField(9)
  TipoRepresentacaoVisual tipoRepresentacao;
  
  @HiveField(10)
  String? icone;
  
  @HiveField(11)
  String? cor;
  
  @HiveField(12)
  String? imagemFileName;
  
  @HiveField(13)
  List<ProdutoAtributoLocal> atributos;
  
  @HiveField(14)
  List<ProdutoVariacaoLocal> variacoes;
  
  @HiveField(15)
  bool isAtivo;
  
  @HiveField(16)
  bool isVendavel;
  
  @HiveField(17)
  DateTime ultimaSincronizacao;
  
  ProdutoLocal({
    required this.id,
    required this.nome,
    // ... outros campos
  });
}

@HiveType(typeId: 1)
class ProdutoAtributoLocal {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String nome;
  
  @HiveField(2)
  List<ProdutoAtributoValorLocal> valores;
  
  // ... outros campos
}

// ... outros modelos aninhados
```

### 1.2. ExibicaoProdutoLocal

```dart
@HiveType(typeId: 10)
class ExibicaoProdutoLocal extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String nome;
  
  @HiveField(2)
  String? categoriaPaiId;
  
  @HiveField(3)
  int ordem;
  
  @HiveField(4)
  TipoRepresentacaoVisual tipoRepresentacao;
  
  @HiveField(5)
  String? icone;
  
  @HiveField(6)
  String? cor;
  
  @HiveField(7)
  String? imagemFileName;
  
  @HiveField(8)
  List<String> produtoIds; // IDs dos produtos vinculados (ordenados)
  
  @HiveField(9)
  List<ExibicaoProdutoLocal> categoriasFilhas; // Hierarquia
  
  @HiveField(10)
  DateTime ultimaSincronizacao;
  
  ExibicaoProdutoLocal({
    required this.id,
    required this.nome,
    // ... outros campos
  });
}
```

### 1.3. PedidoLocal

```dart
@HiveType(typeId: 20)
class PedidoLocal extends HiveObject {
  @HiveField(0)
  String idLocal; // UUID gerado localmente
  
  @HiveField(1)
  String? idRemoto; // ID retornado pelo servidor após sync
  
  @HiveField(2)
  String numero;
  
  @HiveField(3)
  String tipo; // "Orcamento" ou "Venda"
  
  @HiveField(4)
  String status;
  
  @HiveField(5)
  List<PedidoItemLocal> itens;
  
  @HiveField(6)
  double valorTotal;
  
  @HiveField(7)
  bool isSincronizado;
  
  @HiveField(8)
  int tentativasSincronizacao;
  
  @HiveField(9)
  DateTime criadoEm;
  
  @HiveField(10)
  DateTime? ultimaTentativaSincronizacao;
  
  @HiveField(11)
  String? erroSincronizacao;
  
  PedidoLocal({
    required this.idLocal,
    // ... outros campos
  });
}
```

---

## 🔄 2. Serviços de Sincronização

### 2.1. SyncService (Serviço Principal)

**Responsabilidades:**
- Coordenar sincronização completa (produtos + grupos)
- Gerenciar estado de sincronização
- Controlar tentativas e erros
- Notificar progresso

```dart
class SyncService {
  final ApiClient _apiClient;
  final ProdutoLocalRepository _produtoRepo;
  final ExibicaoProdutoLocalRepository _exibicaoRepo;
  final PedidoLocalRepository _pedidoRepo;
  
  // Estado de sincronização
  bool _isSyncing = false;
  SyncProgress? _currentProgress;
  StreamController<SyncProgress>? _progressController;
  
  /// Inicia sincronização completa
  Future<SyncResult> sincronizarCompleto({
    Function(SyncProgress)? onProgress,
    bool forcar = false, // Forçar mesmo se já sincronizado recentemente
  }) async {
    if (_isSyncing) {
      throw SyncException('Sincronização já em andamento');
    }
    
    _isSyncing = true;
    try {
      // 1. Sincronizar produtos
      final produtosResult = await _sincronizarProdutos(onProgress: onProgress);
      
      // 2. Sincronizar grupos de exibição
      final gruposResult = await _sincronizarGruposExibicao(onProgress: onProgress);
      
      // 3. Sincronizar pedidos pendentes (se houver conexão)
      final pedidosResult = await _sincronizarPedidosPendentes(onProgress: onProgress);
      
      return SyncResult(
        sucesso: true,
        produtosSincronizados: produtosResult.total,
        gruposSincronizados: gruposResult.total,
        pedidosSincronizados: pedidosResult.total,
        pedidosComErro: pedidosResult.erros,
      );
    } catch (e) {
      return SyncResult(
        sucesso: false,
        erro: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Sincroniza apenas produtos
  Future<SyncResult> _sincronizarProdutos({
    Function(SyncProgress)? onProgress,
  }) async {
    onProgress?.call(SyncProgress(
      etapa: 'Produtos',
      progresso: 0,
      mensagem: 'Buscando produtos...',
    ));
    
    // Buscar da API
    final response = await _apiClient.get<List<dynamic>>(
      '/api/produto-pdv-sync/produtos',
    );
    
    if (!response.success || response.data == null) {
      throw SyncException('Erro ao buscar produtos: ${response.message}');
    }
    
    final produtosDto = (response.data as List)
        .map((json) => ProdutoPdvSyncDto.fromJson(json))
        .toList();
    
    onProgress?.call(SyncProgress(
      etapa: 'Produtos',
      progresso: 50,
      mensagem: 'Salvando ${produtosDto.length} produtos...',
    ));
    
    // Salvar localmente (substituir todos)
    await _produtoRepo.salvarTodos(produtosDto);
    
    // Atualizar metadados
    await _atualizarMetadadosSincronizacao('produtos', DateTime.now());
    
    onProgress?.call(SyncProgress(
      etapa: 'Produtos',
      progresso: 100,
      mensagem: '${produtosDto.length} produtos sincronizados',
    ));
    
    return SyncResult(
      sucesso: true,
      produtosSincronizados: produtosDto.length,
    );
  }
  
  /// Sincroniza grupos de exibição
  Future<SyncResult> _sincronizarGruposExibicao({
    Function(SyncProgress)? onProgress,
  }) async {
    onProgress?.call(SyncProgress(
      etapa: 'Grupos de Exibição',
      progresso: 0,
      mensagem: 'Buscando grupos...',
    ));
    
    final response = await _apiClient.get<List<dynamic>>(
      '/api/produto-pdv-sync/grupos-exibicao',
    );
    
    if (!response.success || response.data == null) {
      throw SyncException('Erro ao buscar grupos: ${response.message}');
    }
    
    final gruposDto = (response.data as List)
        .map((json) => ExibicaoProdutoPdvSyncDto.fromJson(json))
        .toList();
    
    onProgress?.call(SyncProgress(
      etapa: 'Grupos de Exibição',
      progresso: 50,
      mensagem: 'Salvando grupos...',
    ));
    
    await _exibicaoRepo.salvarTodos(gruposDto);
    await _atualizarMetadadosSincronizacao('grupos_exibicao', DateTime.now());
    
    return SyncResult(
      sucesso: true,
      gruposSincronizados: gruposDto.length,
    );
  }
  
  /// Sincroniza pedidos pendentes
  Future<SyncResult> _sincronizarPedidosPendentes({
    Function(SyncProgress)? onProgress,
  }) async {
    final pedidosPendentes = await _pedidoRepo.buscarPendentes();
    
    if (pedidosPendentes.isEmpty) {
      return SyncResult(sucesso: true, pedidosSincronizados: 0);
    }
    
    int sucesso = 0;
    int erros = 0;
    
    for (int i = 0; i < pedidosPendentes.length; i++) {
      final pedido = pedidosPendentes[i];
      
      onProgress?.call(SyncProgress(
        etapa: 'Pedidos',
        progresso: (i / pedidosPendentes.length * 100).round(),
        mensagem: 'Sincronizando pedido ${i + 1}/${pedidosPendentes.length}...',
      ));
      
      try {
        // Enviar para API
        final response = await _apiClient.post(
          '/api/core/pedidos',
          data: pedido.toJson(),
        );
        
        if (response.success) {
          // Atualizar com ID remoto
          pedido.idRemoto = response.data['id'];
          pedido.isSincronizado = true;
          pedido.tentativasSincronizacao = 0;
          pedido.erroSincronizacao = null;
          await _pedidoRepo.atualizar(pedido);
          sucesso++;
        } else {
          pedido.tentativasSincronizacao++;
          pedido.erroSincronizacao = response.message;
          pedido.ultimaTentativaSincronizacao = DateTime.now();
          await _pedidoRepo.atualizar(pedido);
          erros++;
        }
      } catch (e) {
        pedido.tentativasSincronizacao++;
        pedido.erroSincronizacao = e.toString();
        pedido.ultimaTentativaSincronizacao = DateTime.now();
        await _pedidoRepo.atualizar(pedido);
        erros++;
      }
    }
    
    return SyncResult(
      sucesso: true,
      pedidosSincronizados: sucesso,
      pedidosComErro: erros,
    );
  }
  
  /// Verifica se precisa sincronizar
  Future<bool> precisaSincronizar({Duration? intervaloMinimo}) async {
    final ultimaSync = await _obterUltimaSincronizacao();
    if (ultimaSync == null) return true;
    
    final intervalo = intervaloMinimo ?? const Duration(hours: 1);
    return DateTime.now().difference(ultimaSync) > intervalo;
  }
  
  /// Obtém última sincronização
  Future<DateTime?> _obterUltimaSincronizacao() async {
    final metadados = await _obterMetadadosSincronizacao();
    return metadados['ultima_sincronizacao_produtos'];
  }
  
  /// Atualiza metadados de sincronização
  Future<void> _atualizarMetadadosSincronizacao(String tipo, DateTime data) async {
    final box = await Hive.openBox('sincronizacao_metadados');
    await box.put('ultima_sincronizacao_$tipo', data.toIso8601String());
    await box.put('ultima_sincronizacao_geral', data.toIso8601String());
  }
  
  /// Obtém metadados de sincronização
  Future<Map<String, DateTime?>> _obterMetadadosSincronizacao() async {
    final box = await Hive.openBox('sincronizacao_metadados');
    final produtos = box.get('ultima_sincronizacao_produtos');
    final grupos = box.get('ultima_sincronizacao_grupos_exibicao');
    
    return {
      'ultima_sincronizacao_produtos': produtos != null 
          ? DateTime.parse(produtos) 
          : null,
      'ultima_sincronizacao_grupos_exibicao': grupos != null 
          ? DateTime.parse(grupos) 
          : null,
    };
  }
  
  bool get isSyncing => _isSyncing;
  
  Stream<SyncProgress>? get progressStream => _progressController?.stream;
}
```

### 2.2. Classes de Suporte

```dart
/// Resultado de sincronização
class SyncResult {
  final bool sucesso;
  final String? erro;
  final int produtosSincronizados;
  final int gruposSincronizados;
  final int pedidosSincronizados;
  final int pedidosComErro;
  
  SyncResult({
    required this.sucesso,
    this.erro,
    this.produtosSincronizados = 0,
    this.gruposSincronizados = 0,
    this.pedidosSincronizados = 0,
    this.pedidosComErro = 0,
  });
}

/// Progresso de sincronização
class SyncProgress {
  final String etapa;
  final int progresso; // 0-100
  final String mensagem;
  
  SyncProgress({
    required this.etapa,
    required this.progresso,
    required this.mensagem,
  });
}

/// Exceção de sincronização
class SyncException implements Exception {
  final String message;
  SyncException(this.message);
  
  @override
  String toString() => 'SyncException: $message';
}
```

---

## 📚 3. Repositories Locais

### 3.1. ProdutoLocalRepository

```dart
class ProdutoLocalRepository {
  late Box<ProdutoLocal> _box;
  
  Future<void> init() async {
    _box = await Hive.openBox<ProdutoLocal>('produtos');
  }
  
  /// Salva todos os produtos (substitui existentes)
  Future<void> salvarTodos(List<ProdutoPdvSyncDto> produtosDto) async {
    // Limpar box existente
    await _box.clear();
    
    // Converter DTOs para modelos locais e salvar
    for (final dto in produtosDto) {
      final produtoLocal = _mapDtoToLocal(dto);
      await _box.put(produtoLocal.id, produtoLocal);
    }
  }
  
  /// Busca produto por ID
  ProdutoLocal? buscarPorId(String id) {
    return _box.get(id);
  }
  
  /// Lista todos os produtos
  List<ProdutoLocal> listarTodos() {
    return _box.values.toList();
  }
  
  /// Busca produtos por nome
  List<ProdutoLocal> buscarPorNome(String termo) {
    final termoLower = termo.toLowerCase();
    return _box.values
        .where((p) => 
            p.isAtivo && 
            p.isVendavel &&
            (p.nome.toLowerCase().contains(termoLower) ||
             (p.descricao?.toLowerCase().contains(termoLower) ?? false))
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
  
  /// Filtra por grupo
  List<ProdutoLocal> filtrarPorGrupo(String grupoId) {
    return _box.values
        .where((p) => p.isAtivo && p.isVendavel && p.grupoId == grupoId)
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
  
  /// Conta total de produtos
  int contar() {
    return _box.values.where((p) => p.isAtivo && p.isVendavel).length;
  }
  
  ProdutoLocal _mapDtoToLocal(ProdutoPdvSyncDto dto) {
    return ProdutoLocal(
      id: dto.id,
      nome: dto.nome,
      descricao: dto.descricao,
      sku: dto.sku,
      precoVenda: dto.precoVenda,
      grupoId: dto.grupoId,
      grupoNome: dto.grupoNome,
      subgrupoId: dto.subgrupoId,
      subgrupoNome: dto.subgrupoNome,
      tipoRepresentacao: dto.tipoRepresentacao,
      icone: dto.icone,
      cor: dto.cor,
      imagemFileName: dto.imagemFileName,
      atributos: dto.atributos.map(_mapAtributoDtoToLocal).toList(),
      variacoes: dto.variacoes.map(_mapVariacaoDtoToLocal).toList(),
      isAtivo: dto.isAtivo,
      isVendavel: dto.isVendavel,
      ultimaSincronizacao: DateTime.now(),
    );
  }
  
  // ... métodos de mapeamento
}
```

### 3.2. ExibicaoProdutoLocalRepository

```dart
class ExibicaoProdutoLocalRepository {
  late Box<ExibicaoProdutoLocal> _box;
  
  Future<void> init() async {
    _box = await Hive.openBox<ExibicaoProdutoLocal>('exibicao_produtos');
  }
  
  /// Salva todos os grupos (substitui existentes)
  Future<void> salvarTodos(List<ExibicaoProdutoPdvSyncDto> gruposDto) async {
    await _box.clear();
    
    for (final dto in gruposDto) {
      final grupoLocal = _mapDtoToLocal(dto);
      await _box.put(grupoLocal.id, grupoLocal);
    }
  }
  
  /// Busca categorias raiz
  List<ExibicaoProdutoLocal> buscarCategoriasRaiz() {
    return _box.values
        .where((g) => g.categoriaPaiId == null)
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
  }
  
  /// Busca categorias filhas
  List<ExibicaoProdutoLocal> buscarCategoriasFilhas(String categoriaPaiId) {
    return _box.values
        .where((g) => g.categoriaPaiId == categoriaPaiId)
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
  }
  
  /// Busca categoria por ID
  ExibicaoProdutoLocal? buscarPorId(String id) {
    return _box.get(id);
  }
  
  /// Busca produtos de uma categoria
  List<String> buscarProdutosPorCategoria(String categoriaId) {
    final categoria = _box.get(categoriaId);
    return categoria?.produtoIds ?? [];
  }
  
  ExibicaoProdutoLocal _mapDtoToLocal(ExibicaoProdutoPdvSyncDto dto) {
    return ExibicaoProdutoLocal(
      id: dto.id,
      nome: dto.nome,
      descricao: dto.descricao,
      categoriaPaiId: dto.categoriaPaiId,
      ordem: dto.ordem,
      tipoRepresentacao: dto.tipoRepresentacao,
      icone: dto.icone,
      cor: dto.cor,
      imagemFileName: dto.imagemFileName,
      produtoIds: dto.produtos.map((p) => p.produtoId).toList(),
      categoriasFilhas: dto.categoriasFilhas.map(_mapDtoToLocal).toList(),
      ultimaSincronizacao: DateTime.now(),
    );
  }
}
```

---

## 🎛️ 4. Provider de Sincronização

```dart
class SyncProvider extends ChangeNotifier {
  final SyncService _syncService;
  
  bool _isSyncing = false;
  SyncProgress? _currentProgress;
  SyncResult? _lastResult;
  DateTime? _ultimaSincronizacao;
  int _pedidosPendentes = 0;
  
  SyncProvider(this._syncService) {
    _carregarEstado();
  }
  
  /// Inicia sincronização
  Future<void> sincronizar({bool forcar = false}) async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final result = await _syncService.sincronizarCompleto(
        forcar: forcar,
        onProgress: (progress) {
          _currentProgress = progress;
          notifyListeners();
        },
      );
      
      _lastResult = result;
      _ultimaSincronizacao = DateTime.now();
      await _atualizarPedidosPendentes();
      
      if (result.sucesso) {
        // Mostrar sucesso
      } else {
        // Mostrar erro
      }
    } catch (e) {
      _lastResult = SyncResult(
        sucesso: false,
        erro: e.toString(),
      );
    } finally {
      _isSyncing = false;
      _currentProgress = null;
      notifyListeners();
    }
  }
  
  /// Verifica se precisa sincronizar
  Future<bool> verificarSePrecisaSincronizar() async {
    return await _syncService.precisaSincronizar();
  }
  
  /// Atualiza contagem de pedidos pendentes
  Future<void> _atualizarPedidosPendentes() async {
    // Implementar busca de pedidos pendentes
  }
  
  /// Carrega estado inicial
  Future<void> _carregarEstado() async {
    _ultimaSincronizacao = await _syncService._obterUltimaSincronizacao();
    await _atualizarPedidosPendentes();
    notifyListeners();
  }
  
  // Getters
  bool get isSyncing => _isSyncing;
  SyncProgress? get currentProgress => _currentProgress;
  SyncResult? get lastResult => _lastResult;
  DateTime? get ultimaSincronizacao => _ultimaSincronizacao;
  int get pedidosPendentes => _pedidosPendentes;
}
```

---

## 🔌 5. Integração com UI

### 5.1. Botão de Sincronizar na Home

```dart
// Em home_screen.dart
Consumer<SyncProvider>(
  builder: (context, syncProvider, child) {
    return ActionButton(
      label: 'Sincronizar Produtos',
      icon: Icons.sync,
      color: AppTheme.primaryColor,
      onPressed: syncProvider.isSyncing 
          ? null 
          : () => _mostrarDialogSincronizacao(context, syncProvider),
      badge: syncProvider.pedidosPendentes > 0 
          ? syncProvider.pedidosPendentes.toString() 
          : null,
    );
  },
);

void _mostrarDialogSincronizacao(BuildContext context, SyncProvider syncProvider) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => SyncDialog(syncProvider: syncProvider),
  );
}
```

### 5.2. Dialog de Sincronização

```dart
class SyncDialog extends StatefulWidget {
  final SyncProvider syncProvider;
  
  const SyncDialog({required this.syncProvider});
  
  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  @override
  void initState() {
    super.initState();
    widget.syncProvider.addListener(_onSyncUpdate);
    widget.syncProvider.sincronizar();
  }
  
  void _onSyncUpdate() {
    if (mounted) {
      setState(() {});
      
      // Fechar dialog se concluído
      if (!widget.syncProvider.isSyncing && 
          widget.syncProvider.lastResult != null) {
        Navigator.of(context).pop();
        
        // Mostrar resultado
        final result = widget.syncProvider.lastResult!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.sucesso
                  ? 'Sincronização concluída: ${result.produtosSincronizados} produtos'
                  : 'Erro: ${result.erro}',
            ),
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final progress = widget.syncProvider.currentProgress;
    
    return AlertDialog(
      title: Text('Sincronizando...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null) ...[
            LinearProgressIndicator(value: progress.progresso / 100),
            SizedBox(height: 16),
            Text(progress.etapa),
            Text(progress.mensagem),
          ] else
            CircularProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.syncProvider.isSyncing 
              ? null 
              : () => Navigator.of(context).pop(),
          child: Text('Fechar'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    widget.syncProvider.removeListener(_onSyncUpdate);
    super.dispose();
  }
}
```

---

## 🔄 6. Fluxo Completo

### 6.1. Inicialização do App

```
1. App inicia
2. Inicializa Hive
3. Carrega repositórios locais
4. Verifica se precisa sincronizar
5. Se necessário, sugere sincronização
```

### 6.2. Sincronização Manual

```
1. Usuário clica em "Sincronizar"
2. Abre dialog de progresso
3. SyncService.sincronizarCompleto():
   a. Busca produtos da API
   b. Salva localmente (substitui tudo)
   c. Busca grupos de exibição
   d. Salva localmente
   e. Sincroniza pedidos pendentes
4. Atualiza metadados
5. Fecha dialog e mostra resultado
```

### 6.3. Uso Offline

```
1. Usuário navega produtos:
   - Busca em ProdutoLocalRepository
   - Filtra por grupo/categoria
   - Seleciona produto
   
2. Usuário cria pedido:
   - Salva em PedidoLocalRepository
   - Marca como não sincronizado
   
3. Quando voltar online:
   - SyncService sincroniza pedidos automaticamente
```

---

## 📋 7. Checklist de Implementação

### Fase 1: Setup Hive
- [ ] Adicionar dependências (hive, hive_flutter)
- [ ] Criar adapters para modelos locais
- [ ] Configurar AppDatabase
- [ ] Inicializar Hive no main.dart

### Fase 2: Modelos Locais
- [ ] Criar ProdutoLocal e adapters
- [ ] Criar ExibicaoProdutoLocal e adapters
- [ ] Criar PedidoLocal e adapters
- [ ] Testes básicos de CRUD

### Fase 3: Repositories
- [ ] Implementar ProdutoLocalRepository
- [ ] Implementar ExibicaoProdutoLocalRepository
- [ ] Implementar PedidoLocalRepository
- [ ] Métodos de busca e filtro

### Fase 4: Serviços de Sincronização
- [ ] Criar SyncService
- [ ] Implementar sincronização de produtos
- [ ] Implementar sincronização de grupos
- [ ] Implementar sincronização de pedidos
- [ ] Tratamento de erros

### Fase 5: Provider
- [ ] Criar SyncProvider
- [ ] Gerenciar estado de sincronização
- [ ] Notificações de progresso

### Fase 6: UI
- [ ] Botão de sincronizar na home
- [ ] Dialog de progresso
- [ ] Indicador de status
- [ ] Lista de pedidos pendentes

---

## 🎯 Resumo da Arquitetura

**Camadas:**
1. **Modelos Locais** (Hive) → Armazenamento
2. **Repositories** → Acesso aos dados locais
3. **SyncService** → Lógica de sincronização
4. **SyncProvider** → Estado e UI
5. **UI** → Interface do usuário

**Fluxo:**
- **Sincronização**: API → DTO → Modelo Local → Hive
- **Uso**: Hive → Repository → Service → UI
- **Vendas**: UI → Service → Repository → Hive → API (quando online)

