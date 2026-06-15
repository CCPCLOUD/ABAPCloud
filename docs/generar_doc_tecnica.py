#!/usr/bin/env python3
"""Genera la documentación técnica del desarrollo P158 en formato Word."""

from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT

doc = Document()

# Estilos base
style = doc.styles['Normal']
style.font.name = 'Calibri'
style.font.size = Pt(10)

COLOR_TITLE = RGBColor(0x1F, 0x4E, 0x79)


def h1(text):
    p = doc.add_heading(text, level=1)
    for run in p.runs:
        run.font.color.rgb = COLOR_TITLE
    return p


def h2(text):
    p = doc.add_heading(text, level=2)
    for run in p.runs:
        run.font.color.rgb = COLOR_TITLE
    return p


def h3(text):
    return doc.add_heading(text, level=3)


def para(text, bold=False, italic=False):
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.bold = bold
    run.italic = italic
    return p


def bullet(text):
    doc.add_paragraph(text, style='List Bullet')


def numbered(text):
    doc.add_paragraph(text, style='List Number')


def code_block(text):
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.font.name = 'Consolas'
    run.font.size = Pt(8)
    p.paragraph_format.left_indent = Cm(0.5)
    # Fondo gris claro (shading) en cada run no es directo; usamos un borde simple
    return p


