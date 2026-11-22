# Contexto del desarrollador

## Perfil
- Cristóbal Contreras, consultor y desarrollador SAP ABAP senior, con 21 años de experiencia en consultoría SAP.
- Stack técnico: OO ABAP, ALV, Smart Forms, IDocs, Workflows, Module Pool e interfaces.
- Fuerte enfoque en procesos order-to-cash, soporte, y gestión de equipos y clientes.
- Orientado a proyectos con S/4HANA, RAP y Fiori.
- Formación en curso: Diplomado en Ciberseguridad y Maestría en Ciberseguridad, Ciberinteligencia y Ciberdefensa.

## Preferencias de trabajo
- Comunicación en español; inglés técnico sin problema.
- ABAP: usar únicamente métodos y sentencias vigentes; nada obsoleto (deprecated).
- Entregables formales (cotizaciones, documentación, entregables a cliente): en Word editable.

## Componentes reutilizables conocidos
- `zcl_envio_correo`: su método `enviar_itab_por_email` convierte cualquier tabla interna a XLSX real con `CL_FDT_XL_SPREADSHEET` y la envía por correo con `CL_BCS`.
  - Para evitar errores de campos vacíos, hay que asignar `document_name = 'REPORTE_XLSX'` y `xdocument = lv_init_xstring`.
