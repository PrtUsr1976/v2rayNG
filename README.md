# v2RayNG-alex

Русский | [English](#english)

Android-клиент на базе [v2rayNG](https://github.com/2dust/v2rayNG) с поддержкой [Xray-core](https://github.com/XTLS/Xray-core) и [v2fly-core](https://github.com/v2fly/v2ray-core).

[![API](https://img.shields.io/badge/API-24%2B-yellow.svg?style=flat)](https://developer.android.com/about/versions/nougat)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.4.0-blue.svg)](https://kotlinlang.org)
[![Build APK](https://github.com/PrtUsr1976/v2rayNG/actions/workflows/build.yml/badge.svg)](https://github.com/PrtUsr1976/v2rayNG/actions/workflows/build.yml)
[![GitHub Releases](https://img.shields.io/github/v/release/PrtUsr1976/v2rayNG?include_prereleases)](https://github.com/PrtUsr1976/v2rayNG/releases)

## Русский

### Нововведения

- Приложение и версия имеют маркировку `v2RayNG-alex` и `-alex`.
- В настройках добавлен переключатель **Использовать agent_v**. Выбранный файл сохраняется при выключении функции и снова используется после включения.
- В настройках добавлен переключатель **Экспорт VLESS** и выбор папки назначения. Выбранная папка также сохраняется при выключении функции.
- После успешного обновления подписки исходные ссылки `vless://` экспортируются в отдельный текстовый файл с именем подписки.
- Для Windows добавлены PowerShell-скрипты установки Android SDK, подготовки нативных библиотек, тестирования, сборки, подписи APK и работы с GitHub.
- GitHub Actions собирает APK для `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64` и универсальный APK.
- Релизные APK подписываются Android-ключом, а опубликованные файлы дополнительно получают отдельные GPG-подписи `.sig`.

### Загрузка

Готовые сборки доступны на странице [GitHub Releases](https://github.com/PrtUsr1976/v2rayNG/releases).

Для Samsung Galaxy A15 используйте вариант `arm64-v8a`. Универсальный APK подходит для большинства устройств, но имеет больший размер.

> Если Android сообщает «Приложение не установлено», на устройстве может находиться приложение с тем же package ID, но другой цифровой подписью. В таком случае сохраните нужные данные, удалите прежнюю версию и установите новую.

### Настройка agent_v

1. Откройте настройки подписок.
2. Выберите глобальный файл `agent_v`.
3. Управляйте его применением переключателем **Использовать agent_v**.

Выключение не удаляет выбранный файл. Заголовки из него применяются только во включённом состоянии.

### Экспорт VLESS

1. Откройте настройки подписок.
2. Выберите папку для экспорта.
3. Включите **Экспорт VLESS**.
4. Обновите подписки.

Для каждой успешно обновлённой подписки приложение создаёт или обновляет файл `<имя подписки>.txt`. Ссылки очищаются от повторов и сортируются. Ошибка экспорта не отменяет обновление самой подписки.

### Сборка в Windows

Android SDK и нативные зависимости можно подготовить скриптами из каталога `ps_scripts`:

```powershell
.\ps_scripts\Install-AndroidSdk.ps1
.\ps_scripts\Build-NativeDependencies.ps1
.\ps_scripts\Test-VlessExport.ps1
.\ps_scripts\Build-SamsungA15.ps1
```

Подписанный APK для Samsung Galaxy A15 копируется в:

```text
!binout\v2rayNG_2.2.6-alex_arm64-v8a.apk
```

Локальный ключ подписи хранится в `.local-signing` и исключён из Git.

Основные вспомогательные команды:

```powershell
.\ps_scripts\Read-RepositoryFiles.ps1 -Path 'README.md'
.\ps_scripts\Git-Status.ps1
.\ps_scripts\Save-GitHub.ps1 -CommitMessage 'Описание изменений' -OpenPullRequest
.\ps_scripts\Start-GitHubBuild.ps1 -Branch agent/alex-vless-export
```

### GeoIP и GeoSite

- Файлы `geoip.dat` и `geosite.dat` располагаются в `Android/data/com.v2ray.ang.agentv/files/assets`; на некоторых устройствах путь может отличаться.
- Расширенные наборы правил доступны в [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) и [geoip](https://github.com/Loyalsoldier/geoip).
- Файлы DAT можно импортировать вручную.

### Проверка GPG-подписи

В релизе рядом с APK публикуются файл `<имя APK>.sig` и публичный ключ. Отпечаток ключа `v2RayNG-alex Release`:

```text
7B78 5CA6 ABE0 9726 D4A9 0950 F0CA 1079 4263 DE8B
```

Пример проверки:

```bash
gpg --import v2rayN-public-key.asc
gpg --verify application.apk.sig application.apk
```

## English

Android client based on [v2rayNG](https://github.com/2dust/v2rayNG), with support for [Xray-core](https://github.com/XTLS/Xray-core) and [v2fly-core](https://github.com/v2fly/v2ray-core).

### What's new

- The application is branded as `v2RayNG-alex`, and its version suffix is `-alex`.
- Subscription settings include a **Use agent_v** switch. Disabling it does not forget the selected file.
- Subscription settings include an **Export VLESS** switch and an export-directory picker. Disabling export does not forget the selected directory.
- After a successful subscription update, original `vless://` links are exported to a text file named after the subscription.
- Windows PowerShell scripts cover Android SDK installation, native dependency preparation, tests, APK builds, signing, and GitHub operations.
- GitHub Actions builds `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`, and universal APKs.
- Release APKs use Android signing; published files also receive detached GPG `.sig` signatures.

### Download

Builds are available on the [GitHub Releases](https://github.com/PrtUsr1976/v2rayNG/releases) page.

Use the `arm64-v8a` build for a Samsung Galaxy A15. The universal APK works on most supported devices but is larger.

> If Android reports “App not installed,” another application with the same package ID but a different signing certificate may already be installed. Back up any required data, uninstall the old application, and install the new APK.

### agent_v settings

1. Open the subscription settings.
2. Select the global `agent_v` file.
3. Control its use with the **Use agent_v** switch.

Turning the switch off does not clear the selected file. Its headers are applied only while the switch is enabled.

### VLESS export

1. Open the subscription settings.
2. Select an export directory.
3. Enable **Export VLESS**.
4. Update subscriptions.

For each successfully updated subscription, the application creates or updates `<subscription name>.txt`. Links are deduplicated and sorted. An export error does not cancel the subscription update.

### Building on Windows

Use the scripts in `ps_scripts` to install the Android SDK, prepare native dependencies, run tests, and build the app:

```powershell
.\ps_scripts\Install-AndroidSdk.ps1
.\ps_scripts\Build-NativeDependencies.ps1
.\ps_scripts\Test-VlessExport.ps1
.\ps_scripts\Build-SamsungA15.ps1
```

The signed Samsung Galaxy A15 APK is copied to:

```text
!binout\v2rayNG_2.2.6-alex_arm64-v8a.apk
```

The local signing key is stored in `.local-signing`, which is excluded from Git.

Useful repository commands:

```powershell
.\ps_scripts\Read-RepositoryFiles.ps1 -Path 'README.md'
.\ps_scripts\Git-Status.ps1
.\ps_scripts\Save-GitHub.ps1 -CommitMessage 'Describe the changes' -OpenPullRequest
.\ps_scripts\Start-GitHubBuild.ps1 -Branch agent/alex-vless-export
```

### GeoIP and GeoSite

- `geoip.dat` and `geosite.dat` are stored in `Android/data/com.v2ray.ang.agentv/files/assets`; the path may differ on some devices.
- Enhanced rule sets are available from [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) and [geoip](https://github.com/Loyalsoldier/geoip).
- DAT files can also be imported manually.

### GPG verification

Each release provides `<APK name>.sig` and the public key alongside the APK files. The `v2RayNG-alex Release` key fingerprint is:

```text
7B78 5CA6 ABE0 9726 D4A9 0950 F0CA 1079 4263 DE8B
```

Verification example:

```bash
gpg --import v2rayN-public-key.asc
gpg --verify application.apk.sig application.apk
```

## Credits and license

This project is derived from [2dust/v2rayNG](https://github.com/2dust/v2rayNG). See [LICENSE](LICENSE) for licensing information.