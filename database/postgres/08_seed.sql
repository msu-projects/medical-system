-- ============================================================================
-- 08_seed.sql
-- School Clinic Management System — Sample Data for Testing
-- ============================================================================
-- Run AFTER 07_audit.sql:
--   psql -U postgres -d school_clinic_db -f 08_seed.sql
-- ============================================================================
-- This seed data demonstrates all security features:
--   - Users across all 5 roles
--   - Students with profiles and QR codes
--   - Encrypted consultations and prescriptions
--   - Medicine dispensing records
--   - Health clearances (pending, cleared, not_cleared)
--
-- IMPORTANT: Set the encryption key BEFORE running this file:
--   SELECT set_config('app.encryption_key', 'dev-secret-key-change-in-prod', false);
-- ============================================================================

SET search_path TO clinic, public;

-- ============================================================================
-- Set session variables for seed data insertion
-- ============================================================================
SELECT set_config('app.encryption_key', 'dev-secret-key-change-in-prod', false);
SELECT set_config('app.current_user_id', '1', false);

-- ============================================================================
-- 1. USERS — All Roles
-- ============================================================================
-- Passwords are bcrypt-hashed. In this seed: all passwords are 'password123'
-- Hash generated with: SELECT crypt('password123', gen_salt('bf'));

INSERT INTO clinic.users (username, password_hash, email, first_name, last_name, role) VALUES
    -- Admins
    ('admin',        crypt('password123', gen_salt('bf')), 'admin@school.edu',        'System',      'Administrator', 'admin'),

    -- Doctors
    ('dr.santos',    crypt('password123', gen_salt('bf')), 'santos@school.edu',       'Maria',       'Santos',        'doctor'),
    ('dr.reyes',     crypt('password123', gen_salt('bf')), 'reyes@school.edu',        'Jose',        'Reyes',         'doctor'),

    -- Nurses
    ('nurse.garcia', crypt('password123', gen_salt('bf')), 'garcia@school.edu',       'Ana',         'Garcia',        'nurse'),
    ('nurse.cruz',   crypt('password123', gen_salt('bf')), 'cruz@school.edu',         'Pedro',       'Cruz',          'nurse'),

    -- Students (user_id 6-10)
    ('juan.delacruz',  crypt('password123', gen_salt('bf')), 'juan@student.school.edu',   'Juan',        'Dela Cruz',     'student'),
    ('maria.clara',    crypt('password123', gen_salt('bf')), 'maria@student.school.edu',  'Maria Clara', 'Reyes',         'student'),
    ('andres.boni',    crypt('password123', gen_salt('bf')), 'andres@student.school.edu', 'Andres',      'Bonifacio',     'student'),
    ('gabby.silang',   crypt('password123', gen_salt('bf')), 'gabby@student.school.edu',  'Gabriela',    'Silang',        'student'),
    ('jose.rizal',     crypt('password123', gen_salt('bf')), 'jose@student.school.edu',   'Jose',        'Rizal',         'student'),

    -- Faculty (user_id 11-12)
    ('prof.luna',    crypt('password123', gen_salt('bf')), 'luna@school.edu',         'Antonio',     'Luna',          'faculty'),
    ('prof.mabini',  crypt('password123', gen_salt('bf')), 'mabini@school.edu',       'Apolinario',  'Mabini',        'faculty');

-- ============================================================================
-- 2. STUDENTS — Extended Profiles
-- ============================================================================

INSERT INTO clinic.students (user_id, year_of_enrollment, date_of_birth, sex, contact_number, emergency_contact_name, emergency_contact_number, year_level, section, blood_type, allergies) VALUES
    (6,  2024, '2006-03-15', 'Male',   '09171234567', 'Maria Dela Cruz',    '09181234567', 'Grade 11', 'STEM-A',    'O+',  NULL),
    (7,  2024, '2006-07-22', 'Female', '09172345678', 'Pedro Reyes',        '09182345678', 'Grade 11', 'STEM-A',    'A+',  'Penicillin'),
    (8,  2024, '2005-11-30', 'Male',   '09173456789', 'Catalina Bonifacio', '09183456789', 'Grade 12', 'HUMSS-B',   'B+',  NULL),
    (9,  2024, '2006-01-10', 'Female', '09174567890', 'Diego Silang',       '09184567890', 'Grade 11', 'ABM-A',     'AB+', 'Sulfa drugs, Ibuprofen'),
    (10, 2024, '2005-06-19', 'Male',   '09175678901', 'Teodora Alonso',     '09185678901', 'Grade 12', 'STEM-B',    'O-',  NULL);

