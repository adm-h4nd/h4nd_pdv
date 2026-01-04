# Solução Definitiva: Plugin stone_payments no Windows

## Problema

O plugin `stone_payments` está sendo registrado automaticamente no Windows pelo Flutter, causando erro de DLL porque o plugin não tem suporte Windows.

## Solução Implementada

### 1. Script Automático no GitHub Actions

O workflow `build-windows.yml` foi modificado para:
1. Fazer o build do Flutter normalmente
2. **Remover automaticamente o plugin `stone_payments` do arquivo gerado**
3. **Recompilar apenas o executável** com o plugin removido

### 2. Como Funciona

Após o build do Flutter, o script:
- Localiza o arquivo `build/windows/flutter/generated_plugin_registrant.cc`
- Remove/comenta as linhas relacionadas ao `stone_payments`
- Recompila o executável usando CMake diretamente
- O executável final não terá o plugin registrado

### 3. Para Build Local

Se você quiser fazer build localmente, execute o script manualmente:

```powershell
# Após fazer flutter build windows --release
.\scripts\remove_stone_plugin_windows.ps1
```

Ou execute os comandos manualmente:

```powershell
$pluginFile = "build\windows\flutter\generated_plugin_registrant.cc"

# Remove includes do stone_payments
(Get-Content $pluginFile) -replace '#include <stone_payments/stone_payments_plugin\.h>', '// #include <stone_payments/stone_payments_plugin.h> // Removido: não suporta Windows' | Set-Content $pluginFile

# Remove registro do plugin
(Get-Content $pluginFile) -replace 'stone_payments::StonePaymentsPluginRegisterWithRegistrar\([^)]*\);', '// stone_payments plugin removido (não suporta Windows)' | Set-Content $pluginFile

# Recompila
cd build\windows
cmake --build . --config Release
cd ..\..
```

## Verificação

Após aplicar a solução:

1. ✅ O app deve iniciar sem erro de DLL
2. ✅ O plugin stone_payments não será registrado no Windows
3. ✅ O app funcionará normalmente (sem o provider Stone, mas funcionando)
4. ✅ A solução funciona automaticamente no GitHub Actions

## Observações

- O plugin `stone_payments` não tem suporte Windows
- O Flutter registra todos os plugins automaticamente, mesmo sem suporte
- A solução remove o plugin do registro **após** o build, mas **antes** de compilar o executável final
- O código Dart já verifica a plataforma antes de usar o SDK Stone, mas isso não impede o registro nativo
- Esta solução é **definitiva** e funciona tanto localmente quanto no CI/CD

