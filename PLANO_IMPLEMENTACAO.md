# 📋 Plano de Implementação: Servidor Local com Log de Requisições

## 🎯 Objetivo

Implementar servidor local que:
1. Intercepta todas as requisições (middleware)
2. Salva em log genérico (log_requisicoes)
3. Sincroniza com nuvem em background (SyncService)

---

## 📋 Checklist de Implementação

### **Fase 1: Estrutura Base**
- [ ] Criar migration para tabela `log_requisicoes`
- [ ] Criar modelo `LogRequisicao`
- [ ] Criar `LocalDbContext` (se não existir)
- [ ] Configurar `appsettings.Local.json`

### **Fase 2: Middleware de Log**
- [ ] Criar `LogRequisicaoMiddleware`
- [ ] Implementar interceptação de requisições
- [ ] Salvar token, headers, payload
- [ ] Registrar middleware no `Program.cs`

### **Fase 3: Serviço de Sincronização**
- [ ] Criar `SyncService` (BackgroundService)
- [ ] Implementar leitura de log
- [ ] Implementar repetição de requisições
- [ ] Implementar renovação de token
- [ ] Registrar serviço no `Program.cs`

### **Fase 4: Configuração**
- [ ] Configurar flag `IsLocal`
- [ ] Configurar connection strings
- [ ] Configurar `ApiNuvem` settings
- [ ] Testar localmente

### **Fase 5: Testes**
- [ ] Testar middleware de log
- [ ] Testar sincronização
- [ ] Testar renovação de token
- [ ] Testar offline/online

---

## 🗂️ Estrutura de Arquivos

```
MXCloud.API/
├── Data/
│   ├── LocalDbContext.cs          ← Criar/Atualizar
│   └── Migrations/
│       └── XXXX_CriarLogRequisicoes.cs  ← Criar
├── Models/
│   └── LogRequisicao.cs           ← Criar
├── Middleware/
│   └── LogRequisicaoMiddleware.cs ← Criar
├── Services/
│   └── SyncService.cs             ← Criar
├── Program.cs                      ← Atualizar
└── appsettings.Local.json          ← Criar
```

---

## 🚀 Próximos Passos

1. Criar migration para `log_requisicoes`
2. Criar modelo `LogRequisicao`
3. Criar middleware
4. Criar serviço de sync
5. Configurar tudo

Vamos começar! 🚀

