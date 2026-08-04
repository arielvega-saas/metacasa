#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Compone los screenshots de App Store a partir de capturas crudas del simulador.

Por qué existe
--------------
El set que estaba publicado (18 imágenes) se armó a mano en mayo de 2026 con el
logo ANTERIOR: verde neón con biseles 3D. La identidad vigente es "Midnight Sage"
(sage plano sobre casi negro), que es la que usan la app, la web y los mails desde
el 2026-08-04. Rehacer eso a mano cada vez que cambia una pantalla es lo que hizo
que el set quedara viejo; por eso esto es un script y no un archivo de diseño.

Entrada  : store/raw/<locale>/<NN-slug>.png   — capturas crudas 1320x2868 del simulador
Salida   : store/ready/<locale>/<NN-slug>.png — 1320x2868 listas para App Store Connect

El copy sale de app/APP_STORE_COPY.md, sección 6. Si cambia allá, cambiá acá: es
el mismo texto a propósito, para que la tienda no diga algo distinto del playbook.

Uso:
    python3 scripts/screenshots/compose.py               # todos los locales
    python3 scripts/screenshots/compose.py --locale es-MX
"""

from __future__ import annotations

import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ---------------------------------------------------------------- rutas

AQUI = os.path.dirname(os.path.abspath(__file__))
APP = os.path.abspath(os.path.join(AQUI, "..", ".."))          # ~/dev/HomeFinance/app
PRODUCTO = os.path.abspath(os.path.join(APP, ".."))            # ~/dev/HomeFinance
RAW = os.path.join(PRODUCTO, "store", "raw")
READY = os.path.join(PRODUCTO, "store", "ready")
ICONO = os.path.join(
    APP, "metacasa-ios", "MetaCasa", "Supporting",
    "Assets.xcassets", "AppIcon.appiconset", "Icon-1024.png",
)

# ---------------------------------------------------------------- identidad
# Valores tomados de metacasa-ios/MetaCasa/Core/DesignSystem.swift (Midnight Sage).
# No inventar acá: si cambian allá, cambian acá.

FONDO = (14, 19, 18)          # #0E1312 appBackground dark
CREMA = (232, 228, 220)       # #E8E4DC textPrimary dark
SAGE = (184, 212, 194)        # #B8D4C2 brandPrimary

W, H = 1320, 2868             # 6.9" — tamaño nativo de la captura del 17 Pro Max

# ---------------------------------------------------------------- tipografía

SERIF_CANDIDATAS = [
    "/System/Library/Fonts/NewYork.ttf",          # la misma serif que usa la app
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
]
SANS_CANDIDATAS = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
]


def _primera_existente(rutas):
    for r in rutas:
        if os.path.exists(r):
            return r
    return None


def cargar_fuente(rutas, tamano, peso=None):
    ruta = _primera_existente(rutas)
    if ruta is None:
        sys.exit("No encontré ninguna fuente de: %s" % ", ".join(rutas))
    fuente = ImageFont.truetype(ruta, tamano)
    if peso:
        # New York y SF son fuentes variables: sin fijar instancia salen en Regular.
        try:
            fuente.set_variation_by_name(peso)
        except Exception:
            pass
    return fuente


# ---------------------------------------------------------------- copy
# APP_STORE_COPY.md § 6 "Texto overlay por captura".

PANTALLAS = [
    {
        "slug": "01-home",
        "textos": {
            "es-MX": (u"Tu plata,\nen calma", u"Mirá adónde va cada peso."),
            "en-US": (u"Money,\nfinally calm", u"See where every dollar goes."),
            "pt-BR": (u"Seu dinheiro,\nem paz", u"Veja para onde vai cada real."),
        },
    },
    {
        "slug": "02-ai",
        "textos": {
            "es-MX": (u"Preguntale\na la IA", u"Entendé tus gastos sin planillas."),
            "en-US": (u"Ask the AI", u"Understand your spending — without spreadsheets."),
            "pt-BR": (u"Pergunte\nà IA", u"Entenda seus gastos sem planilhas."),
        },
    },
    {
        "slug": "03-budget",
        "textos": {
            "es-MX": (u"Cada peso\nen su lugar", u"Presupuestos que sí podés seguir."),
            "en-US": (u"Every dollar\nin its place", u"Budgets you'll actually stick to."),
            "pt-BR": (u"Cada real\nno seu lugar", u"Orçamentos que você realmente segue."),
        },
    },
    {
        "slug": "04-goals",
        "textos": {
            "es-MX": (u"Metas con\nfecha clara", u"Ahorrá para lo que importa."),
            "en-US": (u"Goals with\na clear date", u"Save for what actually matters."),
            "pt-BR": (u"Metas com\ndata certa", u"Poupe para o que importa."),
        },
    },
    {
        "slug": "05-debts",
        "textos": {
            "es-MX": (u"Nunca olvides\nun pago", u"Cuotas y vencimientos bajo control."),
            "en-US": (u"Never miss\na payment", u"Installments and bills in one view."),
            "pt-BR": (u"Nunca esqueça\num pagamento", u"Parcelas e vencimentos sob controle."),
        },
    },
    {
        "slug": "06-reports",
        "textos": {
            "es-MX": (u"Decisiones\nmás claras", u"Salud financiera con un solo número."),
            "en-US": (u"Smarter\ndecisions", u"Your financial health, in one score."),
            "pt-BR": (u"Decisões\nmais claras", u"Saúde financeira com um único número."),
        },
    },
]

LOCALES = ["es-MX", "en-US", "pt-BR"]


# ---------------------------------------------------------------- dibujo

def fondo_con_glow():
    """Casi negro verdoso con un halo sage difuso arriba, como el fondo de la app."""
    base = Image.new("RGB", (W, H), FONDO)

    # El glow se dibuja chico y se escala: sale mucho más suave (y más rápido)
    # que aplicar un blur enorme sobre la imagen a tamaño completo.
    chico_w, chico_h = W // 8, H // 8
    glow = Image.new("L", (chico_w, chico_h), 0)
    d = ImageDraw.Draw(glow)
    cx, cy = chico_w // 2, int(chico_h * 0.16)
    for i in range(14, 0, -1):
        radio = int(chico_w * 0.10 * i)
        d.ellipse([cx - radio, cy - radio, cx + radio, cy + radio], fill=int(150 / i))
    glow = glow.filter(ImageFilter.GaussianBlur(chico_w * 0.09)).resize((W, H), Image.LANCZOS)

    capa = Image.new("RGB", (W, H), SAGE)
    return Image.composite(capa, base, glow.point(lambda v: int(v * 0.13)))


def esquinas_redondeadas(img, radio):
    mascara = Image.new("L", img.size, 0)
    ImageDraw.Draw(mascara).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1],
                                              radius=radio, fill=255)
    salida = img.convert("RGBA")
    salida.putalpha(mascara)
    return salida


def pegar_dispositivo(lienzo, captura, top, ancho):
    """Pega la captura como un panel con esquinas redondeadas, borde sage y sombra.

    Se recorta contra el borde inferior a propósito (bleed): da sensación de que la
    pantalla sigue, en vez de dejar una franja muerta abajo.
    """
    escala = float(ancho) / captura.size[0]
    alto = int(captura.size[1] * escala)
    captura = captura.resize((ancho, alto), Image.LANCZOS)

    radio = max(38, int(ancho * 0.055))
    panel = esquinas_redondeadas(captura, radio)

    izq = (W - ancho) // 2

    # Sombra: la silueta del panel, desenfocada y corrida hacia abajo.
    sombra = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    silueta = Image.new("RGBA", panel.size, (0, 0, 0, 150))
    silueta.putalpha(panel.getchannel("A").point(lambda v: int(v * 0.55)))
    sombra.paste(silueta, (izq, top + 26), silueta)
    sombra = sombra.filter(ImageFilter.GaussianBlur(34))
    lienzo.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), sombra)

    lienzo.paste(panel, (izq, top), panel)

    # Borde fino luminoso — el mismo recurso que usa la app en las cards.
    d = ImageDraw.Draw(lienzo, "RGBA")
    d.rounded_rectangle([izq, top, izq + ancho - 1, top + alto - 1],
                        radius=radio, outline=SAGE + (46,), width=3)


def dibujar_texto(lienzo, titulo, subtitulo, icono):
    d = ImageDraw.Draw(lienzo, "RGBA")

    margen = 108

    # Logo + wordmark
    lado = 104
    ico = icono.resize((lado, lado), Image.LANCZOS)
    ico = esquinas_redondeadas(ico, int(lado * 0.225))
    lienzo.paste(ico, (margen, 168), ico)

    f_marca = cargar_fuente(SANS_CANDIDATAS, 46, "Medium")
    d.text((margen + lado + 30, 168 + lado // 2), u"Home Finance",
           font=f_marca, fill=CREMA + (235,), anchor="lm")

    # Título serif
    f_titulo = cargar_fuente(SERIF_CANDIDATAS, 112, "Medium")
    y = 372
    for linea in titulo.split("\n"):
        d.text((margen, y), linea, font=f_titulo, fill=CREMA)
        y += 128

    # Subtítulo
    f_sub = cargar_fuente(SANS_CANDIDATAS, 46, "Regular")
    y += 18
    for linea in envolver(subtitulo, f_sub, W - margen * 2, d):
        d.text((margen, y), linea, font=f_sub, fill=SAGE + (225,))
        y += 60

    return y


def envolver(texto, fuente, ancho_max, draw):
    palabras = texto.split()
    lineas, actual = [], ""
    for palabra in palabras:
        prueba = (actual + " " + palabra).strip()
        if draw.textlength(prueba, font=fuente) <= ancho_max:
            actual = prueba
        else:
            if actual:
                lineas.append(actual)
            actual = palabra
    if actual:
        lineas.append(actual)
    return lineas


def componer(captura_path, titulo, subtitulo, icono, salida_path):
    captura = Image.open(captura_path).convert("RGB")
    lienzo = fondo_con_glow()
    fin_texto = dibujar_texto(lienzo, titulo, subtitulo, icono)

    # El panel sangra hasta el borde inferior, así que no hay lugar para un pie:
    # el set anterior tenía uno y acá quedaría escrito ENCIMA de la app. La firma
    # de marca ya la da el logo + wordmark de arriba.
    top = max(fin_texto + 86, 860)
    pegar_dispositivo(lienzo, captura, top=top, ancho=1012)

    if not os.path.isdir(os.path.dirname(salida_path)):
        os.makedirs(os.path.dirname(salida_path))
    lienzo.save(salida_path, "PNG", optimize=True)


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description="Compone los screenshots de App Store.")
    ap.add_argument("--locale", action="append", choices=LOCALES,
                    help="Locale a componer (repetible). Por defecto, todos.")
    args = ap.parse_args()

    locales = args.locale or LOCALES

    if not os.path.exists(ICONO):
        sys.exit("No está el ícono vigente en %s" % ICONO)
    icono = Image.open(ICONO).convert("RGB")

    hechas, faltantes = 0, []
    for locale in locales:
        for pantalla in PANTALLAS:
            slug = pantalla["slug"]
            entrada = os.path.join(RAW, locale, slug + ".png")
            if not os.path.exists(entrada):
                faltantes.append("%s/%s" % (locale, slug))
                continue
            titulo, subtitulo = pantalla["textos"][locale]
            salida = os.path.join(READY, locale, slug + ".png")
            componer(entrada, titulo, subtitulo, icono, salida)
            print("  ok  %s/%s" % (locale, slug))
            hechas += 1

    print("\n%d compuestas en %s" % (hechas, READY))
    if faltantes:
        # Se avisa fuerte: un set incompleto subido a la tienda es un rechazo 2.3.3
        # esperando, y es exactamente el tipo de cosa que se pasa por alto en silencio.
        print("\nFALTAN %d capturas crudas (no se compusieron):" % len(faltantes))
        for f in faltantes:
            print("   - store/raw/%s.png" % f)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
