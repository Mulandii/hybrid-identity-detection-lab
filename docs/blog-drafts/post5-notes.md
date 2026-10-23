# Notes for post 5 (joining WS01 to the domain)

Collect here, then turn into the post once the rename and verification are done.

- DNS pre-check from win11 passed: nslookup lab.internal and dc01.lab.internal, SRV `_ldap._tcp.dc._msdcs.lab.internal`, port 389. Screenshot: `win11-dns-srv-check.png`. `Server: UnKnown` is only the missing reverse lookup zone.
- Combined `Add-Computer -NewName WS01 -DomainName lab.internal` joined the domain, but the rename failed with "The directory service is busy" and no restart ran. Lesson: join and rename as two steps. Do not publish the credential dialog screenshot (password length visible).
- Login screen: "Other user" is needed because domain accounts are not listed until they have logged in. "Sign in to: LAB" shows the join worked.
- `Lab/Administrator` (forward slash) vs `Lab\Administrator` (backslash). Backslash is the DOMAIN\user separator. UPN form `administrator@lab.internal` also works. Case does not matter.
- LAB vs WIN11 before the backslash = the authority that checks the password (domain via DC01, or this PC's local database). Local `WIN11\Administrator` and domain `LAB\Administrator` are separate accounts. After the rename the hint says WS01.
- Screenshots to use: `ws01-login-sign-in-to-lab.png`, `ws01-login-slash-wrong.png`, `ws01-login-backslash-right.png` (blur the password dots), then the rename and verification output.
- Verification screenshot (WS01 and DC01 side by side): `ws01-dc01-domain-verified.png` (sprite covered; the raw one is `ws01-dc01-domain-verified-raw.png`). Shows WS01 lab.internal PartOfDomain True, and Get-ADComputer listing DC01 and WS01 with no WIN11.
- Sign-in with Lab\Administrator: `ws01-login-domain-lab.png`, and after rename `ws01-login-after-rename.png` (this one had only "Administrator" typed, so it points at the local WS01 account).
- Detection tie-in: 4624/4625 logon events, and local vs domain logons look different.

## Manual AD exercise (2026-10-22 and 23), for the blog

Done on DC01 as `LAB\Administrator`; test objects are in a throwaway OU and removed afterwards.

1. Baseline: only `Domain Controllers` OU, and users Administrator, Guest, krbtgt. Screenshot `dc01-ad-baseline-before-ou.png`.
2. Created OU `Lab_test`. Error: missing comma in `Select Name DistinguishedName` (`dc01-select-comma-error.png`).
3. Created user `tuser`. Error: the password was refused, but the account was left behind disabled with no password, so the second attempt said "already exists" (`dc01-new-aduser-password-error.png`). Typo'd property names print blank, not an error. Fixed with `Set-ADAccountPassword` and `Enable-ADAccount` (`dc01-tuser-fixed-enabled.png`).
4. Created group `GG-Test`, added the user (`dc01-group-created-member-added.png`).
5. Logged in as `Lab\tuser` on WS01 (`ws01-first-domain-user-login.png`). Event 4768 read in full: result 0x0, AES256 (0x12), pre-auth type 2, client 10.0.10.100 (`dc01-event-4768-tuser.png`). The 4768 at 5:47:44 in the unfiltered list was NOT tuser: filter by account name before attributing events.
6. **Open question:** `whoami /groups` on WS01 does not list `LAB\Domain Users`, although `PrimaryGroupID` is 513 for both tuser and Administrator (`dc01-primarygroup-and-tuser-events.png`). Plan: delete and recreate tuser cleanly and compare.
7. Edit and move: Department, Title, Description set; user moved from `Lab_test` to `Lab_moved` (`dc01-edit-and-move-user.png`).
8. Delete: protected OU gives "Access is denied" (`dc01-ou-delete-access-denied.png`); after removing protection, error 8332 "child objects exist" (`dc01-ou-delete-child-objects.png`); `-Recursive` removes the OU and its group (`dc01-ou-delete-recursive-confirm.png`).

### Still to do in the exercise
- Break 2: disable the account, read the login error on WS01, re-enable. Events 4725/4722.
- Break 3: check `Get-ADDefaultDomainPasswordPolicy` (expect LockoutThreshold 0), five wrong passwords, events 4771/4625.
- Delete `tuser` (AD Recycle Bin check, what is left of a deleted object), recreate cleanly, re-test `whoami /groups`.
- Then clean up `Lab_moved` and the test objects.

Other notes: Guest Additions installed on DC01 (host ISO from `virtualbox-guest-iso`), clipboard Host to Guest. Check that DC01's time source is still `time.cloudflare.com` afterwards.
