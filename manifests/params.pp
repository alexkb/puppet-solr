# This is the generic solr parameters
class solr::params {
  case $operatingsystem {
    Ubuntu: {
      $openjdk = 'openjdk-6-jdk'
      $tomcatuser = "tomcat6"
    }
    OracleLinux: {
      $openjdk = 'java-1.6.0-openjdk'
      $tomcatuser = "tomcat"
    }
    default: {
      fail("Operating system, $operatingsystem, is not supported by the tomcat module")
    }
  }
}
