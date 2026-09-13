# MediHive — Product context

What this app is, who holds it, and what the backend actually does. Durable
context: it changes when the product changes, not when a screen does.

---

## The product

MediHive is the **phone and tablet companion** to a hospital's operations
platform. The admin console — a web app — is where a hospital is *configured*:
patients are registered, staff accounts are issued, wards are commissioned,
billing is reconciled. This app is where a hospital is *run*, during a shift,
by somebody who is standing up.

That distinction decides almost every scoping question. If a task is done once
a quarter by an administrator sitting at a desk, it belongs in the console. If
it is done forty times a shift by a clinician holding a device in one hand, it
belongs here.

```
com.medihive.app · "MediHive"
```

---

## Who holds it

Three people, and they want different things from the same screens.

**The charge nurse / triage nurse.** The heaviest user. Screens a waiting room,
records observations, puts people on the queue, and watches the board for
anyone deteriorating. Interruptions are constant; they will put the device
down mid-form and pick it up two minutes later. They need the board to answer
"is anyone in trouble" from across a room.

**The clinician (doctor, registrar, consultant).** Uses it between patients and
on a ward round. Wants the queue, the clinic list and the ward round, and wants
to read a screening or a consultation without losing their place in the list.
Reads at arm's length, often in a corridor.

**The receptionist / ward clerk.** Books, checks in, adds to queue, admits and
discharges. Does not make clinical decisions and should never be offered a
control that implies they do.

Nobody in this list has time. Nobody is at a desk. Several of them are sharing
one tablet, which is why handover — sign out, sign in — has to be clean.

---

## The scene

Assume, unless told otherwise:

- **A shared device.** A ward tablet passed between shifts. The next person
  must not see the last person's data. This is why `SessionManager` exists and
  why every permanent controller is registered as user-scoped.
- **A bright corridor or a dim night-shift bay.** Both themes are real usage,
  not a preference. Dark mode is used at 3am by somebody who has been awake
  for fourteen hours.
- **Wifi that drops.** Hospital wifi is not office wifi. Every fetch can fail
  and every failure needs a retry the user can see.
- **Text scaled up.** Ward devices are often left at the largest system text
  size. The app clamps to 1.3 and has to survive it.
- **Gloves, sometimes.** Tap targets are 48 dp, no exceptions.

---

## What it does

| Area | What the app does |
|---|---|
| **Today** | Census, bed occupancy, queue load, clinic list, and anyone flagged critical |
| **Queue** | A live board ordered by acuity then arrival, with wait-time breach flags; call, start, complete, no-show, remove |
| **Clinic** | Today's appointments split into still-to-be-seen and dealt with; a month grid; check in, start, complete, cancel |
| **Pre-triage** | Screenings taken before a patient record exists — identity, complaint, observations — then routed or registered |
| **Inpatient** | Ward capacity, a bed map, admissions, the ward round; admit, transfer, discharge |
| **Consultations** | The record of what happened in a room, paginated |

### What it deliberately does not do

Routed but not built, each with a screen that says where the work happens
today: **pharmacy, laboratory, radiology, billing, staff, integrations**. Their
counts still appear on the dashboard, because the numbers are real even where
the workflow is not in this app yet.

**Patient registration** is the console's job. This app reads the register and
writes screenings that become patient records; it does not maintain the
register.

---

## The backend

An Express API. Every route answers in one envelope:

```json
{ "success": true, "data": { … }, "message": "" }
```

- The payload is under **`data`**. A handful of older handlers still answer
  `result`, and `ApiEnvelope` reads both.
- A **paged** collection nests one level deeper: `data.data` is the rows,
  `data.meta` the page. Reading only one of the two shapes is how a screen
  renders an empty list against a perfectly good 200.
- A 200 with `success: false` is a real thing this backend returns, so
  unwrapping checks the flag and not just the status code.
- Auth is one call: `POST /api/auth/login` returns a bearer token. The token
  has appeared under three different keys over the API's life; `AuthService`
  resolves all three.
- **Authorisation is the server's job.** The app's permission set is a hint
  that lets it avoid offering a button that would come back 403. A screen that
  gates on it must still handle the 403.

### Site settings

A site configures itself through `GET /api/settings`, a flat list of
`{settingKey, settingValue}`. The keys this app reads are named in
`SiteSettings`. Three of them rebuild the theme (`theme_preset`,
`theme_custom_colors`, `theme_font`); the rest change behaviour:

- `wait_breach_minutes` — when the queue board flags a wait. Zero turns it off.
- `show_patient_names` — off where a board is visible from a waiting area, so
  the bed map keeps its shape and loses its identifying column.
- `triage_scale` — which vocabulary a triage picker offers.

A site that has never been configured gets the documented defaults and a
working app. Settings failing to load is not a reason to refuse a sign-in.

---

## Constraints worth stating once

- **No runtime font fetch.** Ten faces are bundled. `google_fonts` downloads on
  first paint of each screen, which is a stutter on a release install.
- **No `BackdropFilter`.** Not one, anywhere. See `.agents/RULES.md` §2.5.
- **Patient identifiers never reach a log.** The interceptor redacts tokens and
  passwords; it does not know what an MRN is.
- **Adult reference ranges only.** `VitalRange` is a triage aid, not a
  diagnosis, and its ranges are adult. A paediatric department needs the
  paediatric chart; the app says so rather than pretending otherwise.
