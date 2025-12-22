# 🔄 Comparação de Formatos para Armazenamento Local

## 🎯 Objetivo

Escolher o formato ideal para armazenar produtos e vendas localmente no PDV, considerando simplicidade, performance e manutenibilidade.

---

## 📊 Opções Disponíveis

### 1. **Hive** (NoSQL - Chave-Valor)

**Como funciona:**
- Armazena objetos Dart diretamente (sem JSON)
- Type-safe com code generation
- Suporta objetos complexos aninhados
- Busca rápida por chave
- Sem relacionamentos explícitos (mas pode simular com IDs)

**Estrutura proposta:**
```dart
// Box: produtos_locais
{
  "produto-123": {
    "id": "produto-123",
    "nome": "Hambúrguer",
    "atributos": [
      {
        "id": "attr-1",
        "nome": "Tamanho",
        "valores": [
          {"id": "val-1", "nome": "P", "precoAdicional": 0},
          {"id": "val-2", "nome": "M", "precoAdicional": 5}
        ]
      }
    ],
    "variacoes": [...]
  }
}

// Box: pedidos_locais
{
  "pedido-uuid-1": {
    "idLocal": "pedido-uuid-1",
    "itens": [
      {
        "produtoId": "produto-123",
        "atributosSelecionados": [
          {"atributoId": "attr-1", "valorId": "val-2"}
        ]
      }
    ]
  }
}
```

**Prós:**
- ✅ Simples de usar
- ✅ Sem migrations (schema flexível)
- ✅ Performance boa para leitura
- ✅ Suporta objetos complexos
- ✅ Type-safe com code generation

**Contras:**
- ❌ Busca por campos aninhados é limitada (precisa carregar tudo)
- ❌ Não tem queries complexas (JOINs, etc.)
- ❌ Para buscar "todos produtos com atributo X" precisa iterar

**Quando usar:** 
- Dados principalmente acessados por ID/chave
- Estrutura de dados não muito complexa
- Não precisa de queries relacionais complexas

---

### 2. **Isar** (NoSQL Moderno - Document Store)

**Como funciona:**
- Similar ao Hive, mas mais poderoso
- Suporta índices e queries complexas
- Type-safe com code generation
- Performance excelente
- Suporta relacionamentos (mas não é relacional)

**Estrutura proposta:**
```dart
@collection
class ProdutoLocal {
  Id id = Isar.autoIncrement;
  
  @Index()
  String produtoId;
  
  String nome;
  
  // Armazenar atributos como JSON ou objetos aninhados
  List<ProdutoAtributoLocal> atributos;
  
  List<ProdutoVariacaoLocal> variacoes;
}

@collection
class PedidoLocal {
  Id id = Isar.autoIncrement;
  
  @Index()
  String idLocal;
  
  String? idRemoto;
  
  List<PedidoItemLocal> itens;
  
  @Index()
  bool isSincronizado;
}
```

**Prós:**
- ✅ Queries complexas (buscar produtos por nome, filtrar, ordenar)
- ✅ Índices para performance
- ✅ Type-safe
- ✅ Suporta relacionamentos (embedded ou referências)
- ✅ Performance excelente

**Contras:**
- ❌ Curva de aprendizado um pouco maior
- ❌ Mais complexo que Hive
- ❌ Nova dependência (menos maduro que Hive)

**Quando usar:**
- Precisa de queries complexas
- Performance crítica
- Dados com relacionamentos

---

### 3. **JSON Files** (Arquivos JSON Simples)

**Como funciona:**
- Armazenar tudo em arquivos JSON
- Usar `path_provider` para salvar em diretório do app
- Ler/escrever com `dart:io` ou `json_serializable`

**Estrutura proposta:**
```
/data/
  produtos.json          # Lista de todos os produtos
  pedidos_pendentes.json # Lista de pedidos não sincronizados
  metadados.json         # Última sincronização, etc.
```

**Prós:**
- ✅ Extremamente simples
- ✅ Sem dependências extras
- ✅ Fácil de debugar (abrir arquivo JSON)
- ✅ Fácil backup (copiar arquivo)

**Contras:**
- ❌ Performance ruim para muitos dados (precisa carregar tudo)
- ❌ Não tem queries (precisa iterar manualmente)
- ❌ Sem transações (risco de corrupção se app fechar no meio)
- ❌ Difícil atualizar parcialmente

**Quando usar:**
- Poucos dados (< 1000 produtos)
- Não precisa de performance alta
- Simplicidade máxima

---

### 4. **Drift Simplificado** (SQLite sem relacionamentos)

**Como funciona:**
- Usar Drift/SQLite mas armazenar relacionamentos como JSON
- Uma tabela para produtos (com JSON de atributos/variacoes)
- Uma tabela para pedidos (com JSON de itens)

