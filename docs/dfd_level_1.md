# DFD Level 1 Guide (Logical)  
## School Clinic Management System

This document gives you a complete, draw-it-yourself guide for the **Level 1 DFDs** of the system.  
Use it to decompose each Level 0 process (`1.0` to `8.0`) into smaller subprocesses (`1.1`, `1.2`, etc.).

---

## 1. What “Level 1” means in this project

- **Context Diagram:** one big process (`0`)
- **Level 0 Diagram:** major processes (`1.0` to `8.0`)
- **Level 1 Diagram:** one child diagram per Level 0 process (for example, `2.0` becomes `2.1`–`2.4`)

**Important balancing rule:** every child diagram must keep the same parent inputs/outputs from Level 0.

---

## 2. Symbols and IDs to use

### External Entities

- `E1 Student`
- `E2 Nurse / Clinic Staff`
- `E3 Doctor`
- `E4 Faculty / Teacher`
- `E5 System Admin`

### Data Stores

- `D1 Users`
- `D2 Students`
- `D3 QR Codes`
- `D4 Consultations`
- `D5 Prescriptions`
- `D6 Medicines`
- `D7 Consultation Medicines`
- `D8 Health Clearances`

---

## 3. How to draw each Level 1 child diagram

1. Title the page: **“Level 1 DFD — Decomposition of X.0 [Process Name]”**.
2. Put all **subprocesses (X.1, X.2, ...)** in the center.
3. Put relevant external entities on left/right edges.
4. Put required data stores at bottom or side.
5. Draw parent-level inbound/outbound flows first (balancing).
6. Add internal flows between subprocesses.
7. Label every arrow with a noun phrase.

---

## 4. Level 1 child diagrams to draw

## 4.0 Decomposition of **8.0 Authentication & Portal Access**

### Subprocesses

- `8.1 Receive Login Credentials`
- `8.2 Validate Account Status`
- `8.3 Verify Password`
- `8.4 Create User Session`
- `8.5 Route User to Portal`

### Parent-balanced flows (must appear)

- `E1 Student -> 8.x : Login Credentials`
- `E2 Nurse / Clinic Staff -> 8.x : Login Credentials`
- `E3 Doctor -> 8.x : Login Credentials`
- `E4 Faculty / Teacher -> 8.x : Login Credentials`
- `E5 System Admin -> 8.x : Login Credentials`
- `D1 Users -> 8.x : User Account and Role Data`
- `8.x -> D1 Users : Last Login Update`
- `8.x -> E1 Student : Student Session and Portal Access`
- `8.x -> E2 Nurse / Clinic Staff : Staff Session and Portal Access`
- `8.x -> E3 Doctor : Doctor Session and Portal Access`
- `8.x -> E4 Faculty / Teacher : Faculty Session and Portal Access`
- `8.x -> E5 System Admin : Admin Session and Portal Access`
- `8.x -> E1 Student / E2 Nurse / E3 Doctor / E4 Faculty / E5 System Admin : Authentication Error`

### Internal flow sequence

- `8.1 -> 8.2 : Credential Lookup Request`
- `8.2 -> 8.3 : Active User Account`
- `8.3 -> 8.4 : Verified User Identity`
- `8.4 -> 8.5 : Session Token and User Role`

### Drawing notes

- Draw all user entities on the left and right edges to show that every role can log in.
- Keep `D1 Users` close to `8.2` because account status and role data come from the user record.
- Use one generic error flow for failed login so the diagram does not reveal whether username or password was wrong.

---

## 4.1 Decomposition of **1.0 Manage Accounts**

Instead of one combined child diagram, draw **four separate Level 1 diagrams** for account CRUD:

- **Diagram A: Add Account**
- **Diagram B: Read Account**
- **Diagram C: Update Account**
- **Diagram D: Delete Account**

### 4.1.A Level 1 DFD — **Add Account**

#### Subprocesses

- `1.1 Receive Add Account Request`
- `1.2 Validate New Account Data`
- `1.3 Create User Account Record`
- `1.4 Create Student Profile and QR (if role=student)`
- `1.5 Return Add Account Result`

#### Parent-balanced flows (must appear)

- `E5 System Admin -> 1.x : New Account Data`
- `1.x -> D1 Users : New User Record`
- `1.x -> D2 Students : New Student Profile`
- `1.x -> D3 QR Codes : New QR Token`
- `1.x -> E5 System Admin : Add Account Result`

#### Internal flow sequence

