# Como Funciona a Exclusão de Dependências no Gradle

## 🔄 Processo Completo

### **NÃO é "incluir depois remover"**

O Gradle **não inclui e depois remove**. Ele **resolve mas não inclui** no classpath final.

---

## 📋 Fluxo Detalhado Passo a Passo

### **FASE 1: Resolução de Dependências**

Quando você compila o app:

```bash
flutter build apk --flavor mobile
```

**O que acontece:**

1. **Flutter processa `pubspec.yaml`:**
   ```
   stone_payments: ^1.0.0
   ```
   - Flutter baixa o pacote
   - Flutter gera código de plugin (`GeneratedPluginRegistrant.java`)
   - Flutter adiciona dependências nativas ao Gradle

2. **Gradle resolve dependências:**
   ```
   stone_payments (Flutter plugin)
   └── dev.ltag:stone_payments:1.0.0 (plugin nativo)
       └── br.com.stone:stone-sdk:4.10.2 (SDK nativo)
           └── [outras dependências transitivas]
   ```

3. **Gradle cria configurações por variant:**
   - `mobileDebugCompileConfiguration` (para compilar)
   - `mobileDebugRuntimeConfiguration` (para executar)
   - `stoneP2DebugCompileConfiguration`
   - `stoneP2DebugRuntimeConfiguration`

---

### **FASE 2: Aplicação de Exclusões (ANTES de incluir)**

**Arquivo:** `android/app/build.gradle.kts`

```kotlin
applicationVariants.all {
    val variant = this
    if (variant.flavorName == "mobile") {
        // ⚠️ IMPORTANTE: Isso acontece ANTES de incluir no classpath
        variant.runtimeConfiguration.exclude(
            group = "dev.ltag",
            module = "stone_payments"
        )
        variant.compileConfiguration.exclude(
            group = "dev.ltag",
            module = "stone_payments"
        )
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

**O que acontece:**

1. **Gradle identifica o variant:** `mobileDebug`
2. **Gradle aplica exclusões ANTES de montar o classpath:**
   ```
   Lista de dependências resolvidas:
   ✅ androidx.core:core:1.17.0
   ✅ com.llfbandit.app_links:...
   ❌ dev.ltag:stone_payments:1.0.0  ← EXCLUÍDA (não entra no classpath)
   ❌ br.com.stone:stone-sdk:4.10.2  ← EXCLUÍDA (não entra no classpath)
   ✅ io.flutter.plugins.sharedpreferences:...
   ```

3. **Gradle monta o classpath final SEM as dependências excluídas:**
   ```
   Classpath final do mobileDebug:
   - androidx.core:core:1.17.0
   - com.llfbandit.app_links:...
   - io.flutter.plugins.sharedpreferences:...
   - [SEM stone_payments]
   - [SEM stone-sdk]
   ```

---

### **FASE 3: Compilação**

**O que acontece:**

1. **Compilação Java/Kotlin:**
   - Gradle compila apenas com dependências do classpath
   - Como `stone_payments` foi excluído, não está disponível
   - Código que referencia `dev.ltag.stone_payments.*` **não compila** (mas isso não acontece porque o código Dart já foi compilado)

2. **Empacotamento (APK):**
   - Gradle inclui apenas bibliotecas do `runtimeConfiguration`
   - Como `stone-sdk` foi excluído, **não entra no APK**
   - Resultado: APK sem classes nativas do SDK Stone

---

## 🎯 Visualização do Processo

```
┌─────────────────────────────────────────────────────────────┐
│ 1. RESOLUÇÃO                                                │
│    Gradle resolve TODAS as dependências                     │
│    ✅ stone_payments                                        │
│    ✅ stone-sdk                                             │
│    ✅ Outras dependências                                   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. APLICAÇÃO DE EXCLUSÕES (ANTES de incluir)              │
│    Se variant == "mobile":                                 │
│    ❌ Exclui dev.ltag:stone_payments                       │
│    ❌ Exclui br.com.stone:stone-sdk                        │
│                                                             │
│    Classpath filtrado:                                     │
│    ✅ Outras dependências                                  │
│    ❌ stone_payments (removido)                            │
│    ❌ stone-sdk (removido)                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. COMPILAÇÃO                                               │
│    Compila apenas com dependências do classpath filtrado   │
│    ✅ Código compila normalmente                           │
│    ❌ stone_payments não está disponível                   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. EMPACOTAMENTO (APK)                                      │
│    Inclui apenas bibliotecas do runtimeConfiguration       │
│    ✅ Bibliotecas normais                                  │
│    ❌ stone-sdk NÃO está no APK                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 Comparação: Mobile vs StoneP2

