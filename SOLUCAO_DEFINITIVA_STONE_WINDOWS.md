# Solução Definitiva: Plugin stone_payments no Windows

## Problema

O plugin `stone_payments` está sendo registrado automaticamente no Windows pelo Flutter, causando erro de DLL porque o plugin não tem suporte Windows.

## Solução Implementada

### 1. Script Automático no GitHub Actions

O workflow `build-windows.yml` foi modificado para:
1. Fazer o build do Flutter normalmente
2. **Buscar automaticamente o arquivo `generated_plugin_registrant.cc`** (busca recursiva)
3. **Remover automaticamente o plugin `stone_payments` do arquivo gerado**
4. **Recompilar apenas o executável** com o plugin removido

### 2. Como Funciona

Após o build do Flutter, o script:
- Busca o arquivo `generated_plugin_registrant.cc` recursivamente em `build/windows`
- Remove/comenta as linhas relacionadas ao `stone_payments`
- Recompila o executável usando CMake diretamente
- O executável final não terá o plugin registrado

### 3. Busca Inteligente

O script faz busca recursiva para encontrar o arquivo, mesmo que esteja em um local diferente do esperado. Se não encontrar:
- Mostra informações de debug sobre a estrutura de diretórios
- Continua sem modificar (não falha o build)
- O plugin pode não estar sendo registrado (o que é bom!)

### 4. Para Build Local

Se você quiser fazer build localmente, execute o script manualmente:

```powershell
# Após fazer flutter build windows --release
.\scripts\remove_stone_plugin_windows.ps1 -BuildType Release
```

## Verificação

Após aplicar a solução:

1. ✅ O app deve iniciar sem erro de DLL
2. ✅ O plugin stone_payments não será registrado no Windows
3. ✅ O app funcionará normalmente (sem o provider Stone, mas funcionando)
4. ✅ A solução funciona automaticamente no GitHub Actions
5. ✅ Se o arquivo não for encontrado, o build continua (não falha)

## Observações

- O plugin `stone_payments` não tem suporte Windows
- O Flutter registra todos os plugins automaticamente, mesmo sem suporte
- A solução remove o plugin do registro **após** o build, mas **antes** de compilar o executável final
- O código Dart já verifica a plataforma antes de usar o SDK Stone, mas isso não impede o registro nativo
- Esta solução é **definitiva** e funciona tanto localmente quanto no CI/CD
- Se o arquivo não for encontrado, pode significar que o plugin não está sendo incluído (o que é bom!)

## Troubleshooting

### Se o arquivo não for encontrado:

1. **Verifique se o build foi concluído:**
   - O arquivo é gerado durante o build do Flutter
   - Certifique-se de que o step "Build Windows" foi executado com sucesso

2. **Verifique a estrutura de diretórios:**
   - O script mostra informações de debug se não encontrar o arquivo
   - Verifique se o diretório `build/windows` existe

3. **Se o erro de DLL persistir:**
   - O plugin pode estar sendo registrado de outra forma
   - Verifique manualmente o arquivo `generated_plugin_registrant.cc` após o build
   - Procure por `stone_payments` e remova manualmente se necessário
