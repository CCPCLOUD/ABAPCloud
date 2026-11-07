<?php
/**
 * Title: Cabecera
 * Slug: cipe/header
 * Categories: cipe, header
 * Block Types: core/template-part/header
 * Inserter: no
 */
?>
<!-- wp:group {"align":"full","style":{"spacing":{"padding":{"top":"22px","bottom":"22px"}}},"layout":{"type":"constrained","contentSize":"1280px"}} -->
<div class="wp-block-group alignfull" style="padding-top:22px;padding-bottom:22px">
	<!-- wp:group {"layout":{"type":"flex","flexWrap":"nowrap","justifyContent":"space-between"}} -->
	<div class="wp-block-group">
		<!-- wp:group {"className":"cipe-brand","layout":{"type":"flex","flexWrap":"nowrap"}} -->
		<div class="wp-block-group cipe-brand">
			<!-- wp:image {"width":"76px","height":"76px","sizeSlug":"full","linkDestination":"custom"} -->
			<figure class="wp-block-image size-full is-resized"><a href="<?php echo esc_url( home_url( '/' ) ); ?>"><img src="<?php echo esc_url( get_theme_file_uri( 'assets/images/logo.svg' ) ); ?>" alt="<?php esc_attr_e( 'Inicio', 'cipe' ); ?>" style="width:76px;height:76px"/></a></figure>
			<!-- /wp:image -->
			<!-- wp:paragraph {"fontSize":"small"} -->
			<p class="has-small-font-size">Consejo Iberoamericano<br>de Arte, Psicología y Educación.</p>
			<!-- /wp:paragraph -->
		</div>
		<!-- /wp:group -->
		<!-- wp:navigation {"overlayMenu":"mobile","layout":{"type":"flex","justifyContent":"right"}} -->
			<!-- wp:navigation-link {"label":"Inicio","url":"/","kind":"custom"} /-->
			<!-- wp:navigation-link {"label":"Quiénes somos","url":"/quienes-somos/","kind":"custom"} /-->
			<!-- wp:navigation-link {"label":"Cuerpo colegiado","url":"/cuerpo-colegiado/","kind":"custom"} /-->
			<!-- wp:navigation-link {"label":"Solicitar aval","url":"/solicitar-aval/","kind":"custom"} /-->
			<!-- wp:navigation-link {"label":"Consultar registro","url":"/consultar-registro/","kind":"custom"} /-->
			<!-- wp:navigation-link {"label":"Contacto","url":"/contacto/","kind":"custom"} /-->
		<!-- /wp:navigation -->
	</div>
	<!-- /wp:group -->
</div>
<!-- /wp:group -->