### **Flavor `mobile`:**

```
Resolução:
✅ stone_payments resolvido
✅ stone-sdk resolvido

Exclusões aplicadas:
❌ dev.ltag:stone_payments → EXCLUÍDO
❌ br.com.stone:stone-sdk → EXCLUÍDO

Classpath final:
✅ Outras dependências
❌ SEM stone_payments
❌ SEM stone-sdk

APK final:
✅ Outras bibliotecas
❌ SEM classes nativas do SDK Stone
```

### **Flavor `stoneP2`:**

```
Resolução:
✅ stone_payments resolvido
✅ stone-sdk resolvido

Exclusões aplicadas:
✅ Nenhuma exclusão (variant != "mobile")

Classpath final:
✅ Outras dependências
✅ COM stone_payments
✅ COM stone-sdk

APK final:
✅ Outras bibliotecas
✅ COM classes nativas do SDK Stone
```

---

## ⚠️ Importante: Código Dart

### **Por que o código Dart ainda compila?**

O código Dart é compilado **ANTES** do Gradle processar as dependências nativas:

1. **Flutter compila Dart:**
   ```dart
   import 'package:stone_payments/stone_payments.dart';
   ```
   - Flutter compila este código normalmente
   - O código Dart compilado vai para o APK

2. **Gradle processa dependências nativas:**
   - Exclui `stone_payments` e `stone-sdk` do classpath
   - Mas o código Dart já foi compilado

3. **Resultado:**
   - ✅ Código Dart compilado está no APK
   - ❌ Bibliotecas nativas não estão no APK
   - ⚠️ Se o código Dart tentar usar o SDK em runtime, vai falhar (mas não vai tentar porque o provider não é registrado)

---

## 🧪 Como Verificar

### **1. Verificar que as exclusões funcionam:**

```bash
# Compilar e verificar dependências resolvidas
./gradlew :app:dependencies --configuration mobileDebugRuntimeClasspath | grep stone
# Deve retornar vazio ou mostrar que foi excluído
```

### **2. Verificar o APK:**

```bash
# Extrair APK
unzip -q app-release.apk -d apk_extracted

# Procurar por classes Stone
find apk_extracted -name "*.dex" -exec strings {} \; | grep -i "stone" | grep -i "payments"
# Deve retornar mínimo ou nenhum resultado relacionado ao SDK nativo
```

### **3. Verificar bibliotecas nativas:**

```bash
# Procurar por .so (bibliotecas nativas)
find apk_extracted -name "*.so" | xargs strings | grep -i "stone"
# Deve retornar vazio
```

---

## ✅ Conclusão

**Não é "incluir depois remover"**

É **"resolver mas não incluir no classpath final"**:

1. ✅ Gradle resolve todas as dependências
2. ✅ Gradle aplica exclusões ANTES de montar o classpath
3. ✅ Gradle compila apenas com dependências não excluídas
4. ✅ Gradle empacota apenas bibliotecas não excluídas

**Resultado:** As bibliotecas nativas do SDK Stone **nunca entram no APK** do flavor mobile, mesmo que tenham sido resolvidas durante o processo de build.
