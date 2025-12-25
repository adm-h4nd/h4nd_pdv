# ✅ Implementação: Sincronização de Mesas e Comandas para Uso Offline

## 🎯 Objetivo Concluído

Permitir que o app funcione offline para criação de pedidos, sincronizando apenas os dados básicos de mesas e comandas (ID e numeração) necessários para seleção, sem sincronizar status que muda em tempo real.

---

## ✅ O que foi implementado

### Backend (mx_cloud)

#### 1. DTOs Criados (`MesaComandaPdvSyncDtos.cs`)
- ✅ `MesaPdvSyncDto` - apenas ID, número, descrição, isAtiva
- ✅ `ComandaPdvSyncDto` - apenas ID, número, código de barras, descrição, isAtiva
- ✅ `MesaComandaPdvSyncResponseDto` - wrapper com listas

#### 2. Serviço Criado (`MesaComandaPdvSyncService.cs`)
- ✅ Busca mesas e comandas ativas do banco
- ✅ Retorna apenas dados básicos (sem status)
- ✅ Registrado no `DependencyInjection.cs`

#### 3. Controller Criado (`MesaComandaPdvSyncController.cs`)
- ✅ Endpoint: `GET /api/pdv-sync/mesas-comandas`
- ✅ Requer autenticação e permissão de leitura de Mesas
- ✅ Retorna dados básicos de mesas e comandas

### Frontend (mx_cloud_pdv)

#### 1. Modelos Locais Criados
- ✅ `MesaLocal` (typeId: 21) - armazena ID, número, descrição, isAtiva
- ✅ `ComandaLocal` (typeId: 22) - armazena ID, número, código de barras, descrição, isAtiva
- ✅ Adapters Hive registrados no `app_database.dart`

#### 2. Repositórios Locais Criados
- ✅ `MesaLocalRepository` - gerencia armazenamento local usando Hive
- ✅ `ComandaLocalRepository` - gerencia armazenamento local usando Hive
- ✅ Métodos: `init()`, `salvarTodas()`, `getAll()`, `getById()`, `getByNumero()`, `getByCodigoBarras()`, `toListItemDto()`, `getAllAsListItemDto()`

#### 3. DTOs de Sincronização Criados
- ✅ `MesaPdvSyncDto` - DTO Flutter para sincronização
- ✅ `ComandaPdvSyncDto` - DTO Flutter para sincronização
- ✅ `MesaComandaPdvSyncResponseDto` - wrapper Flutter

#### 4. Sincronização Adicionada no `SyncService`
- ✅ Método `_sincronizarMesasComandas()` implementado
- ✅ Integrado na sincronização completa (70-85% do progresso)
- ✅ Endpoint adicionado em `ApiEndpoints`

#### 5. Serviços Modificados para Suporte Offline
- ✅ `MesaService` modificado:
  - Aceita `MesaLocalRepository` opcional no construtor
  - `searchMesas()` tenta API primeiro, se falhar com erro de rede, usa dados locais
  - `getMesaById()` tenta API primeiro, se falhar com erro de rede, usa dados locais
  - Retorna dados locais com status padrão "Livre"

- ✅ `ComandaService` modificado:
  - Aceita `ComandaLocalRepository` opcional no construtor
  - `searchComandas()` tenta API primeiro, se falhar com erro de rede, usa dados locais
  - `getComandaById()` tenta API primeiro, se falhar com erro de rede, usa dados locais
  - `getByCodigoBarras()` tenta API primeiro, se falhar com erro de rede, usa dados locais
  - Retorna dados locais com status padrão "Livre"

#### 6. ServicesProvider Atualizado
- ✅ Repositórios locais criados e inicializados
- ✅ Repositórios passados para `MesaService` e `ComandaService`
- ✅ Getters adicionados para acesso aos repositórios locais
- ✅ Inicialização dos repositórios no `initRepositories()`

---

## 🔄 Como Funciona

### Online (Conexão Disponível)
1. App tenta buscar mesas/comandas da API
2. Se sucesso, retorna dados em tempo real com status atualizado
3. Dados são sincronizados periodicamente para cache local

