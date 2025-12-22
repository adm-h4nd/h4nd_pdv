# Explicação Detalhada: Estrutura de Flavors e Carregamento de Pacotes

## 📋 Resumo Executivo

**Pergunta:** Os pacotes (`stone_payments`, `app_links`) são carregados sempre ou apenas quando necessário?

**Resposta:** Os pacotes são **sempre incluídos no build**, mas são **usados condicionalmente em runtime** baseado no flavor detectado e na configuração JSON.

---

## 🔄 Fluxo Completo Passo a Passo

### **PASSO 1: Build do App com Flavor**

Quando você compila o app com um flavor específico:

```bash
flutter run --flavor stoneP2 --dart-define=FLAVOR=stoneP2
```

**O que acontece:**
- ✅ Todos os pacotes do `pubspec.yaml` são incluídos no build
- ✅ O flavor é passado via `--dart-define=FLAVOR=stoneP2`
- ✅ O `applicationId` muda conforme o flavor (ex: `com.example.mx_cloud_pdv.stone.p2`)

**Trecho relevante - `android/app/build.gradle.kts`:**
```kotlin
productFlavors {
    create("stoneP2") {
        dimension = "device"
        applicationIdSuffix = ".stone.p2"  // ← Define applicationId único
        resValue("string", "app_name", "MX Cloud PDV Stone P2")
    }
}
```

---

### **PASSO 2: Detecção do Flavor (Runtime)**

Quando o app inicia, o `FlavorConfig` detecta qual flavor está rodando:

**Arquivo:** `lib/core/config/flavor_config.dart`

```dart
static Future<String> detectFlavorAsync() async {
    // 1️⃣ Tenta ler do ambiente de build (--dart-define=FLAVOR=stoneP2)
    const flavorEnv = String.fromEnvironment('FLAVOR');
    if (flavorEnv.isNotEmpty) {
        return flavorEnv;  // ✅ Retorna 'stoneP2'
    }
    
    // 2️⃣ Tenta detectar pelo applicationId (mais confiável)
    final packageInfo = await PackageInfo.fromPlatform();
    final applicationId = packageInfo.packageName;
    
    if (applicationId.contains('.stone.p2')) {
        return 'stoneP2';  // ✅ Detectado!
    } else if (applicationId.contains('.mobile')) {
        return 'mobile';
    }
    
    // 3️⃣ Fallback: tenta detectar pelo arquivo de config disponível
    // Tenta carregar 'assets/config/payment_stone_p2.json'
    // Se existir, retorna 'stoneP2'
    
    return 'mobile';  // Fallback final
}
```

**Ordem de prioridade:**
1. `--dart-define=FLAVOR=...` (mais rápido)
2. `applicationId` (mais confiável)
3. Tentativa de carregar arquivo de config (fallback)

---

### **PASSO 3: Carregamento da Configuração por Flavor**

O `PaymentConfig` carrega o arquivo JSON específico do flavor:

**Arquivo:** `lib/core/payment/payment_config.dart`

```dart
static Future<PaymentConfig> load() async {
    // 1️⃣ Detecta o flavor
    final flavor = await FlavorConfig.detectFlavorAsync();
    // Exemplo: flavor = 'stoneP2'
    
    // 2️⃣ Normaliza o nome (stoneP2 -> stone_p2)
    final flavorFileName = _normalizeFlavorFileName(flavor);
    // Resultado: 'stone_p2'
    
    // 3️⃣ Monta o caminho do arquivo
    final configPath = 'assets/config/payment_$flavorFileName.json';
    // Resultado: 'assets/config/payment_stone_p2.json'
    
    // 4️⃣ Carrega o arquivo JSON
    final configJson = await rootBundle.loadString(configPath);
    final configMap = jsonDecode(configJson);
    
    return PaymentConfig.fromJson(configMap);
}
```

**Arquivos de configuração:**

