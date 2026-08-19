-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
--
-- File: 0001_foundation.sql
-- Purpose:
--   Foundation entities, authorization primitives, profile bridge,
--   centralized media metadata, and circular media foreign keys.
--
-- Source of truth:
--   PROJECT_FINAL_HANDOFF_PRE_MIGRATION.md
--
-- IMPORTANT:
--   1. One project = one school.
--   2. People is the canonical human identity.
--   3. Supabase Auth owns authentication credentials.
--   4. Profiles bridge auth.users -> people.
--   5. Roles are multi-valued through user_roles.
--   6. service_role must never be exposed to the browser.
--   7. RLS policies are created later in 0006_rls.sql.
--   8. Public API/RPC is created later in 0007_public_api.sql.
--   9. Storage object policies are created later in 0008_storage.sql.
--  10. Seeds are created later in 0009_seeds.sql.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 2. ENUM TYPES
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'content_status'
          AND typnamespace = 'public'::regnamespace
    ) THEN
        CREATE TYPE public.content_status AS ENUM (
            'draft',
            'published',
            'archived'
        );
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'media_type'
          AND typnamespace = 'public'::regnamespace
    ) THEN
        CREATE TYPE public.media_type AS ENUM (
            'image',
            'document',
            'video',
            'other'
        );
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'achievement_status'
          AND typnamespace = 'public'::regnamespace
    ) THEN
        CREATE TYPE public.achievement_status AS ENUM (
            'draft',
            'verified',
            'published',
            'archived'
        );
    END IF;
END
$$;

-- ============================================================
-- 3. SCHOOLS
--
-- logo_media_id is declared now, but its FK is added only after
-- public.media exists.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,

    description TEXT,
    vision TEXT,
    mission TEXT,

    address TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,

    logo_media_id UUID,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT schools_name_not_empty
        CHECK (length(trim(name)) > 0),

    CONSTRAINT schools_slug_not_empty
        CHECK (length(trim(slug)) > 0),

    CONSTRAINT schools_email_basic_format
        CHECK (
            email IS NULL
            OR email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
        )
);

-- ============================================================
-- 4. PEOPLE
--
-- Canonical human identity.
-- photo_media_id is declared now, but its FK is added after
-- public.media exists.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    school_id UUID NOT NULL,

    full_name TEXT NOT NULL,
    gender TEXT,
    birth_place TEXT,
    birth_date DATE,
    phone TEXT,
    email TEXT,
    address TEXT,

    photo_media_id UUID,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT people_school_fk
        FOREIGN KEY (school_id)
        REFERENCES public.schools(id)
        ON DELETE RESTRICT,

    CONSTRAINT people_full_name_not_empty
        CHECK (length(trim(full_name)) > 0)
);

-- ============================================================
-- 5. ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT roles_code_not_empty
        CHECK (length(trim(code)) > 0),

    CONSTRAINT roles_name_not_empty
        CHECK (length(trim(name)) > 0)
);

-- ============================================================
-- 6. PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT permissions_code_not_empty
        CHECK (length(trim(code)) > 0),

    CONSTRAINT permissions_name_not_empty
        CHECK (length(trim(name)) > 0)
);

-- ============================================================
-- 7. ROLE PERMISSIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id UUID NOT NULL,
    permission_id UUID NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (role_id, permission_id),

    CONSTRAINT role_permissions_role_fk
        FOREIGN KEY (role_id)
        REFERENCES public.roles(id)
        ON DELETE CASCADE,

    CONSTRAINT role_permissions_permission_fk
        FOREIGN KEY (permission_id)
        REFERENCES public.permissions(id)
        ON DELETE CASCADE
);

-- ============================================================
-- 8. PROFILES
--
-- Profile is an account bridge only:
-- auth.users -> profiles -> people
--
-- No role_id.
-- No display_name as canonical human identity.
-- No duplicated school_id.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY,

    person_id UUID NOT NULL UNIQUE,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT profiles_auth_user_fk
        FOREIGN KEY (id)
        REFERENCES auth.users(id)
        ON DELETE CASCADE,

    CONSTRAINT profiles_person_fk
        FOREIGN KEY (person_id)
        REFERENCES public.people(id)
        ON DELETE RESTRICT
);

-- ============================================================
-- 9. USER ROLES
--
-- A profile may have multiple roles.
-- Historical assignments are preserved.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    profile_id UUID NOT NULL,
    role_id UUID NOT NULL,

    start_date DATE,
    end_date DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT user_roles_profile_fk
        FOREIGN KEY (profile_id)
        REFERENCES public.profiles(id)
        ON DELETE CASCADE,

    CONSTRAINT user_roles_role_fk
        FOREIGN KEY (role_id)
        REFERENCES public.roles(id)
        ON DELETE RESTRICT,

    CONSTRAINT user_roles_date_order
        CHECK (
            end_date IS NULL
            OR start_date IS NULL
            OR end_date >= start_date
        )
);

-- Prevent duplicate open-ended active role assignments.
CREATE UNIQUE INDEX IF NOT EXISTS user_roles_active_unique
    ON public.user_roles (profile_id, role_id)
    WHERE end_date IS NULL;