### Offline (Sem Conexão)
1. App tenta buscar mesas/comandas da API
2. Detecta erro de conexão (`DioExceptionType.connectionTimeout`, `sendTimeout`, `receiveTimeout`, `unknown`)
3. Automaticamente busca do cache local (`MesaLocalRepository` / `ComandaLocalRepository`)
4. Retorna dados locais com status padrão "Livre"
5. Usuário pode selecionar mesa/comanda normalmente
6. Criação de pedidos funciona normalmente (pedidos são salvos localmente)

---

## 📋 Próximos Passos (Pendentes)

### 1. Gerar arquivos Hive (.g.dart)
**Comando:**
```bash
cd mx_cloud_pdv
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Testar Funcionalidade
- [ ] Executar sincronização completa (deve sincronizar mesas e comandas)
- [ ] Verificar se mesas/comandas foram salvas localmente
- [ ] Desconectar internet
- [ ] Tentar buscar mesas/comandas (deve usar dados locais)
- [ ] Criar pedido offline selecionando mesa/comanda local
- [ ] Verificar se pedido foi salvo localmente

### 3. Melhorias Futuras (Opcional)
- [ ] Adicionar indicador visual quando está usando dados offline
- [ ] Adicionar opção de forçar sincronização manual de mesas/comandas
- [ ] Adicionar log de quando está usando dados locais vs API

---

## 🎯 Comportamento Esperado

### Sincronização Inicial
1. Usuário executa sincronização completa
2. App sincroniza produtos, grupos, mesas/comandas e pedidos pendentes
3. Mesas e comandas são salvas localmente com dados básicos

### Uso Online
- Listagem de mesas/comandas vem da API em tempo real
- Status atualizado (Livre, Ocupada, etc.)
- Todas as funcionalidades disponíveis

### Uso Offline
- Listagem de mesas/comandas vem do cache local
- Status sempre "Livre" (padrão)
- Apenas criação de pedidos disponível
- Pedidos criados são salvos localmente e sincronizados quando voltar online

---

## ⚠️ Observações Importantes

1. **Status não é sincronizado**: Mesas/comandas offline sempre aparecem como "Livre"
2. **Apenas dados básicos**: ID e numeração são suficientes para criar pedidos
3. **Cache local**: Dados são armazenados em Hive para acesso rápido
4. **Sincronização automática**: Mesas/comandas são sincronizadas junto com produtos
5. **Fallback automático**: Serviços automaticamente usam dados locais quando detectam erro de rede

---

## 📝 Arquivos Criados/Modificados

### Backend
- ✅ `MXCloud.Application/DTOs/Modules/Restaurante/MesaComandaPdvSyncDtos.cs` (NOVO)
- ✅ `MXCloud.Application/Services/Modules/Restaurante/MesaComandaPdvSyncService.cs` (NOVO)
- ✅ `MXCloud.API/Controllers/Core/MesaComandaPdvSyncController.cs` (NOVO)
- ✅ `MXCloud.Application/DependencyInjection.cs` (MODIFICADO)

### Frontend
- ✅ `lib/data/models/local/mesa_local.dart` (NOVO)
- ✅ `lib/data/models/local/comanda_local.dart` (NOVO)
- ✅ `lib/data/repositories/mesa_local_repository.dart` (NOVO)
- ✅ `lib/data/repositories/comanda_local_repository.dart` (NOVO)
- ✅ `lib/data/models/sync/mesa_comanda_pdv_sync_dto.dart` (NOVO)
- ✅ `lib/data/services/sync/sync_service.dart` (MODIFICADO)
- ✅ `lib/data/services/modules/restaurante/mesa_service.dart` (MODIFICADO)
- ✅ `lib/data/services/modules/restaurante/comanda_service.dart` (MODIFICADO)
- ✅ `lib/presentation/providers/services_provider.dart` (MODIFICADO)
- ✅ `lib/core/network/endpoints.dart` (MODIFICADO)
- ✅ `lib/data/database/app_database.dart` (MODIFICADO)

---

## ✅ Status da Implementação

- ✅ Modelos locais criados
- ✅ Repositórios locais criados
- ✅ Endpoint backend criado
- ✅ Sincronização implementada
- ✅ Serviços modificados para suporte offline
- ⏳ Arquivos .g.dart precisam ser gerados (build_runner)
- ⏳ Testes necessários

---

## 🚀 Pronto para Testar!

A implementação está completa. Execute o build_runner para gerar os arquivos Hive e teste a funcionalidade offline!