**`assets/config/payment_stone_p2.json`:**
```json
{
  "availableProviders": ["cash", "stone_p2_deeplink", "stone_pos"],
  "defaultProvider": "stone_p2_deeplink",
  "providerSettings": {
    "stone_p2_deeplink": {
      "model": "P2",
      "returnScheme": "deeplinkmxcloudpdv://pay-response"
    },
    "stone_pos": {
      "appName": "MX Cloud PDV",
      "stoneCode": "206192723",
      "model": "P2"
    }
  }
}
```

**`assets/config/payment_mobile.json`:**
```json
{
  "availableProviders": ["cash", "deep_link"],
  "defaultProvider": null
}
```

---

### **PASSO 4: Registro Condicional dos Providers**

O `PaymentProviderRegistry` registra apenas os providers permitidos pela configuração:

**Arquivo:** `lib/data/adapters/payment/payment_provider_registry.dart`

```dart
static Future<void> registerAll(PaymentConfig config) async {
    // ✅ Sempre registrados (disponíveis em todos os flavors)
    registerProvider('cash', (_) => CashPaymentAdapter());
    registerProvider('deep_link', (_) => DeepLinkPaymentAdapter());
    registerProvider('pix', (_) => DeepLinkPaymentAdapter());
    
    // ⚠️ Registrados CONDICIONALMENTE baseado na config
    if (config.canUseProvider('stone_p2_deeplink')) {
        // Só registra se 'stone_p2_deeplink' estiver em availableProviders
        registerProvider('stone_p2_deeplink', (settings) {
            return StoneP2DeepLinkPaymentAdapter();
        });
    }
    
    if (config.canUseProvider('stone_pos')) {
        // Só registra se 'stone_pos' estiver em availableProviders
        registerProvider('stone_pos', (settings) {
            return StonePOSAdapter(settings: settings);
        });
    }
}
```

**O que acontece:**

**Flavor `stoneP2`:**
- ✅ `cash` → registrado
- ✅ `deep_link` → registrado
- ✅ `stone_p2_deeplink` → registrado (está em `availableProviders`)
- ✅ `stone_pos` → registrado (está em `availableProviders`)

**Flavor `mobile`:**
- ✅ `cash` → registrado
- ✅ `deep_link` → registrado
- ❌ `stone_p2_deeplink` → **NÃO registrado** (não está em `availableProviders`)
- ❌ `stone_pos` → **NÃO registrado** (não está em `availableProviders`)

---

### **PASSO 5: Disponibilização na UI**

O `PaymentService` retorna apenas os métodos disponíveis:

**Arquivo:** `lib/core/payment/payment_service.dart`

```dart
List<PaymentMethodOption> getAvailablePaymentMethods() {
    final methods = <PaymentMethodOption>[];
    
    // Dinheiro sempre disponível
    if (_config!.canUseProvider('cash')) {
        methods.add(PaymentMethodOption.cash());
    }
    
    // Stone P2 DeepLink (só aparece se estiver na config)
    if (_config!.canUseProvider('stone_p2_deeplink')) {
        methods.add(PaymentMethodOption(
            type: PaymentType.deepLink,
            label: 'Cartão (DeepLink)',
            providerKey: 'stone_p2_deeplink',
        ));
    }
    
    // Stone POS SDK (só aparece se estiver na config)
    if (_config!.canUseProvider('stone_pos')) {
        methods.add(PaymentMethodOption(
            type: PaymentType.pos,
            label: 'Cartão (SDK)',
            providerKey: 'stone_pos',
        ));
    }
    
    return methods;
}
```

**Resultado na UI:**

**Flavor `stoneP2`:**
- 💵 Dinheiro
- 💳 Cartão (DeepLink)
- 💳 Cartão (SDK)

**Flavor `mobile`:**
- 💵 Dinheiro
- 📱 PIX (DeepLink genérico)

---

### **PASSO 6: Uso do Provider (Runtime)**

Quando o usuário seleciona um método de pagamento:

```dart
// 1️⃣ Usuário seleciona "Cartão (SDK)"
final providerKey = 'stone_pos';

// 2️⃣ PaymentService obtém o provider
final provider = await getProvider(providerKey);
// Retorna: StonePOSAdapter(settings: {...})

// 3️⃣ Provider inicializa (se necessário)
await provider.initialize();
// StonePOSAdapter chama: StonePayments.activateStone(...)

// 4️⃣ Processa pagamento
final result = await provider.processPayment(...);
// StonePOSAdapter chama: StonePayments.transaction(...)
```

