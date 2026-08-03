/**
 * Sistema de Gestión de Inventario - Google Apps Script
 * Versión: 2.0 - CON SEGURIDAD MEJORADA
 *
 * Mejoras de seguridad:
 * - Login con usuario y contraseña
 * - Contraseñas en texto plano (editable por admin en la hoja)
 * - Protección de hojas para usuarios normales
 * - Sistema de sesiones
 * - Campo BOTE para rastrear salidas por embarcación
 */

// ==========================================
// CONFIGURACIÓN GLOBAL
// ==========================================

const SHEET_NAMES = {
  PRODUCTOS: 'Base de Datos de Repuestos',
  TRANS_ENTRADA: 'TransaccionesEntrada',
  DETALLE_ENTRADA: 'DetalleEntradas',
  TRANS_SALIDA: 'TransaccionesSalida',
  DETALLE_SALIDA: 'DetalleSalidas',
  USUARIOS: 'Usuarios'
};

const ROLES = {
  ADMIN: 'Admin',
  OPERADOR: 'Operador'
};

/**
 * Función de prueba simple para verificar conectividad
 */
function pruebaSimple() {
  Logger.log('pruebaSimple ejecutada correctamente');
  return {mensaje: 'Hola desde el backend', timestamp: new Date().toString()};
}

/**
 * FUNCIÓN DE DIAGNÓSTICO - Ejecuta esto manualmente para ver qué está pasando
 * Ve a Extensiones > Apps Script > Selecciona esta función > Ejecutar
 */
function diagnosticarSistema() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let reporte = '=== DIAGNÓSTICO DEL SISTEMA ===\n\n';

  // Verificar todas las hojas
  reporte += '1. HOJAS EXISTENTES:\n';
  const todasLasHojas = ss.getSheets();
  todasLasHojas.forEach(hoja => {
    reporte += `   - ${hoja.getName()} (${hoja.getLastRow()} filas)\n`;
  });

  // Verificar hojas esperadas
  reporte += '\n2. HOJAS ESPERADAS:\n';
  for (let key in SHEET_NAMES) {
    const nombreHoja = SHEET_NAMES[key];
    const hoja = ss.getSheetByName(nombreHoja);
    if (hoja) {
      reporte += `   ✅ ${nombreHoja}: ${hoja.getLastRow()} filas, ${hoja.getLastColumn()} columnas\n`;

      // Mostrar encabezados
      if (hoja.getLastRow() > 0) {
        const encabezados = hoja.getRange(1, 1, 1, hoja.getLastColumn()).getValues()[0];
        reporte += `      Columnas: ${encabezados.join(', ')}\n`;
      }
    } else {
      reporte += `   ❌ ${nombreHoja}: NO EXISTE\n`;
    }
  }

  // Verificar transacciones
  reporte += '\n3. DATOS DE TRANSACCIONES:\n';
  const sheetTransEntrada = ss.getSheetByName(SHEET_NAMES.TRANS_ENTRADA);
  if (sheetTransEntrada && sheetTransEntrada.getLastRow() > 1) {
    const numCols = sheetTransEntrada.getLastColumn();
    const datos = sheetTransEntrada.getRange(2, 1, Math.min(5, sheetTransEntrada.getLastRow() - 1), numCols).getValues();
    reporte += `   Primeras entradas (${numCols} columnas):\n`;
    datos.forEach(row => {
      reporte += `   - ID: ${row[0]}, Fecha: ${row[1]}, Proveedor: ${row[2]}\n`;
    });
  } else {
    reporte += '   ⚠️ No hay transacciones de entrada\n';
  }

  // NUEVO: Probar la función obtenerHistorialEntradas
  reporte += '\n4. PRUEBA DE obtenerHistorialEntradas():\n';
  try {
    const resultado = obtenerHistorialEntradas({});
    reporte += `   ✅ Resultado: ${Array.isArray(resultado) ? resultado.length + ' transacciones' : 'ERROR - no es array'}\n`;
    if (Array.isArray(resultado) && resultado.length > 0) {
      reporte += `   Primera transacción:\n`;
      reporte += `      - ID: ${resultado[0].idTransaccion}\n`;
      reporte += `      - Fecha: ${resultado[0].fechaHora}\n`;
      reporte += `      - Proveedor: ${resultado[0].proveedor}\n`;
      reporte += `      - Items: ${resultado[0].items ? resultado[0].items.length : 0}\n`;
    }
  } catch (error) {
    reporte += `   ❌ ERROR: ${error.message}\n`;
    reporte += `   Stack: ${error.stack}\n`;
  }

  Logger.log(reporte);
  return reporte;
}

// ==========================================
// FUNCIONES DE MENÚ Y UI
// ==========================================

function onOpen() {
  try {
    const ui = SpreadsheetApp.getUi();
    ui.createMenu('📦 Sistema de Inventario')
      .addItem('🚀 Abrir Sistema', 'mostrarInterfaz')
      .addSeparator()
      .addItem('⚙️ Inicializar Hojas', 'inicializarHojas')
      .addItem('🔒 Proteger Hojas', 'protegerHojas')
      .addItem('🔓 Desproteger Hojas (Admin)', 'desprotegerHojas')
      .addToUi();
  } catch (error) {
    // Ignorar error cuando se llama desde contexto de web app
    Logger.log('onOpen() no disponible en este contexto: ' + error.message);
  }
}

/**
 * Función para acceso web directo
 * Esta función permite abrir la aplicación desde una URL
 */
function doGet() {
  const html = HtmlService.createTemplateFromFile('Index')
    .evaluate()
    .setTitle('Sistema de Inventario de Botes')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');

  return html;
}

function mostrarInterfaz() {
  try {
    const html = HtmlService.createTemplateFromFile('Index')
      .evaluate()
      .setTitle('Sistema de Inventario')
      .setWidth(400);
    SpreadsheetApp.getUi().showSidebar(html);
  } catch (error) {
    Logger.log('mostrarInterfaz() error: ' + error.message);
  }
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

// ==========================================
// SEGURIDAD - ENCRIPTACIÓN
// ==========================================

/**
 * Genera un hash SHA-256 de una contraseña
 */
function encriptarPassword(password) {
  const rawHash = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    password,
    Utilities.Charset.UTF_8
  );

  // Convertir a string hexadecimal
  let hash = '';
  for (let i = 0; i < rawHash.length; i++) {
    let byte = rawHash[i];
    if (byte < 0) byte += 256;
    let byteString = byte.toString(16);
    if (byteString.length === 1) byteString = '0' + byteString;
    hash += byteString;
  }

  return hash;
}

/**
 * Verifica si una contraseña coincide con su hash
 */
function verificarPassword(password, hash) {
  return encriptarPassword(password) === hash;
}

// ==========================================
// SISTEMA DE SESIONES
// ==========================================

/**
 * Guarda la sesión del usuario actual
 */
function guardarSesion(usuario) {
  const userProperties = PropertiesService.getUserProperties();
  userProperties.setProperty('sesionActiva', 'true');
  userProperties.setProperty('usuarioEmail', usuario.email);
  userProperties.setProperty('usuarioNombre', usuario.nombre);
  userProperties.setProperty('usuarioRol', usuario.rol);
  userProperties.setProperty('sesionInicio', new Date().getTime().toString());
}

/**
 * Obtiene la sesión actual
 */
function obtenerSesion() {
  const userProperties = PropertiesService.getUserProperties();
  const sesionActiva = userProperties.getProperty('sesionActiva');

  if (sesionActiva === 'true') {
    // Verificar que la sesión no haya expirado (24 horas)
    const sesionInicio = parseInt(userProperties.getProperty('sesionInicio') || '0');
    const ahora = new Date().getTime();
    const EXPIRACION = 24 * 60 * 60 * 1000; // 24 horas

    if (ahora - sesionInicio > EXPIRACION) {
      cerrarSesion();
      return null;
    }

    return {
      email: userProperties.getProperty('usuarioEmail'),
      nombre: userProperties.getProperty('usuarioNombre'),
      rol: userProperties.getProperty('usuarioRol')
    };
  }

  return null;
}

/**
 * Cierra la sesión actual
 */
function cerrarSesion() {
  const userProperties = PropertiesService.getUserProperties();
  userProperties.deleteAllProperties();
  return { success: true, message: 'Sesión cerrada exitosamente' };
}

// ==========================================
// AUTENTICACIÓN CON USUARIO Y CONTRASEÑA
// ==========================================

/**
 * Autentica un usuario con email/usuario y contraseña
 */
