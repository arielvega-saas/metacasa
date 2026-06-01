# 🎞️ Reels listos para publicar

**9 reels** generados desde los App Preview originales (2026-05-30), formato estándar de redes: **1080×1920 (9:16), ~20s, con audio AAC**, optimizados para web (`+faststart`).

```
reels/
├── ES/ reel-1-home-metas · reel-2-ia-presupuesto · reel-3-movimientos
├── EN/ reel-1-home-ai · reel-2-budget · reel-3-goals
└── PT/ reel-1-home-ia · reel-2-orcamento · reel-3-metas
```

Sirven directo para **TikTok + Instagram Reels + YouTube Shorts**.

> ✅ **Los videos SÍ tienen audio** (verificado con ffprobe: pista AAC en los 27 — App Preview + rail de la landing). El botón de sonido 🔊 de la landing reproduce la voz real.

---

## 🎯 Mapeo a los posts (qué reel usar dónde)

| Reel | Muestra | Post sugerido |
|---|---|---|
| `reel-1` (home + metas/IA) | Dashboard, disponible del mes | Semana 1 · Post 2 "Demo 5s" · Semana 2 · Día 8 (inflación) |
| `reel-2` (IA + presupuesto) | Asistente IA, presupuesto | Semana 1 · Post IA · Semana 2 · Día 9 (quincena) |
| `reel-3` (movimientos/metas) | Movimientos, metas | Semana 2 · Día 11 (multi-moneda) · Día 13 (pareja) |

> El **hook de texto** de cada post (en `semana-01-lanzamiento.md` y `semana-02-motor.md`) se pone **encima del reel** al publicar (texto grande en los primeros 2s, en CapCut/TikTok/IG). Eso frena el scroll. El audio del propio video ya trae la voz; si querés un trending sound, mezclalo bajito o reemplazá.

---

## 🔧 Cómo se generaron (para ajustar duración o tramo)

```bash
ffmpeg -y -i input.mp4 -t 20 \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=0x0f1714,setsar=1" \
  -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k output.mp4
```
- Original = `886×1920`; se escala dentro de `1080×1920` y se padea con barras en el verde midnight de la marca (`0x0f1714`). No se recorta contenido.
- `-t 20` = duración. Para un tramo distinto: `-ss 5 -t 18` (del seg 5, 18s).
- Decime si querés otra duración o recorte y los regenero.

---

## ✅ Para publicar

- [ ] Agregar hook de texto (primeros 2s) según el post
- [ ] Subir mismo reel a TikTok + IG Reels + YT Shorts
- [ ] Medir retención del primer reel → el ganador se amplifica con ads en Semana 3
