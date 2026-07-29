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
    php8.1-bcmath

# 4. PHP 8.4 FPM + extensiones basicas
RUN apt-get install -y \
    php8.4-fpm \
    php8.4-cli \
    php8.4-curl \
    php8.4-mbstring \
    php8.4-xml \
    php8.4-zip \
    php8.4-bcmath

# 5. Composer
RUN php8.1 -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php8.1 composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm composer-setup.php && \
    php8.4 /usr/local/bin/composer --version

# 6. Supervisor
RUN apt-get install -y supervisor

# 7. Herramientas de compilacion (para futuro, NO instalan nada de SQL Server)
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

# 8. Configuracion de Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 9. Crear directorio de sockets PHP-FPM
RUN mkdir -p /run/php

# 10. Configuracion por defecto de PHP-FPM: escuchar en socket unix
RUN sed -i 's|^listen = /run/php/php8.1-fpm.sock|listen = /run/php/php8.1-fpm.sock|' /etc/php/8.1/fpm/pool.d/www.conf && \
    sed -i 's|^;listen.owner = www-data|listen.owner = www-data|' /etc/php/8.1/fpm/pool.d/www.conf && \
    sed -i 's|^;listen.group = www-data|listen.group = www-data|' /etc/php/8.1/fpm/pool.d/www.conf

RUN sed -i 's|^listen = /run/php/php8.4-fpm.sock|listen = /run/php/php8.4-fpm.sock|' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's|^;listen.owner = www-data|listen.owner = www-data|' /etc/php/8.4/fpm/pool.d/www.conf && \
    sed -i 's|^;listen.group = www-data|listen.group = www-data|' /etc/php/8.4/fpm/pool.d/www.conf

# 11. Limpiar cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
