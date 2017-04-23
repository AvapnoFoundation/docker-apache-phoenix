FROM centos:6
MAINTAINER Cheyenne Forbes de Avapno

# Java Version
ENV JAVA_VERSION_MAJOR=8
ENV JAVA_VERSION_MINOR=74
ENV JAVA_VERSION_BUILD=02
ENV JAVA_PACKAGE=jre
ENV JAVA_SHA256_SUM=9c8663a5a67429d423ed1da554a7f93d1c7e50f6bb4bc5e0bbde1f512cf36d95

RUN yum install -y openssh-server openssh-clients initscripts python-argparse && yum clean all

# passwordless ssh
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

COPY "ca-certificate.pem" "/tmp/ca-certificate.pem"

RUN mkdir -p /opt &&\
    curl -jkLH "Cookie: oraclelicense=accept-securebackup-cookie" -o java.tar.gz\
    http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/${JAVA_PACKAGE}-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz &&\
    echo "$JAVA_SHA256_SUM  java.tar.gz" | sha256sum -c - &&\
    gunzip -c java.tar.gz | tar -xf - -C /opt && rm -f java.tar.gz &&\
    ln -s /opt/jre1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} /opt/jre &&\
    yum -y install unzip && \
    curl -jkLH "Cookie: oraclelicense=accept-securebackup-cookie" -o jce.zip http://download.oracle.com/otn-pub/java/jce/${JAVA_VERSION_MAJOR}/jce_policy-${JAVA_VERSION_MAJOR}.zip && \
    unzip -j -o jce.zip -d /opt/jre/lib/security/ && \
    /opt/jre/bin/keytool -importcert -v -keystore /opt/jre/lib/security/cacerts -storepass changeit -file /tmp/ca-certificate.pem -noprompt -alias MeteoGroupCA && \
    rm -rf jce.zip \
        /opt/jre/lib/plugin.jar \
        /opt/jre/lib/ext/jfxrt.jar \
        /opt/jre/bin/javaws \
        /opt/jre/lib/javaws.jar \
        /opt/jre/lib/desktop \
        /opt/jre/plugin \
        /opt/jre/lib/deploy* \
        /opt/jre/lib/*javafx* \
        /opt/jre/lib/*jfx* \
        /opt/jre/lib/amd64/libdecora_sse.so \
        /opt/jre/lib/amd64/libprism_*.so \
        /opt/jre/lib/amd64/libfxplugins.so \
        /opt/jre/lib/amd64/libglass.so \
        /opt/jre/lib/amd64/libgstreamer-lite.so \
        /opt/jre/lib/amd64/libjavafx*.so \
        /opt/jre/lib/amd64/libjfx*.so \
        /tmp/ca-certificate.pem

ENV JAVA_HOME /opt/jre
ENV PATH ${PATH}:${JAVA_HOME}/bin

ARG APACHE_MIRROR=https://www.apache.org/dist

#curl -s

# Hadoop
ARG HADOOP_VERSION=2.7.2
RUN curl $APACHE_MIRROR/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz | tar -xz -C /opt/
RUN cd /opt && ln -s ./hadoop-$HADOOP_VERSION hadoop
ENV HADOOP_PREFIX=/opt/hadoop
ENV HADOOP_HOME=${HADOOP_PREFIX}
ENV	HADOOP_COMMON_HOME=${HADOOP_PREFIX}
ENV	HADOOP_HDFS_HOME=${HADOOP_PREFIX}
ENV	HADOOP_MAPRED_HOME=${HADOOP_PREFIX}
ENV	HADOOP_YARN_HOME=${HADOOP_PREFIX}
ENV	HADOOP_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop
ENV	YARN_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop
ENV PATH $PATH:$HADOOP_HOME/bin

COPY config/hadoop-env.sh ${HADOOP_PREFIX}/etc/hadoop/
COPY config/core-site.xml ${HADOOP_PREFIX}/etc/hadoop/
COPY config/hdfs-site.xml ${HADOOP_PREFIX}/etc/hadoop/
COPY config/mapred-site.xml ${HADOOP_PREFIX}/etc/hadoop/
COPY config/yarn-site.xml ${HADOOP_PREFIX}/etc/hadoop/

RUN if [ ! -x /bin/which ]; then \
      echo '#!/bin/bash' >/bin/which &&\
      echo 'command -v "$1"' >>/bin/which &&\
      chmod 755 /bin/which; \
    fi

# Zookeeper
#ARG ZOOKEEPER_VERSION=3.4.8
#RUN curl $APACHE_MIRROR/dist/zookeeper/zookeeper-$ZOOKEEPER_VERSION/zookeeper-$ZOOKEEPER_VERSION.tar.gz | tar -xz -C /opt/
#RUN cd /opt && ln -s ./zookeeper-$ZOOKEEPER_VERSION zookeeper
#ENV ZOO_HOME /opt/zookeeper
#ENV PATH $PATH:$ZOO_HOME/bin
#RUN mv $ZOO_HOME/conf/zoo_sample.cfg $ZOO_HOME/conf/zoo.cfg
#RUN mkdir /tmp/zookeeper

# HBase
ARG HBASE_MAJORMINOR=1.2
ARG HBASE_PATCH=5
RUN curl $APACHE_MIRROR/hbase/$HBASE_MAJORMINOR.$HBASE_PATCH/hbase-$HBASE_MAJORMINOR.$HBASE_PATCH-bin.tar.gz | tar -xz -C /opt/
RUN cd /opt && ln -s ./hbase-$HBASE_MAJORMINOR.$HBASE_PATCH hbase
ENV HBASE_HOME /opt/hbase
ENV PATH $PATH:$HBASE_HOME/bin

# Phoenix
ARG PHOENIX_VERSION=4.10.0
RUN curl $APACHE_MIRROR/phoenix/apache-phoenix-$PHOENIX_VERSION-HBase-$HBASE_MAJORMINOR/bin/apache-phoenix-$PHOENIX_VERSION-HBase-$HBASE_MAJORMINOR-bin.tar.gz | tar -xz -C /opt/
RUN cd /opt && ln -s ./apache-phoenix-$PHOENIX_VERSION-HBase-$HBASE_MAJORMINOR-bin phoenix
ENV PHOENIX_HOME /opt/phoenix
ENV PATH $PATH:$PHOENIX_HOME/bin
RUN ln -s $PHOENIX_HOME/apache-phoenix-core-$PHOENIX_VERSION-HBase-$HBASE_MAJORMINOR.jar $HBASE_HOME/lib/phoenix.jar
RUN ln -s $PHOENIX_HOME/apache-phoenix-$PHOENIX_VERSION-HBase-$HBASE_MAJORMINOR-server.jar $HBASE_HOME/lib/phoenix-server.jar

# HBase and Phoenix configuration files
RUN rm $HBASE_HOME/conf/hbase-site.xml
RUN rm $HBASE_HOME/conf/hbase-env.sh
COPY config/hbase-site.xml $HBASE_HOME/conf/hbase-site.xml
COPY config/hbase-env.sh $HBASE_HOME/conf/hbase-env.sh

# bootstrap-phoenix
COPY bootstrap-phoenix.sh /etc/bootstrap-phoenix.sh
RUN chown root:root /etc/bootstrap-phoenix.sh
RUN chmod 700 /etc/bootstrap-phoenix.sh

CMD ["/etc/bootstrap-phoenix.sh", "-qs"]

################### Expose ports

### Core

# Zookeeper
EXPOSE 2181

# NameNode metadata service ( fs.defaultFS )
EXPOSE 9000

# FTP Filesystem impl. (fs.ftp.host.port)
EXPOSE 21

### Hdfs ports (Reference: https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml)

# NameNode Web UI: Web UI to look at current status of HDFS, explore file system (dfs.namenode.http-address / dfs.namenode.https-address)
EXPOSE 50070 50470

# DataNode : DataNode WebUI to access the status, logs etc. (dfs.datanode.http.address / dfs.datanode.https.address)
EXPOSE 50075 50475

# DataNode  (dfs.datanode.address / dfs.datanode.ipc.address)
EXPOSE 50010 50020

# Secondary NameNode (dfs.namenode.secondary.http-address / dfs.namenode.secondary.https-address)
EXPOSE 50090 50090

# Backup node (dfs.namenode.backup.address / dfs.namenode.backup.http-address)
EXPOSE 50100 50105

# Journal node (dfs.journalnode.rpc-address / dfs.journalnode.http-address / dfs.journalnode.https-address )
EXPOSE 8485 8480 8481

### Mapred ports (Reference: https://hadoop.apache.org/docs/stable/hadoop-mapreduce-client/hadoop-mapreduce-client-core/mapred-default.xml)

# Task Tracker Web UI and Shuffle (mapreduce.tasktracker.http.address)
EXPOSE 50060

# Job tracker Web UI (mapreduce.jobtracker.http.address)
EXPOSE 50030

# Job History Web UI (mapreduce.jobhistory.webapp.address)
EXPOSE 19888

# Job History Admin Interface (mapreduce.jobhistory.admin.address)
EXPOSE 10033

# Job History IPC (mapreduce.jobhistory.address)
EXPOSE 10020

### Yarn ports (Reference: https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-common/yarn-default.xml)

# Applications manager interface (yarn.resourcemanager.address)
EXPOSE 8032

# Scheduler interface (yarn.resourcemanager.scheduler.address)
EXPOSE 8030

# Resource Manager Web UI (yarn.resourcemanager.webapp.address / yarn.resourcemanager.webapp.https.address)
EXPOSE 8088 8090

# ??? (yarn.resourcemanager.resource-tracker.address)
EXPOSE 8031

# Resource Manager Administration Web UI
EXPOSE 8033

# Address where the localizer IPC is (yarn.nodemanager.localizer.address)
EXPOSE 8040

# Node Manager Web UI (yarn.nodemanager.webapp.address)
EXPOSE 8042

# Timeline servise RPC (yarn.timeline-service.address)
EXPOSE 10200

# Timeline servise Web UI (yarn.timeline-service.webapp.address / yarn.timeline-service.webapp.https.address)
EXPOSE 8188 8190

# Shared Cache Manager Admin Web UI (yarn.sharedcache.admin.address)
EXPOSE 8047

# Shared Cache Web UI (yarn.sharedcache.webapp.address)
EXPOSE 8788

# Shared Cache node manager interface (yarn.sharedcache.uploader.server.address)
EXPOSE 8046

# Shared Cache client interface (yarn.sharedcache.client-server.address)
EXPOSE 8045

### Other ports

# SSH
EXPOSE 22

#Phoenix queryserver
EXPOSE 8765
