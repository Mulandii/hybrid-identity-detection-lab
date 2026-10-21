# Notes for post 5 (joining WS01 to the domain)

Collect here, then turn into the post once the rename and verification are done.

- DNS pre-check from win11 passed: nslookup lab.internal and dc01.lab.internal, SRV `_ldap._tcp.dc._msdcs.lab.internal`, port 389. Screenshot: `win11-dns-srv-check.png`. `Server: UnKnown` is only the missing reverse lookup zone.
- Combined `Add-Computer -NewName WS01 -DomainName lab.internal` joined the domain, but the rename failed with "The directory service is busy" and no restart ran. Lesson: join and rename as two steps. Do not publish the credential dialog screenshot (password length visible).
- Login screen: "Other user" is needed because domain accounts are not listed until they have logged in. "Sign in to: LAB" shows the join worked.
- `Lab/Administrator` (forward slash) vs `Lab\Administrator` (backslash). Backslash is the DOMAIN\user separator. UPN form `administrator@lab.internal` also works. Case does not matter.
- LAB vs WIN11 before the backslash = the authority that checks the password (domain via DC01, or this PC's local database). Local `WIN11\Administrator` and domain `LAB\Administrator` are separate accounts. After the rename the hint says WS01.
- Screenshots to use: `ws01-login-sign-in-to-lab.png`, `ws01-login-slash-wrong.png`, `ws01-login-backslash-right.png` (blur the password dots), then the rename and verification output.
- Detection tie-in: 4624/4625 logon events, and local vs domain logons look different.