**Importante:** Mesmo que o pacote `stone_payments` esteja no build, ele só é usado se:
1. ✅ O flavor permitir (`stone_pos` em `availableProviders`)
2. ✅ O provider estiver registrado
3. ✅ O usuário selecionar esse método

---

## 🎯 Resumo Visual do Fluxo

```
┌─────────────────────────────────────────────────────────────┐
│ 1. BUILD                                                    │
│    flutter run --flavor stoneP2                            │
│    ↓                                                         │
│    ✅ Todos os pacotes incluídos (stone_payments, app_links)│
│    ✅ applicationId = com.example.mx_cloud_pdv.stone.p2     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. APP INICIA                                              │
│    ↓                                                         │
│    FlavorConfig.detectFlavorAsync()                        │
│    ↓                                                         │
│    ✅ Detecta: 'stoneP2' (via applicationId)               │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. CARREGA CONFIG                                           │
│    PaymentConfig.load()                                     │
│    ↓                                                         │
│    ✅ Carrega: assets/config/payment_stone_p2.json        │
│    ✅ availableProviders: [cash, stone_p2_deeplink, stone_pos]│
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. REGISTRA PROVIDERS                                       │
│    PaymentProviderRegistry.registerAll(config)              │
│    ↓                                                         │
│    ✅ Registra: cash, deep_link, stone_p2_deeplink, stone_pos│
│    ❌ NÃO registra: getnet_pos (não está na config)        │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. UI DISPONIBILIZA MÉTODOS                                │
│    PaymentService.getAvailablePaymentMethods()              │
│    ↓                                                         │
│    ✅ Mostra: Dinheiro, Cartão (DeepLink), Cartão (SDK)   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. USUÁRIO SELECIONA "Cartão (SDK)"                        │
│    ↓                                                         │
│    PaymentService.processPayment(providerKey: 'stone_pos') │
│    ↓                                                         │
│    ✅ StonePOSAdapter usa stone_payments SDK               │
│    ✅ StonePayments.transaction(...) é chamado              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔑 Pontos Importantes

### ✅ **O que SEMPRE acontece:**
1. Todos os pacotes do `pubspec.yaml` são incluídos no build
2. O código dos adapters está sempre presente
3. O `import 'package:stone_payments/stone_payments.dart'` está sempre no código

### ⚠️ **O que acontece CONDICIONALMENTE:**
1. **Detecção do flavor:** Baseada em `applicationId` ou `--dart-define`
2. **Carregamento da config:** Arquivo JSON específico do flavor
3. **Registro dos providers:** Apenas os permitidos pela config
4. **Disponibilização na UI:** Apenas métodos dos providers registrados
5. **Uso do SDK:** Apenas quando o provider é instanciado e usado

### 🎯 **Vantagens dessa abordagem:**
- ✅ Um único código base para todos os flavors
- ✅ Configuração flexível via JSON (sem recompilar)
- ✅ Fácil adicionar novos flavors (basta criar novo JSON)
- ✅ Código limpo e organizado

### ⚠️ **Limitações:**
- ❌ Pacotes sempre incluídos no build (aumenta tamanho do APK)
- ❌ Código dos adapters sempre presente (mesmo que não usado)
- ⚠️ Se o SDK não estiver disponível, o adapter pode falhar silenciosamente

---

## 📝 Exemplo Prático

**Cenário:** App compilado com flavor `mobile`

1. **Build:** `stone_payments` está incluído no APK
2. **Detecção:** Flavor = `mobile`
3. **Config:** Carrega `payment_mobile.json` → `availableProviders: [cash, deep_link]`
4. **Registro:** Registra apenas `cash` e `deep_link`
5. **UI:** Mostra apenas "Dinheiro" e "PIX"
6. **Uso:** `StonePOSAdapter` nunca é instanciado, então `stone_payments` nunca é usado

**Resultado:** O pacote está no APK, mas nunca é executado! 🎯
