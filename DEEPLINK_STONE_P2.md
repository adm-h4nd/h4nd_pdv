# Integração DeepLink Stone P2

## Padrões encontrados no projeto `app_restaurante_kotlin`

Este documento descreve os padrões de comunicação via DeepLink usados na máquina Stone P2, baseados no projeto Kotlin existente.

## 1. Pagamento via DeepLink

### Esquema de requisição
```
payment-app://pay?return_scheme=deeplinkmxcloudpdv://pay-response&amount=10000&editable_amount=1&order_id=123
```

### Parâmetros
- `return_scheme`: Esquema de retorno (ex: `deeplinkmxcloudpdv://pay-response`)
- `amount`: Valor em centavos (ex: `10000` para R$ 100,00)
- `editable_amount`: `"1"` para permitir editar valor, `"0"` para não permitir
- `order_id`: ID do pedido/venda

### Resposta via DeepLink
```
deeplinkmxcloudpdv://pay-response?code=0&amount=10000&type=credit&brand=visa&installment_count=1&order_id=123
```

### Códigos de resposta
- `code=0`: Pagamento aprovado ✅
- `code=-2`: Pagamento não concluído ⚠️
- `code=-6`: Pagamento negado ❌
- Outros códigos: Pagamento não realizado

### Parâmetros da resposta
- `amount`: Valor pago em centavos
- `type`: Tipo de pagamento (`credit`, `debit`, `pix`, etc.)
- `brand`: Bandeira do cartão (`visa`, `mastercard`, etc.)
- `installment_count`: Número de parcelas (0 = à vista)
- `order_id`: ID do pedido original

## 2. Impressão via DeepLink

### Esquema de requisição
```
printer-app://print?SHOW_FEEDBACK_SCREEN=true&SCHEME_RETURN=deeplinkprinter&PRINTABLE_CONTENT=[...]
```

### Parâmetros
- `SHOW_FEEDBACK_SCREEN`: `"true"` para mostrar tela de feedback
- `SCHEME_RETURN`: Esquema de retorno (ex: `deeplinkprinter`)
- `PRINTABLE_CONTENT`: JSON array com conteúdo a imprimir

### Formato do PRINTABLE_CONTENT
```json
[
  {
    "type": "text",
    "content": "Texto a imprimir",
    "align": "center|left|right",
    "size": "big|medium|small"
  },
  {
    "type": "line",
    "content": "________________________________"
  },
  {
    "type": "image",
    "imagePath": "base64_encoded_image"
  }
]
```

### Tipos de conteúdo
- `text`: Texto formatado
  - `align`: Alinhamento (`center`, `left`, `right`)
  - `size`: Tamanho (`big`, `medium`, `small`)
- `line`: Linha separadora
- `image`: Imagem em base64

## 3. Configuração AndroidManifest.xml

### Intent Filter para pagamento
```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:host="pay-response"
            android:scheme="deeplinkmxcloudpdv" />
    </intent-filter>
</activity>
```

### Intent Filter para impressão
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:host="print"
        android:scheme="deeplinkprinter" />
</intent-filter>
```

## 4. Implementação Flutter

### Tratamento de DeepLink
```dart
import 'package:flutter/material.dart';
import 'dart:async';

class DeepLinkHandler {
  static StreamSubscription? _linkSubscription;
  
  static void initialize(BuildContext context) {
    // Usar uni_links ou flutter_deep_linking
    // Escutar deeplinks e processar respostas
  }
  
  static void handlePaymentResponse(Uri uri) {
    final code = uri.queryParameters['code'];
    final amount = uri.queryParameters['amount'];
    final type = uri.queryParameters['type'];
    final brand = uri.queryParameters['brand'];
    final installmentCount = uri.queryParameters['installment_count'];
    final orderId = uri.queryParameters['order_id'];
    
    if (code == '0') {
      // Pagamento aprovado
      final valor = (int.parse(amount ?? '0') / 100);
      // Processar pagamento...
    }
  }
}
```

## 5. Exemplo de uso

### Pagamento
```dart
final adapter = DeepLinkPaymentAdapter();
final result = await adapter.processPayment(
  amount: 50.00,
  vendaId: 'venda-123',
  additionalData: {},
);
```

### Impressão
```dart
final adapter = DeepLinkPrintAdapter();
final result = await adapter.printComanda(
  data: printData,
);
```

## 6. Notas importantes

1. **Valor em centavos**: Sempre converter valores para centavos ao enviar
2. **URL Encoding**: Usar `URLDecoder` ao receber respostas
3. **SingleTop**: Usar `launchMode="singleTop"` para evitar múltiplas instâncias
4. **onNewIntent**: Implementar `onNewIntent` no Android para receber deeplinks quando app já está aberto

## 7. Referências

- Projeto Kotlin: `/Users/claudiocamargos/Documents/GitHub/MX/app_restaurante_kotlin`
- Arquivo principal: `PagamentoVendaActivity.kt`
- Arquivo impressão: `TableProductsActivity.kt`

