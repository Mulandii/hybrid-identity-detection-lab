# Notes for post 8 (Group Policy hardening: audit policy first)

Order of events, with the screenshot for each. Keep claims to what was observed.

1. Problem from post 7: DC01 audited Kerberos successes only (`auditpol` showed `Success`), so no 4771 failures.
2. Created GPO `LAB-DC-Audit` with `New-GPO`, linked to Domain Controllers OU with `New-GPLink`: `dc01-gpo-audit-created-linked.png`. Link order was 2 (Default Domain Controllers Policy is 1); later moved to 1 with `Set-GPLink -Order 1`.
3. Edited it in GPMC: `dc01-gpo-audit-edit-menu.png`, `dc01-gpo-audit-policies-editing.png`. Enabled "Audit: Force audit policy subcategory settings...": `dc01-gpo-force-subcategory-override.png`.
4. After `gpupdate /force`, `auditpol` said **No Auditing** for Kerberos: `dc01-gpupdate-auditpol-no-auditing.png`. Explanation: the override makes Windows ignore the old category settings, and the Account Logon subcategories were not set yet. Not the whole story: after setting them (`dc01-gpo-account-logon-audit.png`) every subcategory still said No Auditing.
5. Checked: `gpresult` listed LAB-DC-Audit as applied; `audit.csv` in SYSVOL had all the rows; `GptTmpl.inf` had `SCENoApplyLegacyAuditPolicy=4,1`. But the GPO's `gPCMachineExtensionNames` listed only the security extension, not the audit one: `dc01-gpo-extension-names-missing-audit.png`. A client only runs the extensions a GPO lists.
6. Confirmed the audit extension exists on DC01 (`HKLM\...\Winlogon\GPExtensions\{F3CCC681-...}` = "Audit Policy Configuration", `auditcse.dll`), appended `[{F3CCC681-B74C-4060-9F26-CD84525DCA2A}{0F3F3735-573D-9804-99E4-AB2A69BA5FD4}]` to the attribute, `gpupdate /force`: `auditpol` then showed Success and Failure: `dc01-gpo-audit-extension-fixed.png`.
7. Also fixed in the policy: Non Sensitive Privilege Use was set instead of Sensitive Privilege Use (noisy); old basic "Audit Policy" categories left Not Defined: `dc01-gpo-legacy-audit-not-defined.png`.

Caveats to state in the post:
- Web searches for the extension GUID pair returned nothing; the CSE GUID was verified on DC01, the tool GUID (second in the pair) was not independently confirmed. The fix worked.
- Why GPMC did not register the audit extension on its own is unknown.
- Fallbacks if it had not worked: put the settings in the Default Domain Controllers Policy, or run `auditpol` from a startup script.

Still to do before writing: test that a wrong password now produces event 4771; then lockout/password policy, SMBv1/LLMNR/NBT-NS, firewall GPO, hardened baseline snapshot.