-- ============================================================================
-- 3. QR CODES — One per Student
-- ============================================================================

INSERT INTO clinic.qr_codes (student_id) VALUES
    (1), (2), (3), (4), (5);

-- ============================================================================
-- 4. MEDICINES — Basic Catalog
-- ============================================================================

INSERT INTO clinic.medicines (name, description, unit) VALUES
    ('Paracetamol 500mg',     'For fever and mild pain relief',         'tablet'),
    ('Ibuprofen 200mg',       'Anti-inflammatory and pain relief',      'tablet'),
    ('Mefenamic Acid 500mg',  'For moderate pain and dysmenorrhea',     'capsule'),
    ('Cetirizine 10mg',       'Antihistamine for allergies',            'tablet'),
    ('Loperamide 2mg',        'For acute diarrhea',                     'capsule'),
    ('Oral Rehydration Salts','For dehydration',                        'sachet'),
    ('Betadine Solution',     'Antiseptic for wounds',                  'ml'),
    ('Band-Aid',              'Adhesive bandage for minor wounds',      'piece'),
    ('Cotton Balls',          'For wound cleaning and dressing',        'piece'),
    ('Amoxicillin 500mg',     'Antibiotic (requires prescription)',     'capsule');

-- ============================================================================
-- 5. CONSULTATIONS — Encrypted Medical Records
-- ============================================================================
-- Using the helper function which auto-encrypts diagnosis and treatment_notes.

-- Consultation 1: Juan — headache and fever (attended by Nurse Garcia)
SELECT set_config('app.current_user_id', '4', true);  -- Nurse Garcia

SELECT clinic.create_consultation(
    p_student_id      := 1,
    p_attended_by     := 4,
    p_chief_complaint := 'Headache and fever since this morning',
    p_diagnosis       := 'Acute viral upper respiratory tract infection',
    p_treatment_notes := 'Temperature 38.5C on arrival. Given Paracetamol 500mg. Advised to rest in clinic for 30 minutes. Temperature down to 37.2C before discharge. Advised to drink plenty of fluids. Return if fever persists beyond 3 days.',
    p_vitals_bp       := '110/70',
    p_vitals_temp     := 38.5,
    p_vitals_pulse    := 92,
    p_vitals_weight   := 58.0
);

-- Consultation 2: Maria Clara — allergic reaction (attended by Nurse Garcia)
SELECT clinic.create_consultation(
    p_student_id      := 2,
    p_attended_by     := 4,
    p_chief_complaint := 'Skin rashes and itching after eating seafood',
    p_diagnosis       := 'Allergic dermatitis — likely food allergen (seafood)',
    p_treatment_notes := 'Hives on forearms and neck. No respiratory distress. Given Cetirizine 10mg. Noted existing Penicillin allergy in records. Advised to avoid seafood. Rashes subsiding after 1 hour. Discharged with instructions.',
    p_vitals_bp       := '100/65',
    p_vitals_temp     := 36.8,
    p_vitals_pulse    := 78,
    p_vitals_weight   := 50.0
);

-- Consultation 3: Andres — sports injury (attended by Nurse Cruz)
SELECT set_config('app.current_user_id', '5', true);  -- Nurse Cruz

SELECT clinic.create_consultation(
    p_student_id      := 3,
    p_attended_by     := 5,
    p_chief_complaint := 'Twisted ankle during basketball practice',
    p_diagnosis       := 'Grade 1 ankle sprain — lateral ligament',
    p_treatment_notes := 'Swelling on right lateral ankle. RICE protocol applied. Cold compress for 15 minutes. Elastic bandage wrap. Referred to Dr. Santos for further evaluation. No weight bearing advised.',
    p_vitals_bp       := '125/80',
    p_vitals_temp     := 36.6,
    p_vitals_pulse    := 88,
    p_vitals_weight   := 68.0
);

-- Update consultation 3 status to 'referred'
UPDATE clinic.consultations SET status = 'referred' WHERE consultation_id = 3;

