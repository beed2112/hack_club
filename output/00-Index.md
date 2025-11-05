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
dv.paragraph("Current folder: " + dv.current().file.folder);
```

---

```dataviewjs
(() => {
  const folder = dv.current().file.folder;

  const files = app.vault.getFiles()
    .filter(f => f.path.startsWith(folder + "/") && f.extension === "md" && f.name !== "00-Index.md")
    .sort((a, b) => a.path.localeCompare(b.path));

  dv.table(
    ["File", "Path"],
    files.map(f => [
      dv.fileLink(f.path),
      f.path
    ])
  );
})();

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
table file.link as "Findings"
from ""
where file.name = "PROCESSED-nmap-forest.md"
```

## 🔹 Recon Files
```dataview
table file.link as "Recon File"
from "scans"
where !contains(file.name, ".xml") and !contains(file.name, "port-") and file.name != "00-Index"
sort file.name asc
```

## 🔹 Port-Specific Enum Scripts
```dataview
table file.link as "Script"
from "scans"
where endswith(file.name, "run-enum.sh")
sort file.name asc
```

## 🔹 JSON Snapshot
```dataviewjs
(() => {
  const folder = dv.current().file.folder;

  const files = app.vault.getFiles()
    .filter(f =>
      f.path.startsWith(folder + "/") &&
      f.extension === "json" &&
      f.name.startsWith("PROCESSED-nmap-")
    )
    .sort((a, b) => a.name.localeCompare(b.name));

  dv.table(
    ["Host JSON", "Created"],
    files.map(f => [
      dv.fileLink(f.path),
      new Date(f.stat.ctime).toLocaleString()
    ])
  );
})();
```
