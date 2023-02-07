{ pkgs, config, ... }:

let 
  themes = {
    inherit (pkgs.wordpressPackages.themes) twentytwentythree;
  };
  plugins = {};
  languages = [];
  wpConfig = pkgs.writeTextFile {
    name = "wp-config-dev.php";
    text = ''
      <?php
        $table_prefix  = 'wp_';
        define('DISALLOW_FILE_EDIT', true);
        define('AUTOMATIC_UPDATER_DISABLED', true);
        define('DB_NAME', 'wordpress');
        define('DB_HOST', 'localhost:${config.env.DEVENV_STATE}/mysql.sock');
        define('DB_USER', 'root');
        define('DB_PASSWORD', "");
        define('DB_CHARSET', 'utf8');
        define('AUTH_KEY', "");
	define('SECURE_AUTH_KEY', "");
	define('LOGGED_IN_KEY', "");
	define('NONCE_KEY', "");
	define('AUTH_SALT' , "");
	define('SECURE_AUTH_SALT', "");
	define('LOGGED_IN_SALT', "");
	define('NONCE_SALT', "");
        if ( !defined('ABSPATH') )
          define('ABSPATH', dirname(__FILE__) . '/');
        require_once(ABSPATH . 'wp-settings.php');
      ?>
    '';
    checkPhase = "${pkgs.php81}/bin/php --syntax-check $target";
  };
  wordpress = with pkgs; stdenv.mkDerivation {
    pname = "wordpress-dev";
    version = pkgs.wordpress.version;
    src = pkgs.wordpress;
    installPhase = ''
      mkdir -p $out
      cp -r * $out/
      # symlink the wordpress config
      ln -s ${wpConfig} $out/share/wordpress/wp-config.php
      #
      # Symlinking works for most plugins and themes, but Avada, for instance, fails to
      # understand the symlink, causing its file path stripping to fail. This results in
      # requests that look like: https://example.com/wp-content//nix/store/...plugin/path/some-file.js
      # Since hard linking directories is not allowed, copying is the next best thing.
      # copy additional plugin(s), theme(s) and language(s)
      ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: theme: "cp -r ${theme} $out/share/wordpress/wp-content/themes/${name}") themes)}
      ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: plugin: "cp -r ${plugin} $out/share/wordpress/wp-content/plugins/${name}") plugins)}
      ${pkgs.lib.concatMapStringsSep "\n" (language: "cp -r ${language} $out/share/wordpress/wp-content/languages/") languages}
      ln -sf ${builtins.toString ./.} $out/share/wordpress/wp-content/plugins/dev-plugin
    '';
  };
  wp-cli-yaml = pkgs.writeTextFile {
    name = "wp-cli-dev.yaml";
    text = ''
      path: ${wordpress}/share/wordpress
    '';
  };
in

{
  packages = [ 
    wordpress
    pkgs.wp-cli
  ];

  env = {
    WP_CLI_CONFIG_PATH = "${wp-cli-yaml}";
  };

  scripts.wp-init.exec = ''
    wp core install \
      --url=http://localhost:8000 \
      --title="test" \
      --admin_name="test" \
      --admin_password="test" \
      --admin_email="root@localhost.localhost"
  '';

  processes.wp-init = {
    exec = ''
      while ! MYSQL_PWD="" ${pkgs.mysql}/bin/mysqladmin ping -u root --silent; do sleep 1; done; wp-init; while true; do sleep 86400; done
    '';
  };

  languages.php.enable = true;
  languages.php.fpm.pools.web = {
    settings = {
      "pm" = "dynamic";
      "pm.max_children" = 5;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 5;
    };
  };

  services.mysql.enable = true;
  #services.mysql.settings = { mysqld = { skip_networking = true; }; };
  services.mysql.settings = {
    mysqld = {
      bind_address = "127.0.0.1";
      mysqlx_bind_address = "127.0.0.1";
    };
  };
  services.mysql.initialDatabases = [
    { name = "wordpress"; }
  ];

  services.caddy.enable = true;
  services.caddy.config = ''
    {
      auto_https off
      admin off
    }
  '';
  services.caddy.virtualHosts."http://localhost:8000" = {
    extraConfig = ''
      root * ${wordpress}/share/wordpress
      php_fastcgi unix/${config.languages.php.fpm.pools.web.socket}
      file_server

      #@uploads {
      #  path_regexp path /uploads\/(.*)\.php
      #}
      #rewrite @uploads /

      #@wp-admin {
      #  path  not ^\/wp-admin/*
      #}
      #rewrite @wp-admin {path}/index.php?{query}
    '';
  };
}
