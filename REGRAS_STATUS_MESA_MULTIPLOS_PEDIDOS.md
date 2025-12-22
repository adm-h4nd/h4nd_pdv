# Regras de Status de Mesa com Múltiplos Pedidos

## 🎯 Problema

**Cenário:** Uma mesa pode ter múltiplos pedidos em estados diferentes:
- Pedido 1: `pendente`
- Pedido 2: `sincronizando`
- Pedido 3: `sincronizado`
- Pedido 4: `erro`

**Questões:**
1. Como determinar o status da mesa?
2. O que a mesa deve fazer em cada evento de pedido?
3. Quando o status da mesa muda?

---

## 📊 Estados Possíveis de Pedidos

| Status | Significado | Impacto na Mesa |
|--------|-------------|-----------------|
| `pendente` | Aguardando sincronização | Mesa ocupada/pendente |
| `sincronizando` | Sendo enviado ao servidor | Mesa ocupada/sincronizando |
| `sincronizado` | Enviado com sucesso | Não impacta (já foi enviado) |
| `erro` | Falha na sincronização | Mesa ocupada/com erro |

---

## 🎯 Regras de Prioridade para Status da Mesa

### **Regra 1: Prioridade de Status Visual**

```
1. Se tem pedido PENDENTE → Status: "ocupada" (pendente)
2. Se tem pedido SINCRONIZANDO → Status: "ocupada" (sincronizando)
3. Se tem pedido com ERRO → Status: "ocupada" (com erro)
4. Se TODOS sincronizados → Status: do servidor (livre/ocupada)
```

**Lógica:**
- Status local (pendente/sincronizando/erro) tem PRIORIDADE sobre status do servidor
- Se não há pedidos locais pendentes, usa status do servidor

---

### **Regra 2: Agregação de Estados**

**Contadores:**
- `pedidosPendentes` = count(pendente)
- `pedidosSincronizando` = count(sincronizando)
- `pedidosComErro` = count(erro)
- `pedidosSincronizados` = count(sincronizado)

**Status Visual:**
```dart
if (pedidosPendentes > 0) {
  return 'ocupada'; // Com indicador de pendente
} else if (pedidosSincronizando > 0) {
  return 'ocupada'; // Com indicador de sincronizando
} else if (pedidosComErro > 0) {
  return 'ocupada'; // Com indicador de erro
} else {
  return statusDoServidor; // Livre ou ocupada do servidor
}
```

---

## 🔄 O que a Mesa Faz em Cada Evento

### **Evento: `pedidoCriado`**

**Situação:** Novo pedido pendente criado

**Ação da Mesa:**
1. ✅ Incrementa contador de pedidos pendentes
2. ✅ Recalcula status: se era livre → fica ocupada
3. ✅ Status visual: "ocupada" (pendente)
4. ✅ Atualiza UI imediatamente

**Exemplo:**
```
Mesa tinha: 0 pedidos → Status: "livre"
Evento: pedidoCriado
Mesa agora: 1 pedido pendente → Status: "ocupada" (pendente)
```

---

### **Evento: `pedidoSincronizando`**

**Situação:** Pedido começou a sincronizar

**Ação da Mesa:**
1. ✅ Decrementa contador de pendentes
2. ✅ Incrementa contador de sincronizando
3. ✅ Recalcula status: continua ocupada, mas muda indicador
4. ✅ Status visual: "ocupada" (sincronizando)
5. ✅ Atualiza UI (mostra spinner de sincronização)

**Exemplo:**
```
Mesa tinha: 2 pedidos pendentes → Status: "ocupada" (pendente)
Evento: pedidoSincronizando (1 pedido)
Mesa agora: 1 pendente + 1 sincronizando → Status: "ocupada" (sincronizando)
```

---

### **Evento: `pedidoSincronizado`**

**Situação:** Pedido sincronizado com sucesso

**Ação da Mesa:**
1. ✅ Decrementa contador de sincronizando
2. ✅ Incrementa contador de sincronizados (se necessário)
3. ✅ Recalcula status:
   - Se ainda tem pendentes/sincronizando → continua ocupada
   - Se TODOS sincronizados → busca status do servidor
4. ✅ Se todos sincronizados, agenda atualização do servidor (com delay)
5. ✅ Status visual: baseado em pedidos restantes ou servidor

**Exemplo:**
```
Mesa tinha: 1 pendente + 1 sincronizando → Status: "ocupada" (sincronizando)
Evento: pedidoSincronizado (1 pedido)
Mesa agora: 1 pendente + 0 sincronizando → Status: "ocupada" (pendente)
```

**Exemplo 2 (último pedido):**
```
Mesa tinha: 0 pendentes + 1 sincronizando → Status: "ocupada" (sincronizando)
Evento: pedidoSincronizado (último pedido)
Mesa agora: 0 pendentes + 0 sincronizando → Busca servidor → Status: "livre"
```

---

### **Evento: `pedidoErro`**

