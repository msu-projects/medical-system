# DFD Level 1 Guide (Physical)  
## Decomposition of the Physical Level 0 Diagram

This guide is for drawing **Physical Level 1 (child) DFDs** from your **Physical Level 0** processes (`1.0` to `7.0`).  
It is implementation-focused: include actual modules, APIs, SQL actions, and data formats.

---

## 1. Parent processes to decompose (from Physical Level 0)

Use these exact parent process names:

| Parent ID | Parent Process |
|---|---|
| 1.0 | AccountManager Module |
| 2.0 | QRCheckInService |
| 3.0 | ConsultationRecorder Module |
| 4.0 | PrescriptionManager |
| 5.0 | MedicineDispenseTracker |
| 6.0 | HealthClearanceService |
| 7.0 | StudentPortal (Medical History View) |

---

## 2. Symbols and naming convention for Physical Level 1

### External entities

- `E1 Student Browser`
- `E2 Nurse/Clinic Staff Workstation`
- `E3 Doctor Workstation`
- `E4 Faculty Browser`
- `E5 System Admin Browser`

### Physical data stores

- `D1 clinic.users`
- `D2 clinic.students`
- `D3 clinic.qr_codes`
- `D4 clinic.consultations`
- `D5 clinic.prescriptions`
- `D6 clinic.medicines`
- `D7 clinic.consultation_medicines`
- `D8 clinic.health_clearances`

### Physical subprocess naming

Use this pattern:

- `X.1 UI/Input Handler`
- `X.2 API/Validation Handler`
- `X.3 DB Read/Write Handler`
- `X.4 Output/Response Handler`

Also annotate each subprocess with technology, for example:

- `(React Form)`
- `(Express Route /api/...)`
- `(PostgreSQL SQL)`
- `(JWT Middleware)`

---

## 3. Global rule: balancing from Level 0 to Level 1

For each child diagram:

1. Keep every parent input/output flow from Physical Level 0.
2. Add only internal flows needed to show implementation details.
3. Keep flow labels physical (e.g., `HTTPS POST JSON`, `SQL SELECT`, `JWT token`).

---

## 4. Level 1 child diagram instructions per physical parent process

## 4.1 Child Diagram for **1.0 AccountManager Module**

### Subprocesses to draw

- `1.1 AdminUserFormHandler (React Admin UI)`
- `1.2 UserPayloadValidator (Express /api/users)`
- `1.3 UserWriter (SQL INSERT/UPDATE -> D1)`
- `1.4 StudentProfileWriter (SQL INSERT/UPDATE -> D2)`
- `1.5 QRTokenWriter (SQL INSERT/UPDATE -> D3)`

### Parent-balanced flows (must appear)

- `E5 -> 1.x : HTTPS POST/PUT JSON User Payload`
- `1.x -> D1 : SQL INSERT/UPDATE clinic.users`
- `1.x -> D2 : SQL INSERT/UPDATE clinic.students`
- `1.x -> D3 : SQL INSERT/UPDATE clinic.qr_codes`

### Internal flow routing

- `1.1 -> 1.2 : Parsed Form Payload`
- `1.2 -> 1.3 : Validated User Record (+ bcrypt hash)`
- `1.3 -> 1.4 : student role trigger + user_id`
- `1.4 -> 1.5 : student_id for QR token`
- `1.5 -> 1.1 : HTTP 200/4xx response`

### Layout tip

Place `E5` left, subprocesses center left-to-right (`1.1` to `1.5`), and `D1/D2/D3` on the right.

---

## 4.2 Child Diagram for **2.0 QRCheckInService**

### Subprocesses to draw

- `2.1 QRScanHandler (Scanner/React listener)`
- `2.2 QRValidationAPI (Express POST /api/checkin)`
- `2.3 StudentProfileFetcher (SQL SELECT -> D2)`
- `2.4 ConsultationInitializer (SQL INSERT -> D4)`

### Parent-balanced flows (must appear)

- `E2 -> 2.x : Scanned UUID JSON payload`
- `D3 -> 2.x : SQL SELECT token result`
- `2.x -> D4 : SQL INSERT check-in row`

### Internal flow routing

- `2.1 -> 2.2 : qr_token`
- `2.2 -> D3 : SQL SELECT by qr_token`
- `2.2 -> 2.3 : resolved student_id`
- `2.3 -> D2 : SQL SELECT student profile`
- `2.3 -> 2.4 : student profile + attended_by`
- `2.4 -> E2 : check-in success + student profile`
- `2.2 -> E2 : invalid/inactive QR error`

### Layout tip

Keep `D3` near `2.2` and `D2` near `2.3` to avoid crossed lines.

---

## 4.3 Child Diagram for **3.0 ConsultationRecorder Module**

### Subprocesses to draw

- `3.1 ConsultationFormHandler (React Staff/Doctor form)`
- `3.2 ConsultationAPIValidator (Express POST /api/consultations)`
- `3.3 EncryptionHandler (pgcrypto pgp_sym_encrypt)`
- `3.4 ConsultationWriter (SQL INSERT/UPDATE -> D4)`

### Parent-balanced flows (must appear)

- `E2/E3 -> 3.x : HTTPS POST JSON consultation payload`
- `3.x -> D4 : SQL INSERT/UPDATE encrypted consultation`
- `D4 -> 3.x : SQL SELECT consultation history`

### Internal flow routing

- `3.1 -> 3.2 : complaint + vitals + diagnosis + treatment`
- `3.2 -> 3.3 : validated sensitive fields`
- `3.3 -> 3.4 : encrypted BYTEA fields`
- `3.4 -> D4 : write consultation row`
- `D4 -> 3.4 : existing record/status`
- `3.4 -> E2/E3 : save/update response`

