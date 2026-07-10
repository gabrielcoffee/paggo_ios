# Fontes — Paggo iOS

## Estado atual

| Papel | Fonte | Onde |
|-------|-------|------|
| Corpo (texto geral) | **ABC Camera Plain** (instâncias estáticas 400/500/600/700) | `Font.brand(...)` → `brandName` em `DesignSystem/Typography.swift` |
| Títulos da nav bar (Visão Geral, Pagamentos, Detalhes…) | **Serifa do sistema (New York)** | `titleFont(size:)` em `App/PaggoApp.swift` (UINavigationBarAppearance) |

Os títulos usam a serifa do sistema por escolha de design (o `herbikSerif` do web é um *trial não
licenciado* — evitado de propósito).

## ABC Camera Plain — pesos

A fonte de origem é **variável** (`ABC Camera Plain Variable`, eixo `wght` 400–900). Ela foi
**instanciada** em 4 pesos estáticos `.ttf` (mais confiável no iOS que ajustar o eixo em runtime),
em `Paggo/Resources/Fonts/`, registrados em `Info.plist > UIAppFonts`:

| Font.Weight | Arquivo / PostScript name | wght |
|-------------|---------------------------|------|
| `.light` / `.regular` (e mais finos) | `ABCCameraPlain-Regular` | 400 (piso do eixo — não há mais fino) |
| `.medium` | `ABCCameraPlain-Medium` | 500 |
| `.semibold` | `ABCCameraPlain-SemiBold` | 600 |
| `.bold` / `.heavy` / `.black` | `ABCCameraPlain-Bold` | 700 |

Cobertura de glifos pt-BR (ç ã õ á é í …) verificada — completa.

### Regenerar as instâncias (se precisar de outros pesos)

```bash
pip install fonttools brotli
python3 - <<'PY'
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
src="ABC Camera Plain Variable .woff2 (ou .ttf)"
f=TTFont(src); instantiateVariableFont(f, {"wght": 600, "slnt": 0}, inplace=True)
# ajustar name table (IDs 1/2/4/6/16/17) + OS/2.usWeightClass, f.flavor=None, f.save(...)
PY
```

⚠️ **Licença**: ABC Camera Plain é fonte comercial (ABC Dinamo). Confirme que a licença cobre
*app embedding* (bundle), não só uso web.
