/**
 * Script para gerar ícones do app Flutter (Android e iOS)
 * 
 * Pré-requisitos:
 * npm install --save-dev sharp
 * 
 * Uso:
 * node scripts/generate-app-icons.js [caminho-da-imagem]
 * 
 * Exemplo:
 * node scripts/generate-app-icons.js assets/icons/original/app-icon.png
 */

const fs = require('fs');
const path = require('path');

// Verificar se sharp está instalado
let sharp;
try {
  sharp = require('sharp');
} catch (e) {
  console.error('❌ Erro: sharp não está instalado.');
  console.log('📦 Instale com: npm install --save-dev sharp');
  process.exit(1);
}

// Obter caminho da imagem
const imagePath = process.argv[2] || 'assets/icons/original/app-icon.png';
const fullImagePath = path.resolve(imagePath);

// Verificar se a imagem existe
if (!fs.existsSync(fullImagePath)) {
  console.error(`❌ Erro: Imagem não encontrada em: ${fullImagePath}`);
  console.log('💡 Coloque sua imagem em assets/icons/original/app-icon.png ou forneça o caminho como argumento');
  process.exit(1);
}

// Tamanhos para Android (mipmap)
const androidSizes = [
  { size: 48, folder: 'mipmap-mdpi', name: 'ic_launcher.png' },      // 1x
  { size: 72, folder: 'mipmap-hdpi', name: 'ic_launcher.png' },      // 1.5x
  { size: 96, folder: 'mipmap-xhdpi', name: 'ic_launcher.png' },     // 2x
  { size: 144, folder: 'mipmap-xxhdpi', name: 'ic_launcher.png' },   // 3x
  { size: 192, folder: 'mipmap-xxxhdpi', name: 'ic_launcher.png' }  // 4x
];

// Tamanhos para Android Adaptive Icon (foreground)
// O foreground deve ter 108dp (432px para xxxhdpi) mas o conteúdo deve estar centralizado em 72dp (288px)
const androidForegroundSizes = [
  { size: 108, folder: 'mipmap-mdpi', name: 'ic_launcher_foreground.png' },
  { size: 162, folder: 'mipmap-hdpi', name: 'ic_launcher_foreground.png' },
  { size: 216, folder: 'mipmap-xhdpi', name: 'ic_launcher_foreground.png' },
  { size: 324, folder: 'mipmap-xxhdpi', name: 'ic_launcher_foreground.png' },
  { size: 432, folder: 'mipmap-xxxhdpi', name: 'ic_launcher_foreground.png' }
];

// Tamanhos para iOS
const iosSizes = [
  { size: 20, scale: 1, name: 'Icon-App-20x20@1x.png' },
  { size: 20, scale: 2, name: 'Icon-App-20x20@2x.png' },
  { size: 20, scale: 3, name: 'Icon-App-20x20@3x.png' },
  { size: 29, scale: 1, name: 'Icon-App-29x29@1x.png' },
  { size: 29, scale: 2, name: 'Icon-App-29x29@2x.png' },
  { size: 29, scale: 3, name: 'Icon-App-29x29@3x.png' },
  { size: 40, scale: 1, name: 'Icon-App-40x40@1x.png' },
  { size: 40, scale: 2, name: 'Icon-App-40x40@2x.png' },
  { size: 40, scale: 3, name: 'Icon-App-40x40@3x.png' },
  { size: 60, scale: 2, name: 'Icon-App-60x60@2x.png' },
  { size: 60, scale: 3, name: 'Icon-App-60x60@3x.png' },
  { size: 76, scale: 1, name: 'Icon-App-76x76@1x.png' },
  { size: 76, scale: 2, name: 'Icon-App-76x76@2x.png' },
  { size: 83.5, scale: 2, name: 'Icon-App-83.5x83.5@2x.png' },
  { size: 1024, scale: 1, name: 'Icon-App-1024x1024@1x.png' }
];

// Tamanhos para Web (PWA)
const webSizes = [
  { size: 192, name: 'Icon-192.png' },
  { size: 512, name: 'Icon-512.png' },
  { size: 192, name: 'Icon-maskable-192.png', maskable: true },
  { size: 512, name: 'Icon-maskable-512.png', maskable: true }
];

// Tamanhos para Windows (.ico precisa de múltiplos tamanhos)
const windowsSizes = [16, 32, 48, 64, 128, 256];

// Diretórios
const androidResDir = path.resolve('android/app/src/main/res');
const iosAssetsDir = path.resolve('android/ios/Runner/Assets.xcassets/AppIcon.appiconset');
const webIconsDir = path.resolve('web/icons');
const windowsIconPath = path.resolve('android/windows/runner/resources/app_icon.ico');

