# 📱 Sincronização de Mesas e Comandas para Uso Offline

## 🎯 Objetivo

Permitir que o app funcione offline para criação de pedidos, sincronizando apenas os dados básicos de mesas e comandas (ID e numeração) necessários para seleção, sem sincronizar status que muda em tempo real.

## ✅ O que foi implementado

### 1. Modelos Locais Criados

- **`MesaLocal`** (`lib/data/models/local/mesa_local.dart`)
  - Campos: `id`, `numero`, `descricao` (opcional), `isAtiva`, `ultimaSincronizacao`
  - TypeId Hive: 21
  - Método `toListItemJson()` para converter para `MesaListItemDto` com status padrão "Livre"

- **`ComandaLocal`** (`lib/data/models/local/comanda_local.dart`)
  - Campos: `id`, `numero`, `codigoBarras` (opcional), `descricao` (opcional), `isAtiva`, `ultimaSincronizacao`
  - TypeId Hive: 22
  - Método `toListItemJson()` para converter para `ComandaListItemDto` com status padrão "Livre"

### 2. Repositórios Locais Criados

- **`MesaLocalRepository`** (`lib/data/repositories/mesa_local_repository.dart`)
  - Métodos: `init()`, `salvarTodas()`, `getAll()`, `getById()`, `getByNumero()`, `toListItemDto()`, `getAllAsListItemDto()`
  - Usa cache para performance
  - Box Hive: `'mesas'`

- **`ComandaLocalRepository`** (`lib/data/repositories/comanda_local_repository.dart`)
  - Métodos: `init()`, `salvarTodas()`, `getAll()`, `getById()`, `getByNumero()`, `getByCodigoBarras()`, `toListItemDto()`, `getAllAsListItemDto()`
  - Usa cache para performance
  - Box Hive: `'comandas'`

### 3. Adapters Hive Registrados

- Adicionados imports e registros no `app_database.dart`
- TypeIds: 21 (MesaLocal), 22 (ComandaLocal)

## ⏳ Próximos Passos

### 1. Gerar arquivos Hive (.g.dart)

Execute o build_runner para gerar os adapters:

```bash
cd mx_cloud_pdv
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Criar endpoint no backend para sincronização

No servidor local (`mx_cloud`), criar endpoint que retorna apenas dados básicos:

**Endpoint:** `GET /api/sync/mesas-comandas`

**Resposta:**
```json
{
  "success": true,
  "data": {
    "mesas": [
      {
        "id": "guid",
        "numero": "Mesa 01",
        "descricao": "Mesa próxima à janela",
        "isAtiva": true
      }
    ],
    "comandas": [
      {
        "id": "guid",
        "numero": "001",
        "codigoBarras": "123456789",
        "descricao": "Comanda VIP",
        "isAtiva": true
      }
    ]
  }
}
```

**Implementação sugerida:**
- Criar controller `SyncMesasComandasController` em `MXCloud.API/Controllers/Core/`
- Retornar apenas mesas/comandas ativas (`isAtiva = true`)
- Não incluir status, vendaAtualId, etc.

### 3. Adicionar sincronização no SyncService

Modificar `lib/data/services/sync/sync_service.dart`:

```dart
Future<void> _sincronizarMesasComandas({
  Function(SyncProgress)? onProgress,
}) async {
  // Buscar da API
  final response = await _apiClient.get('/api/sync/mesas-comandas');
  
  // Salvar localmente
  final mesaRepo = MesaLocalRepository();
  final comandaRepo = ComandaLocalRepository();
  
  await mesaRepo.init();
  await comandaRepo.init();
  
  await mesaRepo.salvarTodas(response.data['mesas']);
  await comandaRepo.salvarTodas(response.data['comandas']);
}
```

### 4. Modificar serviços para usar dados locais quando offline

**MesaService:**
- Verificar conectividade antes de buscar da API
- Se offline, buscar do `MesaLocalRepository`
- Converter `MesaLocal` para `MesaListItemDto` com status padrão

**ComandaService:**
- Verificar conectividade antes de buscar da API
- Se offline, buscar do `ComandaLocalRepository`
- Converter `ComandaLocal` para `ComandaListItemDto` com status padrão

### 5. Modificar telas de seleção

**Tela de seleção de mesa/comanda:**
- Quando offline, usar `MesaLocalRepository.getAllAsListItemDto()`
- Mostrar indicador visual de que está usando dados offline
- Permitir seleção normalmente

**Tela principal (home):**
- Quando offline, mostrar apenas opção de criar pedido
- Desabilitar ou ocultar outras funcionalidades que requerem conexão

## 📋 Comportamento Esperado

### Online:
- Listagem de mesas/comandas vem da API em tempo real
- Status atualizado (Livre, Ocupada, etc.)
- Todas as funcionalidades disponíveis

### Offline:
- Listagem de mesas/comandas vem do cache local
- Status sempre "Livre" (padrão)
- Apenas criação de pedidos disponível
- Pedidos criados são salvos localmente e sincronizados quando voltar online

## 🔄 Fluxo de Sincronização

1. **Sincronização inicial (quando online):**
   - App sincroniza produtos, mesas e comandas
   - Dados básicos de mesas/comandas são salvos localmente

2. **Uso offline:**
   - App usa dados locais para seleção de mesa/comanda
   - Criação de pedidos funciona normalmente
   - Pedidos são salvos localmente com status "pendente"

3. **Volta online:**
   - Pedidos pendentes são sincronizados automaticamente
   - Mesas/comandas podem ser re-sincronizadas se necessário

## ⚠️ Observações Importantes

- **Status não é sincronizado**: Mesas/comandas offline sempre aparecem como "Livre"
- **Apenas dados básicos**: ID e numeração são suficientes para criar pedidos
- **Cache local**: Dados são armazenados em Hive para acesso rápido
- **Sincronização manual**: Usuário pode forçar sincronização quando online

