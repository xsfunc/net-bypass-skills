# Router walkthrough: как посмотреть и понять всю систему

Пошаговое руководство для самостоятельной проверки selective routing на роутере.
Все команды выполнять через `ssh router`.

## Ментальная модель

> Пакет из `br-lan` летит в интернет. Если его назначение — IP из набора `@via_awg`, nftables клеит на него метку `0x100`. `ip rule` видит метку и отправляет пакет в таблицу маршрутизации 200. Таблица 200 говорит «default → awg0». Пакет уходит в тоннель.

Три слоя: **MARK** (nftables) → **RULE** (ip rule) → **ROUTE** (ip route table 200 → awg0).

```
┌─────────────────────────────────────────────────────────────┐
│ Телефон 192.168.1.50 → TCP SYN → 149.154.160.1:443          │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────▼───────────────┐
         │ ШАГ 1: nftables mangle_prerouting
         │   iif br-lan + daddr ∈ @via_awg
         │   → meta mark = 0x100          │ СЛОЙ MARK
         └───────────────┬───────────────┘
                         │
         ┌───────────────▼───────────────┐
         │ ШАГ 2: ip rule
         │   fwmark 0x100 + iif br-lan
         │   → lookup table 200          │ СЛОЙ RULE
         └───────────────┬───────────────┘
                         │
         ┌───────────────▼───────────────┐
         │ ШАГ 3: ip route table 200
         │   default dev awg0
         │   → пакет в тоннель           │ СЛОЙ ROUTE
         └───────────────┬───────────────┘
                         │
                  ┌──────▼──────┐
                  │   awg0      │  → Cloudflare WARP → Telegram
                  └─────────────┘
```

Если назначения **нет** в `@via_awg` (например google.com):

```
nftables: daddr ∉ @via_awg → метка НЕ ставится
ip rule:  метки нет → правило 28900 пропускается
ip rule:  доходит до 32766 → lookup main
main:     default via br-wan → обычный интернет
```


## Шаг 1. Интерфейсы — какие сети есть

```sh
ip -br addr show
```

Четыре интерфейса:

| Интерфейс | Что это                     | Сеть            |
|-----------|-----------------------------|-----------------|
| `br-wan`  | Интернет (upstream)         | 100.65.x.x      |
| `br-lan`  | Домашняя сеть               | 192.168.1.0/24  |
| `br-umbra`| «Теневая» сеть              | 192.168.30.0/24 |
| `awg0`    | AmneziaWG тоннель (WARP)    | 172.16.0.2      |

По умолчанию весь трафик идёт через `br-wan`. Задача системы — перехватить трафик к Telegram и пустить его через `awg0`.


## Шаг 2. Набор @via_awg — какие IP считаются «Telegram»

```sh
nft list set inet fw4 via_awg
```

```
set via_awg {
    type ipv4_addr
    flags interval
    auto-merge
    elements = { 91.105.192.0/23, 91.108.4.0-91.108.23.255,
                 91.108.56.0/22, 149.154.160.0/20,
                 185.76.151.0/24 }
}
```

Это **набор IP-адресов** (nftables set). `auto-merge` объединяет смежные /22 в один диапазон `91.108.4.0-91.108.23.255` (это те же 5 подсетей: /22 × 5). Это «список целей» — если пакет летит на любой из этих IP, он становится кандидатом на отправку в тоннель.

Источник диапазонов — официальный `https://core.telegram.org/resources/cidr.txt`.


## Шаг 3. Маркировка — как пакет получает метку (MARK)

```sh
nft list chain inet fw4 mangle_prerouting
```

```
iifname "br-umbra" ip daddr @via_awg counter ... meta mark set 0x00000100 comment "Umbra selected domains via AWG"
iifname "br-lan"   ip daddr @via_awg counter ... meta mark set 0x00000100 comment "LAN Telegram via AWG"
```

Читаем правило слева направо:

- `iifname "br-lan"` — пакет пришёл из домашней сети
- `ip daddr @via_awg` — назначение — IP из набора @via_awg
- `meta mark set 0x100` — поставить метку 0x100 на пакет
- `counter` — считать сколько таких пакетов было

