-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- PRE-DEPLOYMENT SAFETY CHECK
-- File: 0000_preflight_clean_install.sql
--
-- Run this BEFORE 0001_foundation.sql on a NEW/CLEAN project.
-- It intentionally aborts if project-specific application tables
-- already exist. The 0001-0010 migration set is a clean-install
-- baseline, not an in-place upgrade from the legacy schema.
-- ============================================================

DO $$
DECLARE
    v_existing TEXT[];
BEGIN
    SELECT array_agg(x.name ORDER BY x.name)
    INTO v_existing
    FROM (
        SELECT name
        FROM unnest(ARRAY[
            'schools',
            'people',
            'profiles',
            'roles',
            'permissions',
            'role_permissions',
            'user_roles',
            'media',
            'teachers',
            'staff',
            'students',
            'classes',
            'job_positions',
            'job_assignments',
            'homeroom_assignments',
            'school_leadership_assignments',
            'pages',
            'news',
            'announcements',
            'events',
            'galleries',
            'gallery_media',
            'document_categories',
            'documents',
            'site_settings',
            'achievement_types',
            'achievement_levels',
            'achievements',
            'achievement_recipients',
            'public_people',
            'public_documents'
        ]) AS name
        WHERE to_regclass('public.' || name) IS NOT NULL
    ) x;

    IF v_existing IS NOT NULL THEN
        RAISE EXCEPTION
            'PRE-FLIGHT FAILED: existing application tables found: %. Do not run the clean-install migration set on top of an existing/legacy schema.',
            array_to_string(v_existing, ', ')
            USING ERRCODE = '55000';
    END IF;

    IF to_regclass('auth.users') IS NULL THEN
        RAISE EXCEPTION
            'PRE-FLIGHT FAILED: auth.users not found. This migration set expects a Supabase project.'
            USING ERRCODE = '55000';
    END IF;

    IF to_regclass('storage.objects') IS NULL
       OR to_regclass('storage.buckets') IS NULL THEN
        RAISE EXCEPTION
            'PRE-FLIGHT FAILED: Supabase Storage schema not found.'
            USING ERRCODE = '55000';
    END IF;

    RAISE NOTICE 'PRE-FLIGHT PASS: clean Supabase project detected.';
END
$$;
