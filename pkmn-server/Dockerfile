###
### Dockerfile migration of https://github.com/EnergyCube/cowfc_installer
### 
### `docker-compose up`
### 
### Open ports listed below
### TCP: 53, 80, 443, 8000, 9000, 9001, 9009, 9002, 9003, 9998, 27500, 27900, 27901, 28910, 29900, 29901, 29920
### UDP: 53
### 
### Admin URL: http://$IP/?page=admin&section=Dashboard
###

ARG ADMIN_USERNAME
ARG ADMIN_PASSWORD

ARG VERSION_OPENSSL="openssl-1.1.1m"
ARG VERSION_HTTPD="httpd-2.4.52"

###
### Stage 1: Build OpenSSL with SSLv3
### info: https://qiita.com/keys/items/61eb02bd7396cda0d548
###
FROM debian:11 AS builder_openssl
ARG VERSION_OPENSSL
ARG VERSION_HTTPD

### Install Updates and applications
RUN cd / && \
    apt update && apt -y install \
        build-essential \
        curl \
        libapr1-dev \
        libaprutil1-dev \
        libpcre3-dev

### Get Openssl
RUN cd / && \
    curl -L https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1m/$VERSION_OPENSSL.tar.gz -O && \
    tar xvf $VERSION_OPENSSL.tar.gz && rm $VERSION_OPENSSL.tar.gz && cd $VERSION_OPENSSL && \
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared enable-ssl3 enable-ssl3-method enable-weak-ssl-ciphers && make install_sw && make install_ssldirs

### Install httpd
RUN cd / && \
    curl http://archive.apache.org/dist/httpd/$VERSION_HTTPD.tar.bz2 -O && \
    tar xvf $VERSION_HTTPD.tar.bz2 && rm $VERSION_HTTPD.tar.bz2 && cd $VERSION_HTTPD && \
    # with this command, you can switch openssl libraries
    echo "/usr/local/openssl/lib" > /etc/ld.so.conf.d/usr.local.openssl.lib.conf && ldconfig && \
    ./configure --enable-ssl --with-ssl=/usr/local/openssl/ && make

###
### Stage 2: Create dummy certificate files
### info: https://flewkey.com/blog/2020-07-12-nds-constraint.html
###
FROM debian:11 AS builder_dummy-certs

RUN apt update && apt -y install \
        curl \
        openssl

RUN mkdir /dummy-certs && cd /dummy-certs/ && \
    curl https://larsenv.github.io/NintendoCerts/WII_NWC_1_CERT.p12 -LO && \
    openssl pkcs12 -in WII_NWC_1_CERT.p12 -passin pass:alpine -passout pass:alpine -out keys.txt && \
    sed -n '7,29p' keys.txt > nwc.crt && \
    sed -n '33,50p' keys.txt > nwc.key && \
    openssl genrsa -out server.key 1024 && \
    echo "US\nWashington\nRedmond\nNintendo of America Inc.\nNintendo Wifi Network\n*.*.*\nca@noa.nintendo.com\n\n\n" | \
        openssl req -new -key server.key -out server.csr && \
    openssl x509 -req -in server.csr -CA nwc.crt -CAkey nwc.key -CAcreateserial \
        -out server.crt -days 3650 -sha1 -passin pass:alpine && \
    rm WII_NWC_1_CERT.p12 keys.txt nwc.key nwc.srl server.csr

###
### Stage 3: Build pkmn-classic-framework
###
FROM debian:11 AS builder_pkmn-classic-framework

RUN apt update && apt -y install \
        curl \
        git \
        mono-complete \
        nuget

