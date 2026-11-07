# Tema de WordPress: Consejo Iberoamericano de Arte, Psicología y Educación

Tema de bloques hecho a partir del diseño de Figma ("Inicio – desk", 1440 px).
Todos los textos, botones e imágenes se editan desde el editor visual de WordPress.

## Instalar en LocalWP

1. Descarga **`cipe.zip`** (está en esta misma carpeta del repositorio, botón *Download raw file*).
2. En tu sitio de LocalWP abre **WP Admin → Apariencia → Temas → Añadir nuevo tema → Subir tema**.
3. Elige `cipe.zip`, pulsa **Instalar ahora** y después **Activar**.

Para actualizarlo más adelante repite los pasos: WordPress te ofrecerá **Reemplazar el actual por el subido**.

## Editar la página de Inicio

**Apariencia → Editor → Plantillas → Página de inicio** (puede aparecer como *Portada*) (o pulsa *Editar sitio* en la barra superior estando en la portada).
Haz clic en cualquier texto para cambiarlo y pulsa **Guardar**.

- **Logotipo**: el que trae el tema es provisional. Haz clic en él (en la cabecera) → **Reemplazar** → sube tu SVG/PNG.
- **Menú**: Apariencia → Editor → Navegación. Los enlaces apuntan a `/quienes-somos/`, `/cuerpo-colegiado/`, `/solicitar-aval/`, `/consultar-registro/` y `/contacto/`. Crea esas páginas con esos nombres (o cambia los enlaces).
- **Botones**: en el panel derecho → *Estilos* puedes elegir **Con flecha** o **Contorno con flecha**.
- **Colores y tipografía**: Apariencia → Editor → Estilos. La paleta del diseño ya está cargada (Crema, Verde petróleo, Salvia, Ocre, Texto).
- **Patrones**: en el insertador (+) → Patrones → *Consejo Iberoamericano* están las secciones de Inicio para reutilizarlas en otras páginas.

> Ajustes recomendados: **Ajustes → Enlaces permanentes → Nombre de la entrada**.

## Contenido del tema

| Archivo | Para qué sirve |
| --- | --- |
| `cipe/theme.json` | Colores, tipografía (Inter, incluida en el tema), tamaños y espaciados |
| `cipe/style.css` | Detalles visuales: botones con flecha, pasos 1-2-3, buscador, menú activo |
| `cipe/functions.php` | Carga de estilos, estilos de botón y marca del menú activo |
| `cipe/parts/` | Cabecera y pie de página |
| `cipe/templates/` | Plantillas: portada, páginas y listado |
| `cipe/patterns/` | Secciones de la página de Inicio |

## Volver a generar el ZIP

```bash
cd wordpress && rm -f cipe.zip && zip -r cipe.zip cipe -x '*.DS_Store'
```
