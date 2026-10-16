#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera ilustraciones esquemáticas (wireframes) de cada pantalla del
Sistema de Inventario Insevig, con los colores y textos reales de la app,
sin depender de capturas de pantalla en vivo.
"""

import os
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = "/home/alcano/Documentos/mis_proyecto/Sistema de Inventario_logistica_2.0/docs/screens"
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 1400, 820

# Paleta real (core/app_theme.dart)
PRIMARY = (27, 58, 92)
PRIMARY_SOFT = (231, 237, 243)
SURFACE = (255, 255, 255)
SURFACE_ALT = (236, 239, 243)
BG = (245, 247, 249)
BORDER = (223, 228, 234)
TEXT_PRIMARY = (26, 38, 52)
TEXT_SECONDARY = (100, 116, 139)
SUCCESS = (22, 107, 71)
SUCCESS_BG = (227, 243, 236)
WARNING = (180, 83, 9)
WARNING_BG = (252, 238, 220)
ERROR = (176, 35, 28)
ERROR_BG = (250, 227, 225)
INFO = (29, 111, 165)
INFO_BG = (222, 237, 246)
WHITE = (255, 255, 255)

FONT_DIR = "/usr/share/fonts/truetype/dejavu"


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)


F_TITLE = font(22, bold=True)
F_H1 = font(26, bold=True)
F_H2 = font(19, bold=True)
F_BODY = font(16)
F_BODY_B = font(16, bold=True)
F_SMALL = font(13)
F_SMALL_B = font(13, bold=True)
F_TINY = font(11)


def rrect(d, box, radius, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text_w(d, s, f):
    bbox = d.textbbox((0, 0), s, font=f)
    return bbox[2] - bbox[0]


def new_canvas(title, breadcrumb=None, back=True, menu=True, user_badge="Admin"):
    """Crea el lienzo base con la barra superior (igual en toda la app)."""
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    # Barra superior
    d.rectangle([0, 0, W, 64], fill=PRIMARY)
    x = 24
    if back:
        d.line([(x, 32 - 10), (x - 8, 32), (x, 32 + 10)], fill=WHITE, width=3)
        x += 26
    if menu:
        for i in range(3):
            d.line([(x, 22 + i * 8), (x + 22, 22 + i * 8)], fill=WHITE, width=3)
        x += 38
    d.text((x, 32), title, font=F_TITLE, fill=WHITE, anchor="lm")
    # Insignia de usuario (derecha)
    if user_badge:
        bw = text_w(d, user_badge, F_SMALL_B) + 24
        rrect(d, [W - 24 - bw, 20, W - 24, 44], 10, fill=(55, 86, 120))
        d.text((W - 24 - bw / 2, 32), user_badge, font=F_SMALL_B, fill=WHITE, anchor="mm")
    if breadcrumb:
        d.text((24, 90), breadcrumb, font=F_H1, fill=TEXT_PRIMARY, anchor="lm")
    return img, d


def button(d, xy, label, filled=True, color=PRIMARY, w=None, h=44):
    x, y = xy
    bw = (w if w else text_w(d, label, F_BODY_B) + 36)
    box = [x, y, x + bw, y + h]
    if filled:
        rrect(d, box, 8, fill=color)
        d.text((x + bw / 2, y + h / 2), label, font=F_BODY_B, fill=WHITE, anchor="mm")
    else:
        rrect(d, box, 8, outline=color, width=2)
        d.text((x + bw / 2, y + h / 2), label, font=F_BODY_B, fill=color, anchor="mm")
    return box


def field(d, xy, label, value_hint, w=440, required=False):
    x, y = xy
    lbl = ("* " if required else "") + label
    d.text((x, y), lbl, font=F_SMALL_B, fill=(ERROR if required else TEXT_PRIMARY))
    box = [x, y + 22, x + w, y + 60]
    rrect(d, box, 6, fill=SURFACE, outline=BORDER, width=1)
    d.text((x + 12, y + 41), value_hint, font=F_BODY, fill=TEXT_SECONDARY, anchor="lm")
    return box[3] + 14


def stat_card(d, xy, w, number, label, color=TEXT_PRIMARY, accent=False):
    x, y = xy
    box = [x, y, x + w, y + 90]
    rrect(d, box, 8, fill=SURFACE, outline=(color if accent else BORDER), width=2 if accent else 1)
    d.text((x + w / 2, y + 32), str(number), font=F_H1, fill=color, anchor="mm")
    d.text((x + w / 2, y + 66), label.upper(), font=F_TINY, fill=TEXT_SECONDARY, anchor="mm")


def card_row(d, xy, w, title, subtitle, info, accent=PRIMARY):
    x, y = xy
    h = 78
    box = [x, y, x + w, y + h]
    rrect(d, box, 6, fill=SURFACE_ALT)
    d.rectangle([x, y, x + 4, y + h], fill=accent)
    d.text((x + 16, y + 16), title, font=F_BODY_B, fill=TEXT_PRIMARY)
    d.text((x + 16, y + 40), subtitle, font=F_SMALL, fill=TEXT_PRIMARY)
    d.text((x + 16, y + 60), info, font=F_TINY, fill=TEXT_SECONDARY)
    return y + h + 10


def tabs(d, xy, labels, active=0):
    x, y = xy
    for i, lbl in enumerate(labels):
        bw = text_w(d, lbl, F_BODY_B) + 36
        box = [x, y, x + bw, y + 40]
        if i == active:
            rrect(d, box, 6, fill=PRIMARY)
            d.text((x + bw / 2, y + 20), lbl, font=F_BODY_B, fill=WHITE, anchor="mm")
        else:
            rrect(d, box, 6, outline=BORDER, width=2)
            d.text((x + bw / 2, y + 20), lbl, font=F_BODY_B, fill=TEXT_SECONDARY, anchor="mm")
        x += bw + 10
    return y + 54


def searchbox(d, xy, hint, w=620):
    x, y = xy
    box = [x, y, x + w, y + 40]
    rrect(d, box, 8, fill=SURFACE, outline=BORDER, width=1)
    d.ellipse([x + 12, y + 12, x + 24, y + 24], outline=TEXT_SECONDARY, width=2)
    d.text((x + 36, y + 20), hint, font=F_BODY, fill=TEXT_SECONDARY, anchor="lm")
    return y + 54


def save(img, name):
    path = os.path.join(OUT_DIR, name)
    img.save(path, quality=92)
    print("OK", path)


# ----------------------------------------------------------------------
# 0. Login
img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)
cx, cy, cw, ch = W / 2 - 220, 140, 440, 320
rrect(d, [cx, cy, cx + cw, cy + ch], 12, fill=SURFACE, outline=BORDER)
d.ellipse([cx + cw / 2 - 30, cy + 30, cx + cw / 2 + 30, cy + 90], fill=PRIMARY_SOFT)
d.rounded_rectangle([cx + cw / 2 - 14, cy + 48, cx + cw / 2 + 14, cy + 72], 3, outline=PRIMARY, width=2)
d.text((cx + cw / 2, cy + 112), "Inventario Logística Insevig", font=F_BODY_B, fill=TEXT_PRIMARY, anchor="mm")
d.text((cx + cw / 2, cy + 136), "Inicie sesión para continuar", font=F_SMALL, fill=TEXT_SECONDARY, anchor="mm")
fy = cy + 164
d.text((cx + 30, fy), "Usuario o Email:", font=F_SMALL_B, fill=TEXT_PRIMARY)
rrect(d, [cx + 30, fy + 20, cx + cw - 30, fy + 56], 6, fill=SURFACE, outline=BORDER)
d.text((cx + 42, fy + 38), "usuario@ejemplo.com", font=F_BODY, fill=TEXT_SECONDARY, anchor="lm")
fy += 70
d.text((cx + 30, fy), "Contraseña:", font=F_SMALL_B, fill=TEXT_PRIMARY)
rrect(d, [cx + 30, fy + 20, cx + cw - 30, fy + 56], 6, fill=SURFACE, outline=BORDER)
d.text((cx + 42, fy + 38), "••••••••", font=F_BODY, fill=TEXT_SECONDARY, anchor="lm")
button(d, (cx + 30, fy + 70), "Iniciar sesión", w=cw - 60)
save(img, "02_login.png")

# ----------------------------------------------------------------------
# 1. Selector de inventario
img, d = new_canvas("Inventario Logística Insevig", back=False, menu=False, user_badge="")
d.text((24, 100), "Hola, usuario", font=F_H1, fill=TEXT_PRIMARY)
d.text((24, 134), "Elige con qué inventario quieres trabajar.", font=F_BODY, fill=TEXT_SECONDARY)
tarjetas = [
    ("Inventario Dotación\nEmpleados", SUCCESS),
    ("Inventario Barcos", INFO),
    ("Inventario Motos", WARNING),
    ("PRUEBAS", TEXT_SECONDARY),
]
tx, ty, tw, th, gap = 24, 180, 300, 170, 24
for i, (nombre, color) in enumerate(tarjetas):
    cx = tx + i * (tw + gap)
    box = [cx, ty, cx + tw, ty + th]
    rrect(d, box, 10, fill=SURFACE, outline=BORDER, width=1)
    d.ellipse([cx + tw / 2 - 28, ty + 24, cx + tw / 2 + 28, ty + 80], fill=PRIMARY_SOFT)
    d.ellipse([cx + tw / 2 - 10, ty + 42, cx + tw / 2 + 10, ty + 62], outline=color, width=3)
    for j, line in enumerate(nombre.split("\n")):
        d.text((cx + tw / 2, ty + 104 + j * 20), line, font=F_BODY_B, fill=TEXT_PRIMARY, anchor="mm")
    d.text((cx + tw / 2, ty + th - 24), "Disponible", font=F_SMALL, fill=TEXT_SECONDARY, anchor="mm")
save(img, "03_selector.png")

# ----------------------------------------------------------------------
# 2. Dashboard
img, d = new_canvas("Dashboard", breadcrumb="Dashboard")
y = 140
for i, (num, lbl, color, accent) in enumerate([
    ("270", "Con stock", TEXT_PRIMARY, False),
    ("40", "Sin stock", ERROR, False),
    ("172", "Stock bajo", WARNING, True),
    ("482", "Total productos", TEXT_PRIMARY, False),
]):
    stat_card(d, (24 + i * 330, y), 310, num, lbl, color=color, accent=accent)
y += 120
rrect(d, [24, y, W - 24, y + 56], 8, fill=INFO_BG)
d.text((48, y + 28), "Usa el menú lateral para navegar entre las funciones del sistema.",
       font=F_BODY, fill=INFO, anchor="lm")
y += 80
button(d, (24, y), "Diagnóstico del sistema", filled=False, color=TEXT_SECONDARY)
button(d, (310, y), "Gestionar duplicados", filled=False, color=WARNING)
save(img, "04_dashboard.png")

# ----------------------------------------------------------------------
# 3. Entrada
img, d = new_canvas("Entrada", breadcrumb="Registro de Entrada")
y = 150
rrect(d, [24, y, W - 24, y + 88], 10, fill=INFO_BG, outline=INFO, width=1)
d.rounded_rectangle([40, y + 30, 68, y + 56], 4, outline=INFO, width=2)
d.line([(46, y + 38), (62, y + 38)], fill=INFO, width=2)
d.line([(46, y + 44), (62, y + 44)], fill=INFO, width=2)
d.text((80, y + 30),
       "Puede leer el PDF de la factura para pre-llenar proveedor, N° de factura, clave SRI, "
       "fecha e ítems.", font=F_SMALL, fill=TEXT_PRIMARY, anchor="lm")
d.text((80, y + 56),
       "Si el código de un ítem coincide exacto con su catálogo, ese producto queda elegido solo.",
       font=F_SMALL, fill=INFO, anchor="lm")
button(d, (W - 220, y + 22), "Leer factura", w=170)
y += 118
rrect(d, [24, y, W - 24, y + 70], 8, fill=SURFACE, outline=BORDER)
d.text((48, y + 26), "Productos", font=F_H2, fill=TEXT_PRIMARY)
button(d, (W - 260, y + 14), "+  Agregar Producto", filled=False, w=220)
y += 100
y = field(d, (24, y), "Fecha de Entrada:", "13/10/2026", w=300)
y = field(d, (24, y), "Proveedor:", "Nombre del proveedor", w=600, required=True)
y = field(d, (24, y), "Número de Factura/OC:", "Obligatorio — respalda la compra", w=600, required=True)
y = field(d, (24, y), "Clave de acceso SRI (opcional):", "Escanear o pegar los 49 dígitos", w=600)
button(d, (24, y + 6), "Guardar Entrada", w=220)
button(d, (260, y + 6), "Limpiar Formulario", filled=False, color=TEXT_SECONDARY, w=220)
save(img, "05_entrada.png")

# ----------------------------------------------------------------------
# 4. Salida
img, d = new_canvas("Salida", breadcrumb="Registro de Salida")
y = 150
rrect(d, [24, y, W - 24, y + 70], 8, fill=SURFACE, outline=BORDER)
d.text((48, y + 26), "Productos", font=F_H2, fill=TEXT_PRIMARY)
button(d, (W - 260, y + 14), "+  Agregar Producto", filled=False, w=220)
y += 100
y = field(d, (24, y), "Fecha de Salida:", "13/10/2026", w=300)
y = field(d, (24, y), "Bote / Moto:", "Ej: BOTE 1, BOTE 31", w=600, required=True)
y = field(d, (24, y), "A quién se entrega:", "Nombre de la persona que recibe", w=600, required=True)
y = field(d, (24, y), "Propósito de la salida:", "Para qué se utilizarán los repuestos (opcional)", w=600)
d.text((24, y), "* Foto de sustento de la salida:", font=F_SMALL_B, fill=ERROR)
y += 22
rrect(d, [24, y, 74, y + 50], 8, fill=SURFACE_ALT, outline=BORDER)
d.rounded_rectangle([38, y + 15, 60, y + 32], 3, outline=TEXT_SECONDARY, width=2)
d.ellipse([44, y + 18, 54, y + 28], outline=TEXT_SECONDARY, width=2)
button(d, (90, y + 2), "Tomar foto de sustento", filled=False, w=260, h=46)
y += 70
button(d, (24, y), "Guardar Salida", w=200)
button(d, (240, y), "Limpiar Formulario", filled=False, color=TEXT_SECONDARY, w=220)
save(img, "06_salida.png")

# ----------------------------------------------------------------------
# 5. Inventario
img, d = new_canvas("Inventario", breadcrumb="Inventario Actual")
y = searchbox(d, (24, 140), "Buscar por código o producto...")
y += 10
for lbl in ("Exportar a Excel", "Exportar a CSV", "Exportar a PDF"):
    button(d, (24 + [0, 220, 420][["Exportar a Excel", "Exportar a CSV", "Exportar a PDF"].index(lbl)], y),
           lbl, filled=False, w=190, h=38)
y += 60
productos = [
    ("PRU-001", "Producto de prueba A — tornillos", 45, False),
    ("PRU-002", "Producto de prueba B — manguera", 25, False),
    ("PRU-003", "Producto de prueba C — cable eléctrico", 3, True),
]
for cod, nombre, stock, bajo in productos:
    color = WARNING if bajo else SUCCESS
    y2 = card_row(d, (24, y), W - 48, nombre, f"Cód: {cod}", f"Entradas: {stock + 10}  ·  Salidas: 10",
                  accent=color)
    d.text((W - 160, y + 20), str(stock), font=F_H2, fill=color)
    d.text((W - 160, y + 50), "Stock", font=F_TINY, fill=TEXT_SECONDARY)
    if bajo:
        rrect(d, [W - 260, y + 14, W - 180, y + 36], 10, fill=WARNING_BG)
        d.text((W - 220, y + 25), "STOCK BAJO", font=F_TINY, fill=WARNING, anchor="mm")
    y = y2
save(img, "07_inventario.png")

# ----------------------------------------------------------------------
# 6. Productos
img, d = new_canvas("Productos", breadcrumb="Registrar Producto")
y = tabs(d, (24, 140), ["Registro rápido", "Buscar / Editar"], active=0)
y += 20
button(d, (24, y), "Escanear código de barras", w=320)
d.text((24 + 340, y + 22), "o", font=F_BODY, fill=TEXT_SECONDARY, anchor="mm")
y = field(d, (24, y + 56), "Escribir código manualmente", "Código del producto", w=440)
y = field(d, (24, y), "Nombre del producto", "Ej: Manguera hidráulica 1/2\"", w=600)
y = field(d, (24, y), "Cantidad inicial (stock)", "0", w=300)
d.text((24, y), "Más detalles (opcional)", font=F_SMALL, fill=TEXT_SECONDARY)
y += 30
button(d, (24, y), "Guardar y escanear siguiente", w=360)
save(img, "08_productos.png")

# ----------------------------------------------------------------------
# 7. Historial
img, d = new_canvas("Historial", breadcrumb="Historial de Transacciones")
y = tabs(d, (24, 140), ["Entradas", "Salidas", "Por Factura"], active=0)
y = searchbox(d, (24, y + 10), "Buscar por transacción, proveedor, factura...")
y += 10
button(d, (24, y), "Desde", filled=False, color=TEXT_SECONDARY, w=150, h=38)
button(d, (190, y), "Hasta", filled=False, color=TEXT_SECONDARY, w=150, h=38)
rrect(d, [360, y, 620, y + 38], 6, fill=SURFACE, outline=BORDER)
d.text((376, y + 19), "Registrado por: Todos", font=F_SMALL, fill=TEXT_PRIMARY, anchor="lm")
y += 56
filas = [
    ("ENT-20261012201214-6a53dd", "Proveedor: Distribuidora Prueba Ltda.", "12/10/2026 · usuario · 2 ítem(s)"),
    ("ENT-20261011201214-59bb32", "Proveedor: Proveedor de Pruebas S.A.", "11/10/2026 · usuario · 2 ítem(s)"),
]
for titulo, sub, info in filas:
    y = card_row(d, (24, y), W - 48, titulo, sub, info)
save(img, "09_historial.png")

# ----------------------------------------------------------------------
# 8. Taller
img, d = new_canvas("Taller", breadcrumb="Órdenes de Trabajo")
button(d, (W - 220, 100), "+  Nueva OT", w=190)
y = 160
ordenes = [
    ("OT-0031 · MOTO 12", "Falla: fuga de aceite en motor", "Pendiente de despacho", WARNING),
    ("OT-0030 · BOTE 8", "Falla: cambio de impulsor de bomba", "Completada", SUCCESS),
]
for titulo, sub, estado, color in ordenes:
    y2 = card_row(d, (24, y), W - 220, titulo, sub, "Creada por: mecánico de turno", accent=color)
    rrect(d, [W - 180, y + 24, W - 24, y + 54], 15, fill=(color[0], color[1], color[2]))
    d.text((W - 102, y + 39), estado, font=F_TINY, fill=WHITE, anchor="mm")
    y = y2
save(img, "10_taller.png")

# ----------------------------------------------------------------------
# 9. Carga Masiva
img, d = new_canvas("Carga Masiva", breadcrumb="Carga Masiva de Datos")
y = 150
rrect(d, [24, y, W - 24, y + 160], 8, fill=SURFACE, outline=BORDER)
d.text((48, y + 24), "1. Descargue la plantilla de ejemplo (.xlsx)", font=F_BODY, fill=TEXT_PRIMARY)
d.text((48, y + 58), "2. Complete una fila por cada producto", font=F_BODY, fill=TEXT_PRIMARY)
d.text((48, y + 92), "3. Suba el archivo completado", font=F_BODY, fill=TEXT_PRIMARY)
button(d, (48, y + 120), "Descargar plantilla", filled=False, w=220, h=34)
y += 190
button(d, (24, y), "Seleccionar archivo", w=240)
save(img, "11_carga_masiva.png")

# ----------------------------------------------------------------------
# 10. Usuarios
img, d = new_canvas("Usuarios", breadcrumb="Gestión de Usuarios")
button(d, (W - 220, 96), "+  Nuevo Usuario", w=200)
y = 160
usuarios = [
    ("Administrador del Sistema", "Admin · Todos los módulos"),
    ("Bodega Barcos", "Operador · Bodeguero · Barcos"),
    ("Mecánico Motos", "Operador · Mecánico · Motos"),
]
for nombre, sub in usuarios:
    y = card_row(d, (24, y), W - 48, nombre, sub, "Activo", accent=SUCCESS)
save(img, "12_usuarios.png")

# ----------------------------------------------------------------------
# 11. Mi perfil
img, d = new_canvas("Mi Perfil", breadcrumb="Mi Perfil")
y = 150
rrect(d, [24, y, W - 24, y + 200], 10, fill=SURFACE, outline=BORDER)
d.ellipse([56, y + 30, 136, y + 110], fill=PRIMARY_SOFT)
d.text((160, y + 50), "Nombre del usuario", font=F_H2, fill=TEXT_PRIMARY)
d.text((160, y + 82), "Rol: Operador · Oficio: Bodeguero", font=F_BODY, fill=TEXT_SECONDARY)
d.text((160, y + 110), "Módulos: Barcos, Motos", font=F_BODY, fill=TEXT_SECONDARY)
button(d, (56, y + 150), "Salir", color=ERROR, w=160)
save(img, "13_perfil.png")

print("Listo.")