function autenticarUsuario(emailOUsuario, password) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET_NAMES.USUARIOS);

    if (!sheet) {
      return { error: 'Sistema no inicializado. Contacte al administrador.' };
    }

    const datos = sheet.getDataRange().getValues();

    // Buscar usuario por email O por nombre de usuario
    for (let i = 1; i < datos.length; i++) {
      const email = datos[i][0];
      const usuario = datos[i][3];

      // Comparar con email o usuario (case insensitive)
      if (email.toLowerCase() === emailOUsuario.toLowerCase() ||
          usuario.toLowerCase() === emailOUsuario.toLowerCase()) {

        // Verificar si está activo
        if (datos[i][4] !== true) {
          return { error: 'Usuario inactivo. Contacte al administrador.' };
        }

        // Verificar contraseña (comparación directa sin hash)
        const passwordGuardada = datos[i][5];
        if (password === passwordGuardada) {
          const usuarioData = {
            email: datos[i][0],
            nombre: datos[i][1],
            rol: datos[i][2],
            activo: datos[i][4]
          };

          // Guardar sesión
          guardarSesion(usuarioData);

          return {
            success: true,
            usuario: usuarioData
          };
        } else {
          return { error: 'Contraseña incorrecta.' };
        }
      }
    }

    return { error: 'Usuario no encontrado.' };

  } catch (error) {
    return { error: 'Error de autenticación: ' + error.message };
  }
}

/**
 * Obtiene el usuario actual (desde sesión)
 */
function obtenerUsuarioActual() {
  const sesion = obtenerSesion();

  if (!sesion) {
    return { error: 'Sesión no válida. Debe iniciar sesión.' };
  }

  return sesion;
}

/**
 * Verifica si el usuario actual es administrador
 */
function esAdministrador() {
  const usuario = obtenerUsuarioActual();
  return !usuario.error && usuario.rol === ROLES.ADMIN;
}

// ==========================================
// INICIALIZACIÓN DE HOJAS
// ==========================================

function inicializarHojas() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // Base de Datos de Repuestos
  crearOActualizarHoja(ss, SHEET_NAMES.PRODUCTOS, [
    'COD', 'PRODUCTO', 'ENTRADA', 'SALIDA', 'STOCK', 'CATEGORIA', 'UBICACION', 'STOCK_MINIMO'
  ]);

  // Transacciones de Entrada (Cabecera)
  crearOActualizarHoja(ss, SHEET_NAMES.TRANS_ENTRADA, [
    'ID_TRANSACCION', 'FECHA_HORA', 'PROVEEDOR', 'NUM_FACTURA_OC',
    'USUARIO_REGISTRA', 'OBSERVACIONES', 'FIRMA_RECEPCION'
  ]);

  // Detalle de Entradas
  crearOActualizarHoja(ss, SHEET_NAMES.DETALLE_ENTRADA, [
    'ID_TRANSACCION', 'COD', 'PRODUCTO', 'CANTIDAD'
  ]);

  // Transacciones de Salida (Cabecera)
  crearOActualizarHoja(ss, SHEET_NAMES.TRANS_SALIDA, [
    'ID_TRANSACCION', 'FECHA_HORA', 'BOTE', 'A_QUIEN_ENTREGA', 'PROPOSITO_SALIDA',
    'USUARIO_REGISTRA', 'FIRMA_ENTREGA'
  ]);

  // Detalle de Salidas
  crearOActualizarHoja(ss, SHEET_NAMES.DETALLE_SALIDA, [
    'ID_TRANSACCION', 'COD', 'PRODUCTO', 'CANTIDAD'
  ]);

  // Usuarios (con campo de contraseña)
  crearOActualizarHoja(ss, SHEET_NAMES.USUARIOS, [
    'EMAIL', 'NOMBRE_COMPLETO', 'ROL', 'USUARIO', 'ACTIVO', 'PASSWORD', 'FECHA_CREACION'
  ]);

  // Crear usuario admin por defecto si no existe
  crearUsuarioAdminPorDefecto();

  try {
    SpreadsheetApp.getUi().alert('✅ Hojas inicializadas correctamente.\n\n⚠️ IMPORTANTE:\n\nUsuario Admin creado:\nEmail: ' + Session.getActiveUser().getEmail() + '\nUsuario: admin\nContraseña: admin123\n\n🔴 Puede cambiar la contraseña desde Mi Perfil o editando la hoja Usuarios');
  } catch (error) {
    Logger.log('No se puede mostrar alerta: ' + error.message);
  }
}

function crearOActualizarHoja(ss, nombreHoja, encabezados) {
  let sheet = ss.getSheetByName(nombreHoja);

  if (!sheet) {
    sheet = ss.insertSheet(nombreHoja);
  }

  // Si la hoja está vacía, agregar encabezados
  if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, encabezados.length).setValues([encabezados]);
    sheet.getRange(1, 1, 1, encabezados.length).setFontWeight('bold');
    sheet.setFrozenRows(1);
  }
}

/**
 * Crea un usuario administrador por defecto
 */
function crearUsuarioAdminPorDefecto() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.USUARIOS);

  // Si ya hay usuarios, no hacer nada
  if (sheet.getLastRow() > 1) {
    return;
  }

  const email = Session.getActiveUser().getEmail();
  const passwordDefault = 'admin123'; // Contraseña por defecto (sin hash)

  // Agregar usuario admin por defecto
  sheet.appendRow([
    email,
    'Administrador del Sistema',
    ROLES.ADMIN,
    'admin',
    true,
    passwordDefault,
    new Date()
  ]);
}

// ==========================================
// PROTECCIÓN DE HOJAS
// ==========================================

/**
 * Protege todas las hojas excepto para el propietario
 */
function protegerHojas() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const hojas = ss.getSheets();

  hojas.forEach(sheet => {
    // Solo proteger si no está ya protegida
    const protections = sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET);

    if (protections.length === 0) {
      const protection = sheet.protect();
      protection.setDescription('Protección del sistema de inventario');

      // Solo el propietario puede editar
      protection.removeEditors(protection.getEditors());

      // Advertencia para usuarios sin permisos
      protection.setWarningOnly(false);
    }
  });

  try {
    SpreadsheetApp.getUi().alert('✅ Hojas protegidas. Solo el administrador puede ver/editar directamente.');
  } catch (error) {
    Logger.log('No se puede mostrar alerta: ' + error.message);
  }
}

/**
 * Desprotege todas las hojas (solo admin)
 */
function desprotegerHojas() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const hojas = ss.getSheets();

  hojas.forEach(sheet => {
    const protections = sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET);
    protections.forEach(protection => {
      if (protection.canEdit()) {
        protection.remove();
      }
    });
  });

  try {
    SpreadsheetApp.getUi().alert('✅ Hojas desprotegidas.');
  } catch (error) {
    Logger.log('No se puede mostrar alerta: ' + error.message);
  }
}

// ==========================================
// GESTIÓN DE USUARIOS
// ==========================================

function obtenerTodosLosUsuarios() {
  if (!esAdministrador()) {
    return { error: 'Acceso denegado. Solo administradores.' };
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.USUARIOS);
  const datos = sheet.getDataRange().getValues();

  const usuarios = [];
  for (let i = 1; i < datos.length; i++) {
    // Convertir fecha a string para evitar problemas de serialización
    let fechaStr = '';
    if (datos[i][6]) {
      try {
        const fecha = new Date(datos[i][6]);
        if (!isNaN(fecha.getTime())) {
          fechaStr = fecha.toISOString();
        } else {
          fechaStr = String(datos[i][6]);
        }
      } catch (e) {
        fechaStr = String(datos[i][6]);
      }
    }

    usuarios.push({
      email: String(datos[i][0] || ''),
      nombre: String(datos[i][1] || ''),
      rol: String(datos[i][2] || ''),
      usuario: String(datos[i][3] || ''),
      activo: Boolean(datos[i][4]),
      fechaCreacion: fechaStr
    });
  }

  return usuarios;
}

/**
 * Crea un nuevo usuario con contraseña
 */
function crearUsuario(email, nombre, rol, usuario, password) {
  if (!esAdministrador()) {
    return { error: 'Acceso denegado. Solo administradores pueden crear usuarios.' };
  }

  // Validaciones
  if (!email || !nombre || !rol || !usuario || !password) {
    return { error: 'Todos los campos son requeridos.' };
  }

  if (rol !== ROLES.ADMIN && rol !== ROLES.OPERADOR) {
    return { error: 'Rol inválido.' };
  }

  if (password.length < 6) {
    return { error: 'La contraseña debe tener al menos 6 caracteres.' };
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.USUARIOS);
  const datos = sheet.getDataRange().getValues();

  // Verificar si el email o usuario ya existe
  for (let i = 1; i < datos.length; i++) {
    if (datos[i][0] === email) {
      return { error: 'El email ya existe.' };
    }
    if (datos[i][3] === usuario) {
      return { error: 'El nombre de usuario ya existe.' };
    }
  }

  // Guardar contraseña directamente (sin encriptar)
  // Agregar nuevo usuario
  sheet.appendRow([email, nombre, rol, usuario, true, password, new Date()]);

  return { success: true, message: 'Usuario creado exitosamente.' };
}

