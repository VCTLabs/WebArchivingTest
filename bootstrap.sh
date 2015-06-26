#!/usr/bin/env bash

HERITRIX_USER="heritrix"
HERITRIX_GROUP="heritrix"
HERITRIX_HOME=/opt/heritrix-3.3.0-SNAPSHOT
JAVA_HOME=/opt/jdk1.8.0_45

# handy dandy routine to verify SHA1 sums
# usage: sha1verify <filename> <sha1>
# exit 0 = success, 1 = fail
sha1verify() {
  FILE="$1"
  HASH="$2"
  FILEHASH=$(openssl sha1 $FILE)
  if [ "SHA1(${FILE})= $2" = "${FILEHASH}" ]; then  return 0; else return 1; fi
}

# set hostname
echo "Setting hostname..."
hostname wayback
echo wayback > /etc/hostname
sed -i.bak -e 's/precise32/wayback/' /etc/hosts
IPADDR=`ifconfig eth1 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
echo "$IPADDR wayback" >> /etc/hosts

# install packages and stuff
echo "Updating/installing packages..."
apt-get -q=2 update > /dev/null 2>&1
apt-get -q=2 install -y avahi-daemon avahi-utils curl python-pip python-software-properties screen tomcat7 tomcat7-admin vim > /dev/null 2>&1

# install avahi configs
echo "Configuring avahi..."
cp -a /vagrant/avahi_configs/*.service /etc/avahi/services
chmod 644 /etc/avahi/services/*.service

# install mosh
echo "Installing mosh..."
echo "" | add-apt-repository ppa:keithw/mosh
apt-get -q=2 update > /dev/null 2>&1
apt-get -q=2 install -y mosh > /dev/null 2>&1

mkdir -p /opt
mkdir -p /tmp/setup.$$

# download Java
echo "Downloading JDK..."
wget --no-check-certificate --no-cookies --no-verbose --header "Cookie: oraclelicense=accept-securebackup-cookie" -O /tmp/setup.$$/jdk-8u45-linux-i586.tar.gz http://download.oracle.com/otn-pub/java/jdk/8u45-b14/jdk-8u45-linux-i586.tar.gz

echo "Installing JDK..."
tar -C /opt -xf /tmp/setup.$$/jdk-8u45-linux-i586.tar.gz

# add heritrix config
echo "Adding heritrix user and group..."
groupadd $HERITRIX_GROUP
useradd -g $HERITRIX_GROUP $HERITRIX_USER

# download heritrix
echo "Downloading Heritrix..."
wget --no-verbose -O /tmp/setup.$$/heritrix-3.3.0-dist.tar.gz https://builds.archive.org/job/Heritrix-3/lastStableBuild/org.archive.heritrix\$heritrix/artifact/org.archive.heritrix/heritrix/3.3.0-20150504.230614-46/heritrix-3.3.0-20150504.230614-46-dist.tar.gz
#wget --no-verbose -O /tmp/setup.$$/SHA1SUM http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-dist.tar.gz.sha1
#http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-src.tar.gz
#http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-src.tar.gz.sha1
#if ! sha1verify "/tmp/setup.$$/heritrix-3.2.0-dist.tar.gz" "`cat /tmp/setup.$$/SHA1SUM`"; then
#  echo "ERROR: download failed! (checksum mismatch)"
#  exit 1
#fi

# install heritrix
echo "Installing Heritrix..."
mkdir -p /opt
tar -C /opt -xzf /tmp/setup.$$/heritrix-3.3.0-dist.tar.gz
chmod 755 ${HERITRIX_HOME}/bin/heritrix
cat << _EOF_PROFILE_SH_ > /etc/profile.d/heritrix.sh
export JAVA_HOME=$JAVA_HOME
export JAVA_OPTS=-Xmx1024M
export HERITRIX_HOME=$HERITRIX_HOME
export PATH=\$JAVA_HOME/bin:\$HERITRIX_HOME/bin:\$PATH
_EOF_PROFILE_SH_
chmod 644 /etc/profile.d/heritrix.sh
chown -R $HERITRIX_USER:$HERITRIX_GROUP $HERITRIX_HOME

# start up heritrix
echo "Installing Heritrix startup script..."
cp /vagrant/heritrix_init_d.sh /etc/init.d/heritrix
chmod 755 /etc/init.d/heritrix
update-rc.d heritrix defaults
cat << _EOF_DEFAULTS_HERITRIX_ > /etc/default/heritrix
HERITRIX_USER="$HERITRIX_USER"
HERITRIX_CREDENTIALS="admin:password"
HERITRIX_HOME="$HERITRIX_HOME"
JAVA_HOME="$JAVA_HOME"
IP_ADDRESS="/"
PORT=8443
HERITRIX_ADDITIONAL_OPTS=""
_EOF_DEFAULTS_HERITRIX_
echo "Starting up Heritrix..."
service heritrix start
# give it some time to spin up
sleep 10

# set up heritrix job
echo "Setting up Heritrix job..."
curl -qso /dev/null -d "createpath=crawler&action=create" -k -u admin:password --anyauth --location https://localhost:8443/engine
echo "Configuring Heritrix job..."
sed -i.bak \
  -e 's/\(metadata.operatorContactUrl=\).*/\1http:\/\/vctlabs.com\//' \
  -e '/URLS HERE/ r /vagrant/URLS_TO_CRAWL' \
  -e '/example.example\/example/d' \
  -e '/bean id.*acceptSurts/a\
\<property name=\"decision\" value=\"ACCEPT\"\ /\>\
\<property name=\"seedsAsSurtPrefixes\" value=\"true\" \/\>\
\<property name=\"alsoCheckVia\" value=\"false\" \/\>' \
  -e '/WARCWriterProcessor/a\
\<property name=\"directory\" value=\"\/var\/spool\/heritrix\/\" \/\>' \
  -e '/bean id.*rescheduler/a\
--\>\
\<bean id=\"rescheduler\" class=\"org.archive.crawler.postprocessor.ReschedulingProcessor\"\>\
\<!-- every day --\>\
\<property name=\"rescheduleDelaySeconds\" value=\"86400\" \/\>\
\<!-- every hour --\>\
\<!-- \<property name=\"rescheduleDelaySeconds\" value=\"3600\" \/\> --\>\
\<\/bean\>' \
  -e '/ref.*bean.*disposition/a\
\<ref bean=\"rescheduler\" \/\>' \
  -e '/rescheduleDelaySeconds.*-1/ { N; d; }' \
  $HERITRIX_HOME/jobs/crawler/crawler-beans.cxml

# de-duping seems a bit problematic, it is causing the crawler process
# to stall... but maybe I'm not configuring it right... but let's disable
# it for now
#
sed -i.bak \
  -e '/ref.*bean=.*warcWriter/i \
\<bean class=\"org.archive.modules.recrawl.ContentDigestHistoryLoader\" \/\>' \
  -e '/ref.*bean=.*warcWriter/a \
\<bean class=\"org.archive.modules.recrawl.ContentDigestHistoryStorer\" \/\>' \
  -e '/CRAWL METADATA/i \
\<!-- optional, will use the main bdb module if omitted, just like old dedup --\>\
\<bean id=\"historyBdb\" class=\"org.archive.bdb.BdbModule\" autowire-candidate=\"false\"\>\
\<property name=\"dir\" value=\"history\" \/\>\
\<\/bean\>\
\<bean id=\"contentDigestHistory\" class=\"org.archive.modules.recrawl.BdbContentDigestHistory\"\>\
\<property name=\"bdbModule\"\>\
\<ref bean=\"historyBdb\" \/\>\
\<\/property\>\
\<\/bean\>' \
  $HERITRIX_HOME/jobs/crawler/crawler-beans.cxml

#cp /vagrant/crawler-beans.cxml.example /opt/heritrix-3.2.0/jobs/crawler/crawler-beans.cxml
chown $HERITRIX_USER:$HERITRIX_GROUP $HERITRIX_HOME/jobs/crawler/crawler-beans.cxml
chmod 644 $HERITRIX_HOME/jobs/crawler/crawler-beans.cxml
mkdir -p /var/spool/heritrix
chown $HERITRIX_USER:$HERITRIX_GROUP /var/spool/heritrix
chmod 755 /var/spool/heritrix
echo "Building job configuration..."
curl -qso /dev/null -d "action=build" -k -u admin:admin --anyauth --location https://localhost:8443/engine/job/crawler
echo "Launching job..."
curl -qso /dev/null -d "action=launch" -k -u admin:password --anyauth --location https://localhost:8443/engine/job/crawler
curl -qso /dev/null -d "action=unpause" -k -u admin:password --anyauth --location https://localhost:8443/engine/job/crawler

# install hapy
# https://github.com/WilliamMayor/hapy
#
# NOTE: to disable the warning that you get because of the self-signed
# ssl cert, insert this code in your Python script that uses hapy:
#
# import requests
# requests.packages.urllib3.disable_warnings()
echo "Installing Heritrix API python module..."
pip install hapy-heritrix

# set up tomcat
echo "Setting up Tomcat..."
service tomcat7 stop
# install heritrix redirect stub
mkdir -p /var/lib/tomcat7/webapps/heritrix
cp -a /vagrant/heritrix_redirect.html /var/lib/tomcat7/webapps/heritrix/index.html
chown -R tomcat7:tomcat7 /var/lib/tomcat7/webapps/heritrix
chmod 644 /var/lib/tomcat7/webapps/heritrix/index.html
# openwayback needs Java 7
echo JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-i386 >> /etc/default/tomcat7
# set hostname
sed -i.bak \
  -e '/Host name=/{N;N;s/$/\n\<Alias\>wayback\<\/Alias\>/}' \
  /etc/tomcat7/server.xml
# add admin user
sed -i.bak \
  -e '/<tomcat-users>/a<user username="admin" password="password" roles="manager-gui,admin-gui"/>' \
  /etc/tomcat7/tomcat-users.xml

# install openwayback
echo "Downloading OpenWayback..."
wget --no-verbose -O /tmp/setup.$$/openwayback-dist-2.2.0.tar.gz http://search.maven.org/remotecontent?filepath=org/netpreserve/openwayback/openwayback-dist/2.2.0/openwayback-dist-2.2.0.tar.gz
echo "Installing OpenWayback..."
tar xzf /tmp/setup.$$/openwayback-dist-2.2.0.tar.gz
rm -rf /var/lib/tomcat7/webapps/ROOT
#cp target/openwayback-sample-overlay-2.0.0.BETA.1.war /var/lib/tomcat7/webapps/ROOT.war
cp openwayback/openwayback-2.2.0.war /var/lib/tomcat7/webapps/ROOT.war
echo "Restarting Tomcat..."
service tomcat7 start

# wait for tomcat to unpack
echo "Waiting for Tomcat to unpack WAR..."
while [ ! -f /var/lib/tomcat7/webapps/ROOT/WEB-INF/wayback.xml ]; do
  sleep 1
done
# need to wait a bit more for it to finish
sleep 10

# set up openwayback
echo "Configuring OpenWayback..."
sed -i.bak \
  -e 's/\(wayback.url.host.default=\).*/\1wayback/' \
  -e 's/\(wayback.archivedir.1=\).*/\1\/var\/spool\/heritrix\/warcs\//' \
  -e 's/\(wayback.archivedir.2=\).*/\1\/tmp\//' \
  /var/lib/tomcat7/webapps/ROOT/WEB-INF/wayback.xml
echo "Configuring Tomcat to use Oracle java..."
sed -i.bak -e "s/\(JAVA_HOME=\).*/\1$JAVA_HOME" /etc/default/tomcat7
echo "Restarting Tomcat..."
service tomcat7 restart

# copy in the README for reference
cp /vagrant/README.md /home/vagrant
chown vagrant:vagrant /home/vagrant/README.md
chmod 644 /home/vagrant/README.md
cp /vagrant/hapy_test.py /home/vagrant
chown vagrant:vagrant /home/vagrant/hapy_test.py
chmod 644 /home/vagrant/hapy_test.py

# copy in ssh key
if [ -f /vagrant/ssh_public_key ]; then
  echo "Copying in ssh key..."
  cat /vagrant/ssh_public_key >> /home/vagrant/.ssh/authorized_keys
fi

# all done
rm -rf /tmp/setup.$$
echo " "
echo "All Done!"
echo " "
echo "Access the Heritrix web interface (https, self-signed cert) at:"
echo "     https://$IPADDR:8443/"
echo " "
echo "To manage tomcat, browse to"
echo "      http://$IPADDR:8080/manager/html"
echo " "
echo "The default username/password for both of the above is"
echo "\`admin:password'. They can be changed in the following locations:"
echo "     Heritrix - \`/etc/default/heritrix'"
echo "     Tomcat - \`/etc/tomcat7/tomcat-users.xml'"
echo " "
echo "To access openwayback, browse to: (note: http, NOT https as above)"
echo "     http://$IPADDR:8080/wayback/"
echo " "
echo "Note: it may take a while (sometimes a LONG while) to build up the"
echo "openwayback cache. Rebooting the VM will always do the job."
echo " "
echo "Share And Enjoy!"