**Estrutura proposta:**
```dart
class ProdutosLocais extends Table {
  TextColumn get id => text()();
  TextColumn get nome => text()();
  // ... campos básicos ...
  TextColumn get atributosJson => text()(); // JSON string
  TextColumn get variacoesJson => text()(); // JSON string
}

class PedidosLocais extends Table {
  TextColumn get idLocal => text()();
  TextColumn get itensJson => text()(); // JSON string
  BoolColumn get isSincronizado => boolean()();
}
```

**Prós:**
- ✅ Performance SQLite (índices, queries)
- ✅ Transações (segurança)
- ✅ Queries simples (buscar por nome, filtrar)
- ✅ Sem relacionamentos complexos

**Contras:**
- ❌ Precisa serializar/deserializar JSON
- ❌ Queries em campos JSON são limitadas
- ❌ Ainda é SQLite (pode ser complexo)

**Quando usar:**
- Precisa de queries simples mas não relacionamentos
- Quer segurança de transações
- Performance importante

---

## 🎯 Recomendação por Cenário

### **Cenário 1: Poucos Produtos (< 500) e Simplicidade Máxima**
**Escolha: Hive**
- Simples de implementar
- Performance suficiente
- Sem complexidade de migrations

### **Cenário 2: Muitos Produtos (> 1000) e Queries Complexas**
**Escolha: Isar**
- Queries eficientes
- Índices para performance
- Suporta relacionamentos sem ser relacional

### **Cenário 3: Queries Simples mas Segurança Importante**
**Escolha: Drift Simplificado**
- Transações garantem integridade
- Queries básicas funcionam bem
- JSON para relacionamentos (simples)

### **Cenário 4: Prototipagem Rápida**
**Escolha: JSON Files**
- Zero setup
- Fácil de debugar
- Migrar depois se necessário

---

## 💡 Minha Recomendação: **Hive**

**Por quê?**
1. **Simplicidade**: Fácil de usar, sem migrations
2. **Performance**: Boa para o caso de uso (acesso principalmente por ID)
3. **Estrutura**: Produtos completos podem ser armazenados como objetos aninhados
4. **Manutenibilidade**: Código mais simples que SQL

**Estrutura com Hive:**

```dart
// Modelos
@HiveType(typeId: 0)
class ProdutoLocal extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String nome;
  
  @HiveField(2)
  List<ProdutoAtributoLocal> atributos; // Objetos aninhados
  
  @HiveField(3)
  List<ProdutoVariacaoLocal> variacoes;
}

@HiveType(typeId: 1)
class ProdutoAtributoLocal {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String nome;
  
  @HiveField(2)
  List<ProdutoAtributoValorLocal> valores;
}

// Uso
final produtosBox = await Hive.openBox<ProdutoLocal>('produtos');
produtosBox.put('produto-123', produtoLocal);
final produto = produtosBox.get('produto-123');

// Buscar todos
final todosProdutos = produtosBox.values.toList();

// Filtrar (em memória)
final produtosComAtributos = todosProdutos.where((p) => p.atributos.isNotEmpty).toList();
```

**Limitações aceitáveis:**
- Busca por atributos específicos precisa carregar todos os produtos (mas produtos são carregados uma vez na inicialização)
- Não tem JOINs (mas não precisamos, dados já vêm completos da API)

---

## 📋 Comparação Rápida

| Critério | Hive | Isar | JSON Files | Drift Simplificado |
|----------|------|------|-----------|-------------------|
| **Simplicidade** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Performance** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Queries Complexas** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐ |
| **Type Safety** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Manutenibilidade** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Curva de Aprendizado** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |

---

## ❓ Perguntas para Decidir

1. **Quantos produtos esperamos ter?**
   - < 500: Hive ou JSON Files
   - 500-2000: Hive ou Isar
   - > 2000: Isar ou Drift

2. **Precisamos buscar produtos por critérios complexos?**
   - Não (só por ID ou listar todos): Hive
   - Sim (filtrar por nome, atributos, etc.): Isar ou Drift

3. **Qual é mais importante: simplicidade ou performance?**
   - Simplicidade: Hive
   - Performance: Isar

4. **Precisamos de transações (garantir que operação completa ou falha tudo)?**
   - Não: Hive
   - Sim: Drift ou Isar

---

## 🚀 Próximo Passo

**Recomendo começarmos com Hive** porque:
- É simples de implementar
- Atende bem o caso de uso (produtos carregados uma vez, acesso por ID)
- Podemos migrar para Isar depois se necessário
- Menos complexidade = menos bugs

**Quer que eu implemente com Hive ou prefere outra opção?**

