| **Field**                         | **Value** |
|-----------------------------------|-----------|
| IP Address                        | 10.10.10.161 |
| Hostname (Resolved)               | forest |
| Platform                          | 🪟 Windows |
| NetBIOS / AD Domain               | htb.local |
| DNS Subdomain / FQDN              | FOREST |
| Operating System                  | Windows Server 2016 Standard 14393 |
| Target Network                    | 10.10.10.0/24 |
| Possible / Likely Domain Controller | ✅ Yes |

### 🔹 Set Environment Variables

```sh
export targetIP=10.10.10.161
export targetHost=forest
export DOMAIN=FOREST
export dnsSubDomain=FOREST
export targetNet=10.10.10.0/24
```

### 🔹 Add to /etc/hosts

```sh
10.10.10.161 forest.htb.local forest
```
```

### 🔹 tee to /etc/hosts

```sh
echo 10.10.10.161 forest.htb.local forest | sudo tee -a /etc/hosts
```

### ✅ Key Open Ports & Services for 10.10.10.161
| Port | Protocol | Service | Product/Details |
|------|----------|---------|-----------------|
| 53 | tcp | domain | Simple DNS Plus |
| 88 | tcp | kerberos-sec | Microsoft Windows Kerberos server time: 2025-11-05 18:32:54Z |
| 135 | tcp | msrpc | Microsoft Windows RPC |
| 139 | tcp | netbios-ssn | Microsoft Windows netbios-ssn |
| 389 | tcp | ldap | Microsoft Windows Active Directory LDAP Domain: htb.local, Site: Default-First-Site-Name |
| 445 | tcp | microsoft-ds | Windows Server 2016 Standard 14393 microsoft-ds workgroup: HTB |
| 464 | tcp | kpasswd5 |  |
| 593 | tcp | ncacn_http | Microsoft Windows RPC over HTTP 1.0 |
| 636 | tcp | tcpwrapped |  |
| 3268 | tcp | ldap | Microsoft Windows Active Directory LDAP Domain: htb.local, Site: Default-First-Site-Name |
| 3269 | tcp | tcpwrapped |  |
| 5985 | tcp | http | Microsoft HTTPAPI httpd 2.0 SSDP/UPnP |
| 9389 | tcp | mc-nmf | .NET Message Framing |
| 47001 | tcp | http | Microsoft HTTPAPI httpd 2.0 SSDP/UPnP |
| 49664 | tcp | msrpc | Microsoft Windows RPC |
| 49665 | tcp | msrpc | Microsoft Windows RPC |
| 49666 | tcp | msrpc | Microsoft Windows RPC |
| 49667 | tcp | msrpc | Microsoft Windows RPC |
| 49671 | tcp | msrpc | Microsoft Windows RPC |
| 49676 | tcp | ncacn_http | Microsoft Windows RPC over HTTP 1.0 |
| 49677 | tcp | msrpc | Microsoft Windows RPC |
| 49684 | tcp | msrpc | Microsoft Windows RPC |
| 49706 | tcp | msrpc | Microsoft Windows RPC |
| 49918 | tcp | msrpc | Microsoft Windows RPC |


---


### 🧭 Domain Controller Discovery via SRV Lookup
```sh
Server:		10.10.10.161
Address:	10.10.10.161#53

_ldap._tcp.dc._msdcs.htb.local	service = 0 100 389 FOREST.htb.local.
```

