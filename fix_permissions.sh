#!/bin/bash

# Script para corrigir permissões do projeto Flutter
# Execute: bash fix_permissions.sh

echo "🔧 Corrigindo permissões do projeto Flutter..."

# Obtém o usuário atual
USER=$(whoami)

# Remove diretórios de build com sudo
echo "📦 Removendo diretórios de build..."
sudo rm -rf build/ android/.gradle/ android/app/build/ .dart_tool/

# Limpa o projeto Flutter
echo "🧹 Limpando projeto Flutter..."
flutter clean

# Garante que o diretório do projeto pertence ao usuário
echo "🔐 Corrigindo propriedade dos arquivos..."
sudo chown -R $USER:$USER .

# Garante permissões de escrita
echo "✍️  Ajustando permissões..."
chmod -R u+w .

echo "✅ Permissões corrigidas!"
echo ""
echo "Agora você pode executar sem sudo:"
echo "  flutter run -d RXCXB03AYRE"
