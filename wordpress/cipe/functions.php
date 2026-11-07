<?php
/**
 * Funciones del tema.
 *
 * @package cipe
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Carga los estilos del tema en la web y en el editor.
 */
function cipe_setup() {
	add_editor_style( 'style.css' );
}
add_action( 'after_setup_theme', 'cipe_setup' );

function cipe_enqueue_styles() {
	wp_enqueue_style(
		'cipe-style',
		get_stylesheet_uri(),
		array(),
		wp_get_theme()->get( 'Version' )
	);
}
add_action( 'wp_enqueue_scripts', 'cipe_enqueue_styles' );

/**
 * Estilos extra para el bloque Botón (se eligen en el panel "Estilos" del editor).
 */
function cipe_register_block_styles() {
	register_block_style(
		'core/button',
		array(
			'name'  => 'arrow',
			'label' => __( 'Con flecha', 'cipe' ),
		)
	);
	register_block_style(
		'core/button',
		array(
			'name'  => 'arrow-outline',
			'label' => __( 'Contorno con flecha', 'cipe' ),
		)
	);
}
add_action( 'init', 'cipe_register_block_styles' );

/**
 * Categoría propia para los patrones del tema.
 */
function cipe_register_pattern_category() {
	register_block_pattern_category(
		'cipe',
		array( 'label' => __( 'Consejo Iberoamericano', 'cipe' ) )
	);
}
add_action( 'init', 'cipe_register_pattern_category' );

/**
 * Marca como activo el enlace del menú que apunta a la página actual
 * (WordPress no lo hace solo con los enlaces personalizados).
 */
function cipe_mark_current_nav_link( $block_content, $block ) {
	$url = isset( $block['attrs']['url'] ) ? $block['attrs']['url'] : '';
	if ( '' === $url ) {
		return $block_content;
	}
	$link_path    = untrailingslashit( (string) wp_parse_url( $url, PHP_URL_PATH ) );
	$request_path = untrailingslashit( (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH ) );
	$home_path    = untrailingslashit( (string) wp_parse_url( home_url( '/' ), PHP_URL_PATH ) );

	// Los enlaces relativos ("/contacto/") se entienden respecto a la portada.
	if ( '' !== $home_path && 0 !== strpos( $link_path, $home_path ) && ! preg_match( '#^https?://#', $url ) ) {
		$link_path = $home_path . $link_path;
	}

	if ( $link_path !== $request_path ) {
		return $block_content;
	}

	$tags = new WP_HTML_Tag_Processor( $block_content );
	if ( $tags->next_tag( 'li' ) ) {
		$tags->add_class( 'current-menu-item' );
	}
	if ( $tags->next_tag( 'a' ) ) {
		$tags->set_attribute( 'aria-current', 'page' );
	}
	return $tags->get_updated_html();
}
add_filter( 'render_block_core/navigation-link', 'cipe_mark_current_nav_link', 10, 2 );
