---
box: forest
ip: 10.10.10.161
platform: Windows
dc: True
domain: htb.local
dns_name: FOREST
dc_tag: dc
date: 2025-11-05
tags: [htb, enum, dc, windows]
---

---
box: forest
ip: 10.10.10.161
os: Windows
dc: True
domain: htb.local
dns: FOREST
created: 2025-11-05
tags: [enum, htb, {{platform|lower}}, dc]
---

# 📦 Enumeration Index for `forest`




## 🔹 Box Summary

```dataviewjs

```

---

```dataviewjs

```

---


## 🔹 Key Artifacts
- 📄 [`set_env_forest.sh`](set_env_forest.sh)
- 📄 [`dnsupdate-forest.sh`](dnsupdate-forest.sh)
- 🔐 [`krb5.conf`](krb5.conf)
- 🐚 [`rhsell.exe` or `rhsell.elf`](rhsell.{{platform == "Windows" ? "exe" : "elf"}})

---

## 🔹 Vulnerabilities (if found)
```dataview

```

## 🔹 Recon Files
```dataview

```

## 🔹 Port-Specific Enum Scripts
```dataview
```

## 🔹 JSON Snapshot
```dataviewjs

```
