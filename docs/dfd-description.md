# Data Flow Diagrams — School Clinic Management System

A comprehensive guide presenting both **Logical** and **Physical** Data Flow Diagrams for the School Clinic Management System, following the structured analysis approach outlined in the DFD guide.

---

## Overview: Logical vs. Physical DFDs

| Aspect          | Logical DFD                                                        | Physical DFD                                                                                         |
| --------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| **Purpose**     | Shows WHAT the system does — the essence of the business processes | Shows HOW the system is implemented — the actual technology and implementation                       |
| **Focus**       | Business requirements, data transformations, information flow      | Technology, hardware, software, databases, user interfaces                                           |
| **Processes**   | Business activities (e.g., "Record Consultation")                  | Programs, modules, screens (e.g., "ConsultationForm.jsx encrypts via AES-256")                       |
| **Data Stores** | Logical collections (e.g., "D4 Consultations")                     | Physical implementations (e.g., "PostgreSQL clinic.consultations table with encrypted BYTEA fields") |
| **Data Flows**  | Information content (e.g., "Consultation Record")                  | Implementation format (e.g., "JSON via HTTPS POST to /api/consultations")                            |
| **Technology**  | Technology-independent                                             | Technology-specific (PostgreSQL, React, Node.js, QR scanner hardware)                                |
| **Audience**    | Business analysts, stakeholders, end users                         | Developers, system architects, database administrators                                               |
| **When Used**   | Requirements analysis, business process modeling                   | System design, implementation planning                                                               |

---

## Part I: LOGICAL DATA FLOW DIAGRAMS

### 1. Identify the Four Symbol Types

Before drawing anything, map your system to the four basic DFD symbols:

| Symbol              | System Element                                                                                                                                      |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Sources / Sinks** | Student, Nurse/Clinic Staff, Doctor, Faculty/Teacher, System Admin                                                                                  |
| **Processes**       | QR Check-In, Record Consultation, Issue Prescription, Dispense Medicine, Manage Health Clearance, View Medical History, Manage Accounts & Inventory |
| **Data Stores**     | D1 Users, D2 Students, D3 QR Codes, D4 Consultations, D5 Prescriptions, D6 Medicines, D7 Consultation Medicines, D8 Health Clearances               |
| **Data Flows**      | QR Token, Student Profile, Consultation Record, Prescription Details, Medicine Dispense Info, Clearance Request/Status, Login Credentials, etc.     |

---

## 2. Logical Context Diagram (Level 0)

**Purpose:** Show the system as a single process with all external entities and major data flows. This is technology-independent — it shows WHAT information flows between the system and external entities, not HOW. No data stores at this level.

### External Entities (Sources/Sinks)

| Entity                   | Sends to System                                                                                          | Receives from System                                                                            |
| ------------------------ | -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **Student**              | QR Code (scan), Login Credentials                                                                        | Medical History, Consultation Summary, Prescription Details, Health Clearance, Student Schedule |
| **Nurse / Clinic Staff** | QR Scan Input, Consultation Data (complaint, vitals, diagnosis, treatment notes), Medicine Dispense Info | Student Profile (via QR lookup), Consultation Records, Medicine Inventory Status                |
| **Doctor**               | Diagnosis, Prescription Details, Clearance Decision                                                      | Consultation Records, Student Medical History                                                   |
| **Faculty / Teacher**    | Clearance Request                                                                                        | Clearance Status (cleared / not cleared)                                                        |
| **System Admin**         | Account Data, System Settings                                                                            | User Listings, Audit Logs, System Reports                                                       |

### How to Draw It

1. Place a single circle in the centre labelled **"0 — School Clinic Management System"**.
2. Place each external entity (rectangle) around it.
3. Draw labelled arrows for every data flow listed above — one arrow per direction, per distinct piece of data.
4. **Do not** include any data stores at this level.

---

## 3. Logical Level 0 Diagram (Decompose the Single Process)

**Purpose:** Explode the context-level process into its major sub-processes. Carry forward all external entities and data flows from the context diagram, then add logical data stores and internal flows. Focus on WHAT the system does, not the technology used.

### Sub-Processes

