# MediHive — AI patient case taking tracker

The running record for the **patient-facing case-taking feature**: a patient signs
in as themselves, tells their medical story by voice, text or touch, uploads their
old prescriptions, verifies what MediHive understood, and submits a structured,
source-attributed case into the existing clinical workflow.

`docs/PARITY_TRACKER.md` owns the HMS parity work and stays as history. This file
owns everything from 2026-09-14 onward for this feature only.

**Plan** · `~/.claude/plans/impeccable-medihive-patient-dashboard-a-spicy-rainbow.md`

**Specifications** — these are the authority on intent, not this file:
`MediHive_Patient_Dashboard_AI_Case_Taking.md` ·
`MediHive_Patient_Dashboard_Medical_Document_Intelligence.md`

**Branches** · both repos are on `main`. The parity branches were fast-forwarded
into `main` on 2026-09-14 (mobile 65 commits, backend 6, both clean) and work
continues there. `ai-sidecar/` is a new tree versioned with the backend.

Legend: ✅ done · 🔄 in progress · ⬜ not started · ⛔ blocked · ⏭ deferred

**A row is ✅ only when all of its gates pass.**

| Side | Gate |
|---|---|
| Mobile | `flutter analyze` zero · `flutter test test/` · `dart run tool/check_keys.dart` · the module's flow test · a reviewed screenshot round · a live check against the real API |
| Backend | `npm run lint` · `npm run build` · `npm test` · the module's `test/verify-*.ts` against the live API |
| Sidecar | `/health` reports the capability true · a real round-trip through it |

---

## Progress

