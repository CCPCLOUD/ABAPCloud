*&---------------------------------------------------------------*
*& Report ZRMM_MASS_ARTICLE_CREATE
*&---------------------------------------------------------------*
*& P157 - Creación Masiva de Artículos (Ticket #26515)
*& Transacción Z sugerida: ZMM_ARTICLE_CREATE
*&
*& Carga un archivo Excel (.xlsx) local con datos de artículos
*& simples/genéricos/variantes de SAP Retail, valida la información
*& obligatoria y dependiente de customizing, genera y procesa el
*& IDoc estándar ARTMAS09 (FM MASTER_IDOC_DISTRIBUTE) y presenta un
*& log de resultados en ALV.
*&
*& Alcance: creación de artículo a nivel mandante/datos básicos
*& (MARA/MAKT/MARC/MARD/MARM/MEAN/MLAN/MBEW/MVKE/WLK2/variantes).
*& Fuera de alcance: extensión posterior a centros/ventas/canales/
*& almacenes vía otras transacciones, clasificación avanzada.
*&
*& NOTA IMPORTANTE PARA EL DESARROLLADOR:
*& Los nombres de segmento y campos usados abajo (E1BPE1MATHEAD,
*& E1BPE1MARART, etc.) corresponden a los segmentos observados en
*& IDocs ARTMAS09 exitosos de referencia. Las TYPES locales
*& (ty_e1bpe1...) solo ordenan la lógica de negocio: el armado final
*& de cada segmento (FORM MAP_TO_REAL_SEGMENT) copia los valores por
*& NOMBRE de campo contra la estructura DDIC real del sistema
*& destino, por lo que diferencias de longitud entre lo asumido aquí
*& y el sistema real ya no desalinean los datos.
*& Lo que SÍ puede variar por sistema/versión de Retail es el NOMBRE
*& de segmento o de campo en sí (no solo su longitud). Para
*& confirmarlo sin revisar manualmente WE30/SE11: ejecute la
*& transacción en modo simulación (P_SIM = X) contra un archivo real
*& - el log ALV mostrará una fila de advertencia listando cualquier
*& segmento/campo que no haya encontrado su equivalente por nombre en
*& el sistema (FORM REPORT_UNMAPPED_FIELDS). Si aparece alguno,
*& ajústelo solo en la sección de TYPES de segmento; el resto de la
*& lógica funcional no cambia.
*&
*& Estructura del programa:
*&   ZRMM_MASS_ARTICLE_CREATE_TOP  Declaraciones (tipos, constantes,
*&                                 pantalla de selección, clases
*&                                 locales de soporte, datos globales)
*&   ZRMM_MASS_ARTICLE_CREATE_F01  Rutinas FORM (todo el código
*&                                 invocado vía PERFORM)
*&---------------------------------------------------------------*
REPORT zrmm_mass_article_create.

INCLUDE zrmm_mass_article_create_top.
INCLUDE zrmm_mass_article_create_f01.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f4_file_open CHANGING p_file.

START-OF-SELECTION.
  PERFORM main.
