#!/bin/bash

LIST_OF_DEPENDENCIES="gcc expat-devel pcre-devel libtool openssl-devel libxml2-devel"
SOURCE_DIR="/opt"
HTTPD_VERS="httpd-2.4.46"
APR_VERS="apr-1.7.0"
APR_UTIL_VERS="apr-util-1.6.1"
MOD_SECURITY_VERS="modsecurity-2.9.3"
MOD_JK_VERS="tomcat-connectors-1.2.48-src"
TOMCAT_VERS="apache-tomcat-10.0.5"
APACHE_HOME="/usr/local/apache2"
TOMCAT_HOME="/usr/local/tomcat10"
JAVA_VERS="jre1.8.0_291"
JAVA_HOME="/usr/local/$JAVA_VERS"
LOG_FILE="$SOURCE_DIR/installation.log"

#exit_on_error() {
    #exit_code=&1
    #if [ $exit_code -ne 0 ]; then
    #    echo "Script Failed, Refer $LOG_FILE"
    #    exit $exit_code
    #fi
#}

echo "Installing the must-have pre-requisites"
yum install -y $LIST_OF_DEPENDENCIES

echo "Downloading source files to $SOURCE_DIR"
cd $SOURCE_DIR
#URLs="https://mirrors.estointernet.in/apache/httpd/$HTTPD_VERS.tar.gz https://apachemirror.wuchna.com/apr/$APR_VERS.tar.gz https://mirrors.estointernet.in/apache/apr/$APR_UTIL_VERS.tar.gz https://www.modsecurity.org/tarball/2.9.3/$MOD_SECURITY_VERS.tar.gz https://apachemirror.wuchna.com/tomcat/tomcat-connectors/jk/$MOD_JK_VERS.tar.gz https://mirrors.estointernet.in/apache/tomcat/tomcat-10/v10.0.5/bin/$TOMCAT_VERS.tar.gz"
#wget http://dc1.domain.com/sample.war
#for u in $URLs
#do
#  wget -q -O - $u | tar -xzf -
#done
find . -iname "*.tar.gz" -print0 | xargs -0 --max-args=1 tar xzf

echo "Started building HTTPD"
cd $SOURCE_DIR #>> $LOG_FILE 2>&1 || exit_on_error $?
mv $APR_VERS $HTTPD_VERS/srclib/apr
mv $APR_UTIL_VERS $HTTPD_VERS/srclib/apr-util
cd $SOURCE_DIR/$HTTPD_VERS
./configure --enable-ssl --enable-so --with-mpm=event --with-included-apr --prefix=$APACHE_HOME #>> $LOG_FILE 2>&1 || exit_on_error $?
make #>> $LOG_FILE 2>&1 || exit_on_error $?
make install #>> $LOG_FILE 2>&1 || exit_on_error $?
echo "\n\n########### Completed building HTTPD ###########\n\n"

echo "pathmunge /opt/apache2/bin" > /etc/profile.d/httpd.sh

cat <<EOF | tee -a /etc/systemd/system/httpd.service
[Unit]
Description=The Apache HTTP Server
After=network.target

[Service]
Type=forking
ExecStart=$APACHE_HOME/bin/apachectl -k start
ExecReload=$APACHE_HOME/bin/apachectl -k graceful
ExecStop=$APACHE_HOME/bin/apachectl -k graceful-stop
PIDFile=$APACHE_HOME/logs/httpd.pid
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

## JAVA installation
cd $SOURCE_DIR
#tar -xzf jre-8u291-linux-x64.tar.gz
mv jre1.8.0_291 $JAVA_HOME
alternatives --install /usr/bin/java java /usr/local/jre1.8.0_291/bin/java 2
alternatives --install /usr/bin/jar jar /usr/local/jre1.8.0_291/bin/jar 2
alternatives --install /usr/bin/javac javac /usr/local/jre1.8.0_291/bin/javac 2
alternatives --set jar /usr/local/jre1.8.0_291/bin/jar
alternatives --set javac /usr/local/jre1.8.0_291/bin/javac

mv $SOURCE_DIR/$TOMCAT_VERS $TOMCAT_HOME
cp $SOURCE_DIR/sample.war $TOMCAT_HOME/webapps/
echo "export CATALINA_HOME="$TOMCAT_HOME"" >> ~/.bashrc
source ~/.bashrc

mv /usr/local/tomcat10/conf/server.xml /usr/local/tomcat10/conf/server.xml-bak
cat <<EOF | tee -a /usr/local/tomcat10/conf/server.xml
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">
    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />
    <!-- Define an AJP 1.3 Connector on port 8009 -->
    <Connector protocol="AJP/1.3"
               Address="0.0.0.0"
               secretRequired="true"
               secret="mysecret"
               port="8009"
               redirectPort="8443" />
    <Engine name="Catalina" defaultHost="localhost" jvmRoute="jvm1">

      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />

      </Host>
    </Engine>
  </Service>
</Server>
EOF

## mod_jk configuration
cd $SOURCE_DIR/$MOD_JK_VERS/native
./buildconf.sh
./configure -with-apxs=$APACHE_HOME/bin/apxs
make
make install

echo "Include conf/extra/mod_jk.conf" >> $APACHE_HOME/conf/httpd.conf

cat <<EOF | tee -a $APACHE_HOME/conf/extra/mod_jk.conf
LoadModule jk_module modules/mod_jk.so
jkWorkersFile conf/extra/workers.properties
JkMount /sample loadbalancer
JkMount /sample/* loadbalancer
JkMount /status status
EOF

cat <<EOF | tee -a $APACHE_HOME/conf/extra/workers.properties
worker.list=loadbalancer,status

worker.jvm1.type=ajp13
worker.jvm1.host=localhost
worker.jvm1.port=8009
worker.jvm1.secret=mysecret

worker.loadbalancer.type=lb
worker.loadbalancer.balance_workers=jvm1
worker.loadbalancer.sticky_session=1

worker.status.type=status
EOF

## mod_security configuration
cd $SOURCE_DIR/$MOD_SECURITY_VERS
./configure --with-apr=../$HTTPD_VERS/srclib/apr --with-apu=../$HTTPD_VERS/srclib/apr-util
make
make install
cp modsecurity.conf-recommended $APACHE_HOME/conf/extra/modsecurity.conf
cp unicode.mapping $APACHE_HOME/conf/extra/
sed -i "s/SecRuleEngine DetectionOnly/SecRuleEngine On/g" $APACHE_HOME/conf/extra/modsecurity.conf
echo -e "IncludeOptional /usr/local/apache2/conf/extra/modsecurity.d/*.conf\nIncludeOptional /usr/local/apache2/conf/extra/modsecurity.d/activated_rules/*.conf" >> $APACHE_HOME/conf/extra/modsecurity.conf
cat <<EOF | tee -a $APACHE_HOME/conf/httpd.conf
LoadModule unique_id_module modules/mod_unique_id.so
LoadModule security2_module modules/mod_security2.so
<IfModule security2_module>
   Include conf/extra/modsecurity.conf
</IfModule>
EOF
mkdir -p $APACHE_HOME/conf/extra/modsecurity.d/activated_rules
cat <<EOF | tee -a $APACHE_HOME/conf/extra/modsecurity.d/activated_rules/rules-01.conf
SecDefaultAction "phase:2,deny,log,status:406"
SecRule REQUEST_URI "/etc/passwd""id:'500001'"
EOF

/usr/local/tomcat10/bin/startup.sh
systemctl daemon-reload
systemctl start httpd
systemctl enable httpd
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

