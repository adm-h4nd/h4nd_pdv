# Build Flavors - MX Cloud PDV

Este projeto suporta múltiplos flavors para diferentes dispositivos e configurações.

## Flavors Disponíveis

### Mobile
- **Application ID**: `com.example.mx_cloud_pdv.mobile`
- **Uso**: Celular/Tablet comum
- **Pagamentos**: Dinheiro, DeepLink (PIX)
- **Impressão**: PDF, Share, Preview

### StoneP2
- **Application ID**: `com.example.mx_cloud_pdv.stone.p2`
- **Uso**: Máquina POS Stone P2
- **Pagamentos**: Dinheiro, Stone POS SDK, DeepLink
- **Impressão**: Impressora térmica Elgin, PDF

## Como Buildar

### Mobile
```bash
flutter build apk --flavor mobile
flutter run --flavor mobile
```

### StoneP2
```bash
flutter build apk --flavor stoneP2
flutter run --flavor stoneP2
```

**Detecção Automática**: O flavor é detectado automaticamente pelo `applicationId` do app:
- `com.example.mx_cloud_pdv.mobile` → `mobile`
- `com.example.mx_cloud_pdv.stone.p2` → `stoneP2`

**Override Manual** (opcional):
```bash
flutter run --flavor stoneP2 --dart-define=FLAVOR=stoneP2
```

## Configurações

As configurações de cada flavor estão em:
- `assets/config/payment_{flavor}.json` - Configurações de pagamento
- `assets/config/print_{flavor}.json` - Configurações de impressão

## Detecção de Flavor

O app detecta automaticamente o flavor tentando carregar os arquivos de configuração. O primeiro arquivo encontrado determina o flavor.

Para forçar um flavor específico, use:
```bash
flutter run --dart-define=FLAVOR=stoneP2
```

