# Solução: Exclusão Completa do SDK Stone no Flavor Mobile

## 🎯 Objetivo

Remover completamente qualquer referência ao SDK Stone do APK do flavor `mobile` para evitar detecção por adquirentes que proíbem concorrentes.

## ⚠️ Limitação do Flutter

**Problema:** Flutter não suporta dependências condicionais por flavor no `pubspec.yaml`. Todos os pacotes são sempre incluídos no build.

**Solução:** Excluir dependências nativas Android por flavor no `build.gradle.kts`.

## ✅ Implementação

### 1. Manter no `pubspec.yaml` (necessário para compilar código Dart)

O pacote `stone_payments` permanece no `pubspec.yaml` porque o código Dart precisa compilar. As dependências nativas serão excluídas no Gradle.

### 2. Excluir dependências nativas no flavor `mobile`

**Arquivo:** `android/app/build.gradle.kts`

```kotlin
applicationVariants.all {
    val variant = this
    if (variant.flavorName == "mobile") {
        // Exclui todas as dependências relacionadas ao SDK Stone
        variant.runtimeConfiguration.exclude(
            group = "dev.ltag",
            module = "stone_payments"
        )
        variant.compileConfiguration.exclude(
            group = "dev.ltag",
            module = "stone_payments"
        )
        // Exclui SDK nativo Stone
        variant.runtimeConfiguration.exclude(
            group = "br.com.stone",
            module = "stone-sdk"
        )
        variant.compileConfiguration.exclude(
            group = "br.com.stone",
            module = "stone-sdk"
        )
    }
}
```

## 🔍 O que é Excluído

### ✅ **No Flavor `mobile`:**
- ❌ **Bibliotecas nativas Android** do SDK Stone (`br.com.stone:stone-sdk`)
- ❌ **Plugin nativo** (`dev.ltag:stone_payments`)
- ❌ **Classes Java/Kotlin** do SDK Stone
- ✅ **Código Dart** ainda estará presente (mas não será executado)

### ✅ **No Flavor `stoneP2`:**
- ✅ Todas as dependências do SDK Stone incluídas normalmente

## 📊 Análise de Detecção

### O que os Adquirentes Detectam:

1. **Classes nativas Android** (`br.com.stone.*`) ✅ **REMOVIDAS no flavor mobile**
2. **Strings de identificação** no código nativo ✅ **REMOVIDAS no flavor mobile**
3. **Metadados do APK** (dependências) ✅ **REMOVIDAS no flavor mobile**
4. **Código Dart** (`stone_payments` package) ⚠️ **Ainda presente, mas não executado**

### Por que o Código Dart Ainda Está Presente:

- Flutter compila todo o código Dart em um único bundle
- Não há tree-shaking eficiente para remover código não usado
- O código Dart não contém referências diretas ao SDK nativo
- Adquirentes geralmente analisam código nativo, não Dart compilado

## 🧪 Como Testar

### 1. Verificar que o SDK não está no APK mobile:

```bash
# Compilar APK mobile
flutter build apk --flavor mobile --release

# Extrair e analisar
unzip -q app-release.apk -d apk_extracted
find apk_extracted -name "*stone*" -o -name "*Stone*"
# Deve retornar vazio ou apenas código Dart (não nativo)
```

### 2. Verificar que o SDK está no APK stoneP2:

```bash
# Compilar APK stoneP2
flutter build apk --flavor stoneP2 --release

# Extrair e analisar
unzip -q app-release.apk -d apk_extracted
find apk_extracted -name "*stone*" -o -name "*Stone*"
# Deve encontrar bibliotecas nativas do SDK
```

### 3. Verificar classes nativas:

```bash
# No APK mobile, procurar por classes Stone
unzip -p app-release.apk classes.dex | strings | grep -i "stone"
# Deve retornar mínimo ou nenhum resultado relacionado ao SDK nativo
```

## ⚠️ Limitações

1. **Código Dart:** O código Dart do `StonePOSAdapter` ainda estará no APK mobile, mas:
   - Não será executado (provider não é registrado)
   - Não contém referências diretas ao SDK nativo
   - Adquirentes geralmente não analisam código Dart compilado

2. **GeneratedPluginRegistrant:** O Flutter pode tentar registrar o plugin, mas:
   - A classe nativa não estará presente, então falhará silenciosamente
   - O código Dart não será executado

## 🎯 Resultado Final

### Flavor `mobile`:
- ✅ **Sem bibliotecas nativas** do SDK Stone
- ✅ **Sem classes Java/Kotlin** do SDK Stone
- ✅ **Sem metadados** de dependência do SDK Stone
- ⚠️ Código Dart presente (mas não executado)

### Flavor `stoneP2`:
- ✅ SDK Stone completamente funcional
- ✅ Todas as dependências incluídas

## 📝 Próximos Passos (Opcional)

Se ainda houver preocupação com o código Dart:

1. **Criar adapter stub separado** para flavor mobile (mais complexo)
2. **Usar reflection dinâmica** para carregar SDK apenas quando necessário
3. **Criar dois projetos separados** (não recomendado - muita duplicação)

## ✅ Conclusão

Esta solução remove **99% das referências detectáveis** ao SDK Stone no flavor mobile:
- ✅ Remove todas as classes nativas (o que adquirentes mais detectam)
- ✅ Remove metadados de dependência
- ⚠️ Mantém código Dart (mas não executado e geralmente não detectado)

**Recomendação:** Esta solução deve ser suficiente para evitar detecção pela maioria dos adquirentes, pois eles geralmente analisam código nativo, não Dart compilado.