**Situação:** Pedido falhou na sincronização

**Ação da Mesa:**
1. ✅ Decrementa contador de sincronizando (se estava sincronizando)
2. ✅ Incrementa contador de erros
3. ✅ Recalcula status: continua ocupada, mas mostra erro
4. ✅ Status visual: "ocupada" (com erro)
5. ✅ Atualiza UI (mostra indicador de erro)
6. ⚠️ NÃO busca servidor (pedido ainda está local)

**Exemplo:**
```
Mesa tinha: 1 sincronizando → Status: "ocupada" (sincronizando)
Evento: pedidoErro
Mesa agora: 1 erro → Status: "ocupada" (com erro)
```

---

### **Evento: `pedidoRemovido`**

**Situação:** Pedido deletado do Hive

**Ação da Mesa:**
1. ✅ Decrementa contador apropriado (pendente/sincronizando/erro)
2. ✅ Recalcula status:
   - Se ainda tem pedidos → continua ocupada
   - Se era o ÚLTIMO pedido → busca servidor para verificar se está livre
3. ✅ Status visual: baseado em pedidos restantes ou servidor

**Exemplo:**
```
Mesa tinha: 1 pendente → Status: "ocupada" (pendente)
Evento: pedidoRemovido (último pedido)
Mesa agora: 0 pedidos → Busca servidor → Status: "livre"
```

---

## ⏰ Quando o Status da Mesa Muda?

### **Mudanças Imediatas (Local)**

Status muda IMEDIATAMENTE quando:
- ✅ `pedidoCriado` → Mesa fica ocupada
- ✅ `pedidoSincronizando` → Mesa mostra sincronizando
- ✅ `pedidoErro` → Mesa mostra erro
- ✅ `pedidoRemovido` → Recalcula (pode ficar livre)

**Não espera servidor!** Status local tem prioridade.

---

### **Mudanças com Delay (Servidor)**

Status muda APÓS DELAY quando:
- ✅ `pedidoSincronizado` → Se TODOS sincronizados, busca servidor após 2s
- ✅ `pedidoRemovido` → Se era último pedido, busca servidor imediatamente

**Por quê delay?**
- Evita buscar servidor antes de todos os pedidos sincronizarem
- Evita conflito entre status local e servidor

---

## 📋 Exemplo Completo: Múltiplos Pedidos

### **Cenário:**

Mesa 5 tem:
- Pedido A: `pendente`
- Pedido B: `sincronizando`
- Pedido C: `sincronizado`
- Pedido D: `erro`

### **Status da Mesa:**

```
Contadores:
- pendentes: 1
- sincronizando: 1
- sincronizados: 1
- erros: 1

Status Visual: "ocupada" (pendente)
Por quê? Pedidos pendentes têm prioridade máxima
```

### **Eventos e Mudanças:**

```
1. Evento: pedidoSincronizado (Pedido B)
   ↓
   Contadores:
   - pendentes: 1
   - sincronizando: 0
   - sincronizados: 2
   - erros: 1
   ↓
   Status: "ocupada" (pendente) - não muda, ainda tem pendente

2. Evento: pedidoSincronizado (Pedido A)
   ↓
   Contadores:
   - pendentes: 0
   - sincronizando: 0
   - sincronizados: 3
   - erros: 1
   ↓
   Status: "ocupada" (com erro) - ainda tem erro!

3. Evento: pedidoRemovido (Pedido D - erro)
   ↓
   Contadores:
   - pendentes: 0
   - sincronizando: 0
   - sincronizados: 3
   - erros: 0
   ↓
   Status: Busca servidor → "livre" ou "ocupada" (do servidor)
```

---

## 🎯 Regras de Negócio Resumidas

### **1. Prioridade de Status**

```
pendente > sincronizando > erro > servidor
```

### **2. Mesa Fica Ocupada Se:**

- Tem pelo menos 1 pedido `pendente` OU
- Tem pelo menos 1 pedido `sincronizando` OU
- Tem pelo menos 1 pedido `erro`

### **3. Mesa Fica Livre Se:**

- Não tem pedidos locais pendentes/sincronizando/erro E
- Status do servidor é "livre"

### **4. Recalcular Status Quando:**

- Qualquer evento de pedido acontece
- Sempre recalcula TODOS os contadores
- Sempre recalcula status visual baseado em prioridade

---

## ✅ Conclusão

**Respostas:**

1. **Como tratar múltiplos pedidos?**
   - Agregar por status (contadores)
   - Aplicar regra de prioridade
   - Status visual baseado no status de maior prioridade

2. **O que a mesa faz em cada evento?**
   - Atualiza contadores apropriados
   - Recalcula status imediatamente
   - Busca servidor apenas se necessário (todos sincronizados)

3. **Quando status muda?**
   - Imediatamente para status local (pendente/sincronizando/erro)
   - Com delay para status do servidor (após todos sincronizados)

**Faz sentido?** ✅ Sim, cobre todos os casos!
