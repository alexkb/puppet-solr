class solr::install ($source_url, $home_dir, $solr_data_dir, $package, $cores, $tomcat_connector_port) {
  include solr::params

  $tmp_dir = "/var/tmp"
  $solr_dist_dir = "${home_dir}/dist"
  $solr_package = "${solr_dist_dir}/${package}.war"
  $solr_home_dir = "${home_dir}"
  $destination = "$tmp_dir/$package.tgz"

  package { $::solr::params::openjdk:
    ensure => present,
  }
  package {"tomcat6":
    ensure => present,
    require => File['tomcat-config'],
  }

  service { "tomcat6":
    enable => "true",
    ensure => "running",
    require => [Package["tomcat6"], File['tomcat-config']],
    subscribe => File["$solr_home_dir/solr.xml"],
  }

  exec { "solr_home_dir":
    command => "echo 'ceating ${solr_home_dir}' && mkdir -p ${solr_home_dir}",
    path => ["/bin", "/usr/bin", "/usr/sbin"],
    creates => $solr_home_dir
  }

  exec { "download-solr":
    command => "wget $source_url",
    creates => "$destination",
    cwd => "$tmp_dir",
    path => ["/bin", "/usr/bin", "/usr/sbin"],
    require => Exec["solr_home_dir"],
  }

  exec { "unpack-solr":
    command => "tar -xzf $destination --directory=$tmp_dir",
    creates => "$tmp_dir/$package",
    cwd => "$tmp_dir",
    require => Exec["download-solr"],
    path => ["/bin", "/usr/bin", "/usr/sbin"],
  }

  exec { "mv-solr-war":
    command => "mv ${tmp_dir}/${package}/dist/${package}.war /usr/share/tomcat6/webapps/solr.war",
    creates => "/usr/share/tomcat6/webapps/solr.war",
    cwd => "$tmp_dir",
    require => Exec["unpack-solr"],
    path => ["/bin", "/usr/bin", "/usr/sbin"],
  }

  exec { "mv-solr-app":
    command => "mv ${tmp_dir}/${package}/example/solr /usr/share/tomcat6/webapps/solr",
    creates => "/usr/share/tomcat6/webapps/solr",
    cwd => "$tmp_dir",
    require => Exec["mv-solr-war"],
    path => ["/bin", "/usr/bin", "/usr/sbin"],
  }

  file { "/usr/share/tomcat6/webapps/solr":
    ensure => directory,
    require => [Exec["mv-solr-app"]],
    recurse => true,
    source => "/usr/share/tomcat6/webapps/solr",
    group   => $::solr::params::tomcatuser,
    owner   => $::solr::params::tomcatuser,
  }

  # Ensure solr dist directory exist, with the appropriate privileges and copy contents of tar'd dist directory
  file { $solr_dist_dir:
    ensure => directory,
    require => [Package["tomcat6"],Exec["unpack-solr"]],
    source => "${tmp_dir}/${package}/dist/",
    recurse => true,
    group   => $::solr::params::tomcatuser,
    owner   => $::solr::params::tomcatuser,
  }

  file { "/etc/tomcat6/Catalina/localhost/solr.xml":
    ensure => present,
    content => template("solr/tomcat_solr.xml.erb"),
    require => [Package["tomcat6"],File["/usr/share/tomcat6/webapps/solr"]],
    notify  => Service['tomcat6'],
    group   => $::solr::params::tomcatuser,
    owner   => $::solr::params::tomcatuser,
  }

  # Tomcat config file
  # *NOTE*: This _MUST_ come first so that Tomcat starts on the correct port.
  #         If Package['tomcat6'] installs before this file is in place, it will
  #         start on the default port (8080), which can conflict with other
  #         services.

  file { "/etc/tomcat6":
    ensure => "directory",
  }

  file { 'tomcat-config':
    path => "/etc/tomcat6/server.xml",
    ensure => present,
    content => template("solr/tomcat_server.xml.erb"),
    require => File["/etc/tomcat6"],
    notify  => Service['tomcat6'],
  }

  # Fix Tomcat config permissions
  exec { 'fix-tomcat-config-permissions':
    require => [Package["tomcat6"], File['tomcat-config']],
    command => "chown  ${::solr::params::tomcatuser}:${::solr::params::tomcatuser} /etc/tomcat6/server.xml",
    path => ["/bin", "/usr/bin", "/usr/sbin"],
  }

  # Create cores
  solr::core {$cores:
    base_data_dir => $solr_data_dir,
    solr_home => $home_dir,
    require => Package['tomcat6'],
    notify => Service['tomcat6'],
  }

  # Create Solr file referencing new cores
  file { "$solr_home_dir/solr.xml":
    ensure => present,
    content => template("solr/solr.xml.erb"),
    notify  => Service['tomcat6'],
    group   => $::solr::params::tomcatuser,
    owner   => $::solr::params::tomcatuser,
  }
}
