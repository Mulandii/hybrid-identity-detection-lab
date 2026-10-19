# Hybrid Identity Detection Lab

A segmented Active Directory lab that is built, hardened, attacked, monitored and investigated, then extended into Microsoft Entra ID and Microsoft Sentinel.

Identity attacks are the thread through the whole project: password spraying, Kerberoasting, AS-REP roasting and BloodHound enumeration are performed against the lab, detected with Wazuh, Sigma and KQL rules, mapped to MITRE ATT&CK, and investigated as a forensic case.

## Status

| Phase | Description | Status |
|---|---|---|
| 0 | Setup, network design, repo | In progress |
| 1 | Build and harden the domain | Not started |
| 2 | Log, attack and detect | Not started |
| 3 | DFIR investigation of the compromised DC | Not started |
| 4 | Microsoft Sentinel and KQL | Not started |
| 5 | Entra ID hybrid identity | Not started |

## Architecture

Two network zones with a pfSense firewall between them. See [docs/network-design.md](docs/network-design.md) for the full design and rationale.

| Host | Address | Role |
|---|---|---|
| fw01 (pfSense) | 10.0.10.1 / 10.0.66.1 | Routing, NAT, firewall, logs |
| dc01 (Windows Server) | 10.0.10.10 | AD DS, DNS, DHCP |
| ws01 (Windows 10/11) | DHCP 10.0.10.100-200 | Domain-joined client |
| Arch Linux host | 10.0.66.2 | Attacker |

## Repository layout

| Folder | Contents |
|---|---|
| `docs/` | Design documents and phase notes |
| `docs/screenshots/` | Evidence screenshots |
| `scripts/` | PowerShell and Python scripts |
| `detections/` | Wazuh, Sigma and KQL rules |
| `logs/` | Sanitized sample logs |
| `reports/` | Incident and investigation reports |

## Safety

All attacks run only inside this isolated lab. No bridged adapters, evaluation licences only, and a dedicated test tenant for Entra ID. Snapshots are taken before every major change and every attack.
