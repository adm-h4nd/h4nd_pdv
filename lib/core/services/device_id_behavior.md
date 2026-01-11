# 📱 Comportamento do Device ID - Cenários de Uso

Este documento explica como o `DeviceIdService` se comporta em diferentes cenários.

## ✅ Cenários que MANTÉM o ID (mesmo número)

### 1. **Fechar e abrir o app novamente**
- ✅ **Mantém o ID**
- O ID é armazenado em `SharedPreferences`, que persiste entre execuções do app
- O cache em memória é limpo, mas o ID é recuperado do armazenamento

### 2. **Atualizar a versão do app**
- ✅ **Mantém o ID**
- `SharedPreferences` não é deletado durante atualizações
- O ID continua disponível após a atualização

### 3. **Limpar cache do app**
- ✅ **Mantém o ID**
- Limpar cache (Clear Cache) não deleta `SharedPreferences`
- Apenas arquivos temporários são removidos

### 4. **Reiniciar o dispositivo**
- ✅ **Mantém o ID**
- `SharedPreferences` persiste após reinicializações

## ❌ Cenários que PERDEM o ID (gera novo número)

### 1. **Desinstalar o app**
- ❌ **Gera novo ID**
- `SharedPreferences` é deletado junto com o app
- Ao reinstalar, um novo ID será gerado

### 2. **Limpar dados do app (Clear Data)**
- ❌ **Gera novo ID**
- "Clear Data" deleta `SharedPreferences`
- Um novo ID será gerado na próxima execução

### 3. **Reset de fábrica do dispositivo**
- ❌ **Gera novo ID**
- Todos os dados do dispositivo são apagados
- Um novo ID será gerado após reinstalar o app

### 4. **Android: Mudança do Android ID**
- ⚠️ **Pode mudar o ID**
- Se o Android ID mudar (raro, mas possível após reset de fábrica)
- E o ID armazenado foi perdido, um novo será gerado

### 5. **iOS: Desinstalar todos os apps do vendor**
- ⚠️ **Pode mudar o IDFV**
- Se todos os apps do mesmo vendor forem desinstalados
- O IDFV pode mudar na próxima instalação

## 🔄 Fluxo de Obtenção do ID

```
1. Verifica cache em memória
   └─> Se existe, retorna imediatamente

2. Verifica SharedPreferences
   └─> Se existe, retorna e cacheia
   
3. Tenta obter ID nativo (Android/iOS)
   └─> Se existe, salva em SharedPreferences e retorna
   
4. Gera UUID único
   └─> Salva em SharedPreferences e retorna
```

## 📊 Tabela Comparativa

| Cenário | Android | iOS | Windows | Resultado |
|---------|---------|-----|---------|-----------|
| Fechar/Abrir app | ✅ Mantém | ✅ Mantém | ✅ Mantém | **Mantém** |
| Atualizar versão | ✅ Mantém | ✅ Mantém | ✅ Mantém | **Mantém** |
| Limpar cache | ✅ Mantém | ✅ Mantém | ✅ Mantém | **Mantém** |
| Desinstalar app | ❌ Novo ID | ❌ Novo ID | ❌ Novo ID | **Novo ID** |
| Clear Data | ❌ Novo ID | ❌ Novo ID | ❌ Novo ID | **Novo ID** |
| Reset de fábrica | ❌ Novo ID | ❌ Novo ID | ❌ Novo ID | **Novo ID** |

## 💡 Recomendações de Uso

### ✅ Use o Device ID para:
- Identificar instalações únicas do app
- Rastrear dispositivos PDV no sistema
- Associar dados locais a uma instalação específica
- Estatísticas e analytics por instalação

### ⚠️ NÃO use o Device ID para:
- Autenticação de usuário (use tokens JWT)
- Identificação permanente do dispositivo físico
- Rastreamento entre desinstalações/reinstalações
- Dados que precisam persistir após desinstalação

## 🔧 Como Testar

### Testar persistência após atualização:
```dart
// 1. Obter ID inicial
final id1 = await DeviceIdService.getDeviceId();
print('ID inicial: $id1');

// 2. Simular atualização (apenas reiniciar app)
// 3. Obter ID novamente
final id2 = await DeviceIdService.getDeviceId();
print('ID após reiniciar: $id2');
// id1 == id2 ✅
```

### Testar regeneração:
```dart
// Forçar regeneração (útil para testes)
final newId = await DeviceIdService.regenerateDeviceId();
print('Novo ID: $newId');
```

## 🎯 Conclusão

O `DeviceIdService` garante que:
- ✅ O ID persiste entre execuções do app
- ✅ O ID persiste após atualizações
- ✅ O ID persiste após limpar cache
- ❌ O ID muda após desinstalação (comportamento esperado)
- ❌ O ID muda após limpar dados do app (comportamento esperado)

**O ID é único por INSTALAÇÃO do app, não por dispositivo físico.**