/**
 * Cambia la contraseña de un usuario
 */
function cambiarPassword(email, passwordAntiguo, passwordNuevo) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.USUARIOS);
  const datos = sheet.getDataRange().getValues();

  for (let i = 1; i < datos.length; i++) {
    if (datos[i][0] === email) {
      // Verificar contraseña antigua (comparación directa)
      if (passwordAntiguo !== datos[i][5]) {
        return { error: 'Contraseña antigua incorrecta.' };
      }

      if (passwordNuevo.length < 6) {
        return { error: 'La nueva contraseña debe tener al menos 6 caracteres.' };
      }

      // Actualizar contraseña (sin encriptar)
      sheet.getRange(i + 1, 6).setValue(passwordNuevo);

      return { success: true, message: 'Contraseña actualizada exitosamente.' };
    }
  }

  return { error: 'Usuario no encontrado.' };
}

/**
 * Restablece la contraseña de un usuario (solo admin)
 */
function restablecerPassword(email, passwordNuevo) {
  if (!esAdministrador()) {
    return { error: 'Acceso denegado. Solo administradores.' };
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.USUARIOS);
  const datos = sheet.getDataRange().getValues();

  for (let i = 1; i < datos.length; i++) {
    if (datos[i][0] === email) {
      if (passwordNuevo.length < 6) {
        return { error: 'La contraseña debe tener al menos 6 caracteres.' };
      }

      // Guardar contraseña directamente (sin encriptar)
      sheet.getRange(i + 1, 6).setValue(passwordNuevo);

      return { success: true, message: 'Contraseña restablecida exitosamente.' };
    }
  }

  return { error: 'Usuario no encontrado.' };
}

function actualizarUsuario(email, nombre, rol, activo) {
  if (!esAdministrador()) {
    return { error: 'Acceso denegado. Solo administradores.' };
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.USUARIOS);
  const datos = sheet.getDataRange().getValues();

  for (let i = 1; i < datos.length; i++) {
    if (datos[i][0] === email) {
      if (nombre) sheet.getRange(i + 1, 2).setValue(nombre);
      if (rol) sheet.getRange(i + 1, 3).setValue(rol);
      if (activo !== undefined) sheet.getRange(i + 1, 5).setValue(activo);
      return { success: true, message: 'Usuario actualizado exitosamente.' };
    }
  }

  return { error: 'Usuario no encontrado.' };
}

function eliminarUsuario(email) {
  if (!esAdministrador()) {
    return { error: 'Acceso denegado. Solo administradores.' };
  }

  const usuarioActual = obtenerUsuarioActual();
  if (usuarioActual.email === email) {
    return { error: 'No puedes eliminar tu propio usuario.' };
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.USUARIOS);
  const datos = sheet.getDataRange().getValues();

  for (let i = 1; i < datos.length; i++) {
    if (datos[i][0] === email) {
      sheet.deleteRow(i + 1);
      return { success: true, message: 'Usuario eliminado exitosamente.' };
    }
  }

  return { error: 'Usuario no encontrado.' };
}

// ==========================================
// GESTIÓN DE PRODUCTOS (mismo código)
// ==========================================

function obtenerProductos() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

  if (!sheet || sheet.getLastRow() < 2) {
    return [];
  }

  const datos = sheet.getRange(2, 1, sheet.getLastRow() - 1, 8).getValues();

  return datos.map(row => ({
    cod: row[0],
    producto: row[1],
    entrada: row[2] || 0,
    salida: row[3] || 0,
    stock: row[4] || 0,
    categoria: row[5] || '',
    ubicacion: row[6] || '',
    stockMinimo: row[7] || 0
  }));
}

function buscarProductos(termino) {
  const productos = obtenerProductos();

  if (!termino) {
    return productos;
  }

  termino = termino.toLowerCase();

  return productos.filter(p =>
    p.cod.toString().toLowerCase().includes(termino) ||
    p.producto.toLowerCase().includes(termino)
  );
}

function obtenerProductoPorCodigo(codigo) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);
  const datos = sheet.getDataRange().getValues();

  for (let i = 1; i < datos.length; i++) {
    if (datos[i][0].toString() === codigo.toString()) {
      return {
        cod: datos[i][0],
        producto: datos[i][1],
        entrada: datos[i][2] || 0,
        salida: datos[i][3] || 0,
        stock: datos[i][4] || 0,
        categoria: datos[i][5] || '',
        ubicacion: datos[i][6] || '',
        stockMinimo: datos[i][7] || 0,
        fila: i + 1
      };
    }
  }

  return null;
}

function cargarProductosMasivos(datosCSV) {
  if (!esAdministrador()) {
    return { error: 'Solo administradores pueden realizar cargas masivas.' };
  }

  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

    let agregados = 0;
    let actualizados = 0;
    let errores = [];

    for (let i = 0; i < datosCSV.length; i++) {
      const row = datosCSV[i];
      const cod = row[0];
      const producto = row[1];
      const categoria = row[2] || '';
      const ubicacion = row[3] || '';
      const stockMinimo = row[4] || 0;

      if (!cod || !producto) {
        errores.push(`Fila ${i + 1}: Código y producto son requeridos`);
        continue;
      }

      const productoExistente = obtenerProductoPorCodigo(cod);

      if (productoExistente) {
        sheet.getRange(productoExistente.fila, 2).setValue(producto);
        sheet.getRange(productoExistente.fila, 6).setValue(categoria);
        sheet.getRange(productoExistente.fila, 7).setValue(ubicacion);
        sheet.getRange(productoExistente.fila, 8).setValue(stockMinimo);
        actualizados++;
      } else {
        sheet.appendRow([cod, producto, 0, 0, 0, categoria, ubicacion, stockMinimo]);
        agregados++;
      }
    }

    return {
      success: true,
      agregados: agregados,
      actualizados: actualizados,
      errores: errores
    };

  } catch (error) {
    return { error: 'Error en carga masiva: ' + error.message };
  }
}

/**
 * Agregar un producto individual
 */