| #   | Process Name                | Description                                                                                                                                 |
| --- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 1.0 | **Manage Accounts**         | Admin creates/updates user accounts (students, nurses, doctors, faculty). Generates QR code upon student registration.                      |
| 2.0 | **Check In Student (QR)**   | Nurse scans QR code → system looks up student profile → student is checked in for a visit.                                                  |
| 3.0 | **Record Consultation**     | Nurse/Doctor logs chief complaint, vitals (BP, temp, pulse, weight), encrypted diagnosis, and treatment notes.                              |
| 4.0 | **Issue Prescription**      | Doctor creates an encrypted prescription linked to the consultation.                                                                        |
| 5.0 | **Dispense Medicine**       | Nurse records medicines given to the student (name, quantity) from the medicine catalog.                                                    |
| 6.0 | **Manage Health Clearance** | Faculty requests clearance → Doctor/Nurse evaluates and issues clearance status.                                                            |
| 7.0 | **View Medical History**    | Student logs in and views own consultation history, prescriptions, and medicines dispensed (diagnosis decrypted; treatment notes excluded). |

### Data Stores

| ID  | Name                   | Key Data Elements                                                                                                                                             |
| --- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Users                  | user_id, username, password_hash, email, full_name, role, is_active                                                                                           |
| D2  | Students               | student_id, user_id, student_number, date_of_birth, sex, contact_number, emergency_contact, year_level, section, blood_type, allergies |
| D3  | QR Codes               | qr_id, student_id, qr_token (UUID), is_active                                                                                                                 |
| D4  | Consultations          | consultation_id, student_id, attended_by, check_in_time, chief_complaint, diagnosis (encrypted), treatment_notes (encrypted), vitals, status                  |
| D5  | Prescriptions          | prescription_id, consultation_id, prescribed_by, prescription_details (encrypted), notes (encrypted)                                                          |
| D6  | Medicines              | medicine_id, name, description, unit, is_available                                                                                                            |
| D7  | Consultation Medicines | consultation_id, medicine_id, quantity_given, dispensed_by                                                                                                    |
| D8  | Health Clearances      | clearance_id, student_id, issued_by, purpose, status, valid_until, requested_by                                                                               |

### Data Flow Connections

| From                        | To                          | Data Flow Label                                                   |
| --------------------------- | --------------------------- | ----------------------------------------------------------------- |
| System Admin                | 1.0 Manage Accounts         | Account Data (username, role, profile info)                       |
| 1.0 Manage Accounts         | D1 Users                    | User Record                                                       |
| 1.0 Manage Accounts         | D2 Students                 | Student Profile                                                   |
| 1.0 Manage Accounts         | D3 QR Codes                 | QR Token                                                          |
| Nurse                       | 2.0 Check In Student        | QR Scan Input                                                     |
| D3 QR Codes                 | 2.0 Check In Student        | QR Token Lookup                                                   |
| D2 Students                 | 2.0 Check In Student        | Student Profile                                                   |
| 2.0 Check In Student        | Nurse                       | Student Profile Display                                           |
| 2.0 Check In Student        | 3.0 Record Consultation     | Student & Check-In Info                                           |
| Nurse / Doctor              | 3.0 Record Consultation     | Consultation Data (complaint, vitals, diagnosis, treatment notes) |
| 3.0 Record Consultation     | D4 Consultations            | Consultation Record (encrypted)                                   |
| D4 Consultations            | 3.0 Record Consultation     | Existing Consultation Record                                      |
| Doctor                      | 4.0 Issue Prescription      | Prescription Details                                              |
| D4 Consultations            | 4.0 Issue Prescription      | Consultation Reference                                            |
| 4.0 Issue Prescription      | D5 Prescriptions            | Prescription Record (encrypted)                                   |
| Nurse                       | 5.0 Dispense Medicine       | Dispense Info (medicine, quantity)                                |
| D6 Medicines                | 5.0 Dispense Medicine       | Medicine Catalog                                                  |
| D4 Consultations            | 5.0 Dispense Medicine       | Consultation Reference                                            |
| 5.0 Dispense Medicine       | D7 Consultation Medicines   | Dispense Record                                                   |
| Faculty                     | 6.0 Manage Health Clearance | Clearance Request (student, purpose)                              |
| D2 Students                 | 6.0 Manage Health Clearance | Student Info                                                      |
| Doctor / Nurse              | 6.0 Manage Health Clearance | Clearance Decision (cleared / not cleared, remarks)               |
| 6.0 Manage Health Clearance | D8 Health Clearances        | Clearance Record                                                  |
| 6.0 Manage Health Clearance | Faculty                     | Clearance Status                                                  |
| Student                     | 7.0 View Medical History    | Login Credentials                                                 |
| D1 Users                    | 7.0 View Medical History    | Authentication Result                                             |
| D4 Consultations            | 7.0 View Medical History    | Consultation Records (decrypted diagnosis)                        |
| D5 Prescriptions            | 7.0 View Medical History    | Prescription Records (decrypted)                                  |
| D7 Consultation Medicines   | 7.0 View Medical History    | Dispensed Medicines                                               |
| 7.0 View Medical History    | Student                     | Medical History Display                                           |

