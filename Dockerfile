FROM openjdk:8

ARG ZK_HOME=/opt/zookeeper
ARG USER=zookeeper
ARG GROUP=zookeeper
ARG ZK_DIST=zookeeper-3.4.11

ENV ZK_REPLICAS=1

RUN groupadd --gid 1000 ${GROUP} && useradd --uid 1000 --gid 1000 ${USER}

RUN \
  mkdir -p                      /var/lib/zookeeper/data \
  && chown -R ${USER}:${GROUP}  /var/lib/zookeeper/data \
  && chmod -R ug+rwx            /var/lib/zookeeper/data

RUN mkdir -p                   /var/lib/zookeeper/log \
  && chown -R ${USER}:${GROUP}  /var/lib/zookeeper/log \
  && chmod -R ug+rwx            /var/lib/zookeeper/log

RUN mkdir -p                   /var/log/zookeeper \
  && chown -R ${USER}:${GROUP}  /var/log/zookeeper \
  && chmod -R ug+rwx            /var/log/zookeeper

RUN mkdir -p                   ${ZK_HOME} \
  && chown -R ${USER}:${GROUP}  ${ZK_HOME} \
  && chmod -R ug+rwx            ${ZK_HOME}

RUN mkdir -p                    /tmp/zookeeper \
  && chown -R ${USER}:${GROUP}  /tmp/zookeeper \
  && chmod -R ug+rwx            /tmp/zookeeper

RUN mkdir -p                   /usr/share/zookeeper \
  && wget -q "https://www-us.apache.org/dist/zookeeper/zookeeper-3.5.5/apache-zookeeper-3.5.5-bin.tar.gz" -O zookeeper.tar.gz \
  && tar vxfz zookeeper.tar.gz -C ${ZK_HOME} --strip-components=1 \
  && rm -rf zookeeper.tar.gz

COPY zkGenConfig.sh zkOk.sh zkMetrics.sh ${ZK_HOME}/bin/

WORKDIR ${ZK_HOME}

USER 1002