function agregarProducto(cod, producto, categoria, ubicacion, stockMinimo) {
  if (!esAdministrador()) {
    return { error: 'Solo administradores pueden agregar productos.' };
  }

  // Validaciones
  if (!cod || !producto) {
    return { error: 'Código y nombre de producto son requeridos.' };
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

  // Verificar si ya existe
  const productoExistente = obtenerProductoPorCodigo(cod);
  if (productoExistente) {
    return { error: `El producto con código ${cod} ya existe.` };
  }

  // Agregar nuevo producto
  sheet.appendRow([
    cod,
    producto,
    0, // ENTRADA inicial
    0, // SALIDA inicial
    0, // STOCK inicial
    categoria || '',
    ubicacion || '',
    stockMinimo || 5
  ]);

  return {
    success: true,
    message: `Producto ${cod} - ${producto} agregado exitosamente.`
  };
}

// ==========================================
// REGISTRO DE ENTRADAS (mismo código)
// ==========================================

function registrarEntrada(datos) {
  try {
    const usuario = obtenerUsuarioActual();
    if (usuario.error) {
      return { error: usuario.error };
    }

    if (!datos.items || datos.items.length === 0) {
      return { error: 'Debe agregar al menos un ítem.' };
    }

    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetTransacciones = ss.getSheetByName(SHEET_NAMES.TRANS_ENTRADA);
    const sheetDetalle = ss.getSheetByName(SHEET_NAMES.DETALLE_ENTRADA);
    const sheetProductos = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

    const idTransaccion = 'ENT-' + new Date().getTime();
    // Usar fecha del formulario si está disponible, sino usar fecha actual
    const fechaHora = datos.fecha ? new Date(datos.fecha + 'T12:00:00') : new Date();

    sheetTransacciones.appendRow([
      idTransaccion,
      fechaHora,
      datos.proveedor || '',
      datos.numFactura || '',
      usuario.nombre,
      datos.observaciones || '',
      datos.firma || ''
    ]);

    for (let item of datos.items) {
      let producto = obtenerProductoPorCodigo(item.cod);

      // Si el producto no existe, CREARLO automáticamente
      if (!producto) {
        // Crear el producto nuevo con el nombre proporcionado en el item
        const nombreProducto = item.producto || item.nombre || `Producto ${item.cod}`;
        sheetProductos.appendRow([
          item.cod,        // COD
          nombreProducto,  // PRODUCTO
          0,               // ENTRADA (se actualizará abajo)
          0,               // SALIDA
          0,               // STOCK (se actualizará abajo)
          '',              // CATEGORIA
          '',              // UBICACION
          5                // STOCK_MINIMO por defecto
        ]);
        Logger.log(`Producto nuevo creado automáticamente en entrada: ${item.cod} - ${nombreProducto}`);
        // Obtener el producto recién creado
        producto = obtenerProductoPorCodigo(item.cod);
      }

      sheetDetalle.appendRow([
        idTransaccion,
        item.cod,
        producto.producto,
        item.cantidad
      ]);

      const nuevaEntrada = (producto.entrada || 0) + parseFloat(item.cantidad);
      const nuevoStock = (producto.stock || 0) + parseFloat(item.cantidad);

      sheetProductos.getRange(producto.fila, 3).setValue(nuevaEntrada);
      sheetProductos.getRange(producto.fila, 5).setValue(nuevoStock);
    }

    return {
      success: true,
      message: 'Entrada registrada exitosamente.',
      idTransaccion: idTransaccion
    };

  } catch (error) {
    return { error: 'Error al registrar entrada: ' + error.message };
  }
}

function obtenerHistorialEntradas(filtros) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetTransacciones = ss.getSheetByName(SHEET_NAMES.TRANS_ENTRADA);
    const sheetDetalle = ss.getSheetByName(SHEET_NAMES.DETALLE_ENTRADA);

    if (!sheetTransacciones) {
      return [];
    }

    if (!sheetDetalle) {
      return [];
    }

    const lastRow = sheetTransacciones.getLastRow();
    if (lastRow < 2) {
      return [];
    }

    // Leer solo las primeras 6 columnas (sin firma)
    const datosTransacciones = sheetTransacciones.getRange(2, 1, lastRow - 1, 6).getValues();

    const datosDetalle = sheetDetalle.getLastRow() > 1 ?
      sheetDetalle.getRange(2, 1, sheetDetalle.getLastRow() - 1, 4).getValues() : [];

    const transacciones = [];

    for (let i = 0; i < datosTransacciones.length; i++) {
      const row = datosTransacciones[i];
      const idTransaccion = String(row[0] || '');

      // Obtener items de esta transacción
      const items = [];
      for (let j = 0; j < datosDetalle.length; j++) {
        if (String(datosDetalle[j][0]) === idTransaccion) {
          items.push({
            cod: String(datosDetalle[j][1] || ''),
            producto: String(datosDetalle[j][2] || ''),
            cantidad: Number(datosDetalle[j][3]) || 0
          });
        }
      }

      // Convertir fecha a string
      let fechaStr = '';
      if (row[1]) {
        try {
          const fecha = new Date(row[1]);
          if (!isNaN(fecha.getTime())) {
            fechaStr = fecha.toISOString();
          } else {
            fechaStr = String(row[1]);
          }
        } catch (e) {
          fechaStr = String(row[1]);
        }
      }

      transacciones.push({
        idTransaccion: idTransaccion,
        fechaHora: fechaStr,
        proveedor: String(row[2] || ''),
        numFactura: String(row[3] || ''),
        usuario: String(row[4] || ''),
        observaciones: String(row[5] || ''),
        items: items
      });
    }

    if (filtros && filtros.busqueda) {
      const termino = filtros.busqueda.toLowerCase();
      const filtradas = transacciones.filter(function(t) {
        return t.idTransaccion.toLowerCase().indexOf(termino) >= 0 ||
               t.proveedor.toLowerCase().indexOf(termino) >= 0 ||
               t.usuario.toLowerCase().indexOf(termino) >= 0;
      });
      return filtradas.reverse();
    }

    return transacciones.reverse();

  } catch (error) {
    Logger.log('ERROR en obtenerHistorialEntradas: ' + error.message);
    return [];
  }
}

// ==========================================
// REGISTRO DE SALIDAS (mismo código)
// ==========================================

function registrarSalida(datos) {
  try {
    const usuario = obtenerUsuarioActual();
    if (usuario.error) {
      return { error: usuario.error };
    }

    if (!datos.items || datos.items.length === 0) {
      return { error: 'Debe agregar al menos un ítem.' };
    }

    if (!datos.aQuienEntrega) {
      return { error: 'Debe especificar a quién se entrega.' };
    }

    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetTransacciones = ss.getSheetByName(SHEET_NAMES.TRANS_SALIDA);
    const sheetDetalle = ss.getSheetByName(SHEET_NAMES.DETALLE_SALIDA);
    const sheetProductos = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

    for (let item of datos.items) {
      const producto = obtenerProductoPorCodigo(item.cod);

      if (!producto) {
        return { error: `Producto con código ${item.cod} no encontrado.` };
      }

      if (producto.stock < item.cantidad) {
        return {
          error: `Stock insuficiente para ${producto.producto}. Stock actual: ${producto.stock}`
        };
      }
    }

    const idTransaccion = 'SAL-' + new Date().getTime();
    // Usar fecha del formulario si está disponible, sino usar fecha actual
    const fechaHora = datos.fecha ? new Date(datos.fecha + 'T12:00:00') : new Date();

    sheetTransacciones.appendRow([
      idTransaccion,
      fechaHora,
      datos.bote || '',
      datos.aQuienEntrega,
      datos.proposito || '',
      usuario.nombre,
      datos.firma || ''
    ]);

    for (let item of datos.items) {
      const producto = obtenerProductoPorCodigo(item.cod);

      sheetDetalle.appendRow([
        idTransaccion,
        item.cod,
        producto.producto,
        item.cantidad
      ]);

      const nuevaSalida = (producto.salida || 0) + parseFloat(item.cantidad);
      const nuevoStock = (producto.stock || 0) - parseFloat(item.cantidad);

      sheetProductos.getRange(producto.fila, 4).setValue(nuevaSalida);
      sheetProductos.getRange(producto.fila, 5).setValue(nuevoStock);
    }

    return {
      success: true,
      message: 'Salida registrada exitosamente.',
      idTransaccion: idTransaccion
    };

  } catch (error) {
    return { error: 'Error al registrar salida: ' + error.message };
  }
}

function obtenerHistorialSalidas(filtros) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetTransacciones = ss.getSheetByName(SHEET_NAMES.TRANS_SALIDA);
    const sheetDetalle = ss.getSheetByName(SHEET_NAMES.DETALLE_SALIDA);

    if (!sheetTransacciones) {
      Logger.log('ERROR: Hoja TransaccionesSalida no existe');
      return [];
    }

    if (!sheetDetalle) {
      Logger.log('ERROR: Hoja DetalleSalidas no existe');
      return [];
    }

    const lastRow = sheetTransacciones.getLastRow();
    if (lastRow < 2) {
      return [];
    }

    // Leer solo las primeras 6 columnas (sin firma para evitar problemas de tamaño)
    const datosTransacciones = sheetTransacciones.getRange(2, 1, lastRow - 1, 6).getValues();

    const datosDetalle = sheetDetalle.getLastRow() > 1 ?
      sheetDetalle.getRange(2, 1, sheetDetalle.getLastRow() - 1, 4).getValues() : [];

    const transacciones = [];

    for (let i = 0; i < datosTransacciones.length; i++) {
      const row = datosTransacciones[i];
      const idTransaccion = String(row[0] || '');

      // Obtener items de esta transacción
      const items = [];
      for (let j = 0; j < datosDetalle.length; j++) {
        if (String(datosDetalle[j][0]) === idTransaccion) {
          items.push({
            cod: String(datosDetalle[j][1] || ''),
            producto: String(datosDetalle[j][2] || ''),
            cantidad: Number(datosDetalle[j][3]) || 0
          });
        }
      }

      // Convertir fecha a string
      let fechaStr = '';
      if (row[1]) {
        try {
          const fecha = new Date(row[1]);
          if (!isNaN(fecha.getTime())) {
            fechaStr = fecha.toISOString();
          } else {
            fechaStr = String(row[1]);
          }
        } catch (e) {
          fechaStr = String(row[1]);
        }
      }

      transacciones.push({
        idTransaccion: idTransaccion,
        fechaHora: fechaStr,
        bote: String(row[2] || ''),
        aQuienEntrega: String(row[3] || ''),
        proposito: String(row[4] || ''),
        usuario: String(row[5] || ''),
        items: items
      });
    }

    // Filtrar si hay búsqueda
    if (filtros && filtros.busqueda) {
      const termino = filtros.busqueda.toLowerCase();
      const filtradas = transacciones.filter(function(t) {
        return t.idTransaccion.toLowerCase().indexOf(termino) >= 0 ||
               t.aQuienEntrega.toLowerCase().indexOf(termino) >= 0 ||
               t.usuario.toLowerCase().indexOf(termino) >= 0;
      });
      return filtradas.reverse();
    }

    return transacciones.reverse();

  } catch (error) {
    Logger.log('ERROR en obtenerHistorialSalidas: ' + error.message);
    return [];
  }
}