---

## 4. Logical Child Diagrams (Level 1 — Decompose Selected Processes)

Select processes that are complex enough to warrant further decomposition. These remain technology-independent, focusing on the essence of the business logic. Below are two recommended candidates.

### 4a. Logical Child Diagram for Process 2.0 — Check In Student (QR)

| #   | Sub-Process                  | Description                                                                                                                   |
| --- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| 2.1 | **Scan QR Code**             | Nurse scans the physical QR code; system reads the UUID token.                                                                |
| 2.2 | **Validate QR Token**        | System looks up the token in D3 QR Codes, checks `is_active = TRUE`. Returns an error if the token is invalid or deactivated. |
| 2.3 | **Retrieve Student Profile** | System fetches the student record from D2 Students using the `student_id` linked to the QR token.                             |
| 2.4 | **Create Check-In Record**   | System initialises a new consultation row in D4 Consultations with `check_in_time = NOW()` and `status = 'ongoing'`.          |

**Data flows to preserve from parent:**

- _Inbound:_ QR Scan Input (from Nurse)
- _Outbound:_ Student Profile Display (to Nurse), Student & Check-In Info (to Process 3.0)

**Internal data flows added:**

- QR Token → 2.2 Validate QR Token
- Validated Student ID → 2.3 Retrieve Student Profile
- Student Profile + Check-In Time → 2.4 Create Check-In Record

### 4b. Logical Child Diagram for Process 3.0 — Record Consultation

| #   | Sub-Process                           | Description                                                                                                                 |
| --- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| 3.1 | **Enter Chief Complaint**             | Staff enters patient-reported symptoms (plain text).                                                                        |
| 3.2 | **Record Vitals**                     | Staff records blood pressure, temperature, pulse, and weight.                                                               |
| 3.3 | **Enter Diagnosis & Treatment Notes** | Doctor/Nurse enters diagnosis and clinical observations. System encrypts both fields (AES-256 via pgcrypto) before storing. |
| 3.4 | **Update Consultation Status**        | Staff marks the consultation as `completed` or `referred`.                                                                  |

**Data flows to preserve from parent:**

- _Inbound:_ Consultation Data (from Nurse/Doctor), Student & Check-In Info (from Process 2.0)
- _Outbound:_ Consultation Record (to D4 Consultations)

**Internal data flows added:**

- Plain-text Diagnosis → Encryption Function → Encrypted Diagnosis (BYTEA)
- Plain-text Treatment Notes → Encryption Function → Encrypted Notes (BYTEA)
- Error message (to staff) if required fields are missing

---

## Part II: PHYSICAL DATA FLOW DIAGRAMS

### 5. Physical Context Diagram

**Purpose:** Show HOW the system interfaces with external entities using specific technologies, protocols, and formats.

### External Entities with Physical Implementation

| Entity                   | Physical Interface                                   | Sends to System                                                                                             | Receives from System                                                                          |
| ------------------------ | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| **Student**              | Web browser (React app), QR code card (printed UUID) | HTTPS POST (login credentials in JSON), QR scan (UUID token from printed card)                              | HTML/CSS rendered pages, PDF downloads (prescriptions, clearances), JSON API responses        |
| **Nurse / Clinic Staff** | Desktop/tablet browser, USB/Bluetooth QR scanner     | HTTPS POST (consultation form data in JSON), QR scanner input (barcode read), medicine dispense data (JSON) | JSON responses, real-time student profile data, inventory status from PostgreSQL              |
| **Doctor**               | Desktop browser (clinic portal)                      | HTTPS POST (diagnosis, prescription in JSON)                                                                | Decrypted consultation views (HTML), patient history (JSON from view `v_doctor_full_records`) |
| **Faculty / Teacher**    | Web browser (faculty portal)                         | HTTPS GET request for clearance status (student_id in URL parameter)                                        | JSON response (clearance status), HTML rendered clearance certificate                         |
| **System Admin**         | Admin dashboard (React app)                          | HTTPS POST/PUT/DELETE (user CRUD operations in JSON)                                                        | JSON arrays (user listings), CSV exports (audit logs), PostgreSQL query results               |