def make_table(headers, rows, col_widths=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = 'Light Grid Accent 1'
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr_cells = table.rows[0].cells
    for i, htext in enumerate(headers):
        hdr_cells[i].text = htext
        for p in hdr_cells[i].paragraphs:
            for r in p.runs:
                r.bold = True
    for row in rows:
        cells = table.add_row().cells
        for i, val in enumerate(row):
            cells[i].text = str(val)
    if col_widths:
        for i, w in enumerate(col_widths):
            for row in table.rows:
                row.cells[i].width = Cm(w)
    return table


# =====================================================================
# PORTADA
# =====================================================================
title = doc.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = title.add_run('Documentación Técnica')
run.bold = True
run.font.size = Pt(24)
run.font.color.rgb = COLOR_TITLE

subtitle = doc.add_paragraph()
subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = subtitle.add_run('P158 - Liberación masiva de órdenes de compra\nTransacción ZMM_LIB_OC / Programa ZRMM_LIBERACION_MASIVA_OC')
run.font.size = Pt(14)

doc.add_paragraph()
make_table(
    ['Campo', 'Valor'],
    [
        ['ID Requerimiento', 'P158'],
        ['Ticket', '#26598 - Proyectos DM'],
        ['Módulo SAP', 'MM'],
        ['Tipo de objeto', 'Transacción Z (Reporte ABAP)'],
        ['Nombre técnico transacción', 'ZMM_LIB_OC'],
        ['Nombre técnico programa', 'ZRMM_LIBERACION_MASIVA_OC'],
        ['Tipo de programa', 'Reporte ejecutable (1)'],
        ['Versión documento', 'V1.0'],
    ],
    col_widths=[6, 10],
)

doc.add_page_break()

# =====================================================================
# 1. OBJETIVO Y ALCANCE
# =====================================================================
h1('1. Objetivo y alcance')

para(
    'El programa ZRMM_LIBERACION_MASIVA_OC, ejecutado a través de la transacción '
    'ZMM_LIB_OC, automatiza la liberación masiva de órdenes de compra (OC) en '
    'SAP S/4HANA mediante la carga de un archivo Excel local (.xlsx). El '
    'programa valida la información de entrada, ejecuta la liberación con la '
    'BAPI estándar BAPI_PO_RELEASE para cada combinación válida de orden de '
    'compra y código liberador, y presenta un log de resultados en formato ALV '
    'con semáforo (verde, amarillo, rojo) y totales de procesamiento.'
)

h2('1.1 Situación que resuelve')
para(
    'Sustituye la operación manual y repetitiva de la transacción estándar '
    'ME28 cuando existe un alto volumen de OC pendientes de liberación, '
    'reduciendo el riesgo de errores humanos (omisión de documentos, '
    'selección incorrecta o aplicación de códigos fuera de secuencia).'
)

h2('1.2 Fuera de alcance')
bullet('No sustituye la configuración estándar de estrategias de liberación (transacciones OMGS/OMGSCS, etc.).')
bullet('No crea ni modifica órdenes de compra; únicamente ejecuta su liberación.')
bullet('La preparación del archivo Excel de entrada es responsabilidad del usuario/área de compras.')

# =====================================================================
# 2. ARQUITECTURA DE LA SOLUCIÓN
# =====================================================================
h1('2. Arquitectura de la solución')

h2('2.1 Componentes desarrollados')
make_table(
    ['Objeto', 'Tipo', 'Descripción'],
    [
        ['ZMM_LIB_OC', 'Transacción (TCODE)', 'Punto de entrada de usuario, llama al programa ZRMM_LIBERACION_MASIVA_OC, pantalla 1000.'],
        ['ZRMM_LIBERACION_MASIVA_OC', 'Programa ABAP (Report, tipo 1)', 'Lógica de carga, validación, liberación y log ALV.'],
    ],
    col_widths=[5, 4, 9],
)

h2('2.2 Diagrama de flujo general')
code_block(
    "Usuario funcional\n"
    "   |\n"
    "   v\n"
    "Transacción ZMM_LIB_OC (pantalla de selección)\n"
    "   |  - P_FILE: ruta del archivo Excel (.xlsx) con F4 de selección\n"
    "   |  - P_SIMU: checkbox de modo simulación\n"
    "   v\n"
    "START-OF-SELECTION\n"
    "   |\n"
    "   +-> f_validar_archivo      -> valida extensión .xlsx\n"
    "   +-> f_procesar_archivo     -> lee Excel, valida y ejecuta liberación\n"
    "   |        |\n"
    "   |        +-> ALSM_EXCEL_TO_INTERNAL_TABLE  (lectura del archivo)\n"
    "   |        +-> f_validar_encabezados         (valida columnas A/B)\n"
    "   |        +-> Por cada fila:\n"
    "   |              +-> CONVERSION_EXIT_ALPHA_INPUT  (normaliza EBELN)\n"
    "   |              +-> f_validar_oc                  (existencia / estatus OC)\n"
    "   |              +-> f_ejecutar_bapi  (si P_SIMU = ' ')\n"
    "   |                     +-> BAPI_PO_RELEASE\n"
    "   |                     +-> BAPI_TRANSACTION_COMMIT  (si RETURN sin errores)\n"
    "   |                     +-> BAPI_TRANSACTION_ROLLBACK (si RETURN con error)\n"
    "   +-> f_agregar_fila_totales -> agrega fila resumen TOTAL al log\n"
    "   +-> f_mostrar_log          -> presenta ALV (REUSE_ALV_GRID_DISPLAY)\n"
)

# =====================================================================
# 3. PANTALLA DE SELECCIÓN
# =====================================================================
h1('3. Pantalla de selección (Dynpro 1000)')

make_table(
    ['Parámetro', 'Tipo', 'Obligatorio', 'Descripción'],
    [
        ['P_FILE', 'rlgrap-filename', 'Sí',
         'Ruta del archivo Excel local (.xlsx). Incluye botón de búsqueda '
         'mediante F4 (función estándar F4_FILENAME).'],
        ['P_SIMU', 'Checkbox (abap_bool)', 'No',
         'Modo simulación. Si está marcado, el programa valida los registros '
         'pero NO ejecuta BAPI_PO_RELEASE ni confirma cambios; el registro '
         'queda marcado como "Simulado".'],
    ],
    col_widths=[3, 4, 3, 8],
)

para('Textos de los campos definidos dinámicamente en AT SELECTION-SCREEN OUTPUT:')
bullet('P_FILE: "Archivo Excel (.xlsx)"')
bullet('P_SIMU: "Modo simulación (no confirma cambios)"')

# =====================================================================
# 4. ESTRUCTURA DEL ARCHIVO EXCEL DE ENTRADA
# =====================================================================
h1('4. Estructura del archivo Excel de entrada')

para(
    'El archivo debe tener extensión .xlsx, con encabezados en la fila 1 '
    '(columnas A y B) y los registros a procesar a partir de la fila 2. '
    'El programa lee únicamente las columnas A y B (i_begin_col = 1, '
    'i_end_col = 2) usando la función ALSM_EXCEL_TO_INTERNAL_TABLE.'
)

make_table(
    ['Columna', 'Encabezado esperado', 'Tipo', 'Longitud', 'Obligatorio', 'Ejemplo', 'Regla de validación'],
    [
        ['A', 'ORDEN_COMPRA', 'CHAR/NUMC', '10', 'Sí', '4500001234',
         'No puede estar vacío. Se aplica CONVERSION_EXIT_ALPHA_INPUT '
         '(rellena con ceros a la izquierda hasta 10 posiciones). '
         'Debe corresponder a una OC existente y no borrada en EKKO.'],
        ['B', 'CODIGO_LIBERACION', 'CHAR', '2', 'Sí', '01',
         'No puede estar vacío. Se convierte a mayúsculas y se condensa. '
         'La validez del código frente a la estrategia la determina '
         'BAPI_PO_RELEASE.'],
    ],
    col_widths=[2, 4, 2, 2, 2, 2, 6],
)

para('Validaciones de estructura (f_validar_encabezados):', bold=True)
bullet('La celda A1 debe contener exactamente "ORDEN_COMPRA" (insensible a mayúsculas/espacios).')
bullet('La celda B1 debe contener exactamente "CODIGO_LIBERACION".')
bullet('Si alguno de los encabezados no coincide, el programa finaliza con MESSAGE tipo "E" indicando el valor encontrado.')
bullet('Si el archivo no contiene registros desde la fila 2, el programa finaliza con MESSAGE tipo "E".')
bullet('Las filas completamente vacías (ambas columnas en blanco) se descartan automáticamente.')

# =====================================================================
# 5. LÓGICA DE PROCESAMIENTO
# =====================================================================
h1('5. Lógica de procesamiento por registro')

para('Para cada fila leída del Excel (a partir de la fila 2), el programa ejecuta la siguiente secuencia:')

numbered('Normalización de datos:')
bullet('ORDEN_COMPRA se condensa y se pasa por CONVERSION_EXIT_ALPHA_INPUT para obtener el formato interno EBELN (10 caracteres, ceros a la izquierda).')
bullet('CODIGO_LIBERACION se condensa y convierte a mayúsculas (FRGCO).')

numbered('Validación de campos obligatorios:')
bullet('Si EBELN está vacío -> semáforo rojo, estatus "Error", mensaje "Número de orden de compra vacío."')
bullet('Si FRGCO está vacío -> semáforo rojo, estatus "Error", mensaje "Código de liberación vacío."')

numbered('Validación de la orden de compra (FORM f_validar_oc):')
bullet('SELECT SINGLE * FROM EKKO WHERE EBELN = lv_ebeln AND LOEKZ = espacio (no borrada).')
bullet('Si no existe -> semáforo rojo, estatus "Error", mensaje "OC <EBELN> no existe o está borrada."')
bullet('Se recuperan BUKRS (sociedad), EKORG (organización de compras) y FRGSX (estrategia de liberación) para el log.')
bullet('Si FRGKE = \'V\' (indicador de liberación total) -> semáforo amarillo, estatus "Advertencia", mensaje "OC <EBELN> ya se encuentra completamente liberada." y se omite la llamada a la BAPI.')
bullet('En cualquier otro caso, el registro queda en semáforo verde, apto para liberación.')

numbered('Ejecución de la liberación (FORM f_ejecutar_bapi) — solo si P_SIMU = espacio:')
bullet('CALL FUNCTION BAPI_PO_RELEASE con PURCHASEORDER = EBELN y PO_REL_CODE = FRGCO.')
bullet('Se recorre la tabla RETURN; si existe algún mensaje tipo "E" (Error) o "A" (Abort), se considera que la liberación falló.')
bullet('Sin errores -> BAPI_TRANSACTION_COMMIT (WAIT = X), semáforo verde, estatus "Éxito", mensaje "OC <EBELN> liberada con código <FRGCO>."')
bullet('Con errores -> BAPI_TRANSACTION_ROLLBACK, semáforo rojo, estatus "Error".')
bullet('Todos los mensajes de la tabla RETURN se concatenan (tipo, id, número y texto) en el campo MENSAJE_SAP del log.')

numbered('Modo simulación (P_SIMU = X):')
bullet('No se llama a BAPI_PO_RELEASE ni se confirma ningún cambio.')
bullet('El registro válido queda con semáforo amarillo, estatus "Simulado", mensaje "Registro válido. Simulación: no se ejecutaron cambios."')

numbered('Fila de totales (FORM f_agregar_fila_totales):')
bullet('Al finalizar el procesamiento de todas las filas, se recorre el log y se calculan: total procesados, correctos (semáforo verde), errores (semáforo rojo) y simulados/advertencias (semáforo amarillo).')
bullet('Se agrega una fila adicional al log con ESTATUS = "TOTAL" y el resumen en MENSAJE_FUNC, visible siempre como última línea del ALV.')

# =====================================================================
# 6. MAPEO BAPI_PO_RELEASE
# =====================================================================
h1('6. Mapeo de parámetros — BAPI_PO_RELEASE')

make_table(
    ['Parámetro BAPI', 'Dirección', 'Valor enviado / recibido', 'Origen / Observaciones'],
    [
        ['PURCHASEORDER', 'Import', 'EBELN (10 posiciones, formato interno)',
         'Excel ORDEN_COMPRA tras CONVERSION_EXIT_ALPHA_INPUT.'],
        ['PO_REL_CODE', 'Import', 'FRGCO (2 posiciones)',
         'Excel CODIGO_LIBERACION, condensado y en mayúsculas.'],
        ['RETURN', 'Tables (Export)', 'Tabla BAPIRET2',
         'Se recorre completa; mensajes tipo E/A marcan error. '
         'Todos los mensajes se concatenan en MENSAJE_SAP del log.'],
    ],
    col_widths=[4, 3, 5, 6],
)

para(
    'Nota técnica: en esta versión del sistema, BAPI_PO_RELEASE no expone '
    'los parámetros de salida REL_STATUS ni REL_INDICATOR como IMPORTING '
    '(provocan el error en tiempo de ejecución '
    'CALL_FUNCTION_PARM_UNKNOWN / CX_SY_DYN_CALL_PARAM_NOT_FOUND si se '
    'declaran). Por lo tanto, el resultado de la liberación se determina '
    'exclusivamente analizando la tabla RETURN.'
)

para(
    'Confirmación de transacción:', bold=True
)
bullet('BAPI_TRANSACTION_COMMIT con WAIT = \'X\' cuando RETURN no contiene mensajes tipo E/A.')
bullet('BAPI_TRANSACTION_ROLLBACK cuando RETURN contiene al menos un mensaje tipo E o A.')

# =====================================================================
# 7. ESTRUCTURA DE DATOS INTERNA
# =====================================================================
h1('7. Estructuras de datos internas')

h2('7.1 TT_EXCEL')
para('Tabla estándar de tipo ALSMEX_TABLINE (estructura devuelta por ALSM_EXCEL_TO_INTERNAL_TABLE). Necesaria porque el tipo genérico "TABLE OF alsmex_tabline" no es válido como tipo de parámetro de FORM; se declara como tipo global para poder usarse en la firma de f_validar_encabezados.')

h2('7.2 TY_EXCEL_RAW')
make_table(
    ['Campo', 'Tipo', 'Descripción'],
    [
        ['ORDEN_COMPRA', 'CHAR 20', 'Valor crudo leído de la columna A del Excel.'],
        ['CODIGO_LIBERACION', 'CHAR 10', 'Valor crudo leído de la columna B del Excel.'],
    ],
    col_widths=[5, 3, 9],
)

h2('7.3 TY_LOG / TT_LOG (tabla de salida ALV)')
make_table(
    ['Campo', 'Tipo', 'Descripción / origen'],
    [
        ['SEMAFORO', 'CHAR 1', '1 = Verde (éxito), 2 = Amarillo (advertencia/simulado), 3 = Rojo (error). Usado como LIGHTS_FIELDNAME del ALV.'],
        ['LINEA', 'NUMC 4', 'Número de fila del Excel (incluye el desplazamiento +1 por el encabezado).'],
        ['EBELN', 'EBELN', 'Orden de compra en formato interno (10 posiciones).'],
        ['FRGCO', 'FRGCO', 'Código de liberación procesado.'],
        ['BUKRS', 'BUKRS', 'Sociedad, obtenida de EKKO.'],
        ['EKORG', 'EKORG', 'Organización de compras, obtenida de EKKO.'],
        ['FRGST', 'FRGST (dominio)', 'Se usa para almacenar la estrategia de liberación (EKKO-FRGSX).'],
        ['REL_INDICATOR', 'CHAR 1', 'Reservado; no se utiliza (la BAPI no expone este parámetro en este sistema).'],
        ['ESTATUS', 'CHAR 15', 'Éxito / Error / Advertencia / Simulado / TOTAL.'],
        ['MENSAJE_FUNC', 'CHAR 80', 'Mensaje funcional generado por el programa.'],
        ['MENSAJE_SAP', 'CHAR 220', 'Concatenación de los mensajes de la tabla RETURN de la BAPI.'],
    ],
    col_widths=[3, 3, 11],
)

para(
    'Nota: el campo FRGST se reutiliza para mostrar la estrategia de '
    'liberación (EKKO-FRGSX) dado que el campo EKKO-FRGST no existe en '
    'esta versión del Diccionario de datos.'
)

h2('7.4 Variables globales de totales')
make_table(
    ['Variable', 'Tipo', 'Descripción'],
    [
        ['GV_PROCESADOS', 'I', 'Total de filas procesadas (excluye la fila de totales).'],
        ['GV_CORRECTOS', 'I', 'Cantidad de registros con semáforo verde.'],
        ['GV_ERRORES', 'I', 'Cantidad de registros con semáforo rojo.'],
        ['GV_SIMULADOS', 'I', 'Cantidad de registros con semáforo amarillo (simulados o advertencias).'],
    ],
    col_widths=[4, 2, 11],
)

# =====================================================================
# 8. SALIDA / LOG ALV
# =====================================================================
h1('8. Salida — Log ALV de resultados')

para(
    'La salida se presenta mediante REUSE_ALV_GRID_DISPLAY con zebra '
    'activado y semáforo en la primera columna (LIGHTS_FIELDNAME = SEMAFORO).'
)

make_table(
    ['Columna ALV', 'Campo', 'Ancho', 'Alineación', 'Descripción'],
    [
        ['Sem.', 'SEMAFORO', '4', 'Centro', 'Semáforo de resultado (verde/amarillo/rojo).'],
        ['Fila', 'LINEA', '5', 'Derecha', 'Número de fila del Excel.'],
        ['Orden de compra', 'EBELN', '12', 'Izquierda', 'OC procesada.'],
        ['Cód. liberación', 'FRGCO', '6', 'Centro', 'Código liberador procesado.'],
        ['Sociedad', 'BUKRS', '6', 'Centro', 'Sociedad de la OC.'],
        ['Org. compras', 'EKORG', '8', 'Centro', 'Organización de compras de la OC.'],
        ['Estrategia', 'FRGST', '8', 'Centro', 'Estrategia de liberación (EKKO-FRGSX).'],
        ['Estatus', 'ESTATUS', '15', 'Izquierda', 'Éxito / Error / Advertencia / Simulado / TOTAL.'],
        ['Mensaje funcional', 'MENSAJE_FUNC', '80', 'Izquierda', 'Descripción funcional del resultado.'],
        ['Mensaje SAP/BAPI', 'MENSAJE_SAP', '220', 'Izquierda', 'Mensajes devueltos por BAPI_PO_RELEASE.'],
    ],
    col_widths=[3, 2, 1, 2, 6],
)

h2('8.1 Fila de totales')
para(
    'La última fila del ALV siempre corresponde al resumen del '
    'procesamiento, identificable por ESTATUS = "TOTAL" y semáforo '
    'amarillo. El campo MENSAJE_FUNC contiene el detalle:'
)
code_block('Procesados: <n>  Correctos: <n>  Errores: <n>  Simulados/Adv.: <n>')

h2('8.2 Exportación')
para(
    'El usuario puede exportar el resultado mediante las funciones '
    'estándar del ALV (Hoja de cálculo / Local file), habilitadas por '
    'I_SAVE = \'A\' (variantes de visualización ALV permitidas).'
)

# =====================================================================
# 9. CASOS DE PRUEBA
# =====================================================================
h1('9. Casos de prueba (Test cases)')

make_table(
    ['ID', 'Descripción', 'Datos de entrada', 'Resultado esperado'],
    [
        ['PU01', 'Carga de archivo con estructura correcta', 'Archivo .xlsx con columnas ORDEN_COMPRA y CODIGO_LIBERACION', 'El sistema lee el archivo y procesa los registros sin error de estructura.'],
        ['PU02', 'Archivo con estructura incorrecta', 'Archivo sin columna CODIGO_LIBERACION', 'El sistema detiene la ejecución (MESSAGE tipo E) indicando la columna faltante.'],
        ['PU03', 'Liberación correcta de OC con un nivel', 'OC pendiente + código liberador correcto', 'BAPI_PO_RELEASE libera la OC, se ejecuta COMMIT y el log muestra semáforo verde / Éxito.'],
        ['PU04', 'OC inexistente', 'EBELN no existente o borrado', 'El log muestra semáforo rojo / Error "OC no existe o está borrada" y no se llama a la BAPI.'],
        ['PU05', 'Código liberador inválido', 'OC válida + código no asignado a la estrategia', 'BAPI_PO_RELEASE retorna mensaje de error; el log muestra semáforo rojo y el mensaje SAP correspondiente.'],
        ['PU06', 'OC ya liberada', 'OC con FRGKE = \'V\'', 'El log muestra semáforo amarillo / Advertencia "OC ya se encuentra completamente liberada" y no se llama a la BAPI.'],
        ['PU07', 'Liberación de varios niveles', 'Misma OC con códigos nivel 1 y nivel 2 (dos filas)', 'Cada fila se procesa de forma independiente; BAPI_PO_RELEASE valida la secuencia internamente.'],
        ['PU08', 'Nivel superior sin nivel inferior', 'OC pendiente nivel 1, archivo solo contiene código nivel 2', 'BAPI_PO_RELEASE retorna error de secuencia; el log muestra semáforo rojo con el mensaje SAP.'],
        ['PU09', 'Duplicados en archivo', 'Misma OC y código repetidos en dos filas', 'Ambas filas se procesan; la segunda ejecución de la BAPI determina el resultado según el estado tras la primera.'],
        ['PU10', 'Modo simulación', 'Archivo válido + P_SIMU marcado', 'El sistema valida los registros, no llama a BAPI_PO_RELEASE y marca ESTATUS = "Simulado" (semáforo amarillo).'],
        ['PU11', 'Usuario sin autorización', 'Usuario sin permiso para el código liberador', 'BAPI_PO_RELEASE retorna mensaje de error de autorización en RETURN; el log muestra semáforo rojo.'],
        ['PU12', 'Error retornado por BAPI', 'Forzar un caso estándar con error en liberación', 'El programa captura los mensajes de RETURN y los muestra concatenados en MENSAJE_SAP.'],
        ['PU13', 'Exportación de log ALV', 'Ejecutar proceso con resultados mixtos', 'El usuario exporta el log mediante la función estándar del ALV.'],
        ['PU14', 'Alto volumen de registros', 'Archivo con múltiples OC', 'El sistema procesa todas las filas y la fila TOTAL refleja los conteos correctos.'],
    ],
    col_widths=[1.5, 4, 5, 6.5],
)

# =====================================================================
# 10. CONSIDERACIONES TÉCNICAS Y NOTAS DE IMPLEMENTACIÓN
# =====================================================================
h1('10. Consideraciones técnicas y notas de implementación')

para('Durante la implementación se identificaron y corrigieron los siguientes puntos respecto a la especificación funcional original, derivados de diferencias del Diccionario ABAP / interfaces BAPI en el sistema destino:', )

make_table(
    ['# ', 'Punto', 'Ajuste aplicado'],
    [
        ['1', 'Tipo de parámetro de FORM para tabla ALSMEX_TABLINE', 'Se declaró el tipo global TT_EXCEL (STANDARD TABLE OF ALSMEX_TABLINE) para usarlo en la firma de f_validar_encabezados, ya que "TYPE TABLE OF <tabla>" no es válido en la cláusula USING de un FORM.'],
        ['2', 'Lectura de campos de EKKO', 'Se reemplazó el SELECT con lista explícita de campos por SELECT SINGLE * INTO @ls_ekko (TYPE ekko), delegando el mapeo al Diccionario ABAP.'],
        ['3', 'Campo EKKO-FRGST inexistente', 'Se sustituyó por EKKO-FRGSX (estrategia de liberación) para el campo FRGST del log, y la verificación de liberación completa se realiza con EKKO-FRGKE = \'V\'.'],
        ['4', 'Validación previa contra T16FK', 'Se eliminó (el campo FRGCO no es accesible como columna directa en esa tabla en este sistema). La validación de código/secuencia la realiza BAPI_PO_RELEASE.'],
        ['5', 'Parámetros REL_STATUS / REL_INDICATOR de BAPI_PO_RELEASE', 'No existen en la interfaz IMPORTING de esta versión; se eliminaron. El resultado se determina exclusivamente con la tabla RETURN (mensajes tipo E/A = error).'],
        ['6', 'SET/GET PARAMETER ID para totales', 'No es válido para variables TYPE I (requiere C/N/D/T). Se sustituyó por variables globales (GV_PROCESADOS, GV_CORRECTOS, GV_ERRORES, GV_SIMULADOS).'],
        ['7', 'Visualización de totales (footer ALV)', 'El evento END_OF_LIST de REUSE_ALV_GRID_DISPLAY no renderiza el footer de forma confiable en la interfaz Fiori/Web GUI. Se optó por agregar una fila adicional al log (ESTATUS = "TOTAL") con el resumen, siempre visible como última línea del ALV.'],
    ],
    col_widths=[1, 5, 11],
)

h2('10.1 Rendimiento')
bullet('La lectura del archivo Excel se realiza en una sola llamada a ALSM_EXCEL_TO_INTERNAL_TABLE (sin loops por celda adicionales para I/O).')
bullet('Las validaciones contra EKKO se ejecutan con SELECT SINGLE por cada registro; para volúmenes muy altos puede evaluarse una validación previa masiva (SELECT ... FOR ALL ENTRIES) como mejora futura.')
bullet('BAPI_TRANSACTION_COMMIT se ejecuta con WAIT = \'X\' únicamente cuando la liberación de un registro fue exitosa, evitando bloqueos innecesarios entre registros.')

h2('10.2 Autorizaciones')
para(
    'El usuario ejecutor debe contar con las autorizaciones estándar de '
    'liberación de OC (objeto M_EINK_FRG y relacionados) por sociedad, '
    'organización de compras, grupo de compras y código de liberación. '
    'Si el usuario no está autorizado, BAPI_PO_RELEASE devuelve el error '
    'correspondiente en la tabla RETURN, el cual se refleja en el log '
    '(PU11).'
)

# =====================================================================
# GUARDAR
# =====================================================================
output_path = '/home/user/ABAPCloud/docs/P158_Documentacion_Tecnica_ZMM_LIB_OC.docx'
doc.save(output_path)
print(f'Documento generado: {output_path}')
