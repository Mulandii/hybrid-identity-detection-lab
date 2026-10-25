#!/usr/bin/env python3
"""Generate the lab user list (scripts/data/users.csv).

The list is deterministic: the same seed always gives the same 150 people, so the
lab can be rebuilt identically. No passwords are written here. The creation script
generates random passwords on the domain controller.

Usage: python3 scripts/generate-users.py
"""
import csv
import random
from pathlib import Path

SEED = 20261026
DOMAIN = "lab.internal"
OUT = Path(__file__).parent / "data" / "users.csv"

# Users per department. The total is 150.
DEPARTMENTS = {"IT": 20, "HR": 15, "Finance": 25, "Sales": 45, "Operations": 45}

TITLES = {
    "IT": ["Systems Administrator", "Help Desk Technician", "Network Engineer",
           "Security Analyst", "Software Developer", "Database Administrator"],
    "HR": ["HR Officer", "Recruiter", "Payroll Clerk", "Training Coordinator"],
    "Finance": ["Accountant", "Accounts Clerk", "Finance Analyst", "Credit Controller",
                "Auditor"],
    "Sales": ["Sales Executive", "Account Manager", "Sales Representative",
              "Business Development Officer", "Customer Success Officer"],
    "Operations": ["Operations Officer", "Logistics Coordinator", "Warehouse Supervisor",
                   "Procurement Officer", "Facilities Officer", "Quality Inspector"],
}

FIRST_NAMES = [
    "Wanjiru", "Kamau", "Achieng", "Otieno", "Njeri", "Mwangi", "Akinyi", "Odhiambo",
    "Wambui", "Kipchoge", "Chebet", "Kiprop", "Amina", "Hassan", "Fatuma", "Juma",
    "Mercy", "Brian", "Faith", "Kevin", "Grace", "Dennis", "Esther", "Peter", "Lucy",
    "Samuel", "Naomi", "Joseph", "Halima", "Ali", "Janet", "Victor", "Mary", "Daniel",
    "Rose", "Collins", "Beatrice", "Felix", "Irene", "George", "Caroline", "Stephen",
    "Joyce", "Patrick", "Sharon", "Moses", "Lilian", "Isaac", "Purity", "Eric",
    "Nancy", "Allan", "Winnie", "Martin", "Cynthia", "Simon", "Rehema", "Elijah",
    "Hellen", "Kelvin", "Salma", "Anthony", "Doreen", "Vincent", "Zainab", "Ibrahim",
    "Diana", "Mark", "Susan", "Hamisi", "Tabitha", "Cyrus", "Maureen", "Abdi",
]

LAST_NAMES = [
    "Kamau", "Otieno", "Mwangi", "Njoroge", "Wafula", "Kiptoo", "Mutua", "Omondi",
    "Karanja", "Cheruiyot", "Kariuki", "Nyongesa", "Abdi", "Ochieng", "Maina", "Wekesa",
    "Kimani", "Macharia", "Wanjala", "Kibet", "Muriuki", "Onyango", "Gitau", "Rotich",
    "Mohamed", "Barasa", "Koech", "Nyambura", "Waweru", "Atieno", "Chepkoech", "Mbugua",
    "Ndungu", "Okello", "Salim", "Wangari", "Kigen", "Langat", "Mutiso", "Owino",
    "Wambua", "Njuguna", "Adhiambo", "Kyalo", "Simiyu", "Bett", "Mburu", "Musyoka",
]

# People who must be in the lab. They are placed first in their department.
# (department, first name, last name)
REQUIRED = [
    ("IT", "Baraka", "Mulandi"),
    ("Finance", "Lisa", "Otieno"),
    ("Sales", "Charlotte", "Kamau"),
    ("Operations", "Zawadi", "Mwangi"),
]

ADMIN_COUNT = 5  # the first N people in IT also get a separate admin account


def make_people(rng):
    used = {(f, l) for _, f, l in REQUIRED}
    people = {d: [] for d in DEPARTMENTS}
    for dept, first, last in REQUIRED:
        people[dept].append((first, last))
    for dept, total in DEPARTMENTS.items():
        while len(people[dept]) < total:
            pair = (rng.choice(FIRST_NAMES), rng.choice(LAST_NAMES))
            if pair in used:
                continue
            used.add(pair)
            people[dept].append(pair)
    return people


def interleave(people):
    """Order the rows so that any prefix has a proportional mix of departments."""
    total = sum(len(v) for v in people.values())
    emitted = {d: 0 for d in people}
    order = []
    for i in range(total):
        best = max(people, key=lambda d: len(people[d]) * (i + 1) / total - emitted[d])
        order.append((best, people[best][emitted[best]]))
        emitted[best] += 1
    return order


def sam_account(first, last, taken):
    base = f"{first}.{last}".lower()[:20]
    sam, n = base, 1
    while sam in taken:
        n += 1
        suffix = str(n)
        sam = base[: 20 - len(suffix)] + suffix
    taken.add(sam)
    return sam


def main():
    rng = random.Random(SEED)
    people = make_people(rng)
    taken = set()
    rows = []
    it_seen = 0
    for dept, (first, last) in interleave(people):
        is_admin = False
        if dept == "IT":
            it_seen += 1
            is_admin = it_seen <= ADMIN_COUNT
        title = "Systems Administrator" if (first, last) == ("Baraka", "Mulandi") \
            else rng.choice(TITLES[dept])
        sam = sam_account(first, last, taken)
        rows.append({
            "GivenName": first,
            "Surname": last,
            "DisplayName": f"{first} {last}",
            "SamAccountName": sam,
            "UserPrincipalName": f"{sam}@{DOMAIN}",
            "Department": dept,
            "Title": title,
            "IsAdmin": "Yes" if is_admin else "No",
        })

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="ascii") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator="\r\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} users to {OUT}")


if __name__ == "__main__":
    main()