// ==========================================
// FUNCIONES DE ALERTAS Y REPORTES
// ==========================================

function obtenerProductosStockBajo() {
  const productos = obtenerProductos();

  return productos.filter(p =>
    p.stockMinimo > 0 && p.stock <= p.stockMinimo
  );
}

function obtenerEstadisticas() {
  const productos = obtenerProductos();

  const totalProductos = productos.length;
  const productosConStock = productos.filter(p => p.stock > 0).length;
  const productosSinStock = productos.filter(p => p.stock === 0).length;
  const productosStockBajo = obtenerProductosStockBajo().length;

  const valorTotalEntradas = productos.reduce((sum, p) => sum + (p.entrada || 0), 0);
  const valorTotalSalidas = productos.reduce((sum, p) => sum + (p.salida || 0), 0);
  const valorTotalStock = productos.reduce((sum, p) => sum + (p.stock || 0), 0);

  return {
    totalProductos,
    productosConStock,
    productosSinStock,
    productosStockBajo,
    valorTotalEntradas,
    valorTotalSalidas,
    valorTotalStock
  };
}

// ==========================================
// FUNCIONES DE EXPORTACIÓN
// ==========================================

/**
 * Exporta el inventario como datos para CSV/Excel
 * @param {Array} codigosFiltro - Array de códigos de productos a exportar (opcional)
 */
function exportarInventario(codigosFiltro) {
  try {
    let productos = obtenerProductos();

    // Aplicar filtro si se proporcionó
    if (codigosFiltro && codigosFiltro.length > 0) {
      productos = productos.filter(p => codigosFiltro.includes(p.cod.toString()));
    }

    // Crear array de datos con encabezados
    const datos = [];
    datos.push(['Código', 'Producto', 'Entradas', 'Salidas', 'Stock', 'Categoría', 'Ubicación', 'Stock Mínimo']);

    productos.forEach(p => {
      datos.push([
        p.cod,
        p.producto,
        p.entrada || 0,
        p.salida || 0,
        p.stock || 0,
        p.categoria || '',
        p.ubicacion || '',
        p.stockMinimo || 0
      ]);
    });

    const fecha = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd_HHmm');
    const fileName = `Inventario_${fecha}`;

    return {
      success: true,
      datos: datos,
      fileName: fileName,
      totalRegistros: productos.length
    };

  } catch (error) {
    return { error: 'Error al exportar inventario: ' + error.message };
  }
}

// ==========================================
// FUNCIONES DE DIAGNÓSTICO
// ==========================================

/**
 * Diagnóstico del sistema - verifica que las hojas existan y tengan datos
 */
function diagnosticoSistema() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const resultado = {
    hojas: {},
    transacciones: {},
    usuarios: 0
  };

  // Verificar cada hoja
  Object.keys(SHEET_NAMES).forEach(key => {
    const nombreHoja = SHEET_NAMES[key];
    const sheet = ss.getSheetByName(nombreHoja);

    if (sheet) {
      const filas = sheet.getLastRow();
      resultado.hojas[key] = {
        nombre: nombreHoja,
        existe: true,
        filas: filas,
        datos: filas > 1 ? filas - 1 : 0 // -1 por el encabezado
      };
    } else {
      resultado.hojas[key] = {
        nombre: nombreHoja,
        existe: false,
        filas: 0,
        datos: 0
      };
    }
  });

  // Contar transacciones específicamente
  const sheetTransEntrada = ss.getSheetByName(SHEET_NAMES.TRANS_ENTRADA);
  const sheetTransSalida = ss.getSheetByName(SHEET_NAMES.TRANS_SALIDA);

  if (sheetTransEntrada && sheetTransEntrada.getLastRow() > 1) {
    const datos = sheetTransEntrada.getRange(2, 1, sheetTransEntrada.getLastRow() - 1, 1).getValues();
    resultado.transacciones.entradas = datos.length;
    resultado.transacciones.entradasMigradas = datos.filter(row => String(row[0]).includes('ENT-MIG')).length;
  } else {
    resultado.transacciones.entradas = 0;
    resultado.transacciones.entradasMigradas = 0;
  }

  if (sheetTransSalida && sheetTransSalida.getLastRow() > 1) {
    const datos = sheetTransSalida.getRange(2, 1, sheetTransSalida.getLastRow() - 1, 1).getValues();
    resultado.transacciones.salidas = datos.length;
    resultado.transacciones.salidasMigradas = datos.filter(row => String(row[0]).includes('SAL-MIG')).length;
  } else {
    resultado.transacciones.salidas = 0;
    resultado.transacciones.salidasMigradas = 0;
  }

  return resultado;
}

// ==========================================
// CARGA MASIVA DE PRODUCTOS
// ==========================================

/**
 * Carga productos de forma masiva desde CSV
 * Formato esperado: COD, PRODUCTO, CATEGORIA, UBICACION, STOCK_MINIMO
 * Si el producto ya existe, actualiza sus datos (excepto stock/entradas/salidas)
 * Si no existe, lo crea con stock inicial en 0
 */
function cargarProductosMasivos(datosCSV) {
  if (!esAdministrador()) {
    return { error: 'Solo administradores pueden cargar productos masivamente.' };
  }

  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

    if (!sheet) {
      return { error: 'No se encontró la hoja de productos.' };
    }

    const datos = sheet.getDataRange().getValues();
    let agregados = 0;
    let actualizados = 0;
    let errores = [];

    for (let i = 0; i < datosCSV.length; i++) {
      const row = datosCSV[i];

      // Extraer y validar datos
      const cod = String(row[0] || '').trim();
      const producto = String(row[1] || '').trim();
      const categoria = String(row[2] || '').trim();
      const ubicacion = String(row[3] || '').trim();
      const stockMinimo = parseInt(row[4]) || 0;

      // Validación básica
      if (!cod || !producto) {
        errores.push(`Fila ${i + 1}: Código y nombre de producto son obligatorios`);
        continue;
      }

      // Buscar si el producto ya existe
      let filaExistente = -1;
      for (let j = 1; j < datos.length; j++) {
        if (String(datos[j][0]).trim() === cod) {
          filaExistente = j + 1; // +1 porque las filas en Sheets empiezan en 1
          break;
        }
      }

      try {
        if (filaExistente > 0) {
          // Producto existe: actualizar solo nombre, categoría, ubicación y stock mínimo
          // NO tocar columnas de ENTRADA (col 3), SALIDA (col 4), STOCK (col 5)
          sheet.getRange(filaExistente, 2).setValue(producto);          // PRODUCTO
          sheet.getRange(filaExistente, 6).setValue(categoria);         // CATEGORIA
          sheet.getRange(filaExistente, 7).setValue(ubicacion);         // UBICACION
          sheet.getRange(filaExistente, 8).setValue(stockMinimo);       // STOCK_MINIMO
          actualizados++;
        } else {
          // Producto nuevo: agregar al final
          const nuevaFila = [
            cod,           // COD
            producto,      // PRODUCTO
            0,             // ENTRADA (inicial)
            0,             // SALIDA (inicial)
            0,             // STOCK (inicial)
            categoria,     // CATEGORIA
            ubicacion,     // UBICACION
            stockMinimo    // STOCK_MINIMO
          ];
          sheet.appendRow(nuevaFila);
          agregados++;
        }
      } catch (error) {
        errores.push(`Fila ${i + 1} (${cod}): ${error.message}`);
      }
    }

    return {
      success: true,
      agregados: agregados,
      actualizados: actualizados,
      errores: errores
    };

  } catch (error) {
    return { error: 'Error en carga masiva: ' + error.message };
  }
}

// ==========================================
// FUNCIONES DE MIGRACIÓN DE DATOS HISTÓRICOS
// ==========================================

/**
 * Migra entradas históricas desde CSV
 * Formato esperado: COD, PRODUCTO, FECHA, CANTIDAD
 * MEJORADO: Ahora devuelve información detallada de cada fila procesada
 */
