-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
--
-- File: 0002_domain.sql
-- Purpose:
--   Core school-domain entities used by Website/CMS V1:
--   teachers, staff, students, classes, job positions,
--   job assignments, homeroom assignments, and leadership
--   assignments.
--
-- Source of truth:
--   PROJECT_FINAL_HANDOFF_PRE_MIGRATION.md
--
-- IMPORTANT:
--   1. People remains the canonical human identity.
--   2. Domain tables must not duplicate identity fields.
--   3. Classes are active in V1, but Student Enrollment is deferred.
--   4. Do NOT add students.current_class_id.
--   5. Subjects, Teaching Assignments, Assessment, and Grades remain deferred.
--   6. Cross-table domain validation is added later in
--      0005_functions_triggers.sql.
--   7. RLS policies are created later in 0006_rls.sql.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. TEACHERS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL UNIQUE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT teachers_person_fk
        FOREIGN KEY (person_id)
        REFERENCES public.people(id)
        ON DELETE RESTRICT
);

-- ============================================================
-- 2. STAFF
--
-- Staff is a domain marker for non-teaching personnel.
-- A teacher with an additional administrative duty does not
-- automatically need a staff row; use job_assignments instead.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL UNIQUE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT staff_person_fk
        FOREIGN KEY (person_id)
        REFERENCES public.people(id)
        ON DELETE RESTRICT
);

-- ============================================================
-- 3. STUDENTS
--
-- V1 intentionally does NOT store class_id/current_class_id.
-- Student-to-class history remains deferred until Enrollment is
-- explicitly activated in a future migration.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL UNIQUE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT students_person_fk
        FOREIGN KEY (person_id)
        REFERENCES public.people(id)
        ON DELETE RESTRICT
);

-- ============================================================
-- 4. CLASSES
--
-- Classes are active for school structure and homeroom assignment.
-- They are NOT yet the source of a student's current class.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    school_id UUID NOT NULL,

    name TEXT NOT NULL,
    grade_level SMALLINT NOT NULL,
    section TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT classes_school_fk
        FOREIGN KEY (school_id)
        REFERENCES public.schools(id)
        ON DELETE RESTRICT,

    CONSTRAINT classes_name_not_empty
        CHECK (length(trim(name)) > 0),

    CONSTRAINT classes_grade_level_valid
        CHECK (grade_level BETWEEN 1 AND 6),

    CONSTRAINT classes_section_not_empty
        CHECK (
            section IS NULL
            OR length(trim(section)) > 0
        ),

    CONSTRAINT classes_school_name_unique
        UNIQUE (school_id, name)
);

-- ============================================================
-- 5. JOB POSITIONS
--
-- position_kind:
--   GENERAL     -> public.job_assignments
--   LEADERSHIP  -> public.school_leadership_assignments
--
-- Generic teacher membership belongs to public.teachers and
-- should not be duplicated as a job position merely to say
-- someone is a teacher.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.job_positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    school_id UUID NOT NULL,

    code TEXT NOT NULL,
    name TEXT NOT NULL,

    position_kind TEXT NOT NULL,

    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT job_positions_school_fk
        FOREIGN KEY (school_id)
        REFERENCES public.schools(id)
        ON DELETE RESTRICT,

    CONSTRAINT job_positions_code_not_empty
        CHECK (length(trim(code)) > 0),

    CONSTRAINT job_positions_name_not_empty
        CHECK (length(trim(name)) > 0),

    CONSTRAINT job_positions_kind_valid
        CHECK (
            position_kind IN ('GENERAL', 'LEADERSHIP')
        ),

    CONSTRAINT job_positions_school_code_unique
        UNIQUE (school_id, code),

    CONSTRAINT job_positions_school_name_unique
        UNIQUE (school_id, name)
);

-- ============================================================
-- 6. JOB ASSIGNMENTS
--
-- Used only for GENERAL job positions.
-- Same-school and position_kind validation is implemented later
-- by domain-validation triggers.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.job_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL,
    job_position_id UUID NOT NULL,

    start_date DATE NOT NULL,
    end_date DATE,

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT job_assignments_person_fk
        FOREIGN KEY (person_id)
        REFERENCES public.people(id)
        ON DELETE RESTRICT,

    CONSTRAINT job_assignments_position_fk
        FOREIGN KEY (job_position_id)
        REFERENCES public.job_positions(id)
        ON DELETE RESTRICT,

    CONSTRAINT job_assignments_date_order
        CHECK (
            end_date IS NULL
            OR end_date >= start_date
        )
);

-- Prevent duplicate open-ended active assignments for the same
-- person and position.
CREATE UNIQUE INDEX IF NOT EXISTS job_assignments_active_unique
    ON public.job_assignments (person_id, job_position_id)
    WHERE end_date IS NULL;

