# Instalação e Execução no Windows

## ⚠️ Erro: MSVCP140.dll não foi encontrada

Se você receber o erro **"MSVCP140.dll não foi encontrada"** ao tentar executar o aplicativo, siga os passos abaixo:

### Solução: Instalar Visual C++ Redistributable

O aplicativo Flutter para Windows requer o **Microsoft Visual C++ Redistributable** instalado no sistema.

#### Passo a Passo:

1. **Baixe o Visual C++ Redistributable:**
   - Acesse: https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
   - Procure pela seção **"Visual Studio 2015, 2017, 2019, and 2022"**
   - Baixe o arquivo **vc_redist.x64.exe** (para sistemas 64-bit)
   - Ou **vc_redist.x86.exe** (para sistemas 32-bit)

2. **Instale o pacote:**
   - Execute o arquivo baixado
   - Siga as instruções na tela
   - Aguarde a instalação concluir

3. **Reinicie o computador** (recomendado)

4. **Execute o aplicativo novamente:**
   - O erro não deve mais aparecer

## 📦 Como Executar o Aplicativo

1. **Descompacte o arquivo ZIP** baixado do GitHub Actions
   - Extraia em uma pasta (ex: `C:\mx_cloud_pdv\`)

2. **Importante:** Mantenha todos os arquivos juntos
   - Não mova apenas o arquivo `.exe`
   - Todos os arquivos DLL e a pasta `data/` são necessários

3. **Execute o aplicativo:**
   - Entre na pasta descompactada
   - Dê duplo clique em `mx_cloud_pdv.exe`
   - O aplicativo deve abrir normalmente

## 🔧 Requisitos do Sistema

- **Windows 10** ou superior (64-bit recomendado)
- **Visual C++ Redistributable** (instalado conforme instruções acima)
- Espaço em disco: ~100 MB

## ❓ Problemas Comuns

### Erro: "VCRUNTIME140.dll não foi encontrada"
- **Solução:** Instale o Visual C++ Redistributable (mesmo processo acima)

### Erro: "A aplicação não pode ser iniciada"
- **Solução:** Verifique se todos os arquivos do ZIP foram extraídos corretamente
- Certifique-se de que não está executando apenas o `.exe` isolado

### O aplicativo não abre
- Verifique se o Windows Defender ou antivírus não está bloqueando
- Tente executar como administrador (clique direito → Executar como administrador)

## 📝 Notas

- O aplicativo é **portátil** - não precisa de instalação
- Você pode mover a pasta inteira para qualquer local do Windows
- Não é necessário instalar o Flutter no computador de destino