- `1.1 -> 1.2 : Account Creation Payload`
- `1.2 -> 1.3 : Validated User Data`
- `1.3 -> 1.4 : Student Role Context`
- `1.4 -> 1.5 : Creation Outcome`

### 4.1.B Level 1 DFD — **Read Account**

#### Subprocesses

- `1.6 Receive Read Account Request`
- `1.7 Validate Search Criteria`
- `1.8 Retrieve Account Record`
- `1.9 Build Account View`
- `1.10 Return Account Details`

#### Parent-balanced flows (must appear)

- `E5 System Admin -> 1.x : Account Lookup Request`
- `D1 Users -> 1.x : User Record`
- `D2 Students -> 1.x : Student Profile`
- `D3 QR Codes -> 1.x : QR Token`
- `1.x -> E5 System Admin : Account Details`

#### Internal flow sequence

- `1.6 -> 1.7 : Lookup Input`
- `1.7 -> 1.8 : Validated Lookup Criteria`
- `1.8 -> 1.9 : Retrieved Account Data`
- `1.9 -> 1.10 : Account View Payload`

### 4.1.C Level 1 DFD — **Update Account**

#### Subprocesses

- `1.11 Receive Update Account Request`
- `1.12 Validate Update Data and Rules`
- `1.13 Retrieve Existing Account`
- `1.14 Update User Account Record`
- `1.15 Update Student Profile and QR (if role=student)`
- `1.16 Return Update Result`

#### Parent-balanced flows (must appear)

- `E5 System Admin -> 1.x : Account Update Data`
- `D1 Users -> 1.x : Existing User Record`
- `1.x -> D1 Users : Updated User Record`
- `1.x -> D2 Students : Updated Student Profile`
- `1.x -> D3 QR Codes : Updated QR Token`
- `1.x -> E5 System Admin : Update Account Result`

#### Internal flow sequence

- `1.11 -> 1.12 : Update Payload`
- `1.12 -> 1.13 : Validated Update Request`
- `1.13 -> 1.14 : Current + New Account Data`
- `1.14 -> 1.15 : Student Update Context`
- `1.15 -> 1.16 : Update Outcome`

### 4.1.D Level 1 DFD — **Delete Account**

#### Subprocesses

- `1.17 Receive Delete Account Request`
- `1.18 Validate Delete Authorization`
- `1.19 Retrieve target account`
- `1.20 Deactivate/Delete User Account`
- `1.21 Deactivate Student Profile and QR (if role=student)`
- `1.22 Return Delete Result`

#### Parent-balanced flows (must appear)

- `E5 System Admin -> 1.x : Account Delete Request`
- `D1 Users -> 1.x : Target User Record`
- `1.x -> D1 Users : Deleted/Deactivated User Record`
- `1.x -> D2 Students : Deleted/Deactivated Student Profile`
- `1.x -> D3 QR Codes : Deactivated QR Token`
- `1.x -> E5 System Admin : Delete Account Result`

#### Internal flow sequence

- `1.17 -> 1.18 : Delete Request Data`
- `1.18 -> 1.19 : Authorized Delete Request`
- `1.19 -> 1.20 : Target Account Context`
- `1.20 -> 1.21 : Student Deactivation Context`
- `1.21 -> 1.22 : Delete Outcome`

---

## 4.2 Decomposition of **2.0 Check In Student (QR)**

### Subprocesses

- `2.1 Scan QR Code`
- `2.2 Validate QR Token`
- `2.3 Retrieve Student Profile`
- `2.4 Initialize Check-In Context`

### Parent-balanced flows (must appear)

- `E2 Nurse -> 2.x : QR Scan Input`
- `D3 QR Codes -> 2.x : QR Token Lookup`
- `D2 Students -> 2.x : Student Profile`
- `2.x -> E2 Nurse : Student Profile Display`
- `2.x -> 3.0 Record Consultation : Student & Check-In Info`

### Internal flow sequence

- `2.1 -> 2.2 : QR Token`
- `2.2 -> 2.3 : Valid Student ID`
- `2.3 -> 2.4 : Student Profile Data`

---

## 4.3 Decomposition of **3.0 Record Consultation**

### Subprocesses

- `3.1 Receive Check-In Context`
- `3.2 Capture Complaint and Vitals`
- `3.3 Capture Diagnosis and Treatment Notes`
- `3.4 Save/Update Consultation Record`

### Parent-balanced flows (must appear)

