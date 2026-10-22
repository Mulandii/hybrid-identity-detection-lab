# Open items

Things noticed during the build that are not blocking yet, and where they must be resolved.

## DC01 boots with the network profile set to Public

* **Observed:** after a restart, `Get-NetConnectionProfile` on DC01 shows `NetworkCategory: Public` and `IPv4Connectivity: LocalNetwork`. Internet access and DNS work normally.
* **Background:** the network was first labelled Public because the "discoverable?" prompt was answered No while applying the network settings.
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

## IP forwarding is enabled on the Arch host

* **Observed (2026-10-21):** `sysctl net.ipv4.ip_forward` returns `1`. Docker is installed and running, and enables forwarding.
* **Checked (2026-10-22), IPv4 (blocked):** `iptables -S FORWARD` shows `-P FORWARD DROP`. `DOCKER-USER` is empty. `DOCKER-FORWARD` accepts only from `br-2aa2737ac351` and `docker0`, and jumps to `DOCKER-CT`, `DOCKER-INTERNAL` and `DOCKER-BRIDGE`. Nothing accepts traffic from `vboxnet1`, so forwarded lab traffic hits the DROP policy. The three sub-chains were not read; Docker keys them to its own bridges.
* **Checked, IPv6 (weak control):** `ip6tables -S FORWARD` has `-P FORWARD ACCEPT`, but `net.ipv6.conf.all.forwarding` is `0`, so the kernel does not forward IPv6. If anything turns that setting on (Docker IPv6, a VPN), the lab could reach the real network over IPv6.
* **Optional hardening:** `sudo iptables -I DOCKER-USER -i vboxnet1 -j DROP` and `-o vboxnet1`, plus `sudo ip6tables` equivalents, made persistent. Not applied yet; the IPv4 block does not depend on it.
* **Still to do:** a live test from a lab VM that traffic cannot cross the host to the real network.
* **Do not** set `ip_forward=0`: it would break the Docker containers on this machine.

## Host route to the lab is not persistent

* `sudo ip route add 10.0.10.0/24 via 10.0.66.1` is lost at reboot. Re-added on 2026-10-22. Make it persistent before Phase 2.

## DC01 clock was wrong, fixed by a restart (cause not confirmed)

* **Observed (2026-10-22):** DC01 showed the wrong date and time and the wrong time zone. `w32tm /resync` on DC01 and WS01 reported that the time change was too big.
* **Fixed by:** restarting DC01. The time was correct afterwards. The restart is the only thing known to have changed it.
* **Not known:** why it drifted, and why the restart fixed it. The offset was never measured (`w32tm /stripchart` was not run), the time source was never read (`w32tm /query /source`), and it is not confirmed whether the time zone was corrected.
* **Why it matters:** Kerberos rejects logins when clocks differ by more than 5 minutes, and log timestamps become unreliable. Any events from before the fix have wrong timestamps.
* **To do:** read `w32tm /query /source` and `/query /status`, set the time zone to `E. Africa Standard Time` on DC01 and WS01, point DC01 (the PDC emulator) at an external NTP source, and test UDP 123 with `w32tm /stripchart /computer:time.cloudflare.com /samples:3 /dataonly`. Check whether VirtualBox Guest Additions time sync is also active (`Get-Service VBoxService`), because two sources fight each other.

## DC01 network icon says "no network" and Settings say "managed by your organisation"

* **Observed (2026-10-22):** browsing works, but the network icon shows no network. The Settings app says some changes are managed by the organisation.
* **Probable link:** the earlier finding that `IPv4Connectivity` is `LocalNetwork` while internet and DNS work. NCSI, the check behind the icon, probably fails its probe to `www.msftconnecttest.com`. Not confirmed.
* **Not known:** which policy locks the settings. No Group Policy has been created yet.
* **To do:** run `Get-NetConnectionProfile`, `Resolve-DnsName www.msftconnecttest.com`, an HTTP request to `http://www.msftconnecttest.com/connecttest.txt`, read the NlaSvc probe registry values, and `gpresult /scope computer /r`.
