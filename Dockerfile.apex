FROM container-registry.oracle.com/os/oraclelinux:8

# Java ejecuta ORDS; SQL*Plus permite instalar APEX de forma remota en XEPDB1.
RUN dnf update -y && \
    dnf install -y \
        unzip \
        wget \
        java-17-openjdk-headless \
        oracle-instantclient-release-23ai-el8 && \
    dnf install -y \
        oracle-instantclient-basic \
        oracle-instantclient-sqlplus && \
    dnf clean all && \
    rm -rf /var/cache/dnf

ENV ORDS_CONFIG_DIR=/opt/ords/config \
    APEX_IMAGES=/opt/apex/images \
    JAVA_HOME=/usr/lib/jvm/jre-17-openjdk

WORKDIR /opt

ARG APEX_VERSION=24.2
RUN wget "https://download.oracle.com/otn_software/apex/apex_${APEX_VERSION}.zip" \
        -O apex.zip && \
    unzip apex.zip && \
    rm apex.zip

RUN wget https://download.oracle.com/otn_software/java/ords/ords-latest.zip && \
    unzip ords-latest.zip -d ords && \
    rm ords-latest.zip

ENV PATH="/opt/ords/bin:${PATH}"

RUN mkdir -p /opt/scripts
COPY scripts/ /opt/scripts/

RUN find /opt/scripts/ -name "*.sh" -exec sed -i 's/\r$//' {} \; && \
    chmod +x /opt/scripts/*.sh

EXPOSE 8080

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]