- `2.0 -> 3.x : Student & Check-In Info`
- `E2 Nurse / E3 Doctor -> 3.x : Consultation Data`
- `3.x -> D4 Consultations : Consultation Record`
- `D4 Consultations -> 3.x : Existing Consultation Record`

### Internal flow sequence

- `3.1 -> 3.2 : Active Consultation Context`
- `3.2 -> 3.3 : Clinical Intake Data`
- `3.3 -> 3.4 : Completed Clinical Data`

---

## 4.4 Decomposition of **4.0 Issue Prescription**

### Subprocesses

- `4.1 Receive Prescription Request`
- `4.2 Validate Consultation Reference`
- `4.3 Record Prescription`
- `4.4 Publish Prescription Output`

### Parent-balanced flows (must appear)

- `E3 Doctor -> 4.x : Prescription Details`
- `D4 Consultations -> 4.x : Consultation Reference`
- `4.x -> D5 Prescriptions : Prescription Record`

### Internal flow sequence

- `4.1 -> 4.2 : Prescription Payload`
- `4.2 -> 4.3 : Valid Prescription Data`
- `4.3 -> 4.4 : Saved Prescription`

---

## 4.5 Decomposition of **5.0 Dispense Medicine**

### Subprocesses

- `5.1 Retrieve Medicine List`
- `5.2 Validate Dispense Request`
- `5.3 Record Dispensed Medicines`
- `5.4 Update Medicine Availability`

### Parent-balanced flows (must appear)

- `E2 Nurse -> 5.x : Dispense Info`
- `D6 Medicines -> 5.x : Medicine Catalog`
- `D4 Consultations -> 5.x : Consultation Reference`
- `5.x -> D7 Consultation Medicines : Dispense Record`

### Internal flow sequence

- `5.1 -> 5.2 : Available Medicines`
- `5.2 -> 5.3 : Approved Dispense Data`
- `5.3 -> 5.4 : Dispense Outcome`

---

## 4.6 Decomposition of **6.0 Manage Health Clearance**

### Subprocesses

- `6.1 Receive Clearance Request`
- `6.2 Retrieve Student Medical Context`
- `6.3 Evaluate and Decide Clearance`
- `6.4 Record and Release Clearance Result`

### Parent-balanced flows (must appear)

- `E4 Faculty -> 6.x : Clearance Request`
- `D2 Students -> 6.x : Student Info`
- `E3 Doctor / E2 Nurse -> 6.x : Clearance Decision`
- `6.x -> D8 Health Clearances : Clearance Record`
- `6.x -> E4 Faculty : Clearance Status`

### Internal flow sequence

- `6.1 -> 6.2 : Target Student ID`
- `6.2 -> 6.3 : Student Context`
- `6.3 -> 6.4 : Final Clearance Decision`

---

## 4.7 Decomposition of **7.0 View Medical History**

### Subprocesses

- `7.1 Authenticate Student`
- `7.2 Retrieve Consultation History`
- `7.3 Retrieve Prescriptions and Dispensed Medicines`
- `7.4 Build Medical History View`

### Parent-balanced flows (must appear)

- `E1 Student -> 7.x : Login Credentials`
- `D1 Users -> 7.x : Authentication Result`
- `D4 Consultations -> 7.x : Consultation Records`
- `D5 Prescriptions -> 7.x : Prescription Records`
- `D7 Consultation Medicines -> 7.x : Dispensed Medicines`
- `7.x -> E1 Student : Medical History Display`

### Internal flow sequence

- `7.1 -> 7.2 : Authenticated Student Context`
- `7.2 -> 7.3 : Consultation IDs`
- `7.3 -> 7.4 : Combined Medical Data`

---

## 5. Recommended drawing order (fastest clean workflow)

1. Draw **2.0 child diagram** first (easy and central to the flow).
2. Draw **3.0 child diagram** next (core clinical process).
3. Draw **4.0 + 5.0** (prescription and dispensing).
4. Draw **6.0** (clearances).
5. Draw **8.0** (authentication and portal access).
6. Draw **1.0** and **7.0** last (administration and student view).

---

## 6. Final quality checklist before submission

- [ ] Each child diagram keeps all parent input/output flows (balanced).
- [ ] No flow goes directly entity-to-entity, store-to-store, or entity-to-store.
- [ ] Every process has at least one input and one output.
- [ ] Process names are verb phrases.
- [ ] Flow labels are noun phrases.
- [ ] Store IDs (`D1`–`D8`) and process numbers (`X.1`, `X.2`) are consistent.
