# Converter PNG para ICO (Windows)

O script gerou um PNG temporário que precisa ser convertido para .ico.

## Opção 1: Online (Mais Fácil)

1. Acesse: https://convertio.co/png-ico/
2. Faça upload do arquivo: `android/windows/runner/resources/app_icon_temp.png`
3. Baixe o arquivo convertido
4. Renomeie para `app_icon.ico`
5. Coloque em: `android/windows/runner/resources/app_icon.ico`

## Opção 2: ImageMagick (Linha de Comando)

Se você tem ImageMagick instalado:

```bash
cd android/windows/runner/resources
convert app_icon_temp.png -define icon:auto-resize=256,128,64,48,32,16 app_icon.ico
rm app_icon_temp.png
```

## Opção 3: Instalar to-ico (Node.js)

```bash
npm install --save-dev to-ico
npm run generate-icons
```

## Opção 4: Usar GIMP ou Photoshop

1. Abra o PNG no GIMP/Photoshop
2. Exporte como .ico
3. Salve como `app_icon.ico` em `android/windows/runner/resources/`

