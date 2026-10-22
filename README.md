> [!CAUTION]
> This branch contains new reworks of the container logic and structure, it is not recommended to use this branch for production use. No guarantees that it will work as expected, it is still in development and testing phase. Expect some bugs and issues or failed compiled images.
> Old backend hanlding are being replaced in favor for supervisor which will allow the container to be more stable and easier to use.

> [!NOTE]
> **Alpine base.** The images are built on Alpine Linux (previously Debian). Existing `/web`, `/config` and
> `/scripts` volumes keep working: `www-data` is still uid/gid 33, PHP keeps the `/etc/php/<version>/{cli,fpm}`
> layout, the `/run/php/php<version>-fpm.sock` sockets and the `php8.4` / `php-fpm8.4` commands, and Apache keeps
> the `/etc/apache2` layout (`apache2.conf`, `envvars`, `mods-available` / `mods-enabled`).
> On first start the Debian extension symlinks in `/config/php/<version>/*/conf.d` and `mods-available` are removed
> once; ini files you added to `conf.d` stay. Differences you may notice:
> - `php-xmlrpc` is gone (no Alpine package).
> - `iconv()` with `//TRANSLIT` fails (Alpine's C library has no transliteration). Use `Transliterator` from intl
>   or a library such as `voku/portable-ascii` instead.
> - `a2enmod` / `a2dismod` do not exist; enable an Apache module by linking `mods-available/<name>.load` (and
>   `.conf`) into `mods-enabled/`.
> - certbot lives in `/opt/certbot` (a venv with the Cloudflare DNS plugin); `certbot` is on the PATH as before.

> [!IMPORTANT]  
> Details below are outdated, expect changes in the future!

> [!IMPORTANT]  
> To be updated!

`Made in Latvia :)`