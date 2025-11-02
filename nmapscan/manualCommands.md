# Manual Steps (Single Fixed Timestamp via `export TS=...`)

These commands reproduce what `nmapscan` does, while **avoiding timestamp drift** by setting a single timestamp once.
We only use **one environment variable**: `TS`, exported with a one-liner so every later command reuses it.

Target: **IP = 10.76.21.12**, **HOST tag = web01**.

---

## 0) Set a single timestamp for all artifacts

> Run this once at the start of your session.

```bash
export TS="$(date +%Y%m%d-%H%M%S)"; echo "TS=$TS"
```

*(You can re-run this later if you want a new batch with a fresh timestamp.)*

---

## 1) Ensure the XSL is present (auto-download if missing)

```bash
[ -s "$HOME/nmap-bootstrap.xsl" ] || wget -q -O "$HOME/nmap-bootstrap.xsl" "https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl" || curl -sSL -o "$HOME/nmap-bootstrap.xsl" "https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl"
```

---

## TCP Flow (web01 @ 10.76.21.12)

### 2) Fast SYN discovery (all TCP ports)

```bash
sudo nmap -n -sS -p- -T4 --min-rate 1000 --max-retries 2 \
  -oG tcp.discovery-web01.${TS}.gnmap -Pn 10.76.21.12
```

### 3) Parse open TCP ports into list + CSV

```bash
awk -F'Ports: ' '/Ports:/{print $2}' tcp.discovery-web01.${TS}.gnmap \
 | tr ',' '\n' \
 | awk -F'/' '$2 ~ /^open/ {print $1}' \
 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
 | sort -n -u > tcp.open_tcp_ports-web01.${TS}.txt

paste -sd, tcp.open_tcp_ports-web01.${TS}.txt > tcp.open_tcp_ports-web01.${TS}.csv
```

### 4) Targeted heavy TCP scan (service/OS/scripts)

```bash
sudo nmap -n -p "$(cat tcp.open_tcp_ports-web01.${TS}.csv)" -T4 -sT -sV --version-all \
  --script "default,auth,vuln" -O --osscan-guess \
  -oA tcp.heavy-web01.${TS} -Pn 10.76.21.12
```

*(To include brute scripts explicitly, change `--script` to `"default,auth,brute,vuln"`.)*

### 5) Convert heavy TCP XML → HTML

```bash
xsltproc -o tcp.heavy-web01.${TS}.html "$HOME/nmap-bootstrap.xsl" tcp.heavy-web01.${TS}.xml
```

---

## UDP Flow (web01 @ 10.76.21.12)

### 6) UDP top-ports discovery

```bash
sudo nmap -n -sU --top-ports 500 -T4 --max-retries 2 --host-timeout 2m \
  -oG udp.discovery-web01.${TS}.gnmap -Pn 10.76.21.12
```

### 7) Parse open UDP ports into list + CSV

```bash
awk -F'Ports: ' '/Ports:/{print $2}' udp.discovery-web01.${TS}.gnmap \
 | tr ',' '\n' \
 | awk -F'/' '$2=="open"{print $1}' \
 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
 | sort -n -u > udp.open_udp_ports-web01.${TS}.txt

paste -sd, udp.open_udp_ports-web01.${TS}.txt > udp.open_udp_ports-web01.${TS}.csv
```

### 8) Targeted UDP checks (service/scripts)

```bash
sudo nmap -n -sU -p "$(cat udp.open_udp_ports-web01.${TS}.csv)" -T4 -sV \
  --script "default,vuln" \
  -oA udp.heavy-web01.${TS} -Pn 10.76.21.12
```

### 9) Convert heavy UDP XML → HTML

```bash
xsltproc -o udp.heavy-web01.${TS}.html "$HOME/nmap-bootstrap.xsl" udp.heavy-web01.${TS}.xml
```

---

## Produced files (all share the same `${TS}`)

```
tcp.discovery-web01.${TS}.gnmap
tcp.open_tcp_ports-web01.${TS}.txt
tcp.open_tcp_ports-web01.${TS}.csv
tcp.heavy-web01.${TS}.{nmap,xml,gnmap,html}

udp.discovery-web01.${TS}.gnmap
udp.open_udp_ports-web01.${TS}.txt
udp.open_udp_ports-web01.${TS}.csv
udp.heavy-web01.${TS}.{nmap,xml,gnmap,html}
```