RUN git clone --depth 1 https://github.com/mm201/pkmn-classic-framework.git && \
    cd pkmn-classic-framework/ && \
    sed -i -e 's/git@github\.com:/https:\/\/github\.com\//g' .gitmodules && \
    git submodule update --init && \
    find ./ -name *.config | xargs -n 1 sed -i -e 's/connectionString="Server=gts;/connectionString="Server=localhost;/g' && \
    cd gts/ && \
    sed -i -e 's/<Reference Include=\"System.Web.Entity\" \/>//g' gts.csproj && \
    nuget install System.Web.Http.Common && \
    cd .. && \
    nuget restore || true && \
    cd gts/ && \
    xbuild /p:Configuration=Release /p:OutDir=publish/

###
### Stage 3: Isolate pip from runner
###
FROM python:2.7.18 AS builder_twisted
RUN pip install twisted

###
### Stage 4: pkmn-server
###

FROM debian:11
ARG ADMIN_USERNAME
ARG ADMIN_PASSWORD
ARG VERSION_OPENSSL
ARG VERSION_HTTPD

# Copy build artifacts from previous stages
COPY --from=builder_openssl /$VERSION_OPENSSL /$VERSION_OPENSSL
COPY --from=builder_openssl /$VERSION_HTTPD /$VERSION_HTTPD
COPY --from=builder_dummy-certs /dummy-certs /dummy-certs
COPY --from=builder_pkmn-classic-framework /pkmn-classic-framework /pkmn-classic-framework
COPY ./gts_dump/gts_dump.sql /gts_dump.sql
COPY --from=builder_twisted /usr/local/lib/python2.7/site-packages /usr/local/lib/python2.7/dist-packages

### Install base packages
RUN apt update && apt -y --no-install-recommends install \
        apache2 \
        apt-transport-https \
        ca-certificates \
        curl \
        git \
        libapache2-mod-mono \
        lsb-release \
        mono-xsp \
        net-tools \
        python2.7 \
        python3-software-properties \
        software-properties-common \
        vim \
    && ln -s /usr/bin/python2.7 /usr/bin/python

### Install PHP 7.4 and MariaDB
RUN curl https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list && \
    apt update && apt -y --no-install-recommends install \
        mariadb-server \
        php7.4 \
        php7.4-mysql \
        php7.4-sqlite3 \
        sqlite3

### Install custom OpenSSL with SSLv3 support
RUN apt update && apt -y --no-install-recommends install build-essential && \
    cd /$VERSION_OPENSSL && \
    make install_sw && \
    make install_ssldirs && \
    cd /$VERSION_HTTPD && \
    cp modules/ssl/.libs/mod_ssl.so /usr/lib/apache2/modules/ && \
    echo "/usr/local/openssl/lib" > /etc/ld.so.conf.d/usr.local.openssl.lib.conf && \
    ldconfig && \
    rm -rf /$VERSION_OPENSSL /$VERSION_HTTPD && \
    apt purge -y build-essential

### Install Nintendo certificates
RUN mkdir /etc/apache2/certs && \
    cp /dummy-certs/server.crt /etc/apache2/certs/ && \
    cp /dummy-certs/server.key /etc/apache2/certs/ && \
    cp /dummy-certs/nwc.crt /etc/apache2/certs/ && \
    rm -rf /dummy-certs

### Clone and configure CoWFC
RUN cd /var/www/ && \
    git clone --depth 1 https://github.com/EnergyCube/CoWFC.git && \
    git clone --depth 1 https://github.com/EnergyCube/dwc_network_server_emulator.git && \
    sed -i -e "s/db_user = root/db_user = cowfc/g" CoWFC/Web/config.ini && \
    sed -i -e "s/db_pass = passwordhere/db_pass = cowfc/g" CoWFC/Web/config.ini && \
    sed -i -e "s/recaptcha_enabled = 1/recaptcha_enabled = 0/g" CoWFC/Web/config.ini && \
    chmod 777 CoWFC/Web/bans.log && \
    touch dwc_network_server_emulator/gpcm.db && \
    chmod 777 dwc_network_server_emulator/ -R && \
    echo "\npokemondpds\t2\tRwBpAHIAYQBmAGYAZQA_" >> dwc_network_server_emulator/gamestats.cfg