function migrarEntradasHistoricas(datosCSV) {
  if (!esAdministrador()) {
    return { error: 'Solo administradores pueden migrar datos.' };
  }

  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetTransacciones = ss.getSheetByName(SHEET_NAMES.TRANS_ENTRADA);
    const sheetDetalle = ss.getSheetByName(SHEET_NAMES.DETALLE_ENTRADA);
    const sheetProductos = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

    let procesados = 0;
    let errores = [];
    let saltados = 0;
    let productosCreados = 0;
    let detalleFilas = []; // Para reportar cada fila

    // Validar que hay datos
    if (!datosCSV || datosCSV.length === 0) {
      return { error: 'No se recibieron datos para procesar.' };
    }

    Logger.log(`=== INICIANDO MIGRACIÓN DE ${datosCSV.length} FILAS ===`);

    // Agrupar por fecha para crear transacciones
    const transaccionesPorFecha = {};

    for (let i = 0; i < datosCSV.length; i++) {
      const row = datosCSV[i];
      const numFila = i + 1;

      // Log de cada fila recibida
      Logger.log(`Fila ${numFila}: ${JSON.stringify(row)}`);

      const cod = String(row[0] || '').trim();
      const producto = String(row[1] || '').trim();
      const fechaStr = String(row[2] || '').trim();
      const cantidadRaw = row[3];
      const cantidad = parseFloat(cantidadRaw);

      // Validar código
      if (!cod) {
        errores.push(`Fila ${numFila}: Código vacío`);
        detalleFilas.push({ fila: numFila, estado: 'ERROR', motivo: 'Código vacío', datos: row });
        saltados++;
        continue;
      }

      // Validar nombre de producto
      if (!producto) {
        errores.push(`Fila ${numFila}: Nombre de producto vacío para código ${cod}`);
        detalleFilas.push({ fila: numFila, estado: 'ERROR', motivo: 'Nombre vacío', datos: row });
        saltados++;
        continue;
      }

      // Validar fecha
      if (!fechaStr) {
        errores.push(`Fila ${numFila}: Fecha vacía para ${cod}`);
        detalleFilas.push({ fila: numFila, estado: 'ERROR', motivo: 'Fecha vacía', datos: row });
        saltados++;
        continue;
      }

      // Validar cantidad
      if (isNaN(cantidad) || cantidad <= 0) {
        errores.push(`Fila ${numFila}: Cantidad inválida "${cantidadRaw}" para ${cod}`);
        detalleFilas.push({ fila: numFila, estado: 'ERROR', motivo: `Cantidad inválida: ${cantidadRaw}`, datos: row });
        saltados++;
        continue;
      }

      // Convertir fecha (formato: dd/mm/yyyy o dd/mm/yy)
      let fecha;
      try {
        const partes = fechaStr.split('/');
        if (partes.length === 3) {
          let dia = parseInt(partes[0]);
          let mes = parseInt(partes[1]) - 1; // JS months are 0-indexed
          let anio = parseInt(partes[2]);

          // Si el año es de 2 dígitos, asumimos 2000+
          if (anio < 100) {
            anio += 2000;
          }

          fecha = new Date(anio, mes, dia, 12, 0, 0); // Medio día para evitar problemas de zona horaria
        } else {
          throw new Error('Formato de fecha inválido');
        }
      } catch (e) {
        errores.push(`Fila ${i + 1}: Fecha inválida "${fechaStr}"`);
        continue;
      }

      // Verificar que el producto existe, si no existe CREARLO automáticamente
      let productoExistente = obtenerProductoPorCodigo(cod);
      if (!productoExistente) {
        // CREAR EL PRODUCTO NUEVO AUTOMÁTICAMENTE
        sheetProductos.appendRow([
          cod,           // COD
          producto,      // PRODUCTO (nombre del CSV)
          0,             // ENTRADA (se actualizará después)
          0,             // SALIDA
          0,             // STOCK (se actualizará después)
          '',            // CATEGORIA
          '',            // UBICACION
          5              // STOCK_MINIMO por defecto
        ]);
        productosCreados++;
        Logger.log(`Producto nuevo creado automáticamente: ${cod} - ${producto}`);
        // Obtener el producto recién creado para tener la fila correcta
        productoExistente = obtenerProductoPorCodigo(cod);

        if (!productoExistente) {
          errores.push(`Fila ${numFila}: Error al crear producto ${cod}`);
          detalleFilas.push({ fila: numFila, estado: 'ERROR', motivo: 'No se pudo crear el producto', datos: row });
          saltados++;
          continue;
        }
      }

      // Agrupar por fecha
      const fechaKey = Utilities.formatDate(fecha, Session.getScriptTimeZone(), 'yyyy-MM-dd');
      if (!transaccionesPorFecha[fechaKey]) {
        transaccionesPorFecha[fechaKey] = {
          fecha: fecha,
          items: []
        };
      }

      transaccionesPorFecha[fechaKey].items.push({
        cod: cod,
        producto: productoExistente.producto,
        cantidad: cantidad,
        fila: productoExistente.fila
      });

      procesados++;
    }

    // Crear transacciones agrupadas
    let transaccionesCreadas = 0;
    for (const fechaKey in transaccionesPorFecha) {
      const transaccion = transaccionesPorFecha[fechaKey];
      const idTransaccion = 'ENT-MIG-' + fechaKey + '-' + new Date().getTime();

      // Crear transacción de entrada
      sheetTransacciones.appendRow([
        idTransaccion,
        transaccion.fecha,
        'Migración histórica',
        '',
        'Sistema (Migración)',
        'Datos migrados del sistema anterior',
        ''
      ]);

      // Agregar detalles y actualizar stocks
      transaccion.items.forEach(item => {
        sheetDetalle.appendRow([
          idTransaccion,
          item.cod,
          item.producto,
          item.cantidad
        ]);

        // Actualizar producto
        const productoActual = obtenerProductoPorCodigo(item.cod);
        const nuevaEntrada = (productoActual.entrada || 0) + item.cantidad;
        const nuevoStock = (productoActual.stock || 0) + item.cantidad;

        sheetProductos.getRange(item.fila, 3).setValue(nuevaEntrada);
        sheetProductos.getRange(item.fila, 5).setValue(nuevoStock);
      });

      transaccionesCreadas++;
    }

    Logger.log(`=== MIGRACIÓN COMPLETADA ===`);
    Logger.log(`Procesados: ${procesados}, Saltados: ${saltados}, Transacciones: ${transaccionesCreadas}, Productos nuevos: ${productosCreados}`);
    Logger.log(`Errores: ${errores.length}`);

    return {
      success: true,
      procesados: procesados,
      transaccionesCreadas: transaccionesCreadas,
      saltados: saltados,
      productosCreados: productosCreados,
      errores: errores,
      totalFilasRecibidas: datosCSV.length,
      resumen: `De ${datosCSV.length} filas: ${procesados} procesadas, ${saltados} saltadas, ${productosCreados} productos nuevos creados, ${transaccionesCreadas} transacciones generadas`
    };

  } catch (error) {
    Logger.log(`ERROR GENERAL: ${error.message}`);
    Logger.log(`Stack: ${error.stack}`);
    return {
      error: 'Error en migración de entradas: ' + error.message,
      stack: error.stack
    };
  }
}

/**
 * Migra salidas históricas desde CSV
 * Formato esperado: COD, PRODUCTO, FECHA, CANTIDAD, BOTE
 * MEJORADO: Ahora devuelve información detallada de cada fila procesada
 */
