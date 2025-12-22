# Build para Windows - MX Cloud PDV

## 📋 Pré-requisitos

Para fazer build do Flutter para Windows, você precisa:

1. **Máquina Windows** com:
   - Windows 10 ou superior
   - Visual Studio 2022 (com componentes "Desktop development with C++")
   - Flutter SDK instalado
   - Git instalado

2. **OU usar CI/CD** (GitHub Actions) - veja seção abaixo

## 🚀 Build Local (em máquina Windows)

### 1. Habilitar suporte Windows desktop

```bash
flutter config --enable-windows-desktop
```

### 2. Criar/atualizar pasta windows (se necessário)

```bash
flutter create --platforms=windows .
```

### 3. Verificar dependências

```bash
flutter doctor
```

Certifique-se de que:
- ✅ Flutter SDK está instalado
- ✅ Windows toolchain está disponível
- ✅ Visual Studio está configurado

### 4. Build em modo Debug

```bash
flutter build windows --debug
```

O executável estará em: `build/windows/x64/runner/Debug/mx_cloud_pdv.exe`

### 5. Build em modo Release

```bash
flutter build windows --release
```

O executável estará em: `build/windows/x64/runner/Release/mx_cloud_pdv.exe`

### 6. Build com flavor específico

```bash
# Flavor mobile
flutter build windows --release --dart-define=FLAVOR=mobile

# Flavor stoneP2
flutter build windows --release --dart-define=FLAVOR=stoneP2
```

**Nota**: No Windows, os flavors são passados via `--dart-define=FLAVOR=...` em vez de `--flavor`, que é específico do Android.

## 📦 Distribuição

Após o build, você terá uma pasta `build/windows/x64/runner/Release/` contendo:
- `mx_cloud_pdv.exe` - Executável principal
- Arquivos DLL necessários
- Pasta `data/` com assets do Flutter

Para distribuir, você pode:
1. **Zippar toda a pasta** `Release/` e distribuir
2. **Criar um instalador** usando ferramentas como Inno Setup ou NSIS

## 🔄 Build via GitHub Actions (CI/CD)

Se você não tem acesso a uma máquina Windows, pode usar GitHub Actions para fazer o build automaticamente.

Veja o arquivo `.github/workflows/build-windows.yml` para o workflow configurado.

### Como usar:

1. Faça push para o repositório
2. O GitHub Actions compilará automaticamente
3. Baixe o artefato do build na aba "Actions"

## ⚠️ Observações Importantes

1. **SDK Stone**: O SDK Stone (`stone_payments`) pode não funcionar no Windows, pois é específico para Android. O flavor mobile deve funcionar normalmente.

2. **Dependências nativas**: Algumas dependências podem não ter suporte Windows. Verifique os pacotes usados:
   - `flutter_secure_storage` - ✅ Suporta Windows
   - `hive` - ✅ Suporta Windows
   - `path_provider` - ✅ Suporta Windows
   - `stone_payments` - ❌ Apenas Android

3. **Configuração de flavors**: Os flavors (mobile/stoneP2) funcionam no Windows, mas o SDK Stone não estará disponível.

## 🛠️ Troubleshooting

### Erro: "Windows toolchain not found"
```bash
# Instalar Visual Studio 2022 com componentes C++
# Ou usar: flutter doctor --android-licenses
```

### Erro: "CMake not found"
```bash
# Instalar CMake: https://cmake.org/download/
# Adicionar ao PATH do sistema
```

### Erro relacionado a dependências nativas
- Verifique se todas as dependências suportam Windows
- Remova ou condicione dependências específicas de plataforma