async function generateIcons() {
  console.log(`\n🎨 Gerando ícones do app Flutter a partir de: ${fullImagePath}\n`);

  // Gerar ícones Android (mipmap)
  console.log('📱 Gerando ícones Android (mipmap)...');
  for (const { size, folder, name } of androidSizes) {
    const outputDir = path.join(androidResDir, folder);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    const outputPath = path.join(outputDir, name);
    await sharp(fullImagePath)
      .resize(size, size, {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 0 }
      })
      .png()
      .toFile(outputPath);
    console.log(`  ✅ ${folder}/${name} (${size}x${size})`);
  }

  // Gerar foreground para Adaptive Icon Android
  console.log('\n📱 Gerando foreground para Adaptive Icon Android...');
  for (const { size, folder, name } of androidForegroundSizes) {
    const outputDir = path.join(androidResDir, folder);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    const outputPath = path.join(outputDir, name);
    // O foreground deve ter o ícone centralizado, ocupando ~66% do espaço (safe zone)
    const iconSize = Math.round(size * 0.67);
    const padding = Math.round((size - iconSize) / 2);
    
    await sharp(fullImagePath)
      .resize(iconSize, iconSize, {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 0 }
      })
      .extend({
        top: padding,
        bottom: padding,
        left: padding,
        right: padding,
        background: { r: 0, g: 0, b: 0, alpha: 0 }
      })
      .png()
      .toFile(outputPath);
    console.log(`  ✅ ${folder}/${name} (${size}x${size}, ícone ${iconSize}x${iconSize})`);
  }

  // Gerar ícones iOS
  console.log('\n🍎 Gerando ícones iOS...');
  if (!fs.existsSync(iosAssetsDir)) {
    fs.mkdirSync(iosAssetsDir, { recursive: true });
  }
  
  for (const { size, scale, name } of iosSizes) {
    const actualSize = Math.round(size * scale);
    const outputPath = path.join(iosAssetsDir, name);
    await sharp(fullImagePath)
      .resize(actualSize, actualSize, {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 0 }
      })
      .png()
      .toFile(outputPath);
    console.log(`  ✅ ${name} (${actualSize}x${actualSize})`);
  }

  // Gerar ícones Web (PWA)
  console.log('\n🌐 Gerando ícones Web (PWA)...');
  if (!fs.existsSync(webIconsDir)) {
    fs.mkdirSync(webIconsDir, { recursive: true });
  }
  
  for (const { size, name, maskable } of webSizes) {
    const outputPath = path.join(webIconsDir, name);
    // Para maskable, adicionar padding para safe zone
    if (maskable) {
      const iconSize = Math.round(size * 0.8); // 80% do tamanho (safe zone)
      const padding = Math.round((size - iconSize) / 2);
      await sharp(fullImagePath)
        .resize(iconSize, iconSize, {
          fit: 'contain',
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .extend({
          top: padding,
          bottom: padding,
          left: padding,
          right: padding,
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .png()
        .toFile(outputPath);
    } else {
      await sharp(fullImagePath)
        .resize(size, size, {
          fit: 'contain',
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .png()
        .toFile(outputPath);
    }
    console.log(`  ✅ ${name} (${size}x${size}${maskable ? ' - maskable' : ''})`);
  }

  // Gerar favicon.png (32x32 é o tamanho padrão para favicon)
  console.log('\n🌐 Gerando favicon.png...');
  const faviconPath = path.resolve('web/favicon.png');
  await sharp(fullImagePath)
    .resize(32, 32, {
      fit: 'contain',
      background: { r: 0, g: 0, b: 0, alpha: 0 }
    })
    .png()
    .toFile(faviconPath);
  console.log(`  ✅ favicon.png (32x32)`);

  // Gerar ícone Windows (.ico)
  console.log('\n🪟 Gerando ícone Windows (.ico)...');
  const windowsIconDir = path.dirname(windowsIconPath);
  if (!fs.existsSync(windowsIconDir)) {
    fs.mkdirSync(windowsIconDir, { recursive: true });
  }
  
  try {
    const toIco = require('to-ico');
    const icoBuffers = [];
    
    // Criar múltiplos tamanhos para o .ico
    for (const size of windowsSizes) {
      const buffer = await sharp(fullImagePath)
        .resize(size, size, {
          fit: 'contain',
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .png()
        .toBuffer();
      icoBuffers.push(buffer);
    }
    
    // Converter para .ico
    const icoBuffer = await toIco(icoBuffers);
    fs.writeFileSync(windowsIconPath, icoBuffer);
    console.log(`  ✅ app_icon.ico gerado com tamanhos: ${windowsSizes.join(', ')}px`);
  } catch (error) {
    console.log(`  ⚠️  Erro ao gerar .ico: ${error.message}`);
    console.log(`  💡 Instale to-ico: npm install --save-dev to-ico`);
    console.log(`  💡 Ou use uma ferramenta online: https://convertio.co/png-ico/`);
    
    // Criar PNG temporário como fallback
    const largestSize = Math.max(...windowsSizes);
    const tempPngPath = windowsIconPath.replace('.ico', '_temp.png');
    await sharp(fullImagePath)
      .resize(largestSize, largestSize, {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 0 }
      })
      .png()
      .toFile(tempPngPath);
    console.log(`  📄 PNG temporário criado: ${tempPngPath}`);
  }

  console.log('\n✨ Ícones gerados com sucesso!');
  console.log(`📂 Android: ${androidResDir}`);
  console.log(`📂 iOS: ${iosAssetsDir}`);
  console.log(`📂 Web: ${webIconsDir}`);
  console.log(`📂 Windows: ${windowsIconPath} (precisa converter PNG para ICO)`);
  console.log('\n💡 Próximos passos:');
  console.log('   1. Verifique se os ícones estão corretos');
  console.log('   2. Converta o PNG do Windows para .ico (veja instruções acima)');
  console.log('   3. Execute: flutter clean && flutter pub get');
  console.log('   4. Reconstrua o app: flutter build apk/web/windows');
}

generateIcons().catch(err => {
  console.error('❌ Erro ao gerar ícones:', err);
  process.exit(1);
});