-- ============================================================
-- 10. MEDIA
--
-- Canonical file metadata.
-- Physical files live in Supabase Storage.
--
-- V1 buckets:
--   public-media
--   private-media
--
-- is_public means eligible for public delivery/context.
-- It does NOT publish any CMS/domain resource by itself.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    school_id UUID NOT NULL,

    storage_bucket TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    original_name TEXT NOT NULL,

    mime_type TEXT NOT NULL,
    file_size BIGINT NOT NULL,

    width INTEGER,
    height INTEGER,

    alt_text TEXT,
    caption TEXT,

    media_type public.media_type NOT NULL DEFAULT 'image',

    is_public BOOLEAN NOT NULL DEFAULT FALSE,

    uploaded_by_profile_id UUID,

    archived_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT media_school_fk
        FOREIGN KEY (school_id)
        REFERENCES public.schools(id)
        ON DELETE RESTRICT,

    CONSTRAINT media_uploaded_by_profile_fk
        FOREIGN KEY (uploaded_by_profile_id)
        REFERENCES public.profiles(id)
        ON DELETE SET NULL,

    CONSTRAINT media_storage_bucket_not_empty
        CHECK (length(trim(storage_bucket)) > 0),

    CONSTRAINT media_storage_path_not_empty
        CHECK (length(trim(storage_path)) > 0),

    CONSTRAINT media_original_name_not_empty
        CHECK (length(trim(original_name)) > 0),

    CONSTRAINT media_mime_type_not_empty
        CHECK (length(trim(mime_type)) > 0),

    CONSTRAINT media_file_size_valid
        CHECK (file_size >= 0),

    CONSTRAINT media_width_valid
        CHECK (width IS NULL OR width > 0),

    CONSTRAINT media_height_valid
        CHECK (height IS NULL OR height > 0),

    CONSTRAINT media_bucket_allowed
        CHECK (
            storage_bucket IN ('public-media', 'private-media')
        ),

    CONSTRAINT media_bucket_visibility_consistency
        CHECK (
            (storage_bucket = 'public-media' AND is_public = TRUE)
            OR
            (storage_bucket = 'private-media' AND is_public = FALSE)
        ),

    CONSTRAINT media_storage_object_unique
        UNIQUE (storage_bucket, storage_path)
);

-- ============================================================
-- 11. CIRCULAR MEDIA FOREIGN KEYS
-- ============================================================

ALTER TABLE public.schools
    DROP CONSTRAINT IF EXISTS schools_logo_media_fk;

ALTER TABLE public.schools
    ADD CONSTRAINT schools_logo_media_fk
    FOREIGN KEY (logo_media_id)
    REFERENCES public.media(id)
    ON DELETE SET NULL;

ALTER TABLE public.people
    DROP CONSTRAINT IF EXISTS people_photo_media_fk;

ALTER TABLE public.people
    ADD CONSTRAINT people_photo_media_fk
    FOREIGN KEY (photo_media_id)
    REFERENCES public.media(id)
    ON DELETE SET NULL;

-- Cross-school consistency for these media references is enforced
-- later by validation functions/triggers in 0005_functions_triggers.sql.

-- ============================================================
-- 12. FOUNDATION INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS people_school_id_idx
    ON public.people (school_id);

CREATE INDEX IF NOT EXISTS role_permissions_permission_id_idx
    ON public.role_permissions (permission_id);

CREATE INDEX IF NOT EXISTS user_roles_profile_id_idx
    ON public.user_roles (profile_id);

CREATE INDEX IF NOT EXISTS user_roles_role_id_idx
    ON public.user_roles (role_id);

CREATE INDEX IF NOT EXISTS media_school_id_idx
    ON public.media (school_id);

CREATE INDEX IF NOT EXISTS media_uploaded_by_profile_id_idx
    ON public.media (uploaded_by_profile_id);

CREATE INDEX IF NOT EXISTS media_public_eligible_idx
    ON public.media (school_id, created_at DESC)
    WHERE is_public = TRUE
      AND archived_at IS NULL;

-- ============================================================
-- 13. COMMENTS
-- ============================================================

COMMENT ON TABLE public.schools IS
'Canonical institutional source for the single-school project. Public exposure occurs only through the approved public API.';

COMMENT ON TABLE public.people IS
'Canonical human identity. Teacher, staff, student, profile, and CMS layers must not duplicate human identity fields.';

COMMENT ON TABLE public.profiles IS
'Account bridge from Supabase Auth users to canonical people. Roles are assigned through user_roles.';

COMMENT ON TABLE public.roles IS
'Application authorization role groups. Roles are not school job positions or assignments.';

COMMENT ON TABLE public.permissions IS
'Fine-grained application actions. Resource scope is enforced separately through domain relationships and RLS.';

COMMENT ON TABLE public.user_roles IS
'Historical many-to-many assignment of profiles to application roles.';

COMMENT ON TABLE public.media IS
'Canonical metadata for files stored in Supabase Storage. Media public eligibility does not publish parent resources automatically.';

-- ============================================================
-- 14. SECURITY NOTE
--
-- RLS is intentionally implemented in 0006_rls.sql according to
-- the locked migration plan. Apply 0001 through 0006 as one
-- controlled migration release before exposing the schema to
-- untrusted clients.
-- ============================================================

COMMIT;

-- ============================================================
-- END OF 0001_foundation.sql
-- ============================================================
