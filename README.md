# Apache_Installation
Setup latest Apache by compiling from source with mod_security &amp; mod_jk

**Source files:**
  - [apache](https://mirrors.estointernet.in/apache//httpd/httpd-2.4.46.tar.gz)
  - [apr](https://apachemirror.wuchna.com//apr/apr-1.7.0.tar.gz)
  - [apr-util](https://mirrors.estointernet.in/apache//apr/apr-util-1.6.1.tar.gz)
  - [mod_security](https://www.modsecurity.org/tarball/2.9.3/modsecurity-2.9.3.tar.gz)
  - [mod_jk](https://apachemirror.wuchna.com/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.48-src.tar.gz)
  - [apache-tomcat](https://mirrors.estointernet.in/apache/tomcat/tomcat-10/v10.0.5/bin/apache-tomcat-10.0.5.tar.gz)
  - [java](https://javadl.oracle.com/webapps/download/AutoDL?BundleId=244575_d7fc238d0cbf4b0dac67be84580cfb4b)


**Web Archive:**
  - To test mod_jk download this [sample.war](https://tomcat.apache.org/tomcat-6.0-doc/appdev/sample/sample.war) file to /opt.

Before starting the compilation process, make sure that you have all the dependencies in place.


**Automated Compilation:**
--------------------------
Download the above mentioned source files to _/opt_ directory and run _**install.sh**_ to perform the automated compilation.

```
cd /opt
./install.sh
```

If the linux host has active internet connection don't download the files manually. Instead enable the following lines in **_install.sh_** script file to download and extract automatically.

```
URLs="https://mirrors.estointernet.in/apache/httpd/$HTTPD_VERS.tar.gz https://apachemirror.wuchna.com/apr/$APR_VERS.tar.gz https://mirrors.estointernet.in/apache/apr/$APR_UTIL_VERS.tar.gz https://www.modsecurity.org/tarball/2.9.3/$MOD_SECURITY_VERS.tar.gz https://apachemirror.wuchna.com/tomcat/tomcat-connectors/jk/$MOD_JK_VERS.tar.g https://mirrors.estointernet.in/apache/tomcat/tomcat-10/v10.0.5/bin/$TOMCAT_VERS.tar.gz https://javadl.oracle.com/webapps/download/AutoDL?BundleId=244575_d7fc238d0cbf4b0dac67be84580cfb4b"
cd $SOURCE_DIR
for u in $URLs
do
  wget -q -O - $u | tar -xzf -
done
```
and disable the below line.
```
find . -iname "*.tar.gz" -print0 | xargs -0 --max-args=1 tar xzf
```

**Manual Compilation:**
----------------------
**Prerequsite:**
To compile apache we need the following dependencies
- gcc
- expat-devel
- pcre-devel
- libtool
- openssl-devel

To compile mod_security we need the following dependencies
- libxml2-devel

So we need to install the dependencies which before proceeding with the compilation
```
yum install gcc expat-devel pcre-devel libtool openssl-devel libxml2-devel -y
```

After the installation of dependencies we can proceed with the source code compilation.

**Apache Source code Compilation:**

For apache compilation we need apr and apr-util.

Download and extract the source files to /opt.
```
cd /opt
wget -q -O - https://mirrors.estointernet.in/apache//httpd/httpd-2.4.46.tar.gz | tar -xzf -
wget -q -O - https://apachemirror.wuchna.com//apr/apr-1.7.0.tar.gz | tar -xzf -
wget -q -O - https://mirrors.estointernet.in/apache//apr/apr-util-1.6.1.tar.gz | tar -xzf -
```
To compile httpd we need to move apr and apr-util to sourcelib directory.
```
mv apr-1.7.0  httpd-2.4.46/srclib/apr
mv apr-util-1.6.1 httpd-2.4.46/srclib/apr-util
```
Now we are ready to begin the process.
```
cd httpd-2.4.46
./buildconf
./configure --enable-ssl --enable-so --with-mpm=event --with-included-apr --prefix=/usr/local/apache2
make
make install
```
Create **_/etc/systemd/system/httpd.service_** file and add the following to manage httpd service.
``` 
[Unit]
Description=The Apache HTTP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/apache2/bin/apachectl -k start
ExecReload=/usr/local/apache2/bin/apachectl -k graceful
ExecStop=/usr/local/apache2/bin/apachectl -k graceful-stop
PIDFile=/usr/local/apache2/logs/httpd.pid
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```
Once the file is created reload the systemd daemon, start and enable the service.
```
systemctl daemon-reload
systemctl start httpd
systemctl enable httpd
```
If firewall is enabled, then we need to allow http port to be accessed from outside world. Else we can skip this step.
```
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
```
Apache compilation is completed and we can test this by visiting http://localhost from local host or http://server-ip-address from remote host.

**mod_security installation:**

To compile mod_security we need apr and apr-util sources and in addition to that we need libxml2-devel to be installed.

Download the mod_security tarball from the official site.
```
cd /opt
wget -q -O - https://www.modsecurity.org/tarball/2.9.3/modsecurity-2.9.3.tar.gz | tar -xzf -
```
Now to compile mod_security we need to mention source file path of apr and apr-util. We have already downloaded and placed in /opt/httpd-2.4.46/srclib/
```
cd modsecurity-2.9.3
./configure --with-apr=../httpd-2.4.46/srclib/apr --with-apu=../httpd-2.4.46/srclib/apr-util
make
make install
```
Now copy the modsecurity.conf and unicode.mapping to /usr/local/apache2/conf/extra.
```
cp modsecurity.conf-recommended /usr/local/apache2/conf/extra/modsecurity.conf
cp unicode.mapping /usr/local/apache2/conf/extra/
```
Add the following to _**/usr/local/apache2/conf/httpd.conf**_ to load the security modules.
```
LoadModule unique_id_module modules/mod_unique_id.so
LoadModule security2_module modules/mod_security2.so
<IfModule security2_module>
   Include conf/extra/modsecurity.conf
</IfModule>
```
Now Turn on the SecRuleEngine.
```
sed -i "s/SecRuleEngine DetectionOnly/SecRuleEngine On/g" /usr/local/apache2/conf/extra/modsecurity.conf
```
Add the following in **_/usr/local/apache2/conf/extra/modsecurity.conf_** to include the optional config files kept inside /usr/local/apache2/conf/extra/modsecurity.d and rules in /usr/local/apache2/conf/extra/modsecurity.d/activated_rules.
```
IncludeOptional /usr/local/apache2/conf/extra/modsecurity.d/*.conf
IncludeOptional /usr/local/apache2/conf/extra/modsecurity.d/activated_rules/*.conf
```
To add rules create activated_rules directory and create the file(s) with rules.
```
mkdir -p /usr/local/apache2/conf/extra/modsecurity.d/activated_rules
vi /usr/local/apache2/conf/extra/modsecurity.d/activated_rules/rules-01.conf
SecDefaultAction "phase:2,deny,log,status:406"
SecRule REQUEST_URI "/etc/passwd""id:'500001'" 
```
Now restart the httpd service to apply secure rules.

```
systemctl restart httpd
```

To Verify visit http://server-ip-address/etc/passwd. In this case I added the rule to deny access for /etc/passwd.

**mod_jk installation:**

Before installing mod_jk we will install apache tomcat.

In order to run tomcat we need java to be installed in our host.

**Java Installation**

Download the appropriate version of java from the official site. move the extracted archive file to /usr/local.
```
cd /opt
wget -q -O - https://javadl.oracle.com/webapps/download/AutoDL?BundleId=244575_d7fc238d0cbf4b0dac67be84580cfb4b | tar -xzf -
mv jre1.8.0_291/ /usr/local/
```
Lets install java using alternatives command.
```
alternatives --install /usr/bin/java java /usr/local/jre1.8.0_291/bin/java 2
alternatives --install /usr/bin/jar jar /usr/local/jre1.8.0_291/bin/jar 2
alternatives --install /usr/bin/javac javac /usr/local/jre1.8.0_291/bin/javac 2
alternatives --set jar /usr/local/jre1.8.0_291/bin/jar
alternatives --set javac /usr/local/jre1.8.0_291/bin/javac 
```
To verify java version after installation.
```
java -version
```

**Tomcat Installation**
Java has been installad. Now follow the below steps to install the latest version apache tomcat.
Download apache tomcat archive and sample.war file to /opt
```
cd /opt
wget https://mirrors.estointernet.in/apache/tomcat/tomcat-10/v10.0.5/bin/apache-tomcat-10.0.5.tar.gz
wget https://tomcat.apache.org/tomcat-6.0-doc/appdev/sample/sample.war
```
Extract the archive file and move it to /usr/local/tomcat10. Copy the sample.war file to /usr/local/tomcat10/webapps.
```
tar -xzf apache-tomcat-10.0.5.tar.gz
mv apache-tomcat-10.0.5 /usr/local/tomcat10
cp sample.war /usr/local/tomcat10/webapps/
```
Next, we have to Configure the environment variables. configure CATALINA_HOME environment variable in your system using following commands. Its required to run Tomcat server.
```
echo "export CATALINA_HOME="/usr/local/tomcat10"" >> ~/.bashrc
source ~/.bashrc
```
To start the tomcat service. simply extract the archive and start the tomcat server. Tomcat by default listen on port 8080, So make sure no other application using the same port.
```
/usr/local/tomcat10/bin/startup.sh
```
If firewall is enabled, then we need to allow tomcat to be accessed from outside world. Else we can skip this step.
```
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
```
To verify tomcat visit http://server-ip-address:8080

**mod_jk compilation:**

Now we can compile mod_jk. Download the mod_jk tarball from official site.
```
wget -q -O - https://apachemirror.wuchna.com/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.48-src.tar.gz | tar -xzf -
```
To compile mod_jk navigate to native directory inside tomcat-connectors-1.2.48-src.
```
cd /opt/tomcat-connectors-1.2.48-src/native/
./buildconf.sh
./configure -with-apxs=/usr/local/apache2/bin/apxs
make
make install
```
To load the mod_jk conf file, add the following line in **_/usr/local/apache2/conf/httpd.conf_**
```
Include conf/extra/mod_jk.conf
```
Once the configuration file is enabled, load the module and configure Loadbalancer. Add the below content to **_/usr/local/apache2/conf/extra/mod_jk.conf_**
```
LoadModule jk_module modules/mod_jk.so
JkWorkersFile conf/extra/workers.properties
JkMount /sample loadbalancer
JkMount /sample/* loadbalancer
JkMount /status status
```
Define the workers properties. Add the below properties to **_/usr/local/apache2/conf/extra/workers.properties_**
```
worker.list=loadbalancer,status

worker.jvm1.type=ajp13
worker.jvm1.host=localhost
worker.jvm1.port=8009
worker.jvm1.secret=mysecret

worker.loadbalancer.type=lb
worker.loadbalancer.balance_workers=jvm1
worker.loadbalancer.sticky_session=1

worker.status.type=status
```
Now we need to edit **_/usr/local/tomcat10/conf/server.xml_** to tell tomcat to listen on port number 8009.
```
Add: <Connector protocol="AJP/1.3" address="0.0.0.0" secretRequired="true" secret="mysecret" port="8009" redirectPort="8443" />
Find:<Engine name="Catalina" defaultHost="localhost">
Replace: <Engine name="Catalina" defaultHost="localhost" jvmRoute="jvm1">
```
Restart the services
```
/usr/local/tomcat10/bin/startup.sh
systemctl restart httpd
```
To verify visit http://server-ip-addr/sample and http://server-ip-addr/status

