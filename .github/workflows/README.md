# GitHub Actions - Build Windows

## 🚀 Como usar

### Execução Automática
O workflow executa automaticamente quando:
- Você faz push para as branches `main` ou `develop`
- Você cria uma tag começando com `v` (ex: `v1.0.0`)
- Você abre um Pull Request para `main` ou `develop`

### Execução Manual
1. Vá para a aba **Actions** no GitHub
2. Selecione o workflow **Build Windows**
3. Clique em **Run workflow**
4. Escolha o flavor (`mobile` ou `stoneP2`) - padrão é `mobile`
5. Clique em **Run workflow**

## 📦 Baixar o Build

### Passo a Passo Detalhado:

1. **Acesse o GitHub** e vá para o seu repositório
2. **Clique na aba "Actions"** (no topo do repositório, ao lado de "Code", "Issues", etc.)
3. **Encontre a execução do workflow "Build Windows"** (deve estar na lista de workflows executados)
4. **Clique na execução** que você quer baixar (geralmente a mais recente, com um ✅ verde se foi bem-sucedida)
5. **Role a página para baixo** até encontrar a seção **"Artifacts"** (fica no final da página, após todos os steps)
6. **Clique no artefato** `windows-build-mobile` (ou `windows-build-stoneP2` se você escolheu esse flavor)
7. **O download começará automaticamente** - você receberá um arquivo ZIP

### O que vem no ZIP:

O arquivo ZIP contém:
- `mx_cloud_pdv.exe` - Executável principal
- Arquivos DLL necessários (flutter_windows.dll, etc.)
- Pasta `data/` com assets do Flutter
- Outros arquivos de suporte

### Como executar no Windows:

1. **Descompacte o ZIP** em uma pasta (ex: `C:\mx_cloud_pdv\`)
2. **Entre na pasta descompactada**
3. **Execute o arquivo `mx_cloud_pdv.exe`** (duplo clique)
4. Pronto! O aplicativo deve abrir

### ⚠️ Importante:

- **Não mova apenas o .exe** - você precisa de todos os arquivos da pasta
- Mantenha a estrutura de pastas como está no ZIP
- O executável precisa estar junto com as DLLs e a pasta `data/`
- Os artefatos ficam disponíveis por **30 dias** após a execução do workflow

## ⚠️ Troubleshooting

### O workflow não está executando

**Problema**: O workflow não aparece na aba Actions
- ✅ Verifique se o arquivo está em `.github/workflows/build-windows.yml`
- ✅ Verifique se você fez commit e push do arquivo
- ✅ Verifique se há erros de sintaxe YAML

**Problema**: O workflow falha no checkout
- ✅ Verifique se o repositório está público ou se você tem permissões adequadas

**Problema**: Erro "Windows toolchain not found"
- ✅ O GitHub Actions já tem o Visual Studio instalado, mas pode precisar de configuração adicional
- ✅ O workflow já executa `flutter config --enable-windows-desktop`

**Problema**: Erro relacionado a flavors
- ✅ Verifique se os flavors estão configurados corretamente no projeto
- ✅ O flavor padrão é `mobile` se nenhum for especificado
- ✅ Use `mobile` ou `stoneP2` (não `stone_p2`)

**Problema**: Erro ao criar ZIP
- ✅ Verifique se o build foi concluído com sucesso
- ✅ Verifique os logs do step "Build Windows (Release)"

**Problema**: Não consigo encontrar os Artifacts
- ✅ Certifique-se de que o workflow foi executado até o final com sucesso (✅ verde)
- ✅ Os artifacts só aparecem após a conclusão bem-sucedida do workflow
- ✅ Role até o final da página de execução do workflow

### Verificar logs
1. Vá para **Actions** → Selecione a execução → Clique no job **Build Windows App**
2. Expanda cada step para ver os logs detalhados
3. Procure por erros em vermelho

## 🔧 Configuração de Flavors

Certifique-se de que os flavors estão configurados no projeto:
- `mobile`: Versão sem SDK Stone (padrão)
- `stoneP2`: Versão com SDK Stone (pode não funcionar no Windows)

## 📝 Notas Importantes

- O build é feito em modo **Release**
- O executável estará em `build/windows/x64/runner/Release/`
- O ZIP contém todos os arquivos necessários para distribuição
- Os artefatos ficam disponíveis por 30 dias