| Phase | Scope | Size | Status |
|---|---|---|---|
| [P0](#p0--environment) | Ollama, gemma3:4b, Python sidecar, API, device | M | ✅ |
| [P1](#p1--patient-identity-and-self-login) | `Patient`↔`User`, MRN+DOB claim, self-scoping guard | L | ✅ |
| [P2](#p2--case-taking-domain-and-engine) | Schema, tri-state, question selector, safety rules | XL | 🔄 live tier |
| [P3](#p3--ai-module-and-sidecar-wiring) | `LlmProvider`, prompts, sidecar client, degradation | L | 🔄 live tier |
| [P4](#p4--medical-document-intelligence) | Upload, OCR, classify, extract, presigned reads | XL | 🔄 live tier |
| [P5](#p5--flutter-foundations) | Media seams, conversation kit, permissions, language seam | L | ✅ |
| [P6](#p6--patient-shell-and-entry) | Patient shell, claim/activate, language, consent | M | ✅ |
| [P7](#p7--the-interview) | Adaptive interview by voice, text and touch | XL | 🔄 |
| [P8](#p8--documents-on-the-phone) | Capture, upload, review extraction, correct | L | ⬜ |
| [P9](#p9--review-submit-handoff) | Verification, submission, doctor handoff | L | ⬜ |
| [P10](#p10--languages) | Tamil and Hindi — **deliberately last** | M | ⬜ |

Sizes: S ≤ ½ day · M 1 day · L 2–3 days · XL 4+ days.

### Where it stands

| | |
|---|---|
| Backend | **760** unit tests green, 46 suites · lint and build clean |
| Live contract | **39 checks** on `verify-patient-auth.ts`; case-taking and documents still to come |
| Mobile | **399** unit tests · analyze zero · 4 unkeyed (baseline 4) |
| Device | **9 portal flows green on a real vivo I2219, Android 16** — no emulator, no host RAM |
| Database | 7 new tables applied and verified in `hms_v2_dev` |
| Models | `gemma3:4b` serving · faster-whisper, Piper and PP-OCRv5 all answering |
| Routes | case-taking, patient-documents and patient-auth all mounted and guarded |
| Commits | 6 on `hms_v2/main`, 5 on `medihive/main` |

---

## P0 · Environment

Nothing downstream can be verified until the models actually answer.

| # | Task | Status | Notes |
|---|---|---|---|
| 0.1 | Ollama installed | ✅ | to `~/.local/ollama`, **without root** — the install script needs sudo and this box prompts for a password |
| 0.2 | `gemma3:4b` pulled and serving | ✅ | 3.3 GB; the release asset is `.tar.zst` now, not the `.tgz` the docs still name |
| 0.3 | Python sidecar venv on **3.12** | ✅ | never the host's 3.14 — `paddlepaddle` publishes no wheel for it, which is why OCR is RapidOCR |
| 0.4 | `ai-sidecar/` — FastAPI on loopback `:8801` | ✅ | `/health`, `/stt`, `/tts`, `/ocr` |
| 0.5 | OCR — RapidOCR / PP-OCRv5 ONNX | ✅ | `/health` reports `ocr: true` |
| 0.6 | STT — faster-whisper, pinned to CPU | ✅ | the GPU is holding gemma; see the ledger |
| 0.7 | TTS — Piper + `en_US-lessac-medium` | ✅ | real WAV round-trip, 16-bit mono 22050 Hz |
| 0.8 | Backend running against local Postgres | ✅ | startup log confirmed `localhost:5432/hms_v2_dev` before anything destructive ran |
| 0.9 | Containers — postgres, redis, minio | ✅ | already up |
| 0.10 | A device for the device tier | ✅ | **a physical vivo I2219 on Android 16 (`10BF3E014J007KU`)**, not an emulator. The user's own phone, and it costs the host no RAM — which matters on a box whose IDE alone holds 3.4 GB. `Pixel_6_Pro_API_36` remains available but is no longer the gate |
| 0.11 | Tamil/Hindi Piper voices | ⏭ | P10 |

### Measured on this box, 2026-09-14

The numbers the UX has to be designed around, not guessed at.

| Path | Warm | Note |
|---|---|---|
| STT, 3.3 s of speech | **1.1 s** | faster-whisper `small`, CPU |
| STT, 10.3 s of speech | **1.45 s** | ~7× realtime; not the bottleneck |
| TTS, one question | ~1 s | Piper, 22050 Hz mono |
| LLM extraction, short answer | **~8 s** | gemma3:4b, 38% GPU offload |
| LLM extraction, long answer | **~20 s** | ~10–20 tok/s |
| LLM cold load | 74 s | first call after idle eviction |

**Voice in is cheap; the model is the whole cost.** A full round trip through
Piper and back through Whisper returned the sentence verbatim at 0.84
confidence, so the pipeline is sound. What this means for P7: the microphone can
be conversational, and the next question — which comes from the deterministic
selector, not the model — renders immediately. Only extraction is slow, and it
is the one thing the patient never waits on.

---

## P1 · Patient identity and self-login

The blocker. `PATIENT` was in the role enum from the beginning, but a
patient-role user could not resolve *which* patient they were, so nothing
patient-scoped was enforceable.

| # | Task | Status | Notes |
|---|---|---|---|
| 1.1 | `Patient.userId` unique + relation to `User` | ✅ | one record is one person |
| 1.2 | `PatientPortalClaim` table | ✅ | a row per attempt, successes and failures |
| 1.3 | Migration `20260914170000_add_patient_portal_identity` | ✅ | hand-annotated, no backfill needed |
| 1.4 | `patientId` in `JwtPayload` + `AuthenticatedUser` | ✅ | resolved inside `generateTokenPair`, so login and refresh cannot disagree |
| 1.5 | `JwtStrategy` merges it over a cache hit | ✅ | the 5-minute `auth:user` entry can predate the link |
| 1.6 | `PatientSelfGuard` + `@PatientScope()` | ✅ | **discards** the requested id rather than comparing it — comparing makes 403-vs-404 an existence oracle |
| 1.7 | `POST /patient-auth/claim` | ✅ | public, throttled; identical response whether or not the MRN exists |
| 1.8 | `POST /patient-auth/activate` | ✅ | user-create + link + consume in one transaction, both writes conditional |
| 1.9 | `GET /patient-auth/me` | ✅ | behind the guard |
| 1.10 | Permissions + error codes | ✅ | 6 permissions, 7 error codes, append-only |
| 1.11 | Seed links `patient@hms.local` | ✅ | `MRN-PORTAL-0001`, DOB 1990-05-17 |
| 1.12 | `patient-auth.service.spec.ts` | ✅ | 22 new unit tests |
| 1.13 | `test/verify-patient-auth.ts` | ✅ | **39/39** against the live API |

---

## P2 · Case-taking domain and engine

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | `CaseSession`, `CaseTurn`, `CaseFact`, `CaseRedFlag`, `PatientDocument`, `CaseSubmission` | ✅ | verified in Postgres |
| 2.2 | Migration `20260914180000_add_case_taking` | ✅ | `Json` not `String`, argued in the file |
| 2.3 | `CaseFact` append-only with `supersededById` | ✅ | a correction writes a row, never edits one |
| 2.4 | `CaseFact.presence` NOT NULL, **no default** | ✅ | the database refuses a silent "no" |
| 2.5 | `engine/tri-state.ts` | ✅ | six states, collapse structurally impossible |
| 2.6 | `engine/clinical-state.ts` | ✅ | immutable; per-section completion |
| 2.7 | `engine/field-registry.ts` | ✅ | `diagnosis` is deliberately **not** a field |
| 2.8 | `engine/question-selector.ts` | ✅ | pure, synchronous, on the hot path |
| 2.9 | `engine/safety-rules.ts` + `safety-engine.ts` | ✅ | rules as versioned data, never prompt text |
| 2.10 | `engine/case-renderer.ts` | ✅ | throws rather than print a non-`recorded` value |
| 2.11 | `derivePresence()` — code owns presence, not the model | ✅ | see ledger #1 |
| 2.12 | Module, controller, service, repository, DTOs | ⬜ | |
| 2.13 | Endpoint surface under `/api/case-taking` | ⬜ | |
| 2.14 | `test/verify-case-taking.ts` | ⬜ | |

---

## P3 · AI module and sidecar wiring

| # | Task | Status | Notes |
|---|---|---|---|
| 3.1 | Sidecar built and answering | ✅ | P0.4–0.7 |
| 3.2 | `src/modules/ai/` — `LlmProvider` + `OllamaProvider` | ⬜ | the only place that knows an LLM exists |
| 3.3 | Schema-constrained output via Ollama `format` | ⬜ | **proven working** against the real model |
| 3.4 | `presence` removed from every LLM schema | ⬜ | ledger #1 |
| 3.5 | Registry allow-list on returned `fieldPath` | ⬜ | discard, never store |
| 3.6 | Per-field-kind value validation | ⬜ | ledger #2 |
| 3.7 | Medication names via `fuzzyset.js`, never normalised into a guess | ⬜ | already a dependency |
| 3.8 | JSON repair → deterministic fallback question | ⬜ | the interview never dies on a bad turn |
| 3.9 | `SidecarClient` with timeout + circuit breaker | ⬜ | |
| 3.10 | Degradation paths written and tested | ⬜ | sidecar down, Ollama down |
| 3.11 | Prompts as versioned constants, pinned by specs | ⬜ | |
| 3.12 | Env in `validation.schema.ts`, optional with defaults | ⬜ | a box with no Ollama still boots |

---

## P4 · Medical document intelligence

| # | Task | Status | Notes |
|---|---|---|---|
| 4.1 | `POST /api/patient-documents` multipart, field `file` | ⬜ | the shape the mobile client already posts |
| 4.2 | **Presigned reads** on `ObjectStorageService` | ⬜ | only `PutObject` exists today; the bucket is private, so a patient cannot see their own evidence |
| 4.3 | Quality check before OCR, with a written retake | ⬜ | never `PP-OCR inference exception` on screen |
| 4.4 | OCR → classify → extract → validate → confidence | ⬜ | lands as *pending verification*, never auto-merged |
| 4.5 | Duplicate detection: sha256, then text similarity | ⬜ | |
| 4.6 | Vision fallback on low OCR confidence | ⬜ | same `gemma3:4b` — it is multimodal |
| 4.7 | "Not found" never becomes "no" | ⬜ | documents spec §19 |
| 4.8 | `test/verify-patient-documents.ts` | ⬜ | a real prescription image |

---

## P5 · Flutter foundations

| # | Task | Status | Notes |
|---|---|---|---|
| 5.1 | `audio_source.dart` + `StubAudioSource` | ✅ | spelled like the two seams already here |
| 5.2 | `RecordAudioSource` — PCM in memory, wrapped at the end | ✅ | a patient's voice never lands on a shared tablet's disk |
| 5.3 | `ImagePickerImageSource`, `FilePickerFileSource` | ✅ | `image_picker` collides on **two** names, not the one its comment warned about |
| 5.4 | `media_access.dart` — one permission call site | ✅ | a refusal is never a null |
| 5.5 | Android + iOS manifests | ✅ | usage strings written in the patient's voice |
| 5.6 | `app_bento_conversation.dart`, exported from the barrel | ✅ | 12 components; patient density |
| 5.7 | `UnknownAnswerRow` — four equal tiles | ✅ | four different clinical facts, not two and two |
| 5.8 | `RedFlagNotice` cannot state a diagnosis | ✅ | structural: the only free text is the patient's own quoted words |
| 5.9 | `PatientText` language seam | ✅ | English only; placeholders substituted after lookup |
| 5.10 | `test/one_blur_test.dart` | ✅ | ledger #3 — the ratchet the codebase believed it had |
| 5.11 | 43 new unit tests | ✅ | 395 total |

---

## P6 · Patient shell and entry

| # | Task | Status | Notes |
|---|---|---|---|
| 6.1 | `patient_portal/` module tree + route table | ✅ | per-module style, one `...PatientPages.routes,` line |
| 6.2 | Role-shaped landing: a PATIENT never sees the staff shell | ✅ | from `access.modules`, never the role name — RULES §0.1. A deep link to the staff shell lands on the portal instead, and that is a test |
| 6.3 | Patient dashboard | ✅ | shows this patient's appointments and no others |
| 6.4 | Claim / activate screens | ✅ | the copy cannot say "that card was not recognised" — claim answers identically either way, so the app genuinely does not know. It says what to do next instead |
| 6.5 | Language screen | ✅ | English only until P10; the choice is carried on the session from day one |
| 6.6 | Consent screen | ✅ | what is collected, who reads it, that it is not a diagnosis, that they can stop. Declining leaves the patient on their own screen rather than stranding them |
| 6.7 | Robot + fixtures + flow test | ✅ | **9 flows green on the physical device** |

---

## P7 · The interview

| # | Task | Status | Notes |
|---|---|---|---|
| 7.1 | `CaseTakingController` with `LoadStateMixin`, `UnsavedChanges` | ⬜ | `onReady`, never `onInit`; never name a method `refresh()` |
| 7.2 | Server session is the source of truth | ⬜ | secure-storage write-behind for dropped wifi, never `shared_preferences` — this is PHI |
| 7.3 | Every question answerable three ways | ⬜ | voice is never required |
| 7.4 | Next question renders instantly from the selector | ⬜ | extraction runs behind it — ledger #4 |
| 7.5 | `SessionLockService` pinged on interaction | ⬜ | or a long interview locks mid-sentence |
| 7.6 | Red flag mid-interview | ⬜ | plain words, no diagnosis |
| 7.7 | Progress, resume, section completion | ⬜ | read from server state |
| 7.8 | Flow tests — the cases in the plan, not the happy path | ⬜ | |

---

## P8 · Documents on the phone

| # | Task | Status | Notes |
|---|---|---|---|
| 8.1 | Capture or pick → quality check → upload with progress | ⬜ | reuses `CrudRepository.upload` verbatim |
| 8.2 | Size pre-check with a written refusal | ⬜ | the integrations controller is the precedent |
| 8.3 | Review extracted information | ⬜ | confirm / correct / not sure |
| 8.4 | Source and confidence on every value | ⬜ | unconfirmed never styled like confirmed |
| 8.5 | Original one tap away | ⬜ | needs P4.2 |

---

## P9 · Review, submit, handoff

| # | Task | Status | Notes |
|---|---|---|---|
| 9.1 | "Here is what we understood about you" | ⬜ | section by section, each item correctable |
| 9.2 | Read aloud via the sidecar | ⬜ | |
| 9.3 | Contradictions surfaced, never resolved automatically | ⬜ | |
| 9.4 | Submit → structured case on the patient record | ⬜ | mirrors `POST /pre-triage/:id/convert` |
| 9.5 | Doctor sees provenance per item | ⬜ | patient-stated, document-extracted, unverified, corrected |
| 9.6 | Screenshot round, light and dark, again at 1.3× | ⬜ | |

---

## P10 · Languages

**Deliberately last.** Started only once P0–P9 are green.

| # | Task | Status | Notes |
|---|---|---|---|
| 10.1 | `patient_translations.dart`, `PatientText` becomes a lookup | ⬜ | no call-site changes |
| 10.2 | `translations:` / `locale:` / `fallbackLocale:` on `GetMaterialApp` | ⬜ | staff screens untouched |
| 10.3 | Tamil and Hindi unlocked | ⬜ | |
| 10.4 | Tamil/Hindi STT + TTS benchmarked before voice is promised | ⬜ | text and touch must stay sufficient |
| 10.5 | Store the original utterance **and** its English rendering | ⬜ | so doctor and auditor see the same evidence |

---

## Decisions

| Decision | Why |
|---|---|
| Patient self-login, not a staff-launched kiosk | The patient holds their own phone. Cost: a real migration and guard, which P1 paid |
| Nest proxies Ollama; the app never calls a model | Prompts, schema and safety stay server-side and auditable, and it works on any phone |
| RapidOCR on onnxruntime, not PaddleOCR | Same PP-OCRv5 models; `paddlepaddle` has no wheel for this box's Python |
| The sidecar is a separate process | Python model runtimes with their own interpreter and their own ways of wedging. A wedged model must not take the hospital API down |
| `Json` columns for case data, breaking the codebase habit | A `String` column accepts malformed JSON silently, and this is a history a doctor reads |
| `CaseFact` append-only | Provenance is the feature. A correction that overwrites loses the disagreement that mattered |
| Code owns `presence`, the model never sets it | Ledger #1 — the model collapsed the tri-state on its first real probe |
| Translation last | Explicit instruction. The seams in P5 keep the later phase small |

---

## Ledger — what this build has found

| # | Finding | Why it matters | Status |
|---|---|---|---|
| 1 | **`gemma3:4b` collapsed the tri-state.** Given "I don't know if I'm allergic to anything" it returned `allergies.known` as `presence: recorded, value: "unknown"` | An "I don't know" encoded as a fact the patient *told* us. This is the exact path to a fabricated "no known allergies" | ✅ `presence` removed from every LLM schema; code derives it |
| 2 | The model slot-fills eagerly and wrongly — `hpi.radiation: "when I walk"`, which is an aggravating factor | Plausible garbage in a clinical field is worse than an empty one | ✅ `validateFieldValue` rejects it while still accepting "down my left arm when I walk"; a failed value leaves the field `not_assessed` so it is re-asked |
| 3 | Self-reported confidence was a constant `0.95` on every fact | It is not a signal. Anything gating on it is gating on nothing | ✅ never used for safety; derived from STT + validation instead |
| 4 | **`gemma3:4b` gets only 38% GPU offload** — 3.8 GB against 4 GB VRAM, because it loads a CLIP encoder. `num_ctx` does not help | ~10–20 tok/s: 8 s for a short extraction, 20 s for a long one, 74 s cold | ✅ architecture already answers it: the selector renders the next question, extraction runs behind |
| 5 | **`test/one_blur_test.dart` did not exist.** `app_bento.dart` has cited it for months | An absolute stated in DESIGN.md, RULES.md and the source, enforced nowhere | ✅ written; the true count is **zero**, not one — the tab bar gave up its blur and the comment never noticed |
| 6 | **Schema drift**: migration `20260914120000` created the queue's `priorityRank` index in raw SQL without declaring it in the model | Every `migrate diff` since has proposed **dropping** the index the board sorts on. It was in the first generated migration of this feature | ✅ declared in `QueueManagement` |
| 7 | **The lint gate was not green.** 21 errors in three files | Invisible because `lint-staged` only lints files a commit touches | ✅ fixed |
| 8 | Four `no-unsafe-argument` warnings in `appointments.service.spec.ts` had never been linted | Surfaced the moment this work touched the file; pre-commit runs `--max-warnings 0` | ✅ disabled with the reason stated |
| 9 | Express 5's `req.query` is a getter that re-parses on every access | A guard **cannot** neutralise a query-supplied id — the write lands on a throwaway object and `ValidationPipe` still sees the original | ✅ authority is `@PatientScope()`, not the DTO |
| 10 | `POST /patient-auth/claim` is unauthenticated, so there is no tenant | Resolving an org from the body would be a tenant-hopping vector | ✅ oldest org, resolved unconditionally. **Bakes in one hospital per deployment** — see follow-ups |
| 11 | `BaseRepository`'s reads inject `isDeleted: false`, which `PatientPortalClaim` lacks | Calling `findOne`/`paginate` on it is a Prisma validation error, not an empty result | ✅ documented; only `create`/`update` used |
| 12 | `MicState.working` used a `CircularProgressIndicator`, which schedules frames forever and ignores Reduce Motion | Exactly the hang that stalls the e2e harness | ✅ still glyph instead |
| 13 | `TranscriptDraft` overflowed 24 px at 1.3× text | A `Spacer` between two inflexible children lays both out unbounded | ✅ fixed; **no regression guard yet** — carry into `integration_test/` at P7 |
| 14 | Ollama's release asset is `.tar.zst`; the documented `.tgz` URL 404s | Cost a truncated download and a confusing `Unexpected EOF in archive` | ✅ |
| 15 | A ROS field was phrased so that **`yes` was the reassuring answer** — "Are you able to finish a whole sentence without stopping for breath?" | Every safety rule reading it would have fired on well patients. Caught while writing the rule set | ✅ renamed `ros.respiratory.cannot_complete_sentences` and re-phrased so `yes` is the dangerous answer |
| 16 | `readFactAt` indexed the fact map directly | Field paths come from model output, so `facts['toString']` returns a truthy Function and reaches a caller as a "fact" with no presence | ✅ `hasOwnProperty` |
| 17 | Two vocabularies for one concept: the schema said a tapped answer was `touch`, the engine says `choice` | Two spellings is two spellings somebody has to map, and one of them will be missed | ✅ `ANSWER_MODALITIES` is the single source; the schema comment now points at it |
| 18 | Uncertainty must be tested **before** negation in `derivePresence` | Nearly every English way of saying "I don't know" contains a negation, so the obvious order silently turns every "I'm not sure" into an asserted "no" | ✅ rule order documented as load-bearing and pinned by specs |
| 19 | **The Android build was broken and nothing caught it.** P5 added four native plugins and no APK was built afterwards; `permission_handler_android` 14.1.0 ships a `build.gradle.kts` declaring only `com.android.library` in `plugins {}` and then calling a `kotlin { compilerOptions { … } }` extension that exists only where the Kotlin plugin was applied | **Every Android build failed to configure** with "Unresolved reference: jvmTarget" before a line of this app compiled. Invisible to `flutter analyze` and to the whole unit tier, which is why it survived a green gate | ✅ `permission_handler` held below 13, where the Android artifact is still Groovy. The defect is inside someone else's package, so the constraint is the fix |
| 20 | **The machine was OOM-killed** running three agents, an emulator and a Gradle build at once | Lost the session; the work survived only because it was on disk. The IDE alone holds 3.4 GB of the 15 | ✅ device tier moved to a **physical** phone, which costs no host RAM; parallelism capped at two |
| 21 | The emulator segfaults under `-no-window` on this host | Not worth chasing — a real device was attached the whole time | ⏭ use `10BF3E014J007KU` |
| 22 | Two `fetch` mocks were typed narrowly for typed reads, then assigned to `global.fetch` | The suites did not fail — they failed to *compile*, which reads as "3 suites failed, 0 tests failed" and is easy to misread as flaky | ✅ typed at the factory, cast only at the assignment |
| 23 | A spec used `Array.prototype.at(-1)` | The project targets ES2021; `.at` is ES2022, so the suite would not build | ✅ indexed |
| 24 | **`asRefObject` silently ate the interview question.** It is written for a populated relation and returns null unless the map carries an `_id`; a `currentQuestion` is an embedded object with no identity | Every question parsed as absent, so **the screen rendered empty — no exception, no error banner, nothing to debug from**. The quietest possible failure | ✅ `CaseQuestion.maybeFrom` takes a plain map, with the reason in the comment |
| 25 | `onClose` runs *after* the route's dependencies are disposed, so `Get.find<AudioSource>()` there throws while the tree is being finalised | The error names the framework rather than the controller, so it reads as a Flutter bug | ✅ the recorder is held on first use and only cancelled if one was ever built — which also means a patient who types every answer never opens a platform audio session |
| 26 | **A patient-scoped route may never take a bare `:id`.** `PatientSelfGuard` resolves the caller's patient from `patientId` **or `id`** and overwrites both, so a document id was replaced by a patient id before the controller saw it | `GET /patient-documents/:id`, `/:id/original` and `/verify` all returned **404 to the document's own owner**. Every patient-facing read in the module was dead, and the unit tier structurally could not see it — it calls the service, and the damage happens in the guard above | ✅ renamed `:documentId`; `patient-scoped-routes.spec.ts` now reads the controller sources and fails on a bare `:id`. Confirmed non-vacuous by reintroducing the defect |
| 27 | Two parallel Flutter streams: one added a `GET /api/patient-documents` call on a shared path without a fixture in the shared world | `AppHarness` fails any test touching an unfixtured endpoint, so **all 11 case-taking flows went red for a reason that had nothing to do with case taking** | 🔄 shared routes belong in `world.dart`, not in a module's fixtures; a module fixture only overrides |
| 28 | A PDF of a page is not detected as a text-duplicate of its PNG — 0.52 against a measured 0.88 threshold | The sidecar renders PDFs at a different DPI and PP-OCR collapses word spacing (`Tab.METFORMIN500mg`), changing the content signature wholesale. Outside what §21's second signal claims, which is the re-*photographed* page | ⏭ left alone rather than loosening a threshold `duplicates.ts` argues at length was measured. Matters if PDF re-uploads are common in the field |

---

## Follow-ups

| Item | Note |
|---|---|
| Emulator not yet booted | Device-tier and screenshot gates cannot run until it is. P0.10 |
| One hospital per deployment | The unauthenticated claim route resolves the oldest organisation. If one API ever fronts several, the tenant must arrive out of band — subdomain or host header, never the body |
| The residual oracle is `activate`, by construction | Claim leaks nothing. Someone who claims *and* activates learns existence. Mitigated by identical claim failures, the rate limit, and a row naming every MRN tried |
| Email is effectively required at activation | `User.email` is non-nullable and login is by email. Not lowercased — `findByEmail` matches exactly, so normalising would create an account that cannot sign in |
| `file_picker` held at `^11`, `record` at `^6` | The newer majors pull a `win32 ^6` that conflicts with the `flutter_secure_storage` holding the bearer token, and raise the Dart floor above this app's |
| No regression guard on the two widget defects | Agent found them with a throwaway render check, since widget tests are not the house pattern in `test/`. They belong in `integration_test/` at P7 |
| Tamil/Hindi Piper voices not downloaded | P10 |
