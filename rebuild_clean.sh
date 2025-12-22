#!/bin/bash

# Script para limpar completamente e reconstruir o projeto Flutter

echo "🧹 Limpando projeto Flutter..."

# Remove diretórios de build
rm -rf build/
rm -rf android/.gradle/
rm -rf android/app/build/
rm -rf .dart_tool/

# Limpa o projeto Flutter
flutter clean

# Obtém dependências
flutter pub get

echo "✅ Limpeza concluída!"
echo ""
echo "Agora você pode executar:"
echo "  flutter run -d RXCXB03AYRE"
