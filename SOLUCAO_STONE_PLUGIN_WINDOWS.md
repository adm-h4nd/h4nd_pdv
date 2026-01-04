# Solução: Plugin stone_payments sendo carregado no Windows

## Problema Identificado

Após as alterações para funcionar no StoneP2, o plugin `stone_payments` está sendo registrado automaticamente no Windows pelo Flutter, mesmo sem suporte. Isso causa erro de DLL porque o plugin tenta carregar bibliotecas nativas que não existem para Windows.

## Solução: Excluir o plugin do registro no Windows

### Passo 1: Após fazer o build, edite o arquivo gerado

1. **Faça o build:**
   ```bash
   flutter build windows --release
   ```

2. **Localize o arquivo:**
   - Caminho: `build/windows/flutter/generated_plugin_registrant.cc`

3. **Edite o arquivo e remova/comente as linhas do stone_payments:**
   ```cpp
   // Procure por algo como:
   #include <stone_payments/stone_payments_plugin.h>
   
   // E também:
   stone_payments::StonePaymentsPluginRegisterWithRegistrar(
       flutter::PluginRegistrarManager::GetInstance()
           ->GetRegistrarForPlugin("StonePaymentsPlugin"));
   
   // Comente ou remova essas linhas
   ```

4. **Recompile apenas o executável (não precisa fazer flutter build novamente):**
   - Abra o Visual Studio
   - Abra a solução em `build/windows/`
   - Compile apenas o projeto

### Passo 2: Solução Permanente (Criar arquivo customizado)

Para evitar ter que editar o arquivo gerado toda vez:

1. **Crie o diretório se não existir:**
   ```bash
   mkdir -p windows/flutter
   ```

2. **Após fazer o build, copie o arquivo gerado:**
   ```bash
   cp build/windows/flutter/generated_plugin_registrant.cc windows/flutter/custom_plugin_registrant.cc
   ```

3. **Edite `windows/flutter/custom_plugin_registrant.cc` e remova/comente as linhas do stone_payments**

4. **Modifique `windows/runner/CMakeLists.txt`:**
   ```cmake
   # Substitua esta linha:
   "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
   
   # Por:
   "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/custom_plugin_registrant.cc"
   ```

5. **Faça o build novamente:**
   ```bash
   flutter build windows --release
   ```

## Verificação

Após aplicar a solução:

1. O app deve iniciar sem erro de DLL
2. O plugin stone_payments não será registrado no Windows
3. O app funcionará normalmente (sem o provider Stone, mas funcionando)

## Observações

- O plugin `stone_payments` não tem suporte Windows
- O Flutter registra todos os plugins automaticamente, mesmo sem suporte
- A solução definitiva é excluir o plugin do registro no Windows
- O código Dart já verifica a plataforma antes de usar o SDK Stone, mas isso não impede o registro nativo

