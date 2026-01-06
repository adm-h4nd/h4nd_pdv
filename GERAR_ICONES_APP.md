# Guia para Gerar Ícones do App Flutter

## Pré-requisitos

Você precisa ter instalado:
- Node.js e npm
- Sharp (biblioteca de processamento de imagens)

## Passos

### 1. Instalar dependências

```bash
npm install --save-dev sharp
```

### 2. Preparar a imagem original

1. Coloque sua imagem original (PNG) em: `assets/icons/original/app-icon.png`
2. A imagem deve ter pelo menos 1024x1024 pixels
3. **IMPORTANTE**: A imagem deve ter fundo transparente (PNG)
4. O ícone deve estar centralizado e ocupar aproximadamente 80% do espaço (deixar margem para safe zone)

### 3. Remover o fundo (se necessário)

Se sua imagem tem fundo, você pode usar:
- **Online**: https://www.remove.bg/
- **Ferramentas**: GIMP, Photoshop, ou outras ferramentas de edição

### 4. Gerar todos os ícones

Execute o script:

```bash
npm run generate-icons
```

Ou diretamente:

```bash
node scripts/generate-app-icons.js assets/icons/original/app-icon.png
```

### 5. Verificar os ícones gerados

O script gera:

#### Android
- **mipmap-mdpi/ic_launcher.png** (48x48)
- **mipmap-hdpi/ic_launcher.png** (72x72)
- **mipmap-xhdpi/ic_launcher.png** (96x96)
- **mipmap-xxhdpi/ic_launcher.png** (144x144)
- **mipmap-xxxhdpi/ic_launcher.png** (192x192)
- **Foreground para Adaptive Icon** (em cada pasta mipmap)

#### iOS
- Todos os tamanhos necessários em `android/ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### 6. Atualizar o Adaptive Icon (Android)

O Android usa Adaptive Icons que combinam:
- **Background**: Gradiente ou cor sólida (definido em `ic_launcher_background.xml`)
- **Foreground**: Seu ícone (gerado automaticamente)

Se quiser personalizar o background, edite:
- `android/app/src/main/res/drawable/ic_launcher_background.xml`

### 7. Limpar e reconstruir

```bash
flutter clean
flutter pub get
```

### 8. Testar

```bash
# Android
flutter run

# iOS (se tiver Mac)
flutter run -d ios
```

## Estrutura de Pastas

```
h4nd-pdv/
├── assets/
│   └── icons/
│       └── original/
│           └── app-icon.png    # Sua imagem original aqui
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── res/
│                   ├── mipmap-mdpi/
│                   ├── mipmap-hdpi/
│                   ├── mipmap-xhdpi/
│                   ├── mipmap-xxhdpi/
│                   └── mipmap-xxxhdpi/
└── android/
    └── ios/
        └── Runner/
            └── Assets.xcassets/
                └── AppIcon.appiconset/
```

## Tamanhos Gerados

### Android
- **mdpi**: 48x48 (1x)
- **hdpi**: 72x72 (1.5x)
- **xhdpi**: 96x96 (2x)
- **xxhdpi**: 144x144 (3x)
- **xxxhdpi**: 192x192 (4x)
- **Foreground**: 108dp a 432dp (com safe zone)

### iOS
- 20x20 (@1x, @2x, @3x) - Notificações
- 29x29 (@1x, @2x, @3x) - Settings
- 40x40 (@1x, @2x, @3x) - Spotlight
- 60x60 (@2x, @3x) - App Icon
- 76x76 (@1x, @2x) - iPad
- 83.5x83.5 (@2x) - iPad Pro
- 1024x1024 (@1x) - App Store

## Dicas

1. **Safe Zone**: Deixe margem de ~20% ao redor do ícone para evitar que seja cortado em diferentes dispositivos
2. **Cores**: Use cores vibrantes que funcionem bem em diferentes fundos
3. **Formato**: Sempre use PNG com fundo transparente
4. **Tamanho Original**: Use pelo menos 1024x1024 pixels para garantir qualidade

## Troubleshooting

### Erro: "sharp não está instalado"
```bash
npm install --save-dev sharp
```

### Ícones não aparecem após gerar
```bash
flutter clean
flutter pub get
```

### Ícone cortado no Android
- Verifique se o ícone está centralizado na imagem original
- Ajuste o `ic_launcher_foreground.xml` se necessário