### System Boundary

- **Frontend:** React.js single-page applications (SPA) served via HTTPS
- **Backend API:** Node.js/Express.js REST API with JWT authentication
- **Database:** PostgreSQL 14+ with `pgcrypto` extension
- **QR Integration:** Client-side QR scanner library (e.g., `html5-qrcode`) or hardware scanner

---

### 6. Physical Level 0 Diagram

**Purpose:** Show the major subsystems, programs, and physical data stores with implementation-specific details.

### Physical Sub-Processes (Programs/Modules)

| #   | Process Name                             | Physical Implementation                                                                                                                                                           |
| --- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1.0 | **AccountManager Module**                | Admin dashboard (React) → REST API `/api/users` → PostgreSQL stored procedures → Inserts into `clinic.users`, `clinic.students`, `clinic.qr_codes` tables                         |
| 2.0 | **QRCheckInService**                     | QR scanner hardware/software → POST `/api/checkin` → Node.js validation logic → PostgreSQL query on `clinic.qr_codes` → Creates row in `clinic.consultations`                     |
| 3.0 | **ConsultationRecorder Module**          | Staff/Doctor web form → POST `/api/consultations` → Node.js middleware encrypts diagnosis using `pgcrypto.pgp_sym_encrypt()` → INSERT into `clinic.consultations` (BYTEA columns) |
| 4.0 | **PrescriptionManager**                  | Doctor prescription form → POST `/api/prescriptions` → Encrypt prescription details via pgcrypto → INSERT into `clinic.prescriptions`                                             |
| 5.0 | **MedicineDispenseTracker**              | Staff dispense form → POST `/api/medicines/dispense` → INSERT into `clinic.consultation_medicines` + UPDATE `clinic.medicines` inventory                                          |
| 6.0 | **HealthClearanceService**               | Faculty request form → POST `/api/clearances` → Doctor approval workflow → UPDATE `clinic.health_clearances` status → Email notification service                                  |
| 7.0 | **StudentPortal (Medical History View)** | Student login → JWT-authenticated GET `/api/student/history` → PostgreSQL view `v_student_medical_history` (auto-decrypts) → JSON response → React renders history                |

### Physical Data Stores

| ID  | Logical Name           | Physical Implementation                                                                                                           | Access Method                                         |
| --- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| D1  | Users                  | PostgreSQL table `clinic.users`, bcrypt password hashes (VARCHAR 255), RLS enabled                                                | SQL queries via Node.js `pg` driver                   |
| D2  | Students               | PostgreSQL table `clinic.students`, foreign key to `clinic.users`, encrypted fields: none (baseline data is unencrypted)          | SQL queries, row-level security policies per role     |
| D3  | QR Codes               | PostgreSQL table `clinic.qr_codes`, UUID token stored as `qr_token` (TEXT), indexed for fast lookup                               | SELECT by qr_token, CREATE INDEX on `qr_token`        |
| D4  | Consultations          | PostgreSQL table `clinic.consultations`, BYTEA columns: `diagnosis_encrypted`, `treatment_notes_encrypted` (AES-256 via pgcrypto) | INSERT/UPDATE via encrypted functions, SELECT via RLS |
| D5  | Prescriptions          | PostgreSQL table `clinic.prescriptions`, BYTEA column: `prescription_details_encrypted`, `notes_encrypted`                        | Encrypted INSERT, decrypted SELECT via views          |
| D6  | Medicines              | PostgreSQL table `clinic.medicines`, unencrypted catalog, `is_available` boolean flag                                             | SELECT for inventory, UPDATE for stock adjustments    |
| D7  | Consultation Medicines | PostgreSQL table `clinic.consultation_medicines`, junction table with `quantity_given` (INTEGER)                                  | INSERT on dispense, JOIN queries for history          |
| D8  | Health Clearances      | PostgreSQL table `clinic.health_clearances`, `status` ENUM ('pending', 'cleared', 'not_cleared'), `valid_until` TIMESTAMPTZ       | INSERT/UPDATE, SELECT with date range filters         |

