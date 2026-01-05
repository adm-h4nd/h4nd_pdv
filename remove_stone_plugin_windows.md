# Como Remover Plugin stone_payments do Windows

## Problema

O plugin `stone_payments` está sendo registrado automaticamente no Windows pelo Flutter, causando erro de DLL porque o plugin não tem suporte Windows.

## Solução Rápida (Após cada build)

1. **Faça o build:**
   ```bash
   flutter build windows --release
   ```

2. **Edite o arquivo gerado:**
   - Abra: `build/windows/flutter/generated_plugin_registrant.cc`
   - Procure por `stone_payments` ou `StonePayments`
   - Comente ou remova essas linhas:
     ```cpp
     // #include <stone_payments/stone_payments_plugin.h>
     // stone_payments::StonePaymentsPluginRegisterWithRegistrar(...);
     ```

3. **Recompile apenas o executável** (não precisa fazer `flutter build` novamente)

## Solução Permanente (Recomendado)

Crie um arquivo customizado que não inclui o plugin stone_payments:

1. **Após fazer o build, copie o arquivo gerado:**
   ```bash
   cp build/windows/flutter/generated_plugin_registrant.cc windows/flutter/custom_plugin_registrant.cc
   ```

2. **Edite `windows/flutter/custom_plugin_registrant.cc` e remova/comente as linhas do stone_payments**

3. **Modifique `windows/runner/CMakeLists.txt`:**
   - Linha 14: Substitua:
     ```cmake
     "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
     ```
   - Por:
     ```cmake
     "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/custom_plugin_registrant.cc"
     ```

4. **Faça o build novamente:**
   ```bash
   flutter build windows --release
   ```

Agora o arquivo customizado será usado em vez do gerado automaticamente, e o plugin stone_payments não será registrado no Windows.