function migrarSalidasHistoricas(datosCSV) {
  if (!esAdministrador()) {
    return { error: 'Solo administradores pueden migrar datos.' };
  }

  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetTransacciones = ss.getSheetByName(SHEET_NAMES.TRANS_SALIDA);
    const sheetDetalle = ss.getSheetByName(SHEET_NAMES.DETALLE_SALIDA);
    const sheetProductos = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

    let procesados = 0;
    let errores = [];
    let saltados = 0;

    // Agrupar por fecha y bote para crear transacciones
    const transaccionesPorFechaBote = {};

    for (let i = 0; i < datosCSV.length; i++) {
      const row = datosCSV[i];
      const cod = String(row[0]).trim();
      const producto = String(row[1]).trim();
      const fechaStr = String(row[2]).trim();
      const cantidad = parseFloat(row[3]);
      const bote = String(row[4] || '').trim();

      // Validar datos básicos
      if (!cod || !fechaStr || !cantidad || cantidad <= 0) {
        saltados++;
        continue;
      }

      // Convertir fecha (formato: mm/dd/yy o mm/dd)
      let fecha;
      try {
        const partes = fechaStr.split('/');
        if (partes.length >= 2) {
          let mes = parseInt(partes[0]) - 1; // JS months are 0-indexed
          let dia = parseInt(partes[1]);
          let anio = 2025; // Año por defecto

          if (partes.length === 3) {
            anio = parseInt(partes[2]);
            if (anio < 100) {
              anio += 2000;
            }
          }

          fecha = new Date(anio, mes, dia, 12, 0, 0);
        } else {
          throw new Error('Formato de fecha inválido');
        }
      } catch (e) {
        errores.push(`Fila ${i + 1}: Fecha inválida "${fechaStr}"`);
        continue;
      }

      // Verificar que el producto existe, si no existe CREARLO automáticamente
      let productoExistente = obtenerProductoPorCodigo(cod);
      if (!productoExistente) {
        // CREAR EL PRODUCTO NUEVO AUTOMÁTICAMENTE (para salidas históricas)
        sheetProductos.appendRow([
          cod,           // COD
          producto,      // PRODUCTO (nombre del CSV)
          0,             // ENTRADA
          0,             // SALIDA (se actualizará después)
          0,             // STOCK (se actualizará después)
          '',            // CATEGORIA
          '',            // UBICACION
          5              // STOCK_MINIMO por defecto
        ]);
        Logger.log(`Producto nuevo creado automáticamente (salida histórica): ${cod} - ${producto}`);
        productoExistente = obtenerProductoPorCodigo(cod);
      }

      // Verificar stock suficiente
      if (productoExistente.stock < cantidad) {
        errores.push(`Fila ${i + 1}: Stock insuficiente para ${cod} (Stock: ${productoExistente.stock}, Requerido: ${cantidad})`);
        continue;
      }

      // Agrupar por fecha y bote
      const fechaKey = Utilities.formatDate(fecha, Session.getScriptTimeZone(), 'yyyy-MM-dd');
      const key = fechaKey + '_' + (bote || 'SIN_BOTE');

      if (!transaccionesPorFechaBote[key]) {
        transaccionesPorFechaBote[key] = {
          fecha: fecha,
          bote: bote || 'No especificado',
          items: []
        };
      }

      transaccionesPorFechaBote[key].items.push({
        cod: cod,
        producto: productoExistente.producto,
        cantidad: cantidad,
        fila: productoExistente.fila
      });

      procesados++;
    }

    // Crear transacciones agrupadas
    let transaccionesCreadas = 0;
    for (const key in transaccionesPorFechaBote) {
      const transaccion = transaccionesPorFechaBote[key];
      const idTransaccion = 'SAL-MIG-' + key + '-' + new Date().getTime();

      // Crear transacción de salida
      sheetTransacciones.appendRow([
        idTransaccion,
        transaccion.fecha,
        transaccion.bote,
        'Migración histórica',
        'Salida migrada del sistema anterior',
        'Sistema (Migración)',
        ''
      ]);

      // Agregar detalles y actualizar stocks
      transaccion.items.forEach(item => {
        sheetDetalle.appendRow([
          idTransaccion,
          item.cod,
          item.producto,
          item.cantidad
        ]);

        // Actualizar producto
        const productoActual = obtenerProductoPorCodigo(item.cod);
        const nuevaSalida = (productoActual.salida || 0) + item.cantidad;
        const nuevoStock = (productoActual.stock || 0) - item.cantidad;

        sheetProductos.getRange(item.fila, 4).setValue(nuevaSalida);
        sheetProductos.getRange(item.fila, 5).setValue(nuevoStock);
      });

      transaccionesCreadas++;
    }

    return {
      success: true,
      procesados: procesados,
      transaccionesCreadas: transaccionesCreadas,
      saltados: saltados,
      errores: errores
    };

  } catch (error) {
    return { error: 'Error en migración de salidas: ' + error.message };
  }
}

// ==========================================
// GESTIÓN DE DUPLICADOS
// ==========================================

/**
 * Detecta transacciones duplicadas en Entradas y Salidas
 * Retorna información sobre los duplicados encontrados
 */
function detectarDuplicados() {
  if (!esAdministrador()) {
    return { error: 'Solo administradores pueden ejecutar esta función.' };
  }

  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const resultado = {
      entradasDuplicadas: [],
      salidasDuplicadas: [],
      totalEntradasDuplicadas: 0,
      totalSalidasDuplicadas: 0
    };

    // Detectar duplicados en ENTRADAS
    const sheetTransEntrada = ss.getSheetByName(SHEET_NAMES.TRANS_ENTRADA);
    if (sheetTransEntrada && sheetTransEntrada.getLastRow() > 1) {
      const datos = sheetTransEntrada.getRange(2, 1, sheetTransEntrada.getLastRow() - 1, 7).getValues();
      const mapa = {};

      datos.forEach((row, index) => {
        const idTransaccion = row[0];
        const fecha = row[1];
        const proveedor = row[2];
        const numFactura = row[3];
        const usuario = row[4];

        // Para migraciones, usar también la hora exacta en la clave para mejor precisión
        let fechaStr = '';
        try {
          if (fecha instanceof Date) {
            fechaStr = fecha.getTime().toString(); // Usar timestamp para más precisión
          } else {
            fechaStr = new Date(fecha).getTime().toString();
          }
        } catch (e) {
          fechaStr = String(fecha);
        }

        // Crear clave única basada en proveedor, fecha exacta y número de factura
        const clave = `${proveedor}_${fechaStr}_${numFactura}`.toLowerCase();

        if (!mapa[clave]) {
          mapa[clave] = [];
        }

        mapa[clave].push({
          fila: index + 2, // +2 porque index empieza en 0 y hay header
          idTransaccion: idTransaccion,
          fecha: fecha,
          proveedor: proveedor,
          numFactura: numFactura,
          usuario: usuario
        });
      });

      // Filtrar solo los que tienen duplicados
      Object.keys(mapa).forEach(clave => {
        if (mapa[clave].length > 1) {
          resultado.entradasDuplicadas.push({
            clave: clave,
            transacciones: mapa[clave],
            cantidad: mapa[clave].length
          });
          resultado.totalEntradasDuplicadas += mapa[clave].length;
        }
      });
    }

    // Detectar duplicados en SALIDAS
    const sheetTransSalida = ss.getSheetByName(SHEET_NAMES.TRANS_SALIDA);
    if (sheetTransSalida && sheetTransSalida.getLastRow() > 1) {
      const datos = sheetTransSalida.getRange(2, 1, sheetTransSalida.getLastRow() - 1, 7).getValues();
      const mapa = {};

      datos.forEach((row, index) => {
        const idTransaccion = row[0];
        const fecha = row[1];
        const aQuienEntrega = row[2];
        const bote = row[3];
        const proposito = row[4];
        const usuario = row[5];

        // Para migraciones, usar también la hora exacta en la clave para mejor precisión
        let fechaStr = '';
        try {
          if (fecha instanceof Date) {
            fechaStr = fecha.getTime().toString(); // Usar timestamp para más precisión
          } else {
            fechaStr = new Date(fecha).getTime().toString();
          }
        } catch (e) {
          fechaStr = String(fecha);
        }

        // Crear clave única basada en quien entrega, fecha exacta y bote
        const clave = `${aQuienEntrega}_${fechaStr}_${bote}`.toLowerCase();

        if (!mapa[clave]) {
          mapa[clave] = [];
        }

        mapa[clave].push({
          fila: index + 2,
          idTransaccion: idTransaccion,
          fecha: fecha,
          aQuienEntrega: aQuienEntrega,
          bote: bote,
          proposito: proposito,
          usuario: usuario
        });
      });

      // Filtrar solo los que tienen duplicados
      Object.keys(mapa).forEach(clave => {
        if (mapa[clave].length > 1) {
          resultado.salidasDuplicadas.push({
            clave: clave,
            transacciones: mapa[clave],
            cantidad: mapa[clave].length
          });
          resultado.totalSalidasDuplicadas += mapa[clave].length;
        }
      });
    }

    return resultado;

  } catch (error) {
    return { error: 'Error al detectar duplicados: ' + error.message };
  }
}

/**
 * Elimina transacciones duplicadas manteniendo solo la primera de cada grupo
 * IMPORTANTE: Esta función recalcula los stocks después de eliminar duplicados
 */