Это первый слой: **MARK**. nftables работает на уровне ядра, ещё до принятия решения о маршрутизации (chain `prerouting`, priority `mangle`).


## Шаг 4. Правила маршрутизации — как метка направляет пакет (RULE)

```sh
ip rule show
```

Ключевые строки:

```
28900: from all fwmark 0x100/0xff00 iif br-lan   lookup 200
29000: from all fwmark 0x100/0xff00 iif br-umbra lookup 200
32766: from all lookup main
```

Читаем:

- `28900` — приоритет (меньше = раньше проверяется)
- `from all fwmark 0x100/0xff00` — любой пакет с меткой 0x100 (маска 0xff00 ловит 0x100 в старшем байте)
- `iif br-lan` — пришёл из br-lan
- `lookup 200` → отправить в таблицу маршрутизации №200

Если метки нет — правило пропускается, пакет доходит до `32766: lookup main` и идёт через обычный интернет (br-wan).

Это второй слой: **RULE**.


## Шаг 5. Таблица маршрутизации 200 — куда летит помеченный пакет (ROUTE)

```sh
ip route show table 200
```

```
default dev awg0 scope link
172.16.0.2 dev awg0 scope link
```

`default dev awg0` — «всё, что попало в эту таблицу, отправляй в интерфейс awg0». Это тоннель.

Для сравнения — обычная таблица:

```sh
ip route show table main
```

```
default via 100.65.128.1 dev br-wan
```

Это третий слой: **ROUTE**. Пакет с меткой → таблица 200 → awg0. Пакет без метки → таблица main → br-wan.


## Шаг 6. Persistent-файлы — как это переживает ребут

Всё, что мы сделали в `nft` и `ip` — оперативная память. После ребута пропадёт. Поэтому есть два файла.

### Файл 1 — набор @via_awg

```sh
cat /usr/share/nftables.d/ruleset-post/30-telegram-via-awg.nft
```

```
add element inet fw4 via_awg { 149.154.160.0/20, 91.108.4.0/22, ... }
```

fw4 при старте автоматически подхватывает всё из `/usr/share/nftables.d/ruleset-post/` и выполняет.

### Файл 2 — правило маркировки

```sh
cat /etc/lan-via-awg-mark.nft
```

```
iifname "br-lan" ip daddr @via_awg counter meta mark set 0x100 comment "LAN Telegram via AWG"
```

Как fw4 узнаёт про этот файл:

```sh
grep -A5 'lan_awg_mark' /etc/config/firewall
```

```
config include 'lan_awg_mark'
    option type 'nftables'
    option path '/etc/lan-via-awg-mark.nft'
    option position 'chain-pre'
    option chain 'mangle_prerouting'
```

Это firewall include — говорит fw4: «вставь содержимое файла в начало chain `mangle_prerouting`».

### ip rules и ip route table 200

Их создаёт amneziawg при поднятии интерфейса (через `ip4table` в `/etc/config/network`).

```sh
grep -A5 'interface.*awg' /etc/config/network
```


## Шаг 7. Проверка тоннеля — жив ли awg0

```sh
awg show awg0 latest-handshakes
```

Если есть timestamp — тоннель жив.

```sh
ping -c 2 -I awg0 1.1.1.1
```

Пинг через awg0 — проверяет, что тоннель действительно пропускает трафик.


## Шаг 8. Подсчёт пакетов — видно ли, что правила работают

```sh
nft list chain inet fw4 mangle_prerouting
```

Смотреть на `counter`:

```
counter packets 3299 bytes 633536
```

3299 пакетов были помечены и ушли в тоннель. Если счётчик растёт (запомни число, попингай Telegram, проверь снова) — система работает.


## Шпаргалка — 5 команд для оценки за раз

| Что посмотреть        | Команда                                                        |
|-----------------------|----------------------------------------------------------------|
| Какие IP в наборе     | `nft list set inet fw4 via_awg`                                |
| Как пакеты метятся    | `nft list chain inet fw4 mangle_prerouting`                    |
| Куда идут помеченные  | `ip rule show` → `ip route show table 200`                     |
| Какой интерфейс       | `ip -br addr show awg0`                                        |
| Жив ли тоннель        | `awg show awg0 latest-handshakes`                              |
