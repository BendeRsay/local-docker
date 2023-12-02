ARG COMPOSE_PROJECT_NAME
ARG PHP_VERSION

FROM ${COMPOSE_PROJECT_NAME}-php:${PHP_VERSION}

USER root
WORKDIR /root

# нужные пакеты
RUN apt-get update && apt-get install -y \
        cron

COPY crontab /root/crontab

# добавляем задание cron для пользователя www-data и меняем права на папку с логами
RUN crontab -u www-data /root/crontab && chmod 777 /var/log

CMD ["cron", "-f"]