-- Consultation 4: Gabriela — menstrual cramps (attended by Nurse Garcia)
SELECT set_config('app.current_user_id', '4', true);  -- Nurse Garcia

SELECT clinic.create_consultation(
    p_student_id      := 4,
    p_attended_by     := 4,
    p_chief_complaint := 'Severe abdominal cramps since class started',
    p_diagnosis       := 'Dysmenorrhea (primary)',
    p_treatment_notes := 'Noted allergy to Ibuprofen — used Mefenamic Acid instead. Given Mefenamic Acid 500mg. Hot compress applied to abdomen. Rested in clinic for 45 minutes. Pain subsided from 8/10 to 3/10. Discharged.',
    p_vitals_bp       := '105/68',
    p_vitals_temp     := 36.9,
    p_vitals_pulse    := 82,
    p_vitals_weight   := 52.0
);

-- Consultation 5: Jose — stomach ache (attended by Nurse Cruz)
SELECT set_config('app.current_user_id', '5', true);  -- Nurse Cruz

SELECT clinic.create_consultation(
    p_student_id      := 5,
    p_attended_by     := 5,
    p_chief_complaint := 'Stomach pain and nausea after lunch',
    p_diagnosis       := 'Acute gastritis — likely dietary cause',
    p_treatment_notes := 'Epigastric tenderness on palpation. No vomiting. Given ORS. Monitored for 1 hour. Symptoms improving. Advised bland diet for 24 hours. Return if symptoms worsen.',
    p_vitals_bp       := '118/75',
    p_vitals_temp     := 37.1,
    p_vitals_pulse    := 80,
    p_vitals_weight   := 62.0
);

-- Consultation 6: Juan again — follow-up (attended by Nurse Garcia, 3 days later)
SELECT set_config('app.current_user_id', '4', true);

SELECT clinic.create_consultation(
    p_student_id      := 1,
    p_attended_by     := 4,
    p_chief_complaint := 'Follow-up: fever resolved but still has mild cough',
    p_diagnosis       := 'Resolving URTI with residual cough',
    p_treatment_notes := 'Afebrile today. Mild productive cough. Lungs clear on auscultation. Advised to continue fluids. No medication given. Referred to Dr. Santos for prescription if cough persists.',
    p_vitals_bp       := '115/72',
    p_vitals_temp     := 36.7,
    p_vitals_pulse    := 76,
    p_vitals_weight   := 58.0
);

-- Mark completed consultations
UPDATE clinic.consultations SET status = 'completed' WHERE consultation_id IN (1, 2, 4, 5);

-- ============================================================================
-- 6. PRESCRIPTIONS — Doctor-Issued (Encrypted)
-- ============================================================================

SELECT set_config('app.current_user_id', '2', true);  -- Dr. Santos

-- Prescription for Andres (ankle sprain — consultation 3)
SELECT clinic.create_prescription(
    p_consultation_id      := 3,
    p_prescribed_by        := 2,
    p_prescription_details := 'Ibuprofen 200mg — 1 tablet every 8 hours for 5 days with food. Apply cold compress 3x daily for 15 minutes.',
    p_notes                := 'Follow up in 1 week. If swelling worsens or unable to bear weight after 48 hours, refer to orthopedic specialist. X-ray not indicated at this time.'
);

-- Prescription for Juan (persistent cough — consultation 6)
SELECT clinic.create_prescription(
    p_consultation_id      := 6,
    p_prescribed_by        := 2,
    p_prescription_details := 'Carbocisteine 500mg — 1 capsule 3x daily for 7 days. Increase fluid intake.',
    p_notes                := 'Cough likely post-infectious. If persists beyond 2 weeks, chest X-ray recommended.'
);

SELECT set_config('app.current_user_id', '3', true);  -- Dr. Reyes

-- Prescription for Gabriela (dysmenorrhea — consultation 4)
SELECT clinic.create_prescription(
    p_consultation_id      := 4,
    p_prescribed_by        := 3,
    p_prescription_details := 'Mefenamic Acid 500mg — 1 capsule every 8 hours as needed for pain during menstruation. NOTE: Patient allergic to Ibuprofen.',
    p_notes                := 'Recurring dysmenorrhea. If pain consistently >7/10, consider referral to OB-GYN for evaluation. Avoid NSAIDs containing Ibuprofen — documented allergy.'
);

