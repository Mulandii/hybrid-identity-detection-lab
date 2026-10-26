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

* **Update 2026-10-26:** about five hours after DC01's last boot (25 Oct 22:08), `Get-NetConnectionProfile` shows `DomainAuthenticated`, with `IPv4Connectivity LocalNetwork`. Whether the profile is correct *right after a boot* is not re-tested: needs a reboot and a check as soon as the desktop loads.
* **NCSI probes all pass:** `dns.msftncsi.com` resolves to 131.107.255.255, `www.msftconnecttest.com` resolves, and the HTTP probe returns "Microsoft Connect Test". The `LocalNetwork` label (and the "no network" icon) is therefore unexplained. It does not affect AD, DNS or DHCP.
* **Decision:** apply the Windows Firewall rules for DC01 to all profiles, so the policy does not depend on the profile name.

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

## DC01 clock was wrong, fixed by a restart (resolved; cause not confirmed)

* **Observed (2026-10-22):** DC01 showed the wrong date and time and the wrong time zone. `w32tm /resync` on DC01 and WS01 reported that the time change was too big.
* **Fixed by:** restarting DC01. The time was correct afterwards. The restart is the only thing known to have changed it.
* **Not known:** why it drifted, and why the restart fixed it. The offset was never measured (`w32tm /stripchart` was not run), the time source was never read (`w32tm /query /source`), and it is not confirmed whether the time zone was corrected.
* **Why it matters:** Kerberos rejects logins when clocks differ by more than 5 minutes, and log timestamps become unreliable. Any events from before the fix have wrong timestamps.
* **Verified 2026-10-23:** DC01 syncs from `time.cloudflare.com` (stratum 4, source IP 162.159.200.1, poll 128 s), so UDP 123 works through pfSense. Time zone is `E. Africa Standard Time`. WS01's `w32tm /query /source` returns `DC01.lab.internal` and `w32tm /resync` completes. The Settings app greys out the time controls with "managed by your organization"; the cause is not confirmed (see below).
* **Still unknown:** why it drifted, and whether VirtualBox Guest Additions also adjusts the clock (`Get-Service VBoxService` not run). Watch for a repeat.
* **Original to-do (done, kept for the record):** read `w32tm /query /source` and `/query /status`, set the time zone to `E. Africa Standard Time` on DC01 and WS01, point DC01 (the PDC emulator) at an external NTP source, and test UDP 123 with `w32tm /stripchart /computer:time.cloudflare.com /samples:3 /dataonly`. Check whether VirtualBox Guest Additions time sync is also active (`Get-Service VBoxService`), because two sources fight each other.

## DC01 network icon says "no network" and Settings say "managed by your organisation"

* **Observed (2026-10-22):** browsing works, but the network icon shows no network. The Settings app says some changes are managed by the organisation.
* **Probable link:** the earlier finding that `IPv4Connectivity` is `LocalNetwork` while internet and DNS work. NCSI, the check behind the icon, probably fails its probe to `www.msftconnecttest.com`. Not confirmed.
* **Not known:** which policy locks the settings. No Group Policy has been created yet.
* **Checked 2026-10-23:** `gpresult /scope computer /r` on DC01 lists only `Default Domain Controllers Policy` and `Default Domain Policy`; Local Group Policy is empty. So no custom policy causes the "managed by your organization" message. It is probably Windows' own behaviour on a domain controller, but that is not confirmed.
* **To do:** run `Get-NetConnectionProfile`, `Resolve-DnsName www.msftconnecttest.com`, an HTTP request to `http://www.msftconnecttest.com/connecttest.txt`, read the NlaSvc probe registry values, and `gpresult /scope computer /r`.

## DC01 does not audit failed Kerberos logons (to fix in Group Policy)

* **Checked 2026-10-25:** `auditpol /get /subcategory:"Kerberos Authentication Service"` returns `Success` only. No event 4771 exists in DC01's Security log, and none of the wrong-password or disabled-account attempts from WS01 produced an event on DC01.
* **What is recorded instead:** WS01 logs its own failed interactive logons as 4625 (logon type 2, sub status 0xC000006A for a wrong password).
* **Fix:** in the audit policy GPO, set Kerberos Authentication Service to Success and Failure, plus the related Account Logon and Logon/Logoff subcategories. Needed before the Phase 2 password-guessing detections.
* **Related:** domain `LockoutThreshold` is 0 and `MinPasswordLength` is 7. Set a lockout threshold in the same GPO step.

## Recurring time-skew failures from WS01 (to verify)

* **Observed:** DC01 logged 4625 with Status `0xC0000133`, logon type 3, Kerberos, source 10.0.10.100 (WS01) at 2026-10-21 14:44:58, 2026-10-21 15:29:42 (twice), 2026-10-23 05:47:44 and 2026-10-25 23:00:43. No account name in any of them. The three from 21 October predate the domain join (early 22 October by VirtualBox's host-clock snapshot times), which is unexplained; DC01's clock was also unreliable around then.
* **Verified:** the status is `STATUS_TIME_DIFFERENCE_AT_DC` (Kerberos clock skew, more than 5 minutes). `net helpmsg 1398` prints "There is a time and/or date difference between the client and server." Which of the two clocks was wrong is not known.
* **To do:** measure WS01's offset (`w32tm /stripchart /computer:dc01.lab.internal /samples:3 /dataonly`), and find out whether VirtualBox Guest Additions time sync on WS01 competes with the domain time, or whether the VM is being paused or resumed.

## `LAB\Domain Users` missing from login tokens (unexplained, parked)

* **Observed 2026-10-22 to 2026-10-26:** `whoami /groups` as `tuser` on WS01 never lists `LAB\Domain Users`, for the original account and for a clean recreated one (SID ending 1107). The group `GG-Recover`/`GG-Test` does appear.
* **Directory side is correct:** `PrimaryGroupID` is 513, and `net user tuser /domain` on WS01 lists `*Domain Users` under Global Group memberships.
* **Administrator:** a `whoami /groups | findstr /i "Domain"` shows `LAB\Domain Admins` but not `LAB\Domain Users`. Which machine that was run on is not confirmed.
* **Not known:** where the group disappears, and whether it is the same on DC01 and WS01.
* **To do:** run `whoami /groups | findstr /i "Domain"` as Administrator on both DC01 and WS01 and compare.

## Audit policy GPO needed a manual extension registration (fixed 2026-10-26)

* `LAB-DC-Audit` applied and its `audit.csv` was correct, but `auditpol` stayed at `No Auditing` because the GPO's `gPCMachineExtensionNames` did not list the audit extension.
* **Fix:** appended `[{F3CCC681-B74C-4060-9F26-CD84525DCA2A}{0F3F3735-573D-9804-99E4-AB2A69BA5FD4}]` with `Set-ADObject`, then `gpupdate /force`. `auditpol` then showed Success and Failure for Kerberos Authentication Service.
* **Not known:** why GPMC did not register the extension itself. The tool GUID in the pair was not independently confirmed (the extension GUID was, on DC01). Expect the same for any new GPO with audit settings.
* **Still to test:** that a wrong password now produces event 4771.
