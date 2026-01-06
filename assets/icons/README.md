# Ícones do App

## Como Usar

1. Coloque sua imagem original (PNG com fundo transparente) em `original/app-icon.png`
2. A imagem deve ter pelo menos 1024x1024 pixels
3. Execute: `npm install` (primeira vez) e depois `npm run generate-icons`

## Estrutura

```
assets/icons/
└── original/
    └── app-icon.png    # Coloque sua imagem aqui
```

## Requisitos da Imagem

- **Formato**: PNG
- **Fundo**: Transparente
- **Tamanho mínimo**: 1024x1024 pixels
- **Conteúdo**: Ícone centralizado, ocupando ~80% do espaço (deixar margem para safe zone)

## Remover Fundo

Se sua imagem tem fundo, use:
- https://www.remove.bg/ (online)
- GIMP, Photoshop, ou outras ferramentas

