# Physical Data Flow Diagram (DFD) Guide: School Clinic Management System

This guide provides all the components and exact instructions you need to draw the Physical Data Flow Diagram (DFD) for your project. A Physical DFD shows _how_ the system is actually implemented, including specific technologies (like PostgreSQL, Web Apps, and Scanners).

---

## 1. Components to Copy-Paste

Use these exact labels for your diagram shapes.

### 🟦 External Entities (Draw as Squares)

_These are the users interacting with your system._

- `Student`
- `Clinic Staff (Nurse)`
- `School Doctor`
- `Faculty (Teacher)`
- `System Admin`

### 🟢 Processes (Draw as Circles or Rounded Rectangles)

_These are the physical software modules/applications._

- `P1: Authentication & Portal Access (Web App)`
- `P2: QR Code Check-in System (Scanner App)`
- `P3: Consultation Management (Clinic Dashboard)`
- `P4: Prescription & Dispensing (Doctor/Nurse Module)`
- `P5: Health Clearance Management (Faculty Portal)`
- `P6: System & User Administration (Admin Panel)`

### 🗄️ Data Stores (Draw as Open-ended Rectangles)

_These are your actual PostgreSQL database tables._

- `D1: clinic.users (PostgreSQL)`
- `D2: clinic.students (PostgreSQL)`
- `D3: clinic.qr_codes (PostgreSQL)`
- `D4: clinic.consultations (PostgreSQL - Encrypted)`
- `D5: clinic.prescriptions (PostgreSQL - Encrypted)`
- `D6: clinic.medicines (PostgreSQL)`
- `D7: clinic.consultation_medicines (PostgreSQL)`
- `D8: clinic.health_clearances (PostgreSQL)`

---

## 2. Arrow Routing & Labeling Instructions

Draw arrows between the components exactly as described below. The text in quotes (`"..."`) is what you should write on the arrow itself.

### 🔐 P1: Authentication & Portal Access

- **Student / Staff / Doctor / Faculty / Admin** ➔ **P1** : `"Login Credentials"`
- **P1** ➔ **D1: clinic.users** : `"Username & Password Hash Query"`
- **D1: clinic.users** ➔ **P1** : `"Auth Status & Role Data"`
- **P1** ➔ **Student / Staff / Doctor / Faculty / Admin** : `"Dashboard Access / Session Token"`

### 📱 P2: QR Code Check-in System

- **Student** ➔ **P2** : `"QR Code Image"`
- **Clinic Staff** ➔ **P2** : `"Scanned QR Code Data"`
- **P2** ➔ **D3: clinic.qr_codes** : `"QR Token (UUID) Validation Request"`
- **D3: clinic.qr_codes** ➔ **P2** : `"Student ID"`
- **P2** ➔ **D2: clinic.students** : `"Student Profile Request"`
- **D2: clinic.students** ➔ **P2** : `"Demographics & Baseline Data"`
- **P2** ➔ **Clinic Staff** : `"Student Profile & Check-in Status"`

### 🩺 P3: Consultation Management

- **Clinic Staff** ➔ **P3** : `"Vitals & Chief Complaint Data"`
- **School Doctor** ➔ **P3** : `"Diagnosis & Treatment Notes"`
- **P3** ➔ **D4: clinic.consultations** : `"Encrypted Consultation Data"`
- **D4: clinic.consultations** ➔ **P3** : `"Consultation History Data"`
- **P3** ➔ **School Doctor / Clinic Staff** : `"Patient Medical History"`
- **P3** ➔ **Student** : `"Personal Consultation Logs"`

### 💊 P4: Prescription & Dispensing

- **School Doctor** ➔ **P4** : `"Prescription Details"`
- **P4** ➔ **D5: clinic.prescriptions** : `"Encrypted Prescription Data"`
- **D6: clinic.medicines** ➔ **P4** : `"Available Medicine List"`
- **Clinic Staff** ➔ **P4** : `"Dispensed Medicines Log"`
- **P4** ➔ **D7: clinic.consultation_medicines** : `"Dispensation Record"`
- **P4** ➔ **D6: clinic.medicines** : `"Stock Update Data"`
- **P4** ➔ **Student** : `"Prescription Records"`

### 📄 P5: Health Clearance Management

- **Faculty** ➔ **P5** : `"Health Clearance Request"`
- **P5** ➔ **D8: clinic.health_clearances** : `"Clearance Request Data"`
- **School Doctor / Clinic Staff** ➔ **P5** : `"Clearance Evaluation Data"`
- **P5** ➔ **D8: clinic.health_clearances** : `"Updated Clearance Record"`
- **D8: clinic.health_clearances** ➔ **P5** : `"Clearance Status Data"`
- **P5** ➔ **Faculty** : `"Student Clearance Status"`
- **P5** ➔ **Student** : `"Medical Certificate Document"`

### ⚙️ P6: System & User Administration

- **System Admin** ➔ **P6** : `"User, Role & Settings Data"`
- **P6** ➔ **D1: clinic.users** : `"New/Updated User Account Data"`
- **P6** ➔ **D2: clinic.students** : `"Imported/Updated Student Records"`
- **P6** ➔ **D3: clinic.qr_codes** : `"Generated/Revoked QR Code Data"`

---

## 💡 Tips for Drawing

1. **Layout:** Place the **Processes (P1-P6)** in the center of your diagram. Put the **External Entities** on the far left and right edges. Put the **Data Stores (D1-D7)** clustered around the processes that use them most.
2. **Physical Details:** Because this is a _Physical_ DFD, make sure to include the text in parentheses (like `PostgreSQL`, `Web App`, `Scanner App`) inside your shapes. This distinguishes it from a Logical DFD.
3. **Crossing Lines:** Try to arrange the data stores to minimize crossing arrows. It's okay to duplicate an External Entity box (e.g., drawing "Student" twice on opposite sides) if it keeps the diagram clean.
