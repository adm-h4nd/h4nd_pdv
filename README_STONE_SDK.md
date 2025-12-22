# Integração Stone Payments SDK

## Configuração

### 1. Adicionar dependência no pubspec.yaml

```yaml
dependencies:
  stone_payments: ^1.0.0
```

### 2. Configurar local.properties

Adicione na raiz do projeto Android (`android/local.properties`):

```properties
packageCloudReadToken=SEU_TOKEN_AQUI
```

### 3. Configurar minSdkVersion

No `android/app/build.gradle.kts`, certifique-se de que:

```kotlin
minSdk = 23  // ou maior
```

### 4. Configurar tokens no backend

Os tokens da Stone devem vir do backend (configuração por estabelecimento):

```json
{
  "providerKey": "stone_pos",
  "settings": {
    "appName": "MX Cloud PDV",
    "stoneCode": "12345678",
    "qrCodeProviderId": "PROVIDER_ID",
    "qrCodeAuthentication": "TOKEN"
  }
}
```

## Dispositivos Suportados

- Positivo L400
- Positivo L300
- Ingenico APOS A8
- Sunmi P2
- Gertec GPOS700X

## Uso

### Ativação (feita automaticamente)

O `StonePOSAdapter` ativa automaticamente quando inicializado pela primeira vez.

### Processar Pagamento

```dart
final paymentService = await PaymentService.getInstance();
final result = await paymentService.processPayment(
  providerKey: 'stone_pos',
  amount: 50.00,
  vendaId: 'venda-id',
  additionalData: {
    'tipoTransacao': 'credit', // ou 'debit', 'pix'
    'parcelas': 1,
    'imprimirRecibo': false,
  },
);
```

### Tipos de Transação

- `credit`: Crédito
- `debit`: Débito
- `pix`: PIX

### Impressão

A Stone também oferece impressão através do mesmo SDK. Use `StoneThermalAdapter` para imprimir comandas.

## Descomentando o Código

Quando o SDK estiver instalado:

1. Descomentar imports em:
   - `lib/data/adapters/payment/providers/stone_pos_adapter.dart`
   - `lib/data/adapters/printing/providers/stone_thermal_adapter.dart`

2. Descomentar código marcado com `// Descomentar quando SDK estiver instalado:`

3. Remover código mockado

4. Testar com hardware real