### Layout tip

Draw `3.3` directly before `3.4` so encryption is clearly shown before DB write.

---

## 4.4 Child Diagram for **4.0 PrescriptionManager**

### Subprocesses to draw

- `4.1 PrescriptionFormHandler (Doctor UI)`
- `4.2 PrescriptionAPIValidator (Express POST /api/prescriptions)`
- `4.3 PrescriptionEncryptionHandler (pgcrypto)`
- `4.4 PrescriptionWriter (SQL INSERT -> D5)`

### Parent-balanced flows (must appear)

- `E3 -> 4.x : HTTPS POST JSON prescription payload`
- `4.x -> D5 : SQL INSERT encrypted prescription`

### Internal flow routing

- `4.1 -> 4.2 : consultation_id + prescription_details + notes`
- `4.2 -> 4.3 : validated prescription payload`
- `4.3 -> 4.4 : encrypted BYTEA payload`
- `4.4 -> D5 : SQL INSERT`
- `4.4 -> E3 : created response / validation error`

### Layout tip

Keep this child diagram linear (left-to-right) to make encryption flow obvious.

---

## 4.5 Child Diagram for **5.0 MedicineDispenseTracker**

### Subprocesses to draw

- `5.1 DispenseFormHandler (Nurse UI)`
- `5.2 DispenseAPIValidator (Express POST /api/medicines/dispense)`
- `5.3 StockChecker (SQL SELECT -> D6)`
- `5.4 DispenseWriter (SQL INSERT -> D7, SQL UPDATE -> D6)`

### Parent-balanced flows (must appear)

- `E2 -> 5.x : HTTPS POST JSON dispense payload`
- `D6 -> 5.x : SQL SELECT medicine catalog/stock`
- `5.x -> D7 : SQL INSERT dispense rows`
- `5.x -> D6 : SQL UPDATE stock levels`

### Internal flow routing

- `5.1 -> 5.2 : medicine_id + quantity + consultation_id`
- `5.2 -> 5.3 : validated dispense request`
- `5.3 -> 5.4 : stock-approved request`
- `5.4 -> D7 : insert dispense record`
- `5.4 -> D6 : decrement stock`
- `5.3 -> E2 : low-stock error (if insufficient stock)`
- `5.4 -> E2 : dispense success`

### Layout tip

Put `D6` under `5.3/5.4` so both stock-read and stock-update arrows are short.

---

## 4.6 Child Diagram for **6.0 HealthClearanceService**

### Subprocesses to draw

- `6.1 ClearanceRequestHandler (Faculty UI)`
- `6.2 ClearanceRequestAPI (Express POST /api/clearances)`
- `6.3 ClearanceEvaluationHandler (Doctor/Nurse workflow)`
- `6.4 ClearanceStatusWriter (SQL INSERT/UPDATE -> D8)`
- `6.5 NotificationDispatcher (email/app notification)`

### Parent-balanced flows (must appear)

- `E4 -> 6.x : HTTPS POST JSON clearance request`
- `6.x -> D8 : SQL INSERT/UPDATE clearance status`

### Internal flow routing

- `6.1 -> 6.2 : student_id + purpose + requested_by`
- `6.2 -> 6.4 : pending request`
- `6.3 -> 6.4 : cleared/not_cleared decision + remarks`
- `6.4 -> D8 : INSERT/UPDATE`
- `6.4 -> 6.5 : finalized clearance status`
- `6.5 -> E4 : clearance status notification`
- `6.5 -> E1 : certificate availability notice (if cleared)`

### Layout tip

Draw two lanes: faculty request lane (left) and clinical evaluation lane (top/right), merging at `6.4`.

---

## 4.7 Child Diagram for **7.0 StudentPortal (Medical History View)**

### Subprocesses to draw

- `7.1 JWTAuthGuard (Express middleware)`
- `7.2 HistoryAPIHandler (GET /api/student/history)`
- `7.3 HistoryDataFetcher (SQL SELECT via view)`
- `7.4 HistoryResponseRenderer (JSON -> React UI)`

### Parent-balanced flows (must appear)

- `E1 -> 7.x : HTTPS GET + Bearer JWT`
- `D4/D5/D7 -> 7.x : SQL SELECT history records`
- `7.x -> E1 : HTTPS JSON medical history response`

### Internal flow routing

- `7.1 -> 7.2 : authenticated user context`
- `7.2 -> 7.3 : student_id query context`
- `7.3 -> D4/D5/D7 : view/query history data`
- `7.3 -> 7.4 : normalized history payload`
- `7.4 -> E1 : rendered history display`
- `7.1 -> E1 : 401 response (invalid/expired token)`

### Layout tip

Put `D4`, `D5`, and `D7` together as one “history data cluster” under `7.3`.

---

## 5. Drawing sequence (recommended)

1. Draw child diagrams in this order: `2.0`, `3.0`, `4.0`, `5.0`, `6.0`, `1.0`, `7.0`.
2. For each child diagram:
   - Draw entities and stores first.
   - Draw subprocesses next.
   - Add balanced parent flows.
   - Add internal physical flows last.

---

## 6. Final checklist before you finalize the Physical Level 1 set

- [ ] Each child diagram preserves all parent process inputs/outputs from Physical Level 0.
- [ ] Every flow label uses physical form/protocol (`HTTPS`, `JSON`, `SQL SELECT`, `SQL INSERT/UPDATE`, `JWT`).
- [ ] No direct store-to-store or entity-to-store flow without a subprocess.
- [ ] Every subprocess has at least one input and one output.
- [ ] Physical annotations are present in process names (React/Express/PostgreSQL/etc.).
- [ ] IDs are consistent (`X.1`, `X.2` under the correct parent `X.0`).

