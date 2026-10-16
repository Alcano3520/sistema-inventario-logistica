#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera el Manual de Usuario del Sistema de Inventario Insevig en PDF,
con una ilustración por pantalla (generada en generar_mockups.py, sin
depender de capturas en vivo)."""

import os
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, ListFlowable, ListItem, HRFlowable, KeepTogether, Image,
)

PRIMARY = colors.HexColor("#1B3A5C")
TEXT_PRIMARY = colors.HexColor("#1A2634")
TEXT_SECONDARY = colors.HexColor("#64748B")
BORDER = colors.HexColor("#DFE4EA")

BASE = "/home/alcano/Documentos/mis_proyecto/Sistema de Inventario_logistica_2.0/docs"
SCREENS = os.path.join(BASE, "screens")
OUT_PATH = os.path.join(BASE, "Manual_de_Usuario_Insevig.pdf")

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="Portada", fontSize=27, leading=33, textColor=PRIMARY,
                           alignment=TA_CENTER, fontName="Helvetica-Bold", spaceAfter=8))
styles.add(ParagraphStyle(name="PortadaSub", fontSize=12.5, leading=17, textColor=TEXT_SECONDARY,
                           alignment=TA_CENTER, fontName="Helvetica"))
styles.add(ParagraphStyle(name="SeccionNum", fontSize=10, leading=12, textColor=colors.white,
                           fontName="Helvetica-Bold", alignment=TA_CENTER))
styles.add(ParagraphStyle(name="SeccionTitulo", fontSize=16, leading=20, textColor=PRIMARY,
                           fontName="Helvetica-Bold"))
styles.add(ParagraphStyle(name="Cuerpo", fontSize=10.5, leading=15, textColor=TEXT_PRIMARY,
                           fontName="Helvetica", spaceAfter=8, alignment=TA_LEFT))
styles.add(ParagraphStyle(name="Paso", fontSize=10.5, leading=15, textColor=TEXT_PRIMARY,
                           fontName="Helvetica"))
styles.add(ParagraphStyle(name="Pie", fontSize=9, leading=12, textColor=TEXT_SECONDARY,
                           fontName="Helvetica-Oblique"))
styles.add(ParagraphStyle(name="Figura", fontSize=8.5, leading=11, textColor=TEXT_SECONDARY,
                           fontName="Helvetica-Oblique", alignment=TA_CENTER, spaceBefore=3, spaceAfter=10))
styles.add(ParagraphStyle(name="TOCEntry", fontSize=10.5, leading=19, textColor=TEXT_PRIMARY,
                           fontName="Helvetica"))
styles.add(ParagraphStyle(name="Capitulo", fontSize=13, leading=16, textColor=PRIMARY,
                           fontName="Helvetica-Bold", spaceBefore=18, spaceAfter=8))

story = []

# ---------------------------------------------------------------- Portada --
story.append(Spacer(1, 5.5 * cm))
story.append(Table([[""]], colWidths=[2.6 * cm], rowHeights=[2.6 * cm],
                    style=TableStyle([("BACKGROUND", (0, 0), (-1, -1), PRIMARY),
                                       ("ROUNDEDCORNERS", [14, 14, 14, 14])])))
story.append(Spacer(1, 0.9 * cm))
story.append(Paragraph("Manual de Usuario", styles["Portada"]))
story.append(Paragraph("Sistema de Inventario y Logística — Insevig", styles["PortadaSub"]))
story.append(Spacer(1, 0.3 * cm))
story.append(Paragraph("Barcos · Motos · Taller · Dotación de Empleados", styles["PortadaSub"]))
story.append(Spacer(1, 2.6 * cm))
story.append(Paragraph("Octubre de 2026", styles["PortadaSub"]))
story.append(PageBreak())

toc = [
    "1. Antes de empezar", "2. Inicio de sesión", "3. Elegir el inventario con el que se va a trabajar",
    "4. Dashboard (pantalla de inicio)", "5. Registrar una entrada", "6. Registrar una salida",
    "7. Consultar el inventario",
    "8. Dar de alta o editar un producto", "9. Historial de movimientos", "10. Taller: repuestos y órdenes de trabajo",
    "11. Carga masiva de productos", "12. Administrar usuarios", "13. Mi perfil",
    "14. Particularidades del módulo de Dotación a Empleados",
]
story.append(Paragraph("Contenido", styles["Capitulo"]))
story.append(HRFlowable(width="100%", thickness=1, color=BORDER, spaceAfter=8))
for t in toc:
    story.append(Paragraph(t, styles["TOCEntry"]))
story.append(PageBreak())

story.append(Paragraph("1. Antes de empezar", styles["Capitulo"]))
story.append(HRFlowable(width="100%", thickness=1, color=BORDER, spaceAfter=10))
story.append(Paragraph(
    "Este documento explica, pantalla por pantalla, cómo usar el sistema que Insevig utiliza para "
    "llevar el inventario de Barcos, Motos y la dotación entregada a empleados. La idea es que sirva "
    "tanto para quien recién se incorpora como para resolver dudas puntuales más adelante.",
    styles["Cuerpo"]))
story.append(Paragraph(
    "Barcos y Motos funcionan exactamente igual por dentro — las mismas pantallas, los mismos "
    "botones — simplemente cada uno guarda su propia información por separado. El módulo de "
    "Dotación de Empleados es distinto, así que se trata aparte al final del documento.",
    styles["Cuerpo"]))
story.append(Paragraph(
    "Una aclaración importante: lo que una persona puede hacer depende de qué tipo de cuenta tiene. "
    "Hay tres tipos (más abajo se explican) y, dentro de uno de ellos, dos oficios distintos. Cuando "
    "algo solo lo puede hacer cierto tipo de cuenta, se lo aclara en el paso correspondiente.",
    styles["Cuerpo"]))
story.append(Spacer(1, 4))
story.append(Paragraph("Los tres tipos de cuenta, en palabras simples:", styles["Cuerpo"]))
roles = [
    "<b>Administrador</b> — puede hacer absolutamente todo en el sistema, incluyendo crear otras "
    "cuentas.",
    "<b>Encargado de Logística</b> — puede hacer casi todo, salvo tocar las cuentas de los "
    "Administradores.",
    "<b>Operador</b> — registra entradas, salidas y productos. Dentro de este grupo hay dos "
    "oficios: el <b>Bodeguero</b>, que trabaja con el inventario normalmente, y el "
    "<b>Mecánico</b>, que solo puede pedir repuestos (lo que en este manual se llama una "
    "“orden de trabajo”) y ver su propio perfil — no toca el resto del sistema.",
]
story.append(ListFlowable(
    [ListItem(Paragraph(r, styles["Cuerpo"]), leftIndent=14, spaceAfter=4) for r in roles],
    bulletType="bullet", leftIndent=18))
story.append(Spacer(1, 6))
story.append(Paragraph("Algunas palabras que se repiten en este manual:", styles["Cuerpo"]))
glosario = [
    "<b>Stock</b>: la cantidad de un producto que hay disponible en ese momento.",
    "<b>Código de barras</b>: las rayitas que trae un producto; se leen apuntando la cámara del "
    "celular o una pistola lectora, igual que en la caja de un supermercado.",
    "<b>PDF</b>: un tipo de archivo digital muy común para documentos (facturas, manuales, etc.) — "
    "se puede abrir y leer, pero no se edita como un Word.",
    "<b>Excel / CSV</b>: dos formas de guardar una lista de datos en una hoja de cálculo, para "
    "abrirla después en un computador y trabajarla ahí.",
    "<b>SRI</b>: el Servicio de Rentas Internas, la entidad del gobierno ecuatoriano que regula los "
    "impuestos y exige que las facturas electrónicas traigan una “clave de acceso” propia.",
    "<b>Factura electrónica</b>: la factura que en lugar de (o además de) papel, viene como un "
    "archivo digital (normalmente un PDF) con un código de barras propio del SRI.",
]
story.append(ListFlowable(
    [ListItem(Paragraph(g, styles["Cuerpo"]), leftIndent=14, spaceAfter=4) for g in glosario],
    bulletType="bullet", leftIndent=18))
story.append(Spacer(1, 6))
story.append(Paragraph(
    "Una última aclaración: en los pasos de este manual se usa la palabra “toque” para la acción de "
    "seleccionar algo en la pantalla — es lo mismo que hacer clic con el mouse si está usando un "
    "computador, o tocar con el dedo si está en un celular o tablet.",
    styles["Cuerpo"]))
story.append(Paragraph(
    "Las ilustraciones de cada pantalla que acompañan este manual son esquemas de referencia que "
    "reproducen fielmente el diseño real de la aplicación (textos, colores y disposición de los "
    "elementos); se usan en lugar de capturas de pantalla para poder documentar el sistema sin "
    "exponer datos de la empresa.",
    styles["Pie"]))
story.append(PageBreak())


def imagen(nombre, ancho=15.5 * cm):
    path = os.path.join(SCREENS, nombre)
    img = Image(path)
    ratio = img.imageHeight / float(img.imageWidth)
    img.drawWidth = ancho
    img.drawHeight = ancho * ratio
    img._restrictSize(ancho, 22 * cm)
    return img


def seccion(numero, titulo, parrafos, pasos, imagen_nombre, figura_pie, cierre=None):
    bloque = []
    header = Table(
        [[Paragraph(str(numero), styles["SeccionNum"]), Paragraph(titulo, styles["SeccionTitulo"])]],
        colWidths=[1.0 * cm, None],
        style=TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("BACKGROUND", (0, 0), (0, 0), PRIMARY),
            ("ROUNDEDCORNERS", [4, 4, 4, 4]),
            ("TOPPADDING", (0, 0), (0, 0), 4),
            ("BOTTOMPADDING", (0, 0), (0, 0), 4),
        ]))
    bloque.append(header)
    bloque.append(HRFlowable(width="100%", thickness=0.75, color=BORDER, spaceBefore=6, spaceAfter=8))
    story.append(KeepTogether(bloque))

    for p in parrafos:
        story.append(Paragraph(p, styles["Cuerpo"]))

    story.append(Spacer(1, 2))
    story.append(imagen(imagen_nombre))
    story.append(Paragraph(figura_pie, styles["Figura"]))

    items = [ListItem(Paragraph(p, styles["Paso"]), leftIndent=14, spaceAfter=4) for p in pasos]
    story.append(ListFlowable(items, bulletType="1", start="1", leftIndent=18))
    if cierre:
        story.append(Paragraph(cierre, styles["Pie"]))
    story.append(PageBreak())


# -------------------------------------------------------------- 2. Login --
seccion(
    2, "Inicio de sesión",
    ["Al abrir la aplicación, lo primero que se ve es el formulario de acceso. Ahí el sistema revisa "
     "que el usuario y la contraseña sean correctos antes de dejar entrar a la persona a cualquier "
     "inventario."],
    [
        "Abra la aplicación en el navegador (o en el celular, si está instalada ahí).",
        "Escriba su usuario o correo en el campo correspondiente.",
        "Escriba su contraseña.",
        "Toque <b>Iniciar sesión</b>.",
        "Si el usuario y la contraseña son correctos, el sistema pasa directo al selector de "
        "inventario.",
    ],
    "02_login.png", "Fig. 1 — Formulario de acceso.",
    cierre="Si todavía no tiene usuario, o perdió su contraseña, eso lo resuelve un Administrador o "
           "Encargado de Logística desde Gestión de Usuarios — no hay un “recuperar contraseña” "
           "automático.",
)

# ------------------------------------------------------------ 3. Selector --
seccion(
    3, "Elegir el inventario con el que se va a trabajar",
    ["Después de iniciar sesión aparece esta pantalla, con una tarjeta por cada inventario al que la "
     "persona tiene acceso. Un Administrador ve todos; un Operador solo ve los módulos que le hayan "
     "asignado."],
    [
        "Mire las tarjetas disponibles — cada una indica el nombre del inventario y si está "
        "“Disponible”.",
        "Toque la tarjeta del inventario que necesita (por ejemplo, Barcos).",
        "Eso lleva directo al Dashboard de ese módulo.",
        "Para cambiar de inventario después, use la flecha de volver en la pantalla donde esté.",
    ],
    "03_selector.png", "Fig. 2 — Selector de inventario, con las tarjetas de cada módulo.",
    cierre="Si no aparece ninguna tarjeta activa, el usuario no tiene módulos asignados todavía; hay "
           "que pedirle a un Administrador que los habilite.",
)

# ----------------------------------------------------------- 4. Dashboard --
seccion(
    4, "Dashboard (pantalla de inicio)",
    ["“Dashboard” es el nombre que usa el sistema para esta pantalla de inicio, la que resume todo "
     "de un vistazo: cuántos productos hay en total, cuántos tienen stock disponible, cuántos están "
     "agotados (en cero) y cuántos quedaron por debajo del mínimo que se definió para ese producto."],
    [
        "Se abre automáticamente al entrar a un módulo.",
        "Las cuatro tarjetas de arriba resumen el estado general del inventario; la de “Stock bajo” "
        "se resalta cuando hay algo que revisar.",
        "“Diagnóstico del sistema” sirve para comprobar que la conexión esté funcionando bien.",
        "“Gestionar duplicados” (solo para Administradores) ayuda a encontrar entradas o salidas "
        "cargadas dos veces por error.",
        "El menú de la izquierda (el ícono de las tres rayas) lleva a cualquier otra pantalla del "
        "módulo.",
    ],
    "04_dashboard.png", "Fig. 3 — Dashboard con los indicadores principales.",
)

# ------------------------------------------------------------- 5. Entrada --
seccion(
    5, "Registrar una entrada",
    ["Esta pantalla registra el ingreso de mercadería al inventario: una compra, una devolución de "
     "un proveedor, lo que sea. Se puede leer el PDF de la factura para que el sistema complete "
     "buena parte de los datos solo, y queda guardada la evidencia (firma y foto) de que la "
     "recepción ocurrió."],
    [
        "Entre a <b>Entrada</b> desde el menú.",
        "Si tiene a mano el archivo PDF de la factura (ya sea en el celular o guardado en el "
        "computador), toque <b>Leer factura</b> y selecciónelo — el sistema intenta completar "
        "proveedor, número de factura, clave de acceso SRI, fecha e ítems automáticamente. Conviene "
        "siempre revisar lo que detectó antes de seguir, porque no todas las facturas se leen igual "
        "de bien.",
        "Para cada ítem detectado, el sistema compara el código que trae la factura con el código "
        "interno y el código de barras de su catálogo: si coincide exacto con alguno, ese producto "
        "ya queda elegido solo (se marca con un “✓ Coincide”); si no coincide con nada, solo trae la "
        "descripción y hay que buscarlo a mano, como siempre.",
        "En “Productos”, agregue cada repuesto que está entrando: búsquelo o escanee el código de "
        "barras, y ponga la cantidad (y el precio, si lo tiene a mano).",
        "Confirme la fecha.",
        "Complete proveedor y número de factura — ambos son obligatorios, el sistema no deja avanzar "
        "sin ellos.",
        "Si la factura es electrónica, puede escanear o pegar la clave de acceso SRI de 49 dígitos.",
        "Opcionalmente, adjunte una foto de la factura física y dibuje la firma de quien recibió.",
        "Toque <b>Guardar Entrada</b>.",
    ],
    "05_entrada.png", "Fig. 4 — Registro de Entrada.",
    cierre="Proveedor y número de factura son obligatorios a propósito: toda compra tiene que quedar "
           "respaldada, sin excepción. El emparejamiento automático por código es intencionalmente "
           "estricto — solo actúa con una coincidencia exacta — para no arriesgar que una entrada "
           "quede cargada contra el producto equivocado.",
)

# -------------------------------------------------------------- 6. Salida --
seccion(
    6, "Registrar una salida",
    ["El reverso de la entrada: acá se registra lo que sale del inventario, por ejemplo repuestos "
     "entregados para una reparación o retirados por alguien. A diferencia de la entrada, la salida "
     "exige sí o sí una foto como evidencia del despacho."],
    [
        "Entre a <b>Salida</b>.",
        "Agregue cada producto que sale, con su cantidad.",
        "Confirme la fecha.",
        "Indique el bote o la moto al que corresponde, y quién lo retira (obligatorio).",
        "Describa el propósito, si quiere dejarlo anotado.",
        "Tome la foto de sustento — sin ella el sistema no guarda la salida, porque es la prueba de "
        "que el despacho realmente pasó.",
        "Si quien retira puede firmar en el momento, dibuje su firma.",
        "Toque <b>Guardar Salida</b>.",
    ],
    "06_salida.png", "Fig. 5 — Registro de Salida.",
    cierre="El sistema revisa el stock disponible antes de guardar: si no alcanza, avisa con un "
           "error y no deja registrar la salida.",
)

# ---------------------------------------------------------- 7. Inventario --
seccion(
    7, "Consultar el inventario",
    ["Lista todos los productos del módulo con su stock actual, marcando en colores los que están "
     "agotados o bajos. También es desde acá donde se descarga una copia del inventario completo "
     "para revisarla en un computador."],
    [
        "Entre a <b>Inventario</b>.",
        "Use el buscador para ubicar un producto puntual por código o nombre.",
        "Cada tarjeta muestra entradas y salidas acumuladas, el stock actual, y una etiqueta cuando "
        "está agotado o bajo mínimo.",
        "Toque un producto para ver su ficha completa, con todo su historial de movimientos "
        "ordenado del más antiguo al más reciente.",
        "Para descargar la lista completa, use alguno de los tres botones de arriba — “Exportar a "
        "Excel” o “Exportar a CSV” si la quiere seguir trabajando en una hoja de cálculo, o "
        "“Exportar a PDF” si solo la quiere imprimir o enviar para revisión.",
    ],
    "07_inventario.png", "Fig. 6 — Listado de inventario.",
)

# ----------------------------------------------------------- 8. Productos --
seccion(
    8, "Dar de alta o editar un producto",
    ["Acá se cargan productos nuevos al catálogo, o se busca y corrige uno existente. Tiene dos "
     "pestañas: “Registro rápido”, pensada para cargar varios productos seguidos escaneando el "
     "código de barras, y “Buscar / Editar”."],
    [
        "Entre a <b>Productos</b>.",
        "Para un producto nuevo: en “Registro rápido”, escanee el código de barras (o escríbalo), "
        "complete el nombre y la cantidad inicial de stock.",
        "“Más detalles” permite agregar categoría, ubicación, stock mínimo, y la factura o precio "
        "que respalda esa carga inicial, si corresponde.",
        "Toque <b>Guardar y escanear siguiente</b> para seguir cargando sin volver a empezar.",
        "Para editar uno existente, use “Buscar / Editar”, localícelo y abra su ficha.",
        "Si al escanear un código resulta que el producto ya existe, el sistema ofrece directamente "
        "corregir la cantidad en vez de crear uno duplicado.",
    ],
    "08_productos.png", "Fig. 7 — Registro de producto.",
    cierre="El único rol que no puede tocar esta pantalla es el Mecánico: solo consulta el catálogo "
           "para armar sus pedidos de repuestos.",
)

# --------------------------------------------------------- 9. Historial --
seccion(
    9, "Historial de movimientos",
    ["Reúne todas las entradas y salidas que se han registrado alguna vez. Arriba tiene tres "
     "pestañas (como las separaciones de una carpeta) para elegir qué ver: Entradas, Salidas, o "
     "“Por Factura” — esta última pensada para el área de contabilidad, que busca todo lo que entró "
     "bajo un número de factura, aunque haya quedado repartido en varios registros distintos."],
    [
        "Entre a <b>Historial</b>.",
        "Elija la pestaña que necesita: Entradas, Salidas o Por Factura.",
        "El buscador encuentra registros por número, proveedor o quien recibió.",
        "Los filtros de fecha (“Desde” / “Hasta”) y “Registrado por” acotan la lista — útiles para "
        "revisar lo que hizo una persona en particular en un período puntual.",
        "Toque cualquier registro para ver su detalle: productos, cantidades, firma y fotos.",
    ],
    "09_historial.png", "Fig. 8 — Historial con filtros de fecha y responsable.",
    cierre="El historial de un producto puntual también se puede ver desde su propia ficha en "
           "Inventario, ya ordenado del movimiento más antiguo al más reciente, con el total que va "
           "quedando después de cada uno — y con opción de descargarlo en Excel.",
)

# ------------------------------------------------------------- 10. Taller --
seccion(
    10, "Taller: repuestos y órdenes de trabajo",
    ["Solo existe en Barcos y Motos. Acá un Mecánico pide los repuestos que necesita para una "
     "reparación (una “orden de trabajo”), y el Bodeguero los despacha desde el inventario — con la "
     "posibilidad de recuperar después las piezas que resultaron reutilizables."],
    [
        "Entre a <b>Taller</b> (aparece como “Mis Pedidos” si el usuario es Mecánico).",
        "Para un pedido nuevo, elija el vehículo y anote el kilometraje u horas de motor actuales.",
        "Describa la falla; si ya tiene el repuesto dañado o el nuevo en mano, puede fotografiarlos.",
        "Toque <b>Crear OT</b> para enviar el pedido (OT son las siglas de “orden de trabajo”, el "
        "nombre que usa el sistema para cada pedido).",
        "El Bodeguero (o un Administrador) revisa el pedido y despacha el repuesto, dejando registro de ese despacho.",
        "Si una pieza retirada sirve todavía, se marca “Reutilizar” y vuelve al stock; si no, se da "
        "de baja.",
    ],
    "10_taller.png", "Fig. 9 — Órdenes de trabajo del Taller.",
)

# -------------------------------------------------- 11. Carga masiva --
seccion(
    11, "Carga masiva de productos",
    ["Pensada para cuando hay que cargar muchos productos de una sola vez — típicamente al arrancar "
     "un inventario nuevo — en lugar de registrarlos uno por uno."],
    [
        "Entre a <b>Carga Masiva</b> (visible solo para Administradores).",
        "Descargue la plantilla de ejemplo — un archivo Excel ya armado, con los títulos de cada "
        "columna listos para completar.",
        "Complete esa plantilla con un producto por línea, sin cambiar el orden de las columnas.",
        "Suba el archivo completado y revise el resumen que muestra el sistema: cuántos productos se "
        "cargaron bien y cuáles tuvieron algún error, antes de dar por terminada la carga.",
    ],
    "11_carga_masiva.png", "Fig. 10 — Carga masiva de productos.",
    cierre="Si después hace falta corregir datos ya cargados, la herramienta de Migración (en el "
           "mismo menú) sirve para eso.",
)

# --------------------------------------------------- 12. Usuarios --
seccion(
    12, "Administrar usuarios",
    ["Acá se crean las cuentas del sistema y se define qué puede hacer cada una: su tipo de cuenta "
     "(Administrador, Encargado de Logística u Operador), su oficio si es Operador (Bodeguero o "
     "Mecánico), y a qué inventarios (Barcos, Motos, etc.) va a poder entrar."],
    [
        "Entre a <b>Usuarios</b> (solo para Administradores y Encargados de Logística).",
        "Toque <b>Nuevo Usuario</b>.",
        "Complete el nombre, el nombre de usuario, el correo y una contraseña inicial para esa "
        "persona.",
        "Elija su tipo de cuenta — Administrador, Encargado de Logística u Operador — y, si es "
        "Operador, si es Bodeguero o Mecánico.",
        "Marque los inventarios a los que va a tener acceso.",
        "Guarde con <b>Crear</b>.",
        "Para editar a alguien o cambiarle la contraseña más adelante, tóquelo en la lista.",
    ],
    "12_usuarios.png", "Fig. 11 — Gestión de usuarios.",
    cierre="Un Encargado de Logística puede administrar cuentas de Operador, pero nunca cuentas de "
           "Administrador — eso queda reservado a los propios Administradores, y ni ellos pueden "
           "cambiar la contraseña de otro Administrador, salvo la del principal del sistema.",
)

# ----------------------------------------------------------- 13. Perfil --
seccion(
    13, "Mi perfil",
    ["La pantalla personal de cada cuenta: nombre, rol, módulos asignados, y el botón para cerrar "
     "sesión."],
    [
        "Entre a <b>Mi Perfil</b> desde el menú.",
        "Revise que sus datos sean correctos.",
        "Toque <b>Salir</b> para cerrar sesión al terminar de usar el sistema.",
    ],
    "13_perfil.png", "Fig. 12 — Mi Perfil.",
)

story.pop()  # quita el último PageBreak sobrante antes del anexo

# --------------------------------------------- 14. Anexo Dotación --
story.append(Paragraph("14. Particularidades del módulo de Dotación a Empleados", styles["Capitulo"]))
story.append(HRFlowable(width="100%", thickness=1, color=BORDER, spaceAfter=10))
story.append(Paragraph(
    "Este módulo entrega artículos al personal (uniformes, equipo de trabajo, etc.) en lugar de "
    "repuestos, y por eso usa otras palabras: donde Barcos y Motos dicen “Entrada” y “Salida”, acá "
    "se dice “Entregas” y “Devoluciones”. El sistema también puede descontar el valor del artículo "
    "del sueldo del empleado (descuento por nómina), y permite registrar la devolución de un "
    "artículo indicando en qué estado vuelve.",
    styles["Cuerpo"]))
story.append(Paragraph(
    "“Entregas” registra lo que recibe un empleado; “Devoluciones”, lo que devuelve, marcando si "
    "quedó en buen estado, con uso parcial, o si hay que darlo de baja (dejarlo fuera de uso). El "
    "resto de las pantallas — Dashboard, Inventario, Artículos, Historial, Carga Masiva — funcionan "
    "igual que en Barcos y Motos, solo que con este otro vocabulario.",
    styles["Cuerpo"]))
story.append(Paragraph(
    "Una diferencia importante: “Correcciones” solo permite editar o anular una entrega o salida "
    "dentro de los <b>3 días</b> posteriores al movimiento. Pasado ese plazo, cualquier ajuste debe "
    "hacerse como un movimiento nuevo — no se reescribe el historial.",
    styles["Cuerpo"]))

doc = SimpleDocTemplate(
    OUT_PATH, pagesize=A4,
    leftMargin=2.2 * cm, rightMargin=2.2 * cm, topMargin=2 * cm, bottomMargin=2 * cm,
    title="Manual de Usuario - Sistema de Inventario Insevig", author="Insevig")


def pie_pagina(canvas, doc_):
    canvas.saveState()
    canvas.setStrokeColor(BORDER)
    canvas.line(2.2 * cm, 1.4 * cm, A4[0] - 2.2 * cm, 1.4 * cm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(TEXT_SECONDARY)
    canvas.drawString(2.2 * cm, 1.0 * cm, "Sistema de Inventario y Logística — Insevig")
    canvas.drawRightString(A4[0] - 2.2 * cm, 1.0 * cm, f"Página {doc_.page}")
    canvas.restoreState()


doc.build(story, onFirstPage=pie_pagina, onLaterPages=pie_pagina)
print("PDF generado en:", OUT_PATH)
