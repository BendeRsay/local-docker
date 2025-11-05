#---------------
# [ ENV ]
#---------------
-include .env

.DEFAULT_GOAL := help

# получим и установим ip контейнера nginx
NGINX_IP = $(shell docker inspect -f '{{range .NetworkSettings.Networks}} {{.IPAddress}} {{end}}' ${COMPOSE_PROJECT_NAME}-nginx)

##
##╔                 ╗
##║  base commands  ║
##╚                 ╝

help: ##Show this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

sethost: #установим host ip в .hosts контейнера php
	docker exec -it --user root ${COMPOSE_PROJECT_NAME}-php bash -c "echo '${NGINX_IP} ${NGINX_HOST}' >> /etc/hosts"

sertadd: #Обновим общесистемный список доверенных CA контейнера php
	docker exec -it --user root ${COMPOSE_PROJECT_NAME}-php bash -c "cat /usr/local/share/ca-certificates/rootCA.pem > /usr/local/share/ca-certificates/rootmkcertCA.crt && update-ca-certificates"

env: ## Создаёт .env .settings.php dbconn.php urlrewrite.php
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
	fi
	@if [ ! -f bitrix/.settings.php ]; then \
		cp bitrix/.settings.php.example bitrix/.settings.php; \
	fi
	@if [ ! -f bitrix/php_interface/dbconn.php ]; then \
		cp bitrix/php_interface/dbconn.php.example bitrix/php_interface/dbconn.php; \
	fi
	@if [ ! -f urlrewrite.php ]; then \
		cp urlrewrite.php.example urlrewrite.php; \
	fi

##
##╔                           ╗
##║  docker-compose commands  ║
##╚                           ╝

dc-ps: ## Список запущенных контейнеров.
	docker-compose ps

dc-build: ## Сборка образа php и cron в нужном порядке
	docker-compose build php
	docker-compose build cron

dc-up: ## Создаем(если нет) образы и контейнеры, запускаем контейнеры.
	docker-compose up -d
	@$(MAKE) sethost
	@$(MAKE) sertadd
	@$(MAKE) gh-check

dc-stop: ## Останавливает контейнеры.
	docker-compose stop

dc-down: ##Останавливает, удаляет контейнеры. docker-compose down --remove-orphans
	docker-compose down --remove-orphans

dc-down-clear: ##Останавливает, удаляет контейнеры и volumes. docker-compose down -v --remove-orphans
	docker-compose down -v --remove-orphans

dc-console-db: ##Зайти в консоль mysql
	docker-compose exec ${COMPOSE_PROJECT_NAME}-mysql mysql -u $(MYSQL_USER) --password=$(MYSQL_PASSWORD) $(MYSQL_DATABASE)

dc-console-php: ##php консоль под www-data
	docker exec -it --user www-data ${COMPOSE_PROJECT_NAME}-php bash

dc-console-php-root: ##php консоль под root
	docker exec -it --user root ${COMPOSE_PROJECT_NAME}-php bash
dc-ci-bitrix: ##composer install в папке битрикс
	docker exec ${COMPOSE_PROJECT_NAME}-php bash -c "cd bitrix && COMPOSER=composer-bx.json composer install"

##
##╔                     ╗
##║  database commands  ║
##╚                     ╝

db-dump: ## Сделать дамп БД
	docker exec ${COMPOSE_PROJECT_NAME}-mysql mysqldump -u $(MYSQL_USER) --password=$(MYSQL_PASSWORD) $(MYSQL_DATABASE) --no-tablespaces | gzip > ./local/docker/dump.sql.gz
	@if [ -f ./local/docker/dump.sql.gz ]; then \
		mv  ./local/docker/dump.sql.gz ./local/docker/dump/$(shell date +%Y-%m-%d_%H%M%S)_dump.sql.gz; \
	fi

db-restore: ## Восстановить данные в БД. Параметр path - путь до дампа. Пример: make db-restore path=./local/docker/dump/dump.sql.gz
	gunzip < $(path) | docker exec -i ${COMPOSE_PROJECT_NAME}-mysql mysql -u root --password=$(MYSQL_ROOT_PASSWORD) $(MYSQL_DATABASE)

db-migrate-up: ## Установка миграций
	docker exec --user www-data ${COMPOSE_PROJECT_NAME}-php php /var/www/html/local/modules/sprint.migration/tools/migrate.php up

db-migrate-ls: ## Список миграций
	docker exec --user www-data ${COMPOSE_PROJECT_NAME}-php php /var/www/html/local/modules/sprint.migration/tools/migrate.php ls

##
##╔                      ╗
##║       git hooks      ║
##╚                      ╝

gh-check: # Проверка git hooks
	@if [ ! -f .git/hooks/commit-msg ] \
	 || [ ! -f .git/hooks/pre-commit ] \
	 || [ ! -f .git/hooks/prepare-commit-msg ] \
	; then \
		echo "$$(tput setaf 1)\nХуки не установлены!\n$$(tput setaf 0)Выполните команду:\n\n $$(tput setaf 2)make gh \n"; \
	fi

gh: # Инициализация git hooks
	@cd .git/hooks && \
	ln -sf ../../local/docker/hooks/commit-msg commit-msg && \
	ln -sf ../../local/docker/hooks/pre-commit pre-commit && \
	ln -sf ../../local/docker/hooks/prepare-commit-msg prepare-commit-msg
