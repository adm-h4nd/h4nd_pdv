# 🔍 Exemplos de Filtros e Buscas com Hive

## 📋 Operações Necessárias no PDV

1. **Listar produtos** (com paginação)
2. **Buscar produtos por nome** (busca textual)
3. **Filtrar por grupo/subgrupo**
4. **Filtrar por atributos/valores**
5. **Obter grupos disponíveis**
6. **Obter atributos e valores de um produto**
7. **Buscar produtos com variações**

---

## 🏗️ Estrutura de Dados com Hive

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
  String? grupoId;
  
  @HiveField(4)
  String? grupoNome;
  
  @HiveField(5)
  String? subgrupoId;
  
  @HiveField(6)
  String? subgrupoNome;
  
  @HiveField(7)
  double? precoVenda;
  
  @HiveField(8)
  bool temVariacoes;
  
  @HiveField(9)
  List<ProdutoAtributoLocal> atributos;
  
  @HiveField(10)
  List<ProdutoVariacaoLocal> variacoes;
  
  @HiveField(11)
  bool isAtivo;
  
  @HiveField(12)
  bool isVendavel;
}

@HiveType(typeId: 1)
class ProdutoAtributoLocal {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String nome;
  
  @HiveField(2)
  String tipoSelecao; // "Unico", "Multiplo", "Proporcional"
  
  @HiveField(3)
  bool isObrigatorio;
  
  @HiveField(4)
  List<ProdutoAtributoValorLocal> valores;
}

@HiveType(typeId: 2)
class ProdutoAtributoValorLocal {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String nome;
  
  @HiveField(2)
  double? precoAdicional;
}

@HiveType(typeId: 3)
class ProdutoVariacaoLocal {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String nome;
  
  @HiveField(2)
  double? precoAdicional;
}
```

---

## 🔍 Exemplos de Operações

### 1. Listar Todos os Produtos (com paginação)

```dart
class ProdutoLocalRepository {
  late Box<ProdutoLocal> produtosBox;
  
  Future<void> init() async {
    produtosBox = await Hive.openBox<ProdutoLocal>('produtos');
  }
  
  /// Lista todos os produtos ativos e vendáveis
  List<ProdutoLocal> listarProdutos({
    int pagina = 1,
    int itensPorPagina = 20,
  }) {
    final todos = produtosBox.values
        .where((p) => p.isAtivo && p.isVendavel)
        .toList();
    
    // Ordenar por nome
    todos.sort((a, b) => a.nome.compareTo(b.nome));
    
    // Paginação
    final inicio = (pagina - 1) * itensPorPagina;
    final fim = inicio + itensPorPagina;
    
    return todos.sublist(
      inicio.clamp(0, todos.length),
      fim.clamp(0, todos.length),
    );
  }
  
  /// Conta total de produtos
  int contarProdutos() {
    return produtosBox.values
        .where((p) => p.isAtivo && p.isVendavel)
        .length;
  }
}
```

**Uso:**
```dart
final repo = ProdutoLocalRepository();
await repo.init();