-- ============================================================
-- 7. HOMEROOM ASSIGNMENTS
--
-- Homeroom teacher is an assignment, not a role.
-- V1 rules:
--   - one active homeroom teacher per class
--   - one active homeroom class per teacher
--
-- Historical rows remain valid through start_date/end_date.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.homeroom_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    teacher_id UUID NOT NULL,
    class_id UUID NOT NULL,

    start_date DATE NOT NULL,
    end_date DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT homeroom_assignments_teacher_fk
        FOREIGN KEY (teacher_id)
        REFERENCES public.teachers(id)
        ON DELETE RESTRICT,

    CONSTRAINT homeroom_assignments_class_fk
        FOREIGN KEY (class_id)
        REFERENCES public.classes(id)
        ON DELETE RESTRICT,

    CONSTRAINT homeroom_assignments_date_order
        CHECK (
            end_date IS NULL
            OR end_date >= start_date
        )
);

-- One active homeroom teacher per class.
CREATE UNIQUE INDEX IF NOT EXISTS homeroom_active_class_unique
    ON public.homeroom_assignments (class_id)
    WHERE end_date IS NULL;

-- One active homeroom class per teacher.
CREATE UNIQUE INDEX IF NOT EXISTS homeroom_active_teacher_unique
    ON public.homeroom_assignments (teacher_id)
    WHERE end_date IS NULL;

-- ============================================================
-- 8. SCHOOL LEADERSHIP ASSIGNMENTS
--
-- Used only for LEADERSHIP job positions.
-- Same-school and position_kind validation is implemented later
-- by domain-validation triggers.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.school_leadership_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL,
    job_position_id UUID NOT NULL,

    start_date DATE NOT NULL,
    end_date DATE,

    display_order INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT school_leadership_assignments_person_fk
        FOREIGN KEY (person_id)
        REFERENCES public.people(id)
        ON DELETE RESTRICT,

    CONSTRAINT school_leadership_assignments_position_fk
        FOREIGN KEY (job_position_id)
        REFERENCES public.job_positions(id)
        ON DELETE RESTRICT,

    CONSTRAINT school_leadership_assignments_date_order
        CHECK (
            end_date IS NULL
            OR end_date >= start_date
        ),

    CONSTRAINT school_leadership_assignments_display_order_valid
        CHECK (display_order >= 0)
);

-- V1 assumes one active holder for each leadership-position master.
CREATE UNIQUE INDEX IF NOT EXISTS leadership_active_position_unique
    ON public.school_leadership_assignments (job_position_id)
    WHERE end_date IS NULL;

-- ============================================================
-- 9. DOMAIN INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS classes_school_id_idx
    ON public.classes (school_id);

CREATE INDEX IF NOT EXISTS classes_active_grade_idx
    ON public.classes (grade_level, name)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS job_positions_school_id_idx
    ON public.job_positions (school_id);

CREATE INDEX IF NOT EXISTS job_positions_active_kind_idx
    ON public.job_positions (position_kind, name)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS job_assignments_person_id_idx
    ON public.job_assignments (person_id);

CREATE INDEX IF NOT EXISTS job_assignments_job_position_id_idx
    ON public.job_assignments (job_position_id);

CREATE INDEX IF NOT EXISTS homeroom_assignments_teacher_id_idx
    ON public.homeroom_assignments (teacher_id);

CREATE INDEX IF NOT EXISTS homeroom_assignments_class_id_idx
    ON public.homeroom_assignments (class_id);

CREATE INDEX IF NOT EXISTS school_leadership_assignments_person_id_idx
    ON public.school_leadership_assignments (person_id);

CREATE INDEX IF NOT EXISTS school_leadership_assignments_position_id_idx
    ON public.school_leadership_assignments (job_position_id);

CREATE INDEX IF NOT EXISTS school_leadership_display_idx
    ON public.school_leadership_assignments (display_order)
    WHERE end_date IS NULL;

-- ============================================================
-- 10. COMMENTS
-- ============================================================

COMMENT ON TABLE public.teachers IS
'Teacher domain marker referencing canonical people identity. Identity fields must not be duplicated here.';

COMMENT ON TABLE public.staff IS
'Non-teaching staff domain marker referencing canonical people identity. Additional duties for teachers belong in job_assignments.';

COMMENT ON TABLE public.students IS
'Student domain marker referencing canonical people identity. Student class placement is intentionally deferred; do not add current_class_id in V1.';

COMMENT ON TABLE public.classes IS
'School class/rombel master for grades 1-6 and homeroom assignments. Student enrollment/history is deferred.';

COMMENT ON TABLE public.job_positions IS
'School position master. GENERAL positions use job_assignments; LEADERSHIP positions use school_leadership_assignments.';

COMMENT ON TABLE public.job_assignments IS
'Historical assignment of a person to a GENERAL job position. Same-school and position-kind validation is enforced later by triggers.';

COMMENT ON TABLE public.homeroom_assignments IS
'Historical teacher-to-class homeroom assignment. Homeroom is an assignment, not a system role.';

COMMENT ON TABLE public.school_leadership_assignments IS
'Historical assignment of a person to a LEADERSHIP job position. Same-school and position-kind validation is enforced later by triggers.';

-- ============================================================
-- 11. SECURITY NOTE
--
-- RLS is intentionally implemented in 0006_rls.sql.
-- Domain validation that needs cross-table checks is intentionally
-- implemented in 0005_functions_triggers.sql.
-- ============================================================

COMMIT;

-- ============================================================
-- END OF 0002_domain.sql
-- ============================================================
