# Script para remover o plugin stone_payments do registro no Windows
# Este script remove o plugin stone_payments do arquivo generated_plugin_registrant.cc
# porque o plugin não tem suporte Windows e causa erro de DLL

param(
    [string]$BuildType = "Release"
)

$pluginFile = "build\windows\flutter\generated_plugin_registrant.cc"

if (-not (Test-Path $pluginFile)) {
    Write-Host "❌ Arquivo não encontrado: $pluginFile"
    Write-Host "   Execute 'flutter build windows' primeiro"
    exit 1
}

Write-Host "🔧 Removendo plugin stone_payments do registro..."

# Cria backup
$backupFile = "$pluginFile.bak"
Copy-Item $pluginFile $backupFile
Write-Host "   Backup criado: $backupFile"

# Lê o conteúdo do arquivo
$content = Get-Content $pluginFile -Raw

# Remove includes do stone_payments
$content = $content -replace '#include <stone_payments/stone_payments_plugin\.h>', '// #include <stone_payments/stone_payments_plugin.h> // Removido: não suporta Windows'

# Remove registro do plugin (linha completa - pode estar em múltiplas linhas)
$content = $content -replace 'stone_payments::StonePaymentsPluginRegisterWithRegistrar\([^)]*\);', '// stone_payments plugin removido (não suporta Windows)'

# Remove linhas vazias duplicadas
$content = $content -replace "(\r?\n\s*){3,}", "`r`n`r`n"

# Salva o arquivo modificado
Set-Content -Path $pluginFile -Value $content -NoNewline

Write-Host "✅ Plugin stone_payments removido do registro"
Write-Host "   Arquivo modificado: $pluginFile"
Write-Host "   Backup salvo em: $backupFile"

# Tenta recompilar apenas o executável
Write-Host "🔨 Tentando recompilar executável..."
$cmakeBuildDir = "build\windows"
if (Test-Path "$cmakeBuildDir\CMakeCache.txt") {
    cd $cmakeBuildDir
    cmake --build . --config $BuildType
    cd ..\..
    Write-Host "✅ Executável recompilado sem o plugin stone_payments"
} else {
    Write-Host "⚠️ CMakeCache.txt não encontrado"
    Write-Host "   Execute 'flutter build windows' novamente para recompilar"
}

