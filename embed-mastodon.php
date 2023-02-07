<?php
/*
Plugin Name: Embed Mastodon
Plugin URI: https://github.com/mstone/embed-mastodon
Description: Prettily embed Mastodon/ActivityPub posts.
Version: 0.1
Licence: MIT
Author: Michael Stone
Author URI: https://mstone.info
*/

add_action('init', 'embed_mastodon_register');

function embed_mastodon_register() {
  wp_embed_register_handler('mastodon', '#^(https?:\/\/[^/]+)\/@[^/]+\/\d+$#i', 'embed_mastodon_handler');
}

function embed_mastodon_handler($matches, $attr, $url, $rawattr) {
  $embed = '<iframe src="' 
    . esc_attr($url . "/embed") 
    . '" class="mastodon-embed"' 
    . ' style="max-width: 100%; border: 0"' 
    . ' width="100%"' 
    . ' allowfullscreen="allowfullscreen">'
    . '</iframe>'
    . '<script src="' 
    . esc_attr($matches[1]) 
    . '/embed.js"' 
    . ' async="async"></script>';
  return $embed;
}

?>
