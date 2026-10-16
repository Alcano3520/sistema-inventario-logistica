#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Arma el Excel de emparejamiento entre el inventario de Motos que se borró
(respaldo del 2026-09-30) y el inventario nuevo actual, para que una persona
confirme a mano qué producto antiguo corresponde a cuál nuevo.
"""

import difflib
import json
import re
import unicodedata

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.workbook.defined_name import DefinedName

BASE = "/home/alcano/Documentos/mis_proyecto/Sistema de Inventario_logistica_2.0/backups/motos_2026-09-30"
RECON = f"{BASE}/reconciliacion"
OUT_PATH = f"{RECON}/Emparejamiento_Inventario_Motos.xlsx"

# Ítems de la última factura real (N° 371, proveedor "colon moto") que el
# usuario marcó como mal ingresados — se resaltan aparte en el listado.
CODIGOS_ULTIMA_FACTURA = {"091", "096", "019", "0109"}
FACTURA_INFO = "N° 371 · Colón Moto · 22/09/2026"

NAVY = "1B3A5C"
NAVY_LIGHT = "E7EDF3"
GREEN = "E3F3EC"
YELLOW = "FCEEDC"
RED = "FAE3E1"
BORDER_COLOR = "DFE4EA"

thin = Side(style="thin", color=BORDER_COLOR)
border_all = Border(left=thin, right=thin, top=thin, bottom=thin)


def normalizar(s):
    s = (s or "").upper().strip()
    s = "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^A-Z0-9 ]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def mejor_coincidencia(nombre_anterior, productos_nuevos):
    """Devuelve (producto_nuevo, score 0-1) con mayor similitud de texto."""
    objetivo = normalizar(nombre_anterior)
    mejor = None
    mejor_score = 0.0
    for p in productos_nuevos:
        score = difflib.SequenceMatcher(None, objetivo, normalizar(p["producto"])).ratio()
        if score > mejor_score:
            mejor_score = score
            mejor = p
    return mejor, mejor_score


def esc(texto):
    """Escapa comillas para usar un texto como literal dentro de una fórmula de Excel."""
    return (texto or "").replace('"', '""')


def num(v, default=0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def construir_movimientos():
    """Arma el detalle histórico (entradas + salidas) del inventario ANTERIOR,
    cruzando cada línea de detalle con los datos de su transacción (fecha,
    factura/proveedor o a quién se entregó, usuario) — uno por uno, ordenado
    por producto y luego por fecha, con el saldo corrido después de cada
    movimiento (igual que el kardex que muestra la app)."""
    det_ent = json.load(open(f"{BASE}/inv_motos_detalle_entradas.json", encoding="utf-8"))
    tr_ent = json.load(open(f"{BASE}/inv_motos_transacciones_entrada.json", encoding="utf-8"))
    det_sal = json.load(open(f"{BASE}/inv_motos_detalle_salidas.json", encoding="utf-8"))
    tr_sal = json.load(open(f"{BASE}/inv_motos_transacciones_salida.json", encoding="utf-8"))

    tr_ent_por_id = {t["id_transaccion"]: t for t in tr_ent}
    tr_sal_por_id = {t["id_transaccion"]: t for t in tr_sal}

    movimientos = []
    for d in det_ent:
        t = tr_ent_por_id.get(d["id_transaccion"], {})
        movimientos.append({
            "cod": d.get("cod", ""), "producto": d.get("producto", ""),
            "fecha": t.get("fecha_hora", ""), "tipo": "Entrada",
            "cantidad": num(d.get("cantidad")),
            "contraparte": t.get("proveedor") or "",
            "referencia": t.get("num_factura") or "",
            "usuario": t.get("usuario_nombre") or "",
            "id_transaccion": d.get("id_transaccion", ""),
        })
    for d in det_sal:
        t = tr_sal_por_id.get(d["id_transaccion"], {})
        movimientos.append({
            "cod": d.get("cod", ""), "producto": d.get("producto", ""),
            "fecha": t.get("fecha_hora", ""), "tipo": "Salida",
            "cantidad": num(d.get("cantidad")),
            "contraparte": t.get("a_quien_entrega") or "",
            "referencia": t.get("proposito") or (t.get("bote") or ""),
            "usuario": t.get("usuario_nombre") or "",
            "id_transaccion": d.get("id_transaccion", ""),
        })

    movimientos.sort(key=lambda m: (normalizar(m["producto"]), m["fecha"]))

    saldos = {}
    for m in movimientos:
        saldo = saldos.get(m["cod"], 0)
        saldo += m["cantidad"] if m["tipo"] == "Entrada" else -m["cantidad"]
        saldos[m["cod"]] = saldo
        m["saldo"] = saldo
    return movimientos


def main():
    anteriores = json.load(open(f"{BASE}/inv_motos_productos.json", encoding="utf-8"))
    actuales = json.load(open(f"{RECON}/actual_motos.json", encoding="utf-8"))
    anteriores.sort(key=lambda p: normalizar(p["producto"]))
    actuales.sort(key=lambda p: normalizar(p["producto"]))
    movimientos = construir_movimientos()

    wb = Workbook()

    # ------------------------------------------------------- Hoja: LÉAME --
    ws_leame = wb.active
    ws_leame.title = "LÉAME"
    leame = [
        ("Qué es este archivo", ""),
        ("", "Lista de los 121 productos del inventario ANTERIOR de Motos (el que se borró el "
             "30/09/2026, ya respaldado) para emparejarlos a mano con los 89 productos del "
             "inventario NUEVO actual."),
        ("", ""),
        ("Hoja EMPAREJAR (la principal)", ""),
        ("", "Están los 121 productos anteriores, todos por igual, sin excepción. Primero va el "
             "producto ANTERIOR (columnas A-B, el que no tenía código de barras), y luego la "
             "sugerencia del producto NUEVO que sí tiene código (columnas C-E)."),
        ("", "Columnas C y D (\"Producto nuevo sugerido\" / \"Código nuevo sugerido\") se llenan "
             "solas con fórmula: si el nombre coincide EXACTO con uno del inventario nuevo, usa "
             "ese; si el parecido por texto supera el 70%, usa esa sugerencia; si no llega a ese "
             "nivel de confianza, quedan en blanco a propósito — es mejor no sugerir nada que "
             "sugerir algo probablemente equivocado. Columna E muestra el % de parecido como "
             "referencia, incluso cuando no hubo sugerencia (100% = coincidencia exacta)."),
        ("", "Columna F, \"Código nuevo CONFIRMADO\": ahí se elige, por cada fila, cuál es el "
             "producto del inventario NUEVO que realmente corresponde a ese producto anterior. Al "
             "hacer clic en la celda aparece una flechita con los 89 productos nuevos completos "
             "(\"producto — código\") para elegir buscando por nombre, sin tener que escribir el "
             "código a mano ni arriesgarse a poner uno que no exista."),
        ("", "Columnas G y H (\"Entradas histórico\" / \"Salidas histórico\") son fórmulas SUMIFS "
             "que recalculan el total de entradas y salidas de cada producto a partir de la hoja "
             "\"Movimientos ANTERIOR (detalle)\", como control cruzado contra la columna I "
             "(\"Stock al respaldo\")."),
        ("", ""),
        ("Hoja \"Movimientos ANTERIOR (detalle)\"", ""),
        ("", "El histórico completo: cada entrada y cada salida del inventario anterior, una por "
             "fila, con fecha, cantidad, proveedor/N° de factura (en las entradas) o a quién se "
             "entregó/propósito (en las salidas), quién la registró, y el saldo que iba quedando "
             "después de cada movimiento. Use el filtro de la columna \"Código\" o \"Producto\" "
             "para ver el detalle de uno en particular. Entradas en verde, salidas en azul."),
        ("", ""),
        ("Qué significa el color de las columnas C-E", ""),
        ("", "Verde: el nombre coincide exacto con uno del inventario nuevo (alta confianza)."),
        ("", "Amarillo: parecido muy alto (80% o más) — probablemente es, pero conviene confirmar."),
        ("", "Naranja: parecido más moderado (71%-79%, el mínimo que se dejó en esta lista) — "
             "revisar con más cuidado, puede no ser el correcto."),
        ("", ""),
        ("Filas con borde grueso", ""),
        ("", "Son los 4 productos de la última factura que quedó mal ingresada antes de borrar el "
             "inventario (N° 371, proveedor Colón Moto, 22/09/2026) — revisar esas con más cuidado."),
        ("", ""),
        ("Otras hojas", ""),
        ("", "\"Inventario ANTERIOR (borrado)\": el listado completo tal como estaba antes de "
             "borrarlo, con sus códigos y cantidades de ese momento."),
        ("", "\"Inventario ACTUAL (nuevo)\": el listado del inventario nuevo tal como está hoy en "
             "el sistema."),
    ]
    ws_leame.column_dimensions["A"].width = 32
    ws_leame.column_dimensions["B"].width = 95
    for r, (titulo, texto) in enumerate(leame, start=1):
        if titulo:
            c = ws_leame.cell(row=r, column=1, value=titulo)
            c.font = Font(bold=True, size=12, color=NAVY)
        if texto:
            c = ws_leame.cell(row=r, column=2, value=texto)
            c.alignment = Alignment(wrap_text=True, vertical="top")
            ws_leame.row_dimensions[r].height = 30

    # ---------------------------------------------------- Hoja: ANTERIOR --
    ws_ant = wb.create_sheet("Inventario ANTERIOR (borrado)")
    enc_ant = ["Código anterior", "Producto", "Categoría", "Ubicación",
               "Entradas totales", "Salidas totales", "Stock al respaldo"]
    ws_ant.append(enc_ant)
    for p in anteriores:
        ws_ant.append([
            p.get("cod", ""), p.get("producto", ""), p.get("categoria", ""), p.get("ubicacion", ""),
            num(p.get("entrada")), num(p.get("salida")), num(p.get("stock")),
        ])

    # ----------------------------------------------------- Hoja: ACTUAL --
    ws_act = wb.create_sheet("Inventario ACTUAL (nuevo)")
    enc_act = ["Código nuevo", "Producto", "Categoría", "Ubicación",
               "Entradas totales", "Salidas totales", "Stock actual",
               "Para elegir (producto — código)"]
    ws_act.append(enc_act)
    for p in actuales:
        ws_act.append([
            p.get("cod", ""), p.get("producto", ""), p.get("categoria", ""), p.get("ubicacion", ""),
            num(p.get("entrada")), num(p.get("salida")), num(p.get("stock")),
            f'{p.get("producto", "")} — {p.get("cod", "")}',
        ])

    # Nombre con alcance de libro para la lista de autocompletar de la
    # columna H — los 89 productos nuevos completos, "producto — código",
    # para poder elegir buscando por nombre en vez de tener que memorizar
    # el código (que ahora es un texto generado, no dice nada por sí solo).
    wb.defined_names["ListaProductosNuevos"] = DefinedName(
        "ListaProductosNuevos",
        attr_text=f"'Inventario ACTUAL (nuevo)'!$H$2:$H${len(actuales) + 1}",
    )

    # -------------------------------------------------- Hoja: MOVIMIENTOS --
    # Detalle histórico (kardex) del inventario anterior: cada entrada y
    # cada salida, con fecha, cantidad, factura/proveedor o a quién se
    # entregó, y el saldo corrido — para poder filtrar por producto o por
    # código y ver exactamente cómo entró y cómo salió cada uno.
    ws_mov = wb.create_sheet("Movimientos ANTERIOR (detalle)")
    enc_mov = ["Código", "Producto", "Fecha", "Tipo", "Cantidad",
               "Proveedor / Entregado a", "N° Factura / Propósito", "Usuario",
               "Saldo después de este movimiento"]
    ws_mov.append(enc_mov)
    for m in movimientos:
        ws_mov.append([
            m["cod"], m["producto"], m["fecha"][:10] if m["fecha"] else "", m["tipo"],
            m["cantidad"], m["contraparte"], m["referencia"], m["usuario"], m["saldo"],
        ])
    fill_mov_ent = PatternFill("solid", fgColor=GREEN)
    fill_mov_sal = PatternFill("solid", fgColor="E3EEF8")
    for r, m in enumerate(movimientos, start=2):
        fill = fill_mov_ent if m["tipo"] == "Entrada" else fill_mov_sal
        for c in range(1, len(enc_mov) + 1):
            ws_mov.cell(row=r, column=c).fill = fill
            ws_mov.cell(row=r, column=c).border = border_all

    # -------------------------------------------------- Hoja: EMPAREJAR --
    ws = wb.create_sheet("EMPAREJAR", 1)
    encabezados = [
        "Código anterior", "Producto anterior (sin código de barras)",
        "Producto nuevo sugerido", "Código nuevo sugerido", "% de parecido (referencia)",
        "Código nuevo CONFIRMADO (clic y elegir de la lista)",
        "Entradas histórico (fórmula)", "Salidas histórico (fórmula)", "Stock al respaldo",
        "¿De la última factura mal ingresada?",
        "Observaciones",
    ]
    ws.append(encabezados)

    nombres_actuales = {normalizar(p["producto"]) for p in actuales}
    filas_info = []  # (es_factura, exacta, score) por fila, para los colores

    fila_excel = 2
    for p in anteriores:
        fila_ant = anteriores.index(p) + 2  # fila correspondiente en la hoja ANTERIOR

        # Columnas A-B: producto ANTERIOR, traído con fórmula desde la hoja
        # ANTERIOR (no valores fijos), para que esta hoja siempre refleje
        # esa hoja base.
        ws.cell(row=fila_excel, column=1, value=f"='Inventario ANTERIOR (borrado)'!A{fila_ant}")
        ws.cell(row=fila_excel, column=2, value=f"='Inventario ANTERIOR (borrado)'!B{fila_ant}")

        # Sugerencia por parecido de texto, para cuando NO hay coincidencia
        # exacta de nombre (la mayoría de los casos, porque el inventario
        # nuevo se cargó con nombres/códigos distintos a los de antes).
        # Van TODOS los productos anteriores por igual, sin excepción — lo
        # único que cambia es que, si el parecido no supera 70%, la
        # sugerencia queda en blanco (en vez de forzar un producto nuevo
        # que probablemente no sea el correcto).
        match, score = mejor_coincidencia(p.get("producto", ""), actuales)
        exacta = normalizar(p.get("producto", "")) in nombres_actuales

        # El respaldo se usa como texto fijo dentro de la fórmula, por si la
        # función MATCH de Excel no encuentra la coincidencia "exacta" que
        # detectó Python (que ignora tildes y espacios de más) — así nunca
        # queda en blanco un producto que en realidad sí se identificó.
        hay_sugerencia = exacta or score > 0.70
        respaldo_prod = esc(match["producto"]) if match and hay_sugerencia else ""
        respaldo_cod = esc(match["cod"]) if match and hay_sugerencia else ""

        # Columnas C-D: fórmula real de Excel — primero intenta la
        # coincidencia EXACTA de nombre contra el inventario nuevo; si no
        # encuentra ninguna, cae en la sugerencia por parecido ya calculada.
        f_prod = (
            f'=IFERROR(INDEX(\'Inventario ACTUAL (nuevo)\'!$B:$B,'
            f'MATCH(B{fila_excel},\'Inventario ACTUAL (nuevo)\'!$B:$B,0)),"{respaldo_prod}")'
        )
        ws.cell(row=fila_excel, column=3, value=f_prod)
        f_cod = (
            f'=IFERROR(INDEX(\'Inventario ACTUAL (nuevo)\'!$A:$A,'
            f'MATCH(B{fila_excel},\'Inventario ACTUAL (nuevo)\'!$B:$B,0)),"{respaldo_cod}")'
        )
        ws.cell(row=fila_excel, column=4, value=f_cod)
        ws.cell(row=fila_excel, column=5, value=100 if exacta else (round(score * 100) if match else 0))

        # Columnas G-H: fórmulas SUMIFS recalculadas desde el detalle de
        # movimientos (hoja "Movimientos ANTERIOR (detalle)"), por código y
        # tipo — un recálculo independiente que debería dar el mismo total
        # que ya traía el producto, útil para confirmar que el histórico
        # cuadra con el total.
        cod_celda = f"A{fila_excel}"
        f_ent_hist = (
            f"=SUMIFS('Movimientos ANTERIOR (detalle)'!$E:$E,"
            f"'Movimientos ANTERIOR (detalle)'!$A:$A,{cod_celda},"
            f"'Movimientos ANTERIOR (detalle)'!$D:$D,\"Entrada\")"
        )
        f_sal_hist = (
            f"=SUMIFS('Movimientos ANTERIOR (detalle)'!$E:$E,"
            f"'Movimientos ANTERIOR (detalle)'!$A:$A,{cod_celda},"
            f"'Movimientos ANTERIOR (detalle)'!$D:$D,\"Salida\")"
        )
        ws.cell(row=fila_excel, column=7, value=f_ent_hist)
        ws.cell(row=fila_excel, column=8, value=f_sal_hist)

        # Columnas I-J: datos de respaldo (stock y bandera de última factura).
        ws.cell(row=fila_excel, column=9, value=f"='Inventario ANTERIOR (borrado)'!G{fila_ant}")
        ws.cell(row=fila_excel, column=10,
                value=("SÍ — " + FACTURA_INFO) if p.get("cod") in CODIGOS_ULTIMA_FACTURA else "")

        filas_info.append((p.get("cod") in CODIGOS_ULTIMA_FACTURA, exacta, score))
        fila_excel += 1

    total_filas = fila_excel - 1

    # ------------------------------------------------------------- Estilos --
    def estilo_encabezado(ws_, ncols):
        for c in range(1, ncols + 1):
            cell = ws_.cell(row=1, column=c)
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill("solid", fgColor=NAVY)
            cell.alignment = Alignment(wrap_text=True, vertical="center")
            cell.border = border_all
        ws_.freeze_panes = "A2"
        ws_.row_dimensions[1].height = 34

    estilo_encabezado(ws_ant, len(enc_ant))
    estilo_encabezado(ws_act, len(enc_act))
    estilo_encabezado(ws_mov, len(enc_mov))
    estilo_encabezado(ws, len(encabezados))

    anchos_ant = [16, 34, 14, 14, 14, 14, 14]
    for i, w in enumerate(anchos_ant, start=1):
        ws_ant.column_dimensions[get_column_letter(i)].width = w
    for i, w in enumerate(anchos_ant + [42], start=1):
        ws_act.column_dimensions[get_column_letter(i)].width = w

    anchos_mov = [14, 34, 13, 10, 11, 26, 24, 20, 14]
    for i, w in enumerate(anchos_mov, start=1):
        ws_mov.column_dimensions[get_column_letter(i)].width = w

    anchos = [16, 34, 28, 18, 14, 22, 16, 16, 12, 22, 24]
    for i, w in enumerate(anchos, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w

    # Colorea las columnas de sugerencia (C-E) según qué tan confiable es:
    # verde si el nombre coincide exacto con uno del inventario nuevo,
    # amarillo si el parecido es alto (80%+), naranja claro si es medio
    # (50-79%), y sin color si es bajo o no hay nada que sugerir — para que,
    # con solo mirar el color, se note cuáles sugerencias conviene revisar
    # primero. Además, las filas de la última factura mal ingresada quedan
    # con un borde grueso para ubicarlas de un vistazo.
    fill_green = PatternFill("solid", fgColor=GREEN)
    fill_yellow = PatternFill("solid", fgColor=YELLOW)
    fill_orange = PatternFill("solid", fgColor=RED)
    thick = Side(style="medium", color="B45309")

    for idx, (es_factura, exacta, score) in enumerate(filas_info):
        r = idx + 2
        for c in range(1, len(encabezados) + 1):
            ws.cell(row=r, column=c).border = border_all
        if exacta:
            fill = fill_green
        elif score >= 0.80:
            fill = fill_yellow
        elif score > 0.70:
            fill = fill_orange
        else:
            fill = None  # sin sugerencia — queda en blanco, columnas C-D vacías
        if fill:
            for c in (3, 4, 5):
                ws.cell(row=r, column=c).fill = fill
        if es_factura:
            for c in range(1, len(encabezados) + 1):
                ws.cell(row=r, column=c).border = Border(left=thick, right=thick, top=thick, bottom=thick)

    # Autocompletar (lista desplegable) en la columna F, "Código nuevo
    # CONFIRMADO": al hacer clic en la celda aparece la flechita para elegir
    # de los 89 productos nuevos completos (buscando por nombre, no por el
    # código generado que no dice nada por sí solo) — así se escribe sin
    # errores de tipeo y siempre contra un producto que sí existe.
    dv = DataValidation(type="list", formula1="ListaProductosNuevos", allow_blank=True, showDropDown=False)
    dv.showInputMessage = True
    dv.showErrorMessage = True
    dv.error = 'Elija un producto de la lista (use la flecha de la celda).'
    dv.errorTitle = 'Producto no reconocido'
    dv.prompt = 'Escriba o busque el nombre del producto nuevo y elíjalo de la lista.'
    dv.promptTitle = 'Código nuevo CONFIRMADO'
    ws.add_data_validation(dv)
    dv.add(f"F2:F{total_filas}")

    # Tabla con autofiltro en EMPAREJAR.
    ultima_col = get_column_letter(len(encabezados))
    tabla = Table(displayName="Emparejamiento", ref=f"A1:{ultima_col}{total_filas}")
    tabla.tableStyleInfo = TableStyleInfo(
        name="TableStyleMedium2", showRowStripes=True, showFirstColumn=False)
    ws.add_table(tabla)

    ws_ant.add_table(Table(
        displayName="InventarioAnterior",
        ref=f"A1:{get_column_letter(len(enc_ant))}{len(anteriores) + 1}"))
    ws_act.add_table(Table(
        displayName="InventarioActual",
        ref=f"A1:{get_column_letter(len(enc_act))}{len(actuales) + 1}"))
    ws_mov.add_table(Table(
        displayName="MovimientosAnterior",
        ref=f"A1:{get_column_letter(len(enc_mov))}{len(movimientos) + 1}"))
    ws_mov.freeze_panes = "A2"

    # Nota explicativa arriba de la hoja principal (como comentario de la
    # primera celda, visible al pasar el mouse, y como fila de ayuda aparte).
    ws.cell(row=1, column=1).comment = None

    wb.save(OUT_PATH)
    print("Generado:", OUT_PATH)
    print("Total productos anteriores:", len(anteriores))
    print("Total productos actuales:", len(actuales))
    exactas = sum(1 for _, exacta, _ in filas_info if exacta)
    con_sugerencia = sum(1 for _, exacta, score in filas_info if not exacta and score > 0.70)
    en_blanco = sum(1 for _, exacta, score in filas_info if not exacta and score <= 0.70)
    print("En la hoja EMPAREJAR (los 121, todos por igual):", len(filas_info))
    print("  — con coincidencia EXACTA de nombre:", exactas)
    print("  — con sugerencia por parecido de texto (más de 70%):", con_sugerencia)
    print("  — sin sugerencia (70% o menos de parecido, columnas en blanco):", en_blanco)


if __name__ == "__main__":
    main()
