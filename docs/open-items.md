# Open items

Things noticed during the build that are not blocking yet, and where they must be resolved.

## DC01 boots with the network profile set to Public

* **Observed:** after a restart, `Get-NetConnectionProfile` on DC01 shows `NetworkCategory: Public` and `IPv4Connectivity: LocalNetwork`. Internet access and DNS work normally.
* **Probable cause:** Network Location Awareness classifies the network early in boot, before Active Directory and DNS (which run on DC01 itself) have started, so it cannot find the domain.
* **What fixed it temporarily:** `Restart-NetAdapter -Name "Ethernet"` after boot gives `DomainAuthenticated`.
* **Delayed start:** `sc.exe config NlaSvc start= delayed-auto` was suggested. It is not confirmed that the command was applied before the test restart, and the profile was Public after that restart, so the result is inconclusive.
* **Why it matters:** Windows Firewall rules from Group Policy apply per profile. Rules set for the Domain profile will not apply to DC01 while it is on Public.
* **Resolve before:** the Group Policy firewall hardening step in Phase 1. Options: apply the DC01 rules to all profiles, or add a startup task that restarts the adapter.

## win11 received the wrong DNS server from the lease (resolved)

* **Observed:** after switching `win11` to DHCP, DNS was `10.0.10.1` (pfSense) instead of `10.0.10.10` (DC01).
* **Cause:** the DNS value typed during the earlier static configuration was left on manual.
* **Fix:** `Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ResetServerAddresses`. `ipconfig /all` then showed DNS `10.0.10.10`.
* **Still to check:** `nslookup lab.internal` from `win11`, before joining the domain.
