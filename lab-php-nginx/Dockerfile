FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Sistema base + PPA Ondrej
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php && \
    apt-get update

# 2. Nginx
RUN apt-get install -y nginx

# 3. PHP 8.1 FPM + extensiones basicas
RUN apt-get install -y \
    php8.1-fpm \
    php8.1-cli \
    php8.1-curl \
    php8.1-mbstring \
    php8.1-xml \
    php8.1-zip \
    php8.1-bcmath \
    php8.1-sqlite3

# 4. PHP 8.4 FPM + extensiones basicas
RUN apt-get install -y \
    php8.4-fpm \
    php8.4-cli \
    php8.4-curl \
    php8.4-mbstring \
    php8.4-xml \
    php8.4-zip \
    php8.4-bcmath \
    php8.4-sqlite3

# 5. Composer
RUN php8.1 -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php8.1 composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm composer-setup.php && \
    php8.4 /usr/local/bin/composer --version

# 6. Supervisor
RUN apt-get install -y supervisor

# 7. Herramientas de compilacion
RUN apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    autoconf \
    automake \
    libtool \
    php8.1-dev \
    php8.4-dev \
    php-pear \
    curl \
    wget \
    git \
    unzip

# 8. Microsoft ODBC Driver 18 para SQL Server
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" \
    > /etc/apt/sources.list.d/microsoft-prod.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc-dev

# 9. Compilar extensiones SQL Server para PHP 8.1
RUN update-alternatives --set phpize /usr/bin/phpize8.1 && \
    update-alternatives --set php-config /usr/bin/php-config8.1 && \
    pecl install sqlsrv && \
    pecl install pdo_sqlsrv

# 10. Compilar extensiones SQL Server para PHP 8.4
RUN update-alternatives --set phpize /usr/bin/phpize8.4 && \
    update-alternatives --set php-config /usr/bin/php-config8.4 && \
    pecl install sqlsrv && \
    pecl install pdo_sqlsrv

# 11. Habilitar extensiones en PHP 8.1
RUN echo "extension=sqlsrv.so" > /etc/php/8.1/mods-available/sqlsrv.ini && \
    echo "extension=pdo_sqlsrv.so" > /etc/php/8.1/mods-available/pdo_sqlsrv.ini && \
    phpenmod -v 8.1 sqlsrv pdo_sqlsrv

# 12. Habilitar extensiones en PHP 8.4
RUN echo "extension=sqlsrv.so" > /etc/php/8.4/mods-available/sqlsrv.ini && \
    echo "extension=pdo_sqlsrv.so" > /etc/php/8.4/mods-available/pdo_sqlsrv.ini && \
    phpenmod -v 8.4 sqlsrv pdo_sqlsrv

# 13. Crear usuarios del sistema
# phpuser (uid 1000) corre PHP-FPM, coincide con uid del host para compatibilidad de archivos
RUN groupadd -g 1000 phpuser && \
    useradd -m -u 1000 -g phpuser -s /bin/bash phpuser && \
    usermod -aG www-data phpuser
# devuser (uid 2000) para tareas de desarrollo/administracion
RUN groupadd -g 2000 devuser && \
    useradd -m -u 2000 -g devuser -s /bin/bash devuser && \
    usermod -aG www-data devuser && \
    usermod -aG phpuser devuser

# 14. Configuracion de Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 15. Crear directorio de sockets PHP-FPM
RUN mkdir -p /run/php

# 16. Configuracion por defecto de PHP-FPM: escuchar en socket unix
RUN sed -i 's|^user = www-data|user = phpuser|' /etc/php/8.1/fpm/pool.d/www.conf && \
    sed -i 's|^group = www-data|group = phpuser|' /etc/php/8.1/fpm/pool.d/www.conf && \
    sed -i 's|^listen = /run/php/php8.1-fpm.sock|listen = /run/php/php8.1-fpm.sock|' /etc/php/8.1/fpm/pool.d/www.conf && \
    sed -i 's|^;listen.owner = www-data|listen.owner = www-data|' /etc/php/8.1/fpm/pool.d/www.conf && \
    sed -i 's|^;listen.group = www-data|listen.group = www-data|' /etc/php/8.1/fpm/pool.d/www.conf

RUN sed -i 's|^user = www-data|user = phpuser|' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's|^group = www-data|group = phpuser|' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's|^listen = /run/php/php8.4-fpm.sock|listen = /run/php/php8.4-fpm.sock|' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's|^;listen.owner = www-data|listen.owner = www-data|' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's|^;listen.group = www-data|listen.group = www-data|' /etc/php/8.4/fpm/pool.d/www.conf

# 17. Limpiar cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
