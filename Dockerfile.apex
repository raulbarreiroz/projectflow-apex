FROM container-registry.oracle.com/os/oraclelinux:8

# ============================================
# 1. Instalar dependencias del sistema + JAVA 17
# ============================================
RUN dnf update -y && \
    dnf install -y unzip wget java-17-openjdk-headless && \
    dnf clean all

# ============================================
# 2. Variables de entorno útiles
# ============================================
ENV ORDS_CONFIG_DIR=/opt/ords/config \
    APEX_IMAGES=/opt/apex/images \
    JAVA_HOME=/usr/lib/jvm/jre-17-openjdk

# ============================================
# 3. Instalar APEX
# ============================================
WORKDIR /opt

COPY apex_24.2.zip .
RUN unzip apex_24.2.zip && rm apex_24.2.zip

# ============================================
# 4. Instalar ORDS
# ============================================
RUN wget https://download.oracle.com/otn_software/java/ords/ords-latest.zip && \
    unzip ords-latest.zip -d ords && \
    rm ords-latest.zip

ENV PATH="/opt/ords/bin:${PATH}"

# ============================================
# 5. Copiar scripts de entrada
# ============================================
RUN mkdir -p /opt/scripts
COPY scripts/ /opt/scripts/

# Convertir CRLF a LF y dar permisos de ejecución
RUN find /opt/scripts/ -name "*.sh" -exec sed -i 's/\r$//' {} \; && \
    chmod +x /opt/scripts/*.sh

# ============================================
# 6. (Opcional) Definir volúmenes para persistencia
#    Estos directorios conservarán sus datos aunque el contenedor se elimine
# ============================================
VOLUME ["/opt/ords/config", "/opt/apex/images"]

# ============================================
# 7. Puerto y punto de entrada
# ============================================
EXPOSE 8080

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]