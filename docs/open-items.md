# Open items

Things noticed during the build that are not blocking yet, and where they must be resolved.

## DC01 boots with the network profile set to Public

* **Observed:** after a restart, `Get-NetConnectionProfile` on DC01 shows `NetworkCategory: Public` and `IPv4Connectivity: LocalNetwork`. Internet access and DNS work normally.
* **Probable cause:** Network Location Awareness classifies the network early in boot, before Active Directory and DNS (which run on DC01 itself) have started, so it cannot find the domain.
* **What fixed it temporarily:** `Restart-NetAdapter -Name "Ethernet"` after boot gives `DomainAuthenticated`.
* **Tried:** `sc.exe config NlaSvc start= delayed-auto`. The profile was still Public after a restart.
* **Why it matters:** Windows Firewall rules from Group Policy apply per profile. Rules set for the Domain profile will not apply to DC01 while it is on Public.
* **Resolve before:** the Group Policy firewall hardening step in Phase 1. Options: apply the DC01 rules to all profiles, or add a startup task that restarts the adapter.
