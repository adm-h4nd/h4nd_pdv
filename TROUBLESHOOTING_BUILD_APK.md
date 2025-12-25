# Troubleshooting: Erro ao fazer flutter build apk

## Problema Corrigido
O erro estava relacionado ao uso de `dart:io` com `Platform.isWindows`, que não funciona em todas as plataformas durante o build de release.

**Solução aplicada:** Substituído por `defaultTargetPlatform` que funciona em todas as plataformas.

## Como testar agora

### 1. Limpar build anterior
```bash
flutter clean
flutter pub get
```

### 2. Testar build APK
```bash
# Build debug (mais rápido para testar)
flutter build apk --debug

# Build release (produção)
flutter build apk --release
```

### 3. Se ainda der erro, verificar logs completos
```bash
flutter build apk --release --verbose 2>&1 | tee build_log.txt
```

## Problemas comuns e soluções

### Erro: "dart:io not available"
**Causa:** Uso de `dart:io` em código que precisa funcionar em todas as plataformas
**Solução:** Usar `defaultTargetPlatform` do Flutter em vez de `Platform`

### Erro: "R8/ProGuard"
**Causa:** Minificação/obfuscação removendo código necessário
**Solução:** Verificar `android/app/proguard-rules.pro` e adicionar regras se necessário

### Erro: "Native dependencies"
**Causa:** Dependências nativas não compiladas
**Solução:** 
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

### Erro: "Out of memory"
**Causa:** Build precisa de mais memória
**Solução:** Aumentar memória do Gradle em `android/gradle.properties`:
```
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=512m
```

## Verificar se o código está correto

O arquivo `home_navigation.dart` agora deve usar:
```dart
final isDesktop = kIsWeb || 
                  (defaultTargetPlatform == TargetPlatform.windows ||
                   defaultTargetPlatform == TargetPlatform.linux ||
                   defaultTargetPlatform == TargetPlatform.macOS);
```

**NÃO deve ter:** `import 'dart:io'` ou `Platform.isWindows`

## Próximos passos

1. Execute `flutter clean`
2. Execute `flutter pub get`
3. Tente `flutter build apk --debug` primeiro
4. Se funcionar, tente `flutter build apk --release`
5. Se ainda der erro, envie a mensagem de erro completa

