# Docker под 1С-Битрикс.
Сборка представляет собой связку:
nginx + php-fpm + mysql + memcached + redis

В отличие от сборки https://github.com/BendeRsay/docker предназначена для использования внутри проекта, в папке /local.

Поддерживает технологию композитный сайт. Работает в https или http.

Здесь и дальше `localhost` может быть изменен на любой домен, который указывается в `.env`, а так же в вашем локальном `.hosts`

Для работы **https** локально требуется установить корневой сертификат ssl в браузере.

Есть **phpmyadmin** для просмотра БД. http://localhost:8181/

Есть **mailhog** для просмотра почты. http://localhost:8025/
> порты могут отличаться, зависит от настроек в `.env`

**PHP:** 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4

**MySql:** 5.7, 8

**ВАЖНО**

Запускать проект не от root пользователя - иначе возникает проблема с правами в контейнере. 

**[Использование Docker без sudo](https://docs.docker.com/engine/install/linux-postinstall/)**

## Установка
Клонируем проект

`git clone  https://github.com/BendeRsay/local-docker.git`

Настраиваем окружение в файле `.env` в случае необходимости

`NGINX_HOST` должен совпадать с настройками Главного модуля, "URL сайта (без http://, например www.mysite.com)". При запуске одновременно нескольких проектов, порты на контейнеры должны отличаться.

Настраиваем `cron` в файле /local/docker/images/cron/crontab

Закрываем доступ к служебным файлам, к примеру через .htaccess при использовании apache.

Список файлов:
/local, .env.example, .gitattributes, .gitignore, docker-compose.yml, Makefile, README.md

Собираем базовый образ php и cron в нужном порядке

`make dc-build`

Запускаем docker

`make dc-up`

Рекомендуется всегда пользоваться командами `make dc-up` и `make dc-down` для запуска и остановки проекта в docker.
В `make dc-up` происходит установка домена и ip nginx в файл `.hosts` контейнера php.

## Структура проекта
```bash
-- local/docker
    -- bash_history # папка для хранения истории bash контейнеров
    -- conf # конфиги nginx и пр.
    -- dump # папка для дампов БД
    -- images # папка с docker образами
-- .env.example # пример файла `.env`
-- .gitignore # список игнорирования GIT
-- Makefile # команды make. Список команд make можно посмотреть так: `make` или `make help`
-- docker-compose.yml # конфиг контейнеров
-- README.md # этот файл
```

## memcached
Пример кэширования в **memcached**, настройки файла `bitrix/.settings.php`
````php
return [
//...        
    'cache' =>
        array(
            'value' => array(
                'type' => array(
                    'class_name' => '\\Bitrix\\Main\\Data\\CacheEngineMemcache',
                    'extension' => 'memcache'
                ),
                'memcache' => array(
                    'host' => 'memcached',
                    'port' => '11211',
                ),
                'sid' => $_SERVER["DOCUMENT_ROOT"] . "#01"
            ),
            'readonly' => false,
        ),
````
Подробнее в https://dev.1c-bitrix.ru/learning/course/index.php?COURSE_ID=43&LESSON_ID=2795#cache

## redis
Пример хранения данных сессии в **redis**, настройки файла `bitrix/.settings.php`
````php
return [
//...        
    'session' => [
        'value' => [
            'mode' => 'default',
            'handlers' => [
                'general' => [
                    'type' => 'redis',
                    'host' => 'redis',
                    'port' => '6379',
                ],
            ],
        ],
    ],
];
````
Подробнее в https://dev.1c-bitrix.ru/learning/course/index.php?COURSE_ID=43&LESSON_ID=14026&LESSON_PATH=3913.3435.4816.14028.14026

## Отладка и профилирование

<details>
  <summary>Xdebug</summary>

**[Документация](https://xdebug.org/docs/)**
    
**[Расширения для браузеров](https://www.jetbrains.com/help/phpstorm/2022.3/browser-debugging-extensions.html)**

В php.ini нашего контейнера с PHP имеется секция xdebug, где прописываются параметры для работы с Xdebug.

Пример параметров:
```ini
xdebug.idekey = www-data
xdebug.mode = develop, debug, coverage
xdebug.start_with_request=trigger
xdebug.trigger_value=startXdebug
#xdebug.log="/var/www/html/xdebug.log"
```
О параметрах:

| Параметр                  | Описание                                                                                               |
|---------------------------|--------------------------------------------------------------------------------------------------------|
| xdebug.idekey             | ключ IDE                                                                                               |
| xdebug.mode               | **[возможные режимы работы](https://xdebug.org/docs/code_coverage#mode)**                              |
| xdebug.start_with_request | как будет запускаться. **[Подробнее](https://xdebug.org/docs/all_settings#start_with_request)**        |
| xdebug.trigger_value      | значение для активации триггера. **[Подробнее](https://xdebug.org/docs/all_settings#trigger_value)**   |
| xdebug.log                | путь до логов. Если не работает xdebug - **[смотрим логи](https://xdebug.org/docs/code_coverage#log)** |

**Настройка в IDE:**

<details>
  <summary>PhpStorm</summary>

**[Документация от PhpStorm](https://www.jetbrains.com/help/phpstorm/configuring-xdebug.html)**

1. Открываем список серверов **Settings -> PHP -> Servers**
2. Добавляем новый сервер с любым названием. Хост указываем тот, по которому заходим на сайт локально без указания протокола (нужен только порт 80 или 443)
3. Включаем маппинг и для корня проекта указываем **/var/www/html**
4. Открываем **Run -> Edit Configurations...**
5. Нажимаем на **+** и выбираем **PHP Remote Debug**
6. Вводим любое имя, выбираем из выпадающего списка наш сервер, указываем IDE key (обычно PHP_STORM). Дополнительно в пункте Pre-configuration можно провести валидацию. Сохраняем
7. Ставим **[точки остановки](https://www.jetbrains.com/help/phpstorm/using-breakpoints.html)**, включаем прослушивание (телефонная трубка в правом верхнем углу) и открываем нужную страницу в браузере

</details>

<details>
  <summary>VS Code</summary>

Для начала **[установим расширение](https://marketplace.visualstudio.com/items?itemName=xdebug.php-debug)** для работы с xdebug.
**[Подробнее об установке расширения](https://habr.com/ru/post/310708/)**.

Настраиваем launch.json:
```json
{
    "name": "Listen for Xdebug",
    "type": "php",
    "request": "launch",
    "port": 9003,
    "log": true,
    "externalConsole": false,
    "pathMappings": {
      "/var/www/html": "${workspaceFolder}"
    },
    "hostname": "localhost"
}
```

**port** - должен совпадать с портом из настроек в php.ini. А там по умолчанию 9003.

**pathMappings** - слева путь внутри контейнера PHP. Справа путь на нашей машине. ${workspaceFolder} - указывает на нашу рабочую область/текущий проект в VS Code.

**hostname** - Очень важный параметр для windows (wsl2), если его не указать, то VS Code не ловит запросы от Xdebug.

**[Подробней про отличие настроек xdebug 2 и xdebug 3](https://stackoverflow.com/questions/62104199/issues-when-debugging-php-in-vscode-using-docker-and-wsl2)**

**[Подробней про параметры в launch.json](https://stackoverflow.com/questions/38703278/vscode-environment-variables-besides-workspaceroot)**

</details>

</details>