function eliminarDuplicados() {
  if (!esAdministrador()) {
    return { error: 'Solo administradores pueden ejecutar esta función.' };
  }

  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetProductos = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);

    let entradasEliminadas = 0;
    let salidasEliminadas = 0;
    let filasEliminadasDetalle = 0;

    // Primero detectar duplicados
    const duplicados = detectarDuplicados();
    if (duplicados.error) {
      return duplicados;
    }

    // Eliminar ENTRADAS duplicadas (mantener la primera, eliminar el resto)
    if (duplicados.entradasDuplicadas.length > 0) {
      const sheetTransEntrada = ss.getSheetByName(SHEET_NAMES.TRANS_ENTRADA);
      const sheetDetalleEntrada = ss.getSheetByName(SHEET_NAMES.DETALLE_ENTRADA);

      // Recolectar IDs a eliminar y filas (ordenar de mayor a menor para no descuadrar índices)
      const filasAEliminar = [];
      const idsAEliminar = [];

      duplicados.entradasDuplicadas.forEach(grupo => {
        // Mantener la primera, eliminar el resto
        for (let i = 1; i < grupo.transacciones.length; i++) {
          filasAEliminar.push(grupo.transacciones[i].fila);
          idsAEliminar.push(grupo.transacciones[i].idTransaccion);
        }
      });

      // Ordenar filas de mayor a menor
      filasAEliminar.sort((a, b) => b - a);

      // Eliminar filas de transacciones
      filasAEliminar.forEach(fila => {
        sheetTransEntrada.deleteRow(fila);
        entradasEliminadas++;
      });

      // Eliminar detalles asociados
      if (sheetDetalleEntrada && sheetDetalleEntrada.getLastRow() > 1) {
        const datosDetalle = sheetDetalleEntrada.getRange(2, 1, sheetDetalleEntrada.getLastRow() - 1, 4).getValues();
        const filasDetalleAEliminar = [];

        datosDetalle.forEach((row, index) => {
          if (idsAEliminar.includes(row[0])) {
            filasDetalleAEliminar.push(index + 2);
          }
        });

        // Eliminar de mayor a menor
        filasDetalleAEliminar.sort((a, b) => b - a);
        filasDetalleAEliminar.forEach(fila => {
          sheetDetalleEntrada.deleteRow(fila);
          filasEliminadasDetalle++;
        });
      }
    }

    // Eliminar SALIDAS duplicadas (mantener la primera, eliminar el resto)
    if (duplicados.salidasDuplicadas.length > 0) {
      const sheetTransSalida = ss.getSheetByName(SHEET_NAMES.TRANS_SALIDA);
      const sheetDetalleSalida = ss.getSheetByName(SHEET_NAMES.DETALLE_SALIDA);

      const filasAEliminar = [];
      const idsAEliminar = [];

      duplicados.salidasDuplicadas.forEach(grupo => {
        // Mantener la primera, eliminar el resto
        for (let i = 1; i < grupo.transacciones.length; i++) {
          filasAEliminar.push(grupo.transacciones[i].fila);
          idsAEliminar.push(grupo.transacciones[i].idTransaccion);
        }
      });

      // Ordenar filas de mayor a menor
      filasAEliminar.sort((a, b) => b - a);

      // Eliminar filas de transacciones
      filasAEliminar.forEach(fila => {
        sheetTransSalida.deleteRow(fila);
        salidasEliminadas++;
      });

      // Eliminar detalles asociados
      if (sheetDetalleSalida && sheetDetalleSalida.getLastRow() > 1) {
        const datosDetalle = sheetDetalleSalida.getRange(2, 1, sheetDetalleSalida.getLastRow() - 1, 4).getValues();
        const filasDetalleAEliminar = [];

        datosDetalle.forEach((row, index) => {
          if (idsAEliminar.includes(row[0])) {
            filasDetalleAEliminar.push(index + 2);
          }
        });

        // Eliminar de mayor a menor
        filasDetalleAEliminar.sort((a, b) => b - a);
        filasDetalleAEliminar.forEach(fila => {
          sheetDetalleSalida.deleteRow(fila);
          filasEliminadasDetalle++;
        });
      }
    }

    // RECALCULAR STOCKS desde cero
    const resultadoRecalculo = recalcularTodosLosStocks();

    return {
      success: true,
      entradasEliminadas: entradasEliminadas,
      salidasEliminadas: salidasEliminadas,
      filasDetalleEliminadas: filasEliminadasDetalle,
      stocksRecalculados: resultadoRecalculo.productosActualizados || 0,
      mensaje: `Duplicados eliminados: ${entradasEliminadas} entradas, ${salidasEliminadas} salidas. Stocks recalculados.`
    };

  } catch (error) {
    return { error: 'Error al eliminar duplicados: ' + error.message };
  }
}

/**
 * Recalcula todos los stocks, entradas y salidas desde cero
 * basándose en las transacciones registradas
 * AHORA: Crea automáticamente productos que están en transacciones pero no en Base de Datos
 */
function recalcularTodosLosStocks() {
  if (!esAdministrador()) {
    return { error: 'Solo administradores pueden ejecutar esta función.' };
  }

  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetProductos = ss.getSheetByName(SHEET_NAMES.PRODUCTOS);
    const sheetDetalleEntrada = ss.getSheetByName(SHEET_NAMES.DETALLE_ENTRADA);
    const sheetDetalleSalida = ss.getSheetByName(SHEET_NAMES.DETALLE_SALIDA);

    let productosCreados = 0;

    // PASO 1: Crear productos faltantes desde DetalleEntradas
    if (sheetDetalleEntrada && sheetDetalleEntrada.getLastRow() > 1) {
      const datosEntradas = sheetDetalleEntrada.getRange(2, 1, sheetDetalleEntrada.getLastRow() - 1, 4).getValues();

      datosEntradas.forEach(row => {
        const cod = String(row[1]).trim();
        const nombreProducto = String(row[2]).trim();

        if (cod && !obtenerProductoPorCodigo(cod)) {
          // Crear el producto que falta
          sheetProductos.appendRow([
            cod,                              // COD
            nombreProducto || `Producto ${cod}`, // PRODUCTO
            0,                                // ENTRADA (se calculará después)
            0,                                // SALIDA
            0,                                // STOCK (se calculará después)
            '',                               // CATEGORIA
            '',                               // UBICACION
            5                                 // STOCK_MINIMO por defecto
          ]);
          productosCreados++;
          Logger.log(`Producto creado desde entradas: ${cod} - ${nombreProducto}`);
        }
      });
    }

    // PASO 2: Crear productos faltantes desde DetalleSalidas
    if (sheetDetalleSalida && sheetDetalleSalida.getLastRow() > 1) {
      const datosSalidas = sheetDetalleSalida.getRange(2, 1, sheetDetalleSalida.getLastRow() - 1, 4).getValues();

      datosSalidas.forEach(row => {
        const cod = String(row[1]).trim();
        const nombreProducto = String(row[2]).trim();

        if (cod && !obtenerProductoPorCodigo(cod)) {
          // Crear el producto que falta
          sheetProductos.appendRow([
            cod,                              // COD
            nombreProducto || `Producto ${cod}`, // PRODUCTO
            0,                                // ENTRADA
            0,                                // SALIDA (se calculará después)
            0,                                // STOCK (se calculará después)
            '',                               // CATEGORIA
            '',                               // UBICACION
            5                                 // STOCK_MINIMO por defecto
          ]);
          productosCreados++;
          Logger.log(`Producto creado desde salidas: ${cod} - ${nombreProducto}`);
        }
      });
    }

    // PASO 3: Resetear todas las entradas, salidas y stocks a 0
    if (sheetProductos.getLastRow() > 1) {
      const datosProductos = sheetProductos.getRange(2, 1, sheetProductos.getLastRow() - 1, 1).getValues();

      datosProductos.forEach((row, index) => {
        const fila = index + 2;
        sheetProductos.getRange(fila, 3).setValue(0); // Entrada
        sheetProductos.getRange(fila, 4).setValue(0); // Salida
        sheetProductos.getRange(fila, 5).setValue(0); // Stock
      });
    }

    // PASO 4: Recalcular ENTRADAS
    if (sheetDetalleEntrada && sheetDetalleEntrada.getLastRow() > 1) {
      const datosEntradas = sheetDetalleEntrada.getRange(2, 1, sheetDetalleEntrada.getLastRow() - 1, 4).getValues();

      datosEntradas.forEach(row => {
        const cod = String(row[1]).trim();
        const cantidad = parseFloat(row[3]) || 0;

        const producto = obtenerProductoPorCodigo(cod);
        if (producto) {
          const nuevaEntrada = producto.entrada + cantidad;
          const nuevoStock = producto.stock + cantidad;

          sheetProductos.getRange(producto.fila, 3).setValue(nuevaEntrada);
          sheetProductos.getRange(producto.fila, 5).setValue(nuevoStock);
        }
      });
    }

    // PASO 5: Recalcular SALIDAS
    if (sheetDetalleSalida && sheetDetalleSalida.getLastRow() > 1) {
      const datosSalidas = sheetDetalleSalida.getRange(2, 1, sheetDetalleSalida.getLastRow() - 1, 4).getValues();

      datosSalidas.forEach(row => {
        const cod = String(row[1]).trim();
        const cantidad = parseFloat(row[3]) || 0;

        const producto = obtenerProductoPorCodigo(cod);
        if (producto) {
          const nuevaSalida = producto.salida + cantidad;
          const nuevoStock = producto.stock - cantidad;

          sheetProductos.getRange(producto.fila, 4).setValue(nuevaSalida);
          sheetProductos.getRange(producto.fila, 5).setValue(nuevoStock);
        }
      });
    }

    return {
      success: true,
      mensaje: `Stocks recalculados exitosamente. ${productosCreados > 0 ? `Se crearon ${productosCreados} productos nuevos.` : ''}`,
      productosActualizados: sheetProductos.getLastRow() - 1,
      productosCreados: productosCreados
    };

  } catch (error) {
    return { error: 'Error al recalcular stocks: ' + error.message };
  }
}

