#!/bin/bash
echo "🧹 Limpando build completo..."

# Limpa Flutter
echo "1. Limpando Flutter..."
flutter clean

# Limpa Gradle
echo "2. Limpando Gradle..."
cd android
./gradlew clean
cd ..

# Remove pastas de build
echo "3. Removendo pastas de build..."
rm -rf build/
rm -rf android/app/build/
rm -rf android/.gradle/

# Limpa pub cache (opcional, mais agressivo)
echo "4. Limpando pub cache..."
flutter pub cache repair

# Reinstala dependências
echo "5. Reinstalando dependências..."
flutter pub get

echo "✅ Limpeza completa! Agora você pode fazer: flutter build apk"