-- ============================================================================
-- 7. MEDICINES DISPENSED — Per Consultation
-- ============================================================================

INSERT INTO clinic.consultation_medicines (consultation_id, medicine_id, quantity_given, dispensed_by) VALUES
    -- Consultation 1 (Juan — fever): Paracetamol
    (1, 1, 2, 4),
    -- Consultation 2 (Maria — allergy): Cetirizine
    (2, 4, 1, 4),
    -- Consultation 3 (Andres — sprain): Ibuprofen
    (3, 2, 3, 5),
    -- Consultation 4 (Gabriela — cramps): Mefenamic Acid
    (4, 3, 2, 4),
    -- Consultation 5 (Jose — stomach): ORS
    (5, 6, 2, 5),
    -- Consultation 3 (Andres — sprain): also cotton + bandage for wrap
    (3, 8, 3, 5),
    (3, 9, 5, 5);

-- ============================================================================
-- 8. HEALTH CLEARANCES
-- ============================================================================

SELECT set_config('app.current_user_id', '11', true);  -- Prof. Luna

-- Faculty requests clearance for field trip
INSERT INTO clinic.health_clearances (student_id, purpose, requested_by) VALUES
    (1, 'Field trip to Science Museum — March 2026',  11),
    (2, 'Field trip to Science Museum — March 2026',  11),
    (3, 'Field trip to Science Museum — March 2026',  11);

-- Faculty requests sports clearance
INSERT INTO clinic.health_clearances (student_id, purpose, requested_by) VALUES
    (3, 'Interschool Basketball Tournament — April 2026', 11);

SELECT set_config('app.current_user_id', '12', true);  -- Prof. Mabini

INSERT INTO clinic.health_clearances (student_id, purpose, requested_by) VALUES
    (5, 'School camping activity — March 2026', 12);

-- Doctor processes some clearances
SELECT set_config('app.current_user_id', '2', true);  -- Dr. Santos

UPDATE clinic.health_clearances
SET status = 'cleared', issued_by = 2, valid_until = '2026-03-31', remarks = 'Fit for participation'
WHERE clearance_id = 1;

UPDATE clinic.health_clearances
SET status = 'cleared', issued_by = 2, valid_until = '2026-03-31', remarks = 'Fit for participation. Note: patient has Penicillin allergy — ensure first aid kit has alternative medications.'
WHERE clearance_id = 2;

-- Andres not cleared for field trip (ankle sprain still recovering)
UPDATE clinic.health_clearances
SET status = 'not_cleared', issued_by = 2, remarks = 'Not cleared — recovering from Grade 1 ankle sprain. Re-evaluate in 2 weeks.'
WHERE clearance_id = 3;

-- ============================================================================
-- 9. VERIFICATION QUERIES
-- ============================================================================
-- After seeding, run these to verify:

-- Check user counts by role:
-- SELECT role, COUNT(*) FROM clinic.users GROUP BY role ORDER BY role;

-- Verify encryption (should show binary data, NOT readable text):
-- SELECT consultation_id, diagnosis FROM clinic.consultations LIMIT 3;

-- Verify decryption works:
-- SELECT set_config('app.encryption_key', 'dev-secret-key-change-in-prod', true);
-- SELECT consultation_id, clinic.decrypt_data(diagnosis) AS diagnosis FROM clinic.consultations;

-- Check audit trail was populated:
-- SELECT table_name, operation, COUNT(*) FROM audit.activity_log GROUP BY table_name, operation ORDER BY table_name;

-- Test RLS as student Juan (user_id=6):
-- SET ROLE clinic_student;
-- SELECT set_config('app.current_user_id', '6', true);
-- SELECT set_config('app.encryption_key', 'dev-secret-key-change-in-prod', true);
-- SELECT * FROM clinic.v_student_medical_history;  -- Should see only Juan's records
-- RESET ROLE;

-- Test faculty view:
-- SET ROLE clinic_faculty;
-- SELECT set_config('app.current_user_id', '11', true);
-- SELECT * FROM clinic.v_faculty_clearance;  -- Should see clearance status only
-- RESET ROLE;

-- ============================================================================