final produtos = repo.listarProdutos(pagina: 1, itensPorPagina: 20);
final total = repo.contarProdutos();
```

---

### 2. Buscar Produtos por Nome (busca textual)

```dart
class ProdutoLocalRepository {
  /// Busca produtos por nome (case-insensitive)
  List<ProdutoLocal> buscarPorNome(String termo) {
    final termoLower = termo.toLowerCase();
    
    return produtosBox.values
        .where((p) => 
            p.isAtivo && 
            p.isVendavel &&
            (p.nome.toLowerCase().contains(termoLower) ||
             (p.descricao?.toLowerCase().contains(termoLower) ?? false))
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
  
  /// Busca com limite de resultados
  List<ProdutoLocal> buscarPorNomeLimitado(String termo, {int limite = 50}) {
    return buscarPorNome(termo).take(limite).toList();
  }
}
```

**Uso:**
```dart
final resultados = repo.buscarPorNome("hambúrguer");
// Retorna: ["Hambúrguer Artesanal", "Hambúrguer Vegetariano", ...]
```

---

### 3. Filtrar por Grupo/Subgrupo

```dart
class ProdutoLocalRepository {
  /// Filtra produtos por grupo
  List<ProdutoLocal> filtrarPorGrupo(String grupoId) {
    return produtosBox.values
        .where((p) => 
            p.isAtivo && 
            p.isVendavel &&
            p.grupoId == grupoId
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
  
  /// Filtra produtos por subgrupo
  List<ProdutoLocal> filtrarPorSubgrupo(String subgrupoId) {
    return produtosBox.values
        .where((p) => 
            p.isAtivo && 
            p.isVendavel &&
            p.subgrupoId == subgrupoId
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
  
  /// Filtra por grupo E subgrupo
  List<ProdutoLocal> filtrarPorGrupoESubgrupo({
    String? grupoId,
    String? subgrupoId,
  }) {
    return produtosBox.values
        .where((p) {
          if (!p.isAtivo || !p.isVendavel) return false;
          if (grupoId != null && p.grupoId != grupoId) return false;
          if (subgrupoId != null && p.subgrupoId != subgrupoId) return false;
          return true;
        })
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
}
```

**Uso:**
```dart
final produtosDoGrupo = repo.filtrarPorGrupo("grupo-bebidas");
final produtosDoSubgrupo = repo.filtrarPorSubgrupo("subgrupo-refrigerantes");
```

---

### 4. Obter Grupos Disponíveis

```dart
class ProdutoLocalRepository {
  /// Retorna lista única de grupos (com contagem de produtos)
  List<GrupoInfo> obterGruposDisponiveis() {
    final gruposMap = <String, GrupoInfo>{};
    
    for (final produto in produtosBox.values) {
      if (!produto.isAtivo || !produto.isVendavel) continue;
      
      if (produto.grupoId != null && produto.grupoNome != null) {
        gruposMap.putIfAbsent(
          produto.grupoId!,
          () => GrupoInfo(
            id: produto.grupoId!,
            nome: produto.grupoNome!,
            quantidadeProdutos: 0,
          ),
        );
        gruposMap[produto.grupoId]!.quantidadeProdutos++;
      }
    }
    
    final grupos = gruposMap.values.toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    
    return grupos;
  }
  
  /// Retorna subgrupos de um grupo específico
  List<SubgrupoInfo> obterSubgruposDoGrupo(String grupoId) {
    final subgruposMap = <String, SubgrupoInfo>{};
    
    for (final produto in produtosBox.values) {
      if (!produto.isAtivo || !produto.isVendavel) continue;
      if (produto.grupoId != grupoId) continue;
      
      if (produto.subgrupoId != null && produto.subgrupoNome != null) {
        subgruposMap.putIfAbsent(
          produto.subgrupoId!,
          () => SubgrupoInfo(
            id: produto.subgrupoId!,
            nome: produto.subgrupoNome!,
            quantidadeProdutos: 0,
          ),
        );
        subgruposMap[produto.subgrupoId]!.quantidadeProdutos++;
      }
    }
    
    return subgruposMap.values.toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
}

class GrupoInfo {
  final String id;
  final String nome;
  int quantidadeProdutos;
  
  GrupoInfo({
    required this.id,
    required this.nome,
    required this.quantidadeProdutos,
  });
}

class SubgrupoInfo {
  final String id;
  final String nome;
  int quantidadeProdutos;
  
  SubgrupoInfo({
    required this.id,
    required this.nome,
    required this.quantidadeProdutos,
  });
}
```

**Uso:**
```dart
final grupos = repo.obterGruposDisponiveis();
// Retorna: [
//   GrupoInfo(id: "grupo-1", nome: "Bebidas", quantidadeProdutos: 15),
//   GrupoInfo(id: "grupo-2", nome: "Lanches", quantidadeProdutos: 25),
// ]

final subgrupos = repo.obterSubgruposDoGrupo("grupo-1");
// Retorna: [
//   SubgrupoInfo(id: "sub-1", nome: "Refrigerantes", quantidadeProdutos: 8),
//   SubgrupoInfo(id: "sub-2", nome: "Sucos", quantidadeProdutos: 7),
// ]
```

---

### 5. Obter Atributos e Valores de um Produto

```dart
class ProdutoLocalRepository {
  /// Busca produto por ID
  ProdutoLocal? obterProdutoPorId(String produtoId) {
    return produtosBox.get(produtoId);
  }
  
  /// Obtém atributos de um produto
  List<ProdutoAtributoLocal> obterAtributosDoProduto(String produtoId) {
    final produto = produtosBox.get(produtoId);
    return produto?.atributos ?? [];
  }
  
  /// Obtém valores de um atributo específico
  List<ProdutoAtributoValorLocal> obterValoresDoAtributo(
    String produtoId,
    String atributoId,
  ) {
    final produto = produtosBox.get(produtoId);
    if (produto == null) return [];
    
    final atributo = produto.atributos.firstWhere(
      (a) => a.id == atributoId,
      orElse: () => throw Exception('Atributo não encontrado'),
    );
    
    return atributo.valores;
  }
  
  /// Obtém variações de um produto
  List<ProdutoVariacaoLocal> obterVariacoesDoProduto(String produtoId) {
    final produto = produtosBox.get(produtoId);
    return produto?.variacoes ?? [];
  }
}
```

**Uso:**
```dart
final produto = repo.obterProdutoPorId("produto-123");
final atributos = repo.obterAtributosDoProduto("produto-123");
final valores = repo.obterValoresDoAtributo("produto-123", "attr-tamanho");
final variacoes = repo.obterVariacoesDoProduto("produto-123");
```

---

### 6. Filtrar Produtos por Atributos/Valores

```dart
class ProdutoLocalRepository {
  /// Filtra produtos que têm um atributo específico
  List<ProdutoLocal> filtrarPorAtributo(String atributoId) {
    return produtosBox.values
        .where((p) => 
            p.isAtivo && 
            p.isVendavel &&
            p.atributos.any((a) => a.id == atributoId)
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
  
  /// Filtra produtos que têm um valor específico de atributo
  List<ProdutoLocal> filtrarPorValorAtributo(String valorId) {
    return produtosBox.values
        .where((p) => 
            p.isAtivo && 
            p.isVendavel &&
            p.atributos.any((a) => 
                a.valores.any((v) => v.id == valorId)
            )
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
  
  /// Filtra produtos com variações
  List<ProdutoLocal> filtrarComVariacoes() {
    return produtosBox.values
        .where((p) => 
            p.isAtivo && 
            p.isVendavel &&
            p.temVariacoes &&
            p.variacoes.isNotEmpty
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
}
```

**Uso:**
```dart
// Produtos que têm atributo "Tamanho"
final produtosComTamanho = repo.filtrarPorAtributo("attr-tamanho");

// Produtos que têm valor "Grande"
final produtosGrandes = repo.filtrarPorValorAtributo("val-grande");

// Produtos com variações
final produtosComVariacoes = repo.filtrarComVariacoes();
```

---

### 7. Busca Complexa (Múltiplos Filtros)

```dart
class ProdutoLocalRepository {
  /// Busca avançada com múltiplos filtros
  List<ProdutoLocal> buscarAvancada({
    String? termoBusca,
    String? grupoId,
    String? subgrupoId,
    String? atributoId,
    String? valorId,
    bool? comVariacoes,
    double? precoMinimo,
    double? precoMaximo,
  }) {
    var resultados = produtosBox.values
        .where((p) => p.isAtivo && p.isVendavel)
        .toList();
    
    // Filtro por termo de busca
    if (termoBusca != null && termoBusca.isNotEmpty) {
      final termoLower = termoBusca.toLowerCase();
      resultados = resultados.where((p) =>
          p.nome.toLowerCase().contains(termoLower) ||
          (p.descricao?.toLowerCase().contains(termoLower) ?? false)
      ).toList();
    }
    
    // Filtro por grupo
    if (grupoId != null) {
      resultados = resultados.where((p) => p.grupoId == grupoId).toList();
    }
    
    // Filtro por subgrupo
    if (subgrupoId != null) {
      resultados = resultados.where((p) => p.subgrupoId == subgrupoId).toList();
    }
    
    // Filtro por atributo
    if (atributoId != null) {
      resultados = resultados.where((p) =>
          p.atributos.any((a) => a.id == atributoId)
      ).toList();
    }
    
    // Filtro por valor de atributo
    if (valorId != null) {
      resultados = resultados.where((p) =>
          p.atributos.any((a) => 
              a.valores.any((v) => v.id == valorId)
          )
      ).toList();
    }
    
    // Filtro por variações
    if (comVariacoes != null) {
      resultados = resultados.where((p) => 
          comVariacoes 
              ? (p.temVariacoes && p.variacoes.isNotEmpty)
              : (!p.temVariacoes || p.variacoes.isEmpty)
      ).toList();
    }
    
    // Filtro por preço
    if (precoMinimo != null) {
      resultados = resultados.where((p) =>
          p.precoVenda != null && p.precoVenda! >= precoMinimo
      ).toList();
    }
    
    if (precoMaximo != null) {
      resultados = resultados.where((p) =>
          p.precoVenda != null && p.precoVenda! <= precoMaximo
      ).toList();
    }
    
    // Ordenar por nome
    resultados.sort((a, b) => a.nome.compareTo(b.nome));
    
    return resultados;
  }
}
```

**Uso:**
```dart
final resultados = repo.buscarAvancada(
  termoBusca: "hambúrguer",
  grupoId: "grupo-lanches",
  comVariacoes: true,
  precoMinimo: 10.0,
  precoMaximo: 50.0,
);
```

---

### 8. Otimização: Cache em Memória

Para melhorar performance, podemos manter uma lista em memória:

```dart
class ProdutoLocalRepository {
  late Box<ProdutoLocal> produtosBox;
  List<ProdutoLocal>? _cacheProdutos;
  DateTime? _cacheTimestamp;
  
  Future<void> init() async {
    produtosBox = await Hive.openBox<ProdutoLocal>('produtos');
    _carregarCache();
  }
  
  void _carregarCache() {
    _cacheProdutos = produtosBox.values
        .where((p) => p.isAtivo && p.isVendavel)
        .toList();
    _cacheTimestamp = DateTime.now();
  }
  
  /// Invalida cache (chamar após sincronização)
  void invalidarCache() {
    _cacheProdutos = null;
    _cacheTimestamp = null;
  }
  
  /// Usa cache se disponível, senão carrega do box
  List<ProdutoLocal> _obterProdutos() {
    if (_cacheProdutos != null) {
      return _cacheProdutos!;
    }
    _carregarCache();
    return _cacheProdutos!;
  }
  
  /// Busca otimizada usando cache
  List<ProdutoLocal> buscarPorNome(String termo) {
    final termoLower = termo.toLowerCase();
    return _obterProdutos()
        .where((p) => 
            p.nome.toLowerCase().contains(termoLower) ||
            (p.descricao?.toLowerCase().contains(termoLower) ?? false)
        )
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
  
  /// Filtra por grupo usando cache
  List<ProdutoLocal> filtrarPorGrupo(String grupoId) {
    return _obterProdutos()
        .where((p) => p.grupoId == grupoId)
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
  }
}
```

---

## ⚡ Performance

### Cenário: 1000 produtos

**Operações:**
- **Carregar todos**: ~50-100ms (uma vez na inicialização)
- **Buscar por nome**: ~5-10ms (com cache em memória)
- **Filtrar por grupo**: ~2-5ms (com cache)
- **Obter grupos**: ~10-20ms (uma vez, pode cachear)

**Otimizações:**
1. ✅ Cache em memória após primeira carga
2. ✅ Filtrar apenas produtos ativos/vendáveis uma vez
3. ✅ Ordenar apenas quando necessário
4. ✅ Usar `take()` para limitar resultados

---

## 📊 Resumo: O que é possível com Hive

| Operação | Possível? | Performance |
|----------|-----------|-------------|
| Listar produtos | ✅ Sim | ⭐⭐⭐⭐ |
| Buscar por nome | ✅ Sim | ⭐⭐⭐⭐ |
| Filtrar por grupo | ✅ Sim | ⭐⭐⭐⭐ |
| Filtrar por atributos | ✅ Sim | ⭐⭐⭐ |
| Obter grupos únicos | ✅ Sim | ⭐⭐⭐ |
| Busca complexa | ✅ Sim | ⭐⭐⭐ |
| JOINs entre tabelas | ❌ Não | - |
| Índices customizados | ❌ Não | - |

**Conclusão:** Hive atende bem todas as necessidades do PDV! 🎯

