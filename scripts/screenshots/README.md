# Screenshots de App Store

Pipeline en dos pasos: **capturar** del simulador → **componer** con la identidad de marca.

```
store/raw/<locale>/NN-slug.png     capturas crudas del simulador (1320×2868)
        ↓  python3 scripts/screenshots/compose.py
store/ready/<locale>/NN-slug.png   listas para subir a App Store Connect
```

## Por qué existe este script

El set publicado (18 imágenes, mayo 2026) se armó a mano con el **logo anterior** — verde
neón con biseles 3D. La identidad vigente es *Midnight Sage*: sage plano sobre casi negro,
la que usan la app, la web y los mails desde el 2026-08-04. Rehacer 18 composiciones a mano
cada vez que cambia una pantalla es exactamente lo que hizo que el set quedara viejo sin que
nadie se enterara. Ahora es un comando.

Los colores salen de `metacasa-ios/MetaCasa/Core/DesignSystem.swift` y el ícono de
`AppIcon.appiconset/Icon-1024.png`, que es la fuente de verdad de la marca. El copy sale de
`APP_STORE_COPY.md` § 6 — si cambia allá, cambialo acá.

## Las 6 pantallas

El orden es el de `APP_STORE_COPY.md` y está pensado para conversión, no por comodidad de
captura: la primera imagen es el 70% de la decisión.

| # | slug | Pantalla |
|---|---|---|
| 1 | `01-home` | Home con saldo grande + salud financiera |
| 2 | `02-ai` | Asistente IA con una consulta real |
| 3 | `03-budget` | Presupuesto por categorías |
| 4 | `04-goals` | Metas con progreso |
| 5 | `05-debts` | Deudas y vencimientos |
| 6 | `06-reports` | Reportes / análisis |

## Capturar

El simulador tiene que ser un **iPhone 17 Pro Max** (1320×2868 = 6.9", el tamaño que pide
Apple). El 17 Pro normal da 1206×2622 y **no es un tamaño aceptado**.

```bash
D=<udid del 17 Pro Max>
xcrun simctl boot $D
xcrun simctl status_bar $D override --time "9:41" --dataNetwork wifi --wifiMode active \
  --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charging --batteryLevel 100
xcrun simctl launch $D com.metacasa.app
xcrun simctl io $D screenshot store/raw/es-MX/01-home.png
```

Capturar con build **Release**: en Debug el launch screen no renderiza (ver la memoria
`leccion-launchscreen-debug-dylib`).

### Gotchas

- **El botón flotante del asistente tapa contenido.** En Home tapa el badge del patrimonio
  neto, en Presupuesto la píldora de rollover. Antes de capturar, scrolleá para que abajo a la
  derecha no quede nada importante.
- **Un idioma por corrida.** El locale se cambia en Ajustes → General → Idioma del simulador.
  Apple penaliza traducir la imagen con un cartel encima en vez de capturar la app traducida.
- **La moneda tiene que ser la del mercado**: ARS para es, USD para en, BRL para pt.

## Componer

```bash
python3 scripts/screenshots/compose.py                # los 3 locales
python3 scripts/screenshots/compose.py --locale es-MX
```

Si falta una captura cruda avisa y sigue con el resto; el código de salida es distinto de 0
para que no pase inadvertido. Un set incompleto en la tienda es rechazo por guideline 2.3.3.

Requiere Pillow (`python3 -m pip install --user Pillow`) y las fuentes del sistema New York
y SF, que ya vienen en macOS.