### Setup CoWFC database
RUN service mariadb start && \
    echo "CREATE DATABASE cowfc; \
          CREATE USER 'cowfc'@'localhost' IDENTIFIED BY 'cowfc'; \
          GRANT ALL PRIVILEGES ON *.* TO 'cowfc'@'localhost'; \
          FLUSH PRIVILEGES;" | mysql --user=root && \
    mysql --user=root --database=cowfc < /var/www/CoWFC/SQL/cowfc.sql && \
    echo "INSERT INTO users (Username, Password, Rank) \
          VALUES ('$ADMIN_USERNAME', \
                  '`/var/www/CoWFC/SQL/bcrypt-hash "$ADMIN_PASSWORD"`', \
                  '1');" | mysql --user=root --database=cowfc

### Install CoWFC web interface
RUN cd /var/www/ && \
    rm -rf html/* && \
    mv CoWFC/Web/* html/ && \
    mv html/config.ini ./ && \
    touch /etc/.dwc_installed

### Setup GTS (pkmn-classic-framework)
RUN cd /var/www/ && \
    mkdir gamestats2.gs.nintendowifi.net && \
    mv /pkmn-classic-framework/gts/publish/_PublishedWebsites/gts/* gamestats2.gs.nintendowifi.net/

### Setup GTS database
RUN echo "[mysqld]\nlower_case_table_names=1" >> /etc/mysql/my.cnf && \
    service mariadb restart && \
    echo "CREATE DATABASE gts; \
          CREATE USER 'gts'@'localhost' IDENTIFIED BY 'gts'; \
          GRANT ALL ON *.* TO 'gts'@'localhost';" | mysql --user=root && \
    mysql --user=root --database=gts < /gts_dump.sql

### Configure Apache base settings
RUN cd /etc/apache2/ && \
    echo "ServerName localhost\nHttpProtocolOptions Unsafe LenientMethods Allow0.9" >> apache2.conf && \
    sed -i -e "s/SSLCipherSuite HIGH:!aNULL/SSLCipherSuite @SECLEVEL=0:RC4-SHA:RC4-MD5/g" mods-available/ssl.conf && \
    sed -i -e "s/SSLProtocol all -SSLv3/SSLProtocol SSLv3/g" mods-available/ssl.conf

### Setup Apache VirtualHosts
RUN cd /etc/apache2/ && \
    mv /var/www/dwc_network_server_emulator/tools/apache-hosts/* sites-available/ && \
    sed -i -e 's/ServerAlias "nas.nintendowifi.net"//g' \
           -e 's/ServerAlias "nas.nintendowifi.net, nas.nintendowifi.net"//g' \
        sites-available/nas-naswii-dls1-conntest.nintendowifi.net.conf

### Create GTS VirtualHost
COPY ./pkmn-server/apache-configs/gamestats2.gs.nintendowifi.net.conf /etc/apache2/sites-available/
COPY ./pkmn-server/apache-configs/nas.nintendowifi.net.conf /etc/apache2/sites-available/

### Enable Apache modules and sites
RUN a2dismod mpm_event mod_mono_auto && \
    a2enmod proxy proxy_http "php7.4" ssl && \
    a2ensite *.nintendowifi.net.conf

### Copy startup script
COPY ./pkmn-server/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

### Disable DLC server (optional)
#RUN cd /var/www/dwc_network_server_emulator/ && \
#    rm -rf dlc/* && \
#    sed -i -e 's/gamecodes_return_random_file = \[.*\]/gamecodes_return_random_file = \[\]/g' nas_server.py

### Cleanup unnecessary packages
RUN apt purge -y \
        apt-transport-https \
        git \
        lsb-release \
        net-tools \
        python3-software-properties \
        software-properties-common \
        vim && \
    apt autoremove -y && \
    rm -rf /var/lib/apt/lists/*

CMD ["/bin/sh", "/entrypoint.sh"]