### Physical Data Flow Specifications

| From                       | To                         | Physical Data Flow                                                                                                                 | Protocol/Format                   |
| -------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| System Admin Browser       | 1.0 AccountManager         | JSON payload: `{"username": "jdoe", "role": "student", "email": "jdoe@school.edu"}`                                                | HTTPS POST                        |
| 1.0 AccountManager         | D1 Users (PostgreSQL)      | SQL INSERT with bcrypt-hashed password                                                                                             | PostgreSQL wire protocol          |
| 1.0 AccountManager         | D3 QR Codes (PostgreSQL)   | SQL INSERT with `gen_random_uuid()` for qr_token                                                                                   | PostgreSQL wire protocol          |
| Nurse QR Scanner           | 2.0 QRCheckInService       | Scanned UUID string (e.g., `"a3f2e1d4-..."`), sent as POST body                                                                    | HTTPS POST (JSON)                 |
| D3 QR Codes                | 2.0 QRCheckInService       | SQL SELECT result: `{student_id: 123, is_active: true}`                                                                            | PostgreSQL result set             |
| 2.0 QRCheckInService       | D4 Consultations           | SQL INSERT: `INSERT INTO consultations (student_id, check_in_time, status) VALUES ($1, NOW(), 'ongoing')`                          | PostgreSQL parameterized query    |
| Nurse/Doctor Form          | 3.0 ConsultationRecorder   | JSON: `{"complaint": "Headache", "bp": "120/80", "diagnosis": "Migraine", "treatment": "Rest"}`                                    | HTTPS POST                        |
| 3.0 ConsultationRecorder   | D4 Consultations           | SQL UPDATE with pgcrypto: `diagnosis_encrypted = pgp_sym_encrypt('Migraine', 'secret_key')`                                        | PostgreSQL encrypted BYTEA insert |
| Doctor Prescription Form   | 4.0 PrescriptionManager    | JSON: `{"consultation_id": 45, "prescription": "Ibuprofen 400mg, 1 tab TID", "notes": "Take with food"}`                           | HTTPS POST                        |
| 4.0 PrescriptionManager    | D5 Prescriptions           | SQL INSERT with encryption: `prescription_details_encrypted = pgp_sym_encrypt($1, key)`                                            | PostgreSQL encrypted insert       |
| Faculty Request (browser)  | 6.0 HealthClearanceService | JSON: `{"student_id": 78, "purpose": "Field trip", "requested_by": 12}`                                                            | HTTPS POST                        |
| 6.0 HealthClearanceService | D8 Health Clearances       | SQL INSERT + later UPDATE when doctor approves: `status = 'cleared', issued_by = doctor_id, valid_until = NOW() + INTERVAL '1 yr'` | PostgreSQL query                  |
| Student (authenticated)    | 7.0 StudentPortal          | JWT token in Authorization header, GET `/api/student/history`                                                                      | HTTPS GET with Bearer token       |
| D4 Consultations + D5 + D7 | 7.0 StudentPortal          | SQL SELECT from view `v_student_medical_history` (auto-decrypts diagnosis) → returns JSON array                                    | PostgreSQL view query             |
| 7.0 StudentPortal          | Student Browser            | JSON array rendered as HTML table by React components                                                                              | HTTPS response (JSON → HTML DOM)  |

---

### 7. Physical Child Diagrams

### 7a. Physical Child Diagram for Process 2.0 — QRCheckInService

| #   | Sub-Process                 | Physical Implementation                                                                                                                            |
| --- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2.1 | **QRScanHandler**           | USB/Bluetooth scanner → JavaScript event listener → extracts UUID string                                                                           |
| 2.2 | **QRValidationAPI**         | Node.js endpoint `/api/qr/validate` → SQL: `SELECT student_id FROM clinic.qr_codes WHERE qr_token = $1 AND is_active = TRUE` → returns JSON or 404 |
| 2.3 | **StudentProfileFetcher**   | Node.js → SQL: `SELECT * FROM clinic.students WHERE student_id = $1` → returns JSON object                                                         |
| 2.4 | **ConsultationInitializer** | Node.js → SQL: `INSERT INTO clinic.consultations (student_id, attended_by, check_in_time, status) VALUES ($1, $2, NOW(), 'ongoing')`               |

**Technology Stack:**

- Frontend: React QR scanner component (`html5-qrcode` library)
- Backend: Express.js route handlers
- Database: PostgreSQL with indexed `qr_token` column
- Security: RLS policies ensure only nurses/doctors can create consultations

### 7b. Physical Child Diagram for Process 3.0 — ConsultationRecorder Module

| #   | Sub-Process                   | Physical Implementation                                                                                                                               |
| --- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 3.1 | **ComplaintInputForm**        | React controlled component → stores plain text in state → submitted via POST                                                                          |
| 3.2 | **VitalsInputForm**           | React form with numeric inputs (BP, temp, pulse, weight) → validation rules → JSON payload                                                            |
| 3.3 | **EncryptedDiagnosisHandler** | Node.js receives plain text → calls PostgreSQL function: `pgp_sym_encrypt('diagnosis text', current_setting('app.encryption_key'))` → stores as BYTEA |
| 3.4 | **ConsultationStatusUpdater** | Node.js → SQL: `UPDATE clinic.consultations SET status = 'completed', completed_at = NOW() WHERE consultation_id = $1`                                |

**Encryption Details:**

- Algorithm: AES-256 via `pgcrypto` extension
- Key Management: Encryption key stored in environment variable, passed to PostgreSQL session via `SET app.encryption_key = 'key'`
- Decryption: Only authorized roles (student for own records, doctors) can decrypt via `pgp_sym_decrypt(field, key)`

---

### 8. Physical System Architecture (Partitioned Physical DFD)

Group physical processes into deployment components:

| Component                      | Physical Processes Included                                             | Technology Stack                                                      | Deployment                           |
| ------------------------------ | ----------------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------ |
| **Web Application (Frontend)** | All React components (Student Portal, Staff Dashboard, Admin Panel)     | React 18, React Router, Axios for HTTP, Material-UI components        | Nginx static file server (HTTPS)     |
| **API Server (Backend)**       | All Node.js endpoints (authentication, CRUD operations, business logic) | Node.js 18, Express.js, JWT middleware, `pg` driver, bcrypt library   | Node.js server (PM2 process manager) |
| **Database Server**            | PostgreSQL instance with all tables, views, RLS policies, encryption    | PostgreSQL 14+, pgcrypto extension, Row-Level Security, GIN indexes   | Dedicated PostgreSQL server          |
| **QR Scanner Integration**     | Hardware scanner drivers + frontend scanner library                     | USB HID scanner (hardware), `html5-qrcode` (software fallback)        | Client-side (browser + USB device)   |
| **Authentication Service**     | Login endpoints, session management, JWT issuance/validation            | JWT (JSON Web Tokens), bcrypt for password hashing                    | Part of API server                   |
| **Encryption Service**         | Symmetric encryption/decryption layer                                   | pgcrypto (AES-256), encryption keys managed via environment variables | PostgreSQL extension                 |
| **Audit & Logging**            | Trigger-based audit trail                                               | PostgreSQL triggers, `audit_log` table with JSONB columns             | Database server                      |

**System Boundaries:**

- **Client Tier:** Web browsers (Chrome, Firefox, Safari) on desktops, tablets, mobile devices
- **Application Tier:** Node.js API server behind reverse proxy (Nginx)
- **Data Tier:** PostgreSQL database with encrypted disk storage
- **Network:** All external communication via HTTPS (TLS 1.3), internal communication via localhost or private network

---

### 9. Physical Implementation: Security & Data Flow Controls

| Security Layer                | Physical Implementation                                                                                                                                                               | Applied To                                   |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| **Transport Security**        | TLS 1.3 encryption for all HTTPS traffic, SSL certificates (Let's Encrypt)                                                                                                            | All client-server communication              |
| **Authentication**            | JWT tokens (HS256), bcrypt password hashing (cost factor 12)                                                                                                                          | All API endpoints                            |
| **Authorization (Row-Level)** | PostgreSQL RLS policies: `CREATE POLICY student_own_records ON consultations FOR SELECT TO student USING (student_id = current_user_id())`                                            | All sensitive tables                         |
| **Field-Level Encryption**    | `pgp_sym_encrypt(data, key)` for diagnosis, treatment notes, prescriptions; decryption restricted by RLS                                                                              | Sensitive BYTEA columns                      |
| **View-Based Access Control** | Students see `v_student_medical_history` (auto-decrypts diagnosis), doctors see `v_doctor_full_records` (decrypts all fields), faculty see `v_faculty_clearance` (no medical details) | All role-specific data access                |
| **Audit Trail**               | PostgreSQL triggers log all INSERT/UPDATE/DELETE to `audit_log` table with JSONB old/new values, timestamp, user_id                                                                   | Critical tables (users, consultations, etc.) |
| **Input Validation**          | Express.js middleware with `express-validator`, parameterized queries (no SQL injection)                                                                                              | All API inputs                               |
| **Session Management**        | JWT expiration (24 hours), refresh token mechanism, secure httpOnly cookies                                                                                                           | User sessions                                |

---

## Part III: COMPARISON AND MAPPING

### 10. Logical vs. Physical DFD Mapping

| Logical Element                        | Physical Implementation                                                                                                       |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **External Entity: Student**           | Web browser running React SPA, QR code card (printed UUID)                                                                    |
| **External Entity: Nurse**             | Desktop browser + USB QR scanner hardware                                                                                     |
| **Process: 1.0 Manage Accounts**       | React admin dashboard → Node.js `/api/users` endpoint → PostgreSQL stored procedure `create_user_with_student()`              |
| **Process: 2.0 Check In Student**      | QR scanner → POST `/api/checkin` → Node.js validator → PostgreSQL insert                                                      |
| **Process: 3.0 Record Consultation**   | React form → POST `/api/consultations` → Node.js encryption → PostgreSQL `clinic.consultations` with BYTEA                    |
| **Data Store: D1 Users**               | PostgreSQL table `clinic.users` with bcrypt password_hash, RLS policies, indexed on username                                  |
| **Data Store: D4 Consultations**       | PostgreSQL table `clinic.consultations`, columns: `diagnosis_encrypted BYTEA`, `treatment_notes_encrypted BYTEA`, RLS enabled |
| **Data Flow: QR Token**                | UUID string transmitted via HTTPS POST in JSON: `{"qr_token": "a3f2e1d4-b8c9-..."}`                                           |
| **Data Flow: Consultation Record**     | JSON object: `{"student_id": 123, "complaint": "...", "bp": "120/80", ...}` → encrypted → PostgreSQL row                      |
| **Data Flow: Medical History Display** | PostgreSQL view `v_student_medical_history` → JSON array → React component renders HTML table                                 |

---

### 11. DFD Rules Checklist (Applies to Both Logical and Physical)

Before finalising each diagram, verify these rules (from the DFD guide):

**Process Rules:**

- [ ] Every process has at least one input **and** one output
- [ ] Process names are verb phrases (e.g., "Record Consultation", "QRCheckInService")
- [ ] Inputs to a process differ from its outputs (transformations occur)

**Data Flow Rules:**

- [ ] All data flows are unidirectional (use separate arrows for bidirectional communication)
- [ ] Data flows are labelled with noun phrases (e.g., "Consultation Record", "JSON Payload")
- [ ] No data flows directly between two data stores (a process must mediate)
- [ ] No data flows directly between a data store and a source/sink (a process must mediate)
- [ ] No data flows directly between two sources/sinks

**Data Store Rules:**

- [ ] Data elements flowing in/out of a data store are a subset of that store's elements
- [ ] Data stores appear only in Level 0 and below (not in context diagrams)

**General Rules:**

- [ ] Every object has a unique name
- [ ] Child diagrams preserve all data flows of the parent process (balancing rule)
- [ ] Diagrams are readable and uncluttered (use child diagrams to manage complexity)

---

## Part IV: RELATIONSHIP TO OTHER MODELS

### 12. Relationship to the Entity-Relationship Diagram

Per the DFD guide, DFDs and ERDs model complementary perspectives:

| DFD Element               | ERD Counterpart                                                                           | Physical Table                  |
| ------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------- |
| D1 Users                  | `users` entity                                                                            | `clinic.users`                  |
| D2 Students               | `students` entity (1:1 with `users`)                                                      | `clinic.students`               |
| D3 QR Codes               | `qr_codes` entity (1:1 with `students`)                                                   | `clinic.qr_codes`               |
| D4 Consultations          | `consultations` entity (M:1 with `students`, M:1 with `users`)                            | `clinic.consultations`          |
| D5 Prescriptions          | `prescriptions` entity (M:1 with `consultations`)                                         | `clinic.prescriptions`          |
| D6 Medicines              | `medicines` entity                                                                        | `clinic.medicines`              |
| D7 Consultation Medicines | `consultation_medicines` associative entity (M:M between `consultations` and `medicines`) | `clinic.consultation_medicines` |
| D8 Health Clearances      | `health_clearances` entity (M:1 with `students`)                                          | `clinic.health_clearances`      |

**Key Differences:**

- **Sources/sinks** (Student, Nurse, Doctor, Faculty, Admin) are **roles** within the `users` entity — they do **not** appear as separate ERD entities
- **DFD processes** (e.g., "Record Consultation") do **not** map to ERD relationships; processes describe transformations, while ERD relationships describe associations
- **Data flows** describe movement and transformation; **ERD attributes** describe static data structure

---

### 13. Use Cases for Each DFD Type

| DFD Type                | When to Use                                                                               | Primary Audience                          |
| ----------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------- |
| **Logical Context**     | Initial requirements gathering, stakeholder presentations, business process documentation | Business analysts, stakeholders, managers |
| **Logical Level 0**     | Detailed requirements specification, identifying business processes, user story mapping   | Business analysts, product owners, QA     |
| **Logical Child (L1+)** | Complex process decomposition, detailed business rules, process optimization              | Business analysts, process engineers      |
| **Physical Context**    | System architecture overview, technology selection justification, deployment planning     | Solution architects, CTOs                 |
| **Physical Level 0**    | System design, API specification, database schema design, security planning               | Software architects, lead developers      |
| **Physical Child**      | Component design, implementation planning, code structure, integration specifications     | Developers, database administrators       |

---

### 14. Summary: Key Takeaways

✅ **Logical DFDs** focus on WHAT the system does:

- Business processes and data transformations
- Technology-independent
- Essential for requirements validation
- Bridge between business needs and technical solution

✅ **Physical DFDs** focus on HOW the system works:

- Specific technologies, protocols, and formats
- Implementation-ready specifications
- Guide for developers and system administrators
- Bridge between design and implementation

✅ **Both are essential:**

- Logical DFDs validate business requirements
- Physical DFDs guide implementation
- Together they provide complete system documentation
- Must be kept synchronized as system evolves

✅ **For the School Clinic Management System:**

- **Logical:** Check-in, consultations, prescriptions, medical history
- **Physical:** PostgreSQL + pgcrypto, React, Node.js, QR scanners, JWT, HTTPS
- **Security:** Multi-layered (transport, authentication, RLS, encryption, views)
- **Compliance:** HIPAA-ready with encrypted PHI and audit trails

---

## Appendix: Quick Reference

### Logical DFD Symbols (Technology-Independent)

```
┌─────────────┐
│   Student   │  ← External Entity (Source/Sink)
└─────────────┘

     ( 1.0 )
    ( Check )     ← Process (Business Activity)
     ( In  )

   ───────►       ← Data Flow (Information)

  | D1 Users |   ← Data Store (Logical Collection)
```

### Physical DFD Annotations (Technology-Specific)

```
┌──────────────────┐
│  Student Browser │  ← Physical Device/Interface
│  (React App)     │
└──────────────────┘

     ( 2.0 QR       )
    ( CheckInService)  ← Program/Module/Component
     (  Node.js API  )

   ──HTTPS POST──►     ← Protocol + Format

  | PostgreSQL      |  ← Physical Database
  | clinic.qr_codes |
  | (indexed UUID)  |
```

### Encryption Workflow (Physical Implementation)

1. **Input:** User enters diagnosis (plain text) in React form
2. **Transport:** HTTPS POST to `/api/consultations` (encrypted in transit)
3. **Processing:** Node.js middleware validates and prepares data
4. **Encryption:** PostgreSQL function `pgp_sym_encrypt('diagnosis text', key)` → BYTEA
5. **Storage:** Stored in `clinic.consultations.diagnosis_encrypted` column
6. **Retrieval:** Authorized user queries view (e.g., `v_student_medical_history`)
7. **Decryption:** `pgp_sym_decrypt(diagnosis_encrypted, key)` → plain text (RLS enforced)
8. **Response:** JSON sent via HTTPS, rendered by React

---

**Document Version:** 2.0  
**Last Updated:** February 15, 2026  
**Authors:** Medical System Development Team  
**Status:** Complete — Logical & Physical DFDs Documented
