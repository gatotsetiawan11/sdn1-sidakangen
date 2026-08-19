-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
-- File: 0010_security_tests.sql
-- ============================================================

BEGIN;

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- RLS enabled on required base tables.
    SELECT COUNT(*) INTO v_count
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY (ARRAY[
          'schools','people','roles','permissions','role_permissions',
          'profiles','user_roles','media','teachers','staff','students',
          'classes','job_positions','job_assignments',
          'homeroom_assignments','school_leadership_assignments',
          'pages','news','announcements','events','galleries',
          'gallery_media','document_categories','documents','site_settings',
          'achievement_types','achievement_levels','achievements',
          'achievement_recipients'
      ])
      AND c.relrowsecurity = FALSE;

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: % required public tables lack RLS',
            v_count;
    END IF;

    -- Legacy public_people must not exist.
    IF to_regclass('public.public_people') IS NOT NULL THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: legacy public.public_people exists';
    END IF;

    -- Legacy Profile columns must not exist.
    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name IN ('role_id', 'display_name', 'school_id');

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: legacy Profile columns exist';
    END IF;

    -- Student class shortcut must not exist.
    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'students'
      AND column_name IN ('class_id', 'current_class_id');

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: Student class shortcut exists';
    END IF;

    -- Media bucket/public classification must be exact.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'public'
          AND t.relname = 'media'
          AND c.conname = 'media_bucket_visibility_consistency'
    ) THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: media bucket/public consistency constraint missing';
    END IF;

    -- anon must have no base-table privileges.
    SELECT COUNT(*) INTO v_count
    FROM (
        SELECT unnest(ARRAY[
            'schools','people','profiles','roles','permissions',
            'user_roles','role_permissions','teachers','staff','students',
            'classes','media','pages','news','announcements','events',
            'galleries','gallery_media','documents','site_settings',
            'achievements','achievement_recipients'
        ]) AS table_name
    ) x
    WHERE has_table_privilege('anon','public.' || x.table_name,'SELECT')
       OR has_table_privilege('anon','public.' || x.table_name,'INSERT')
       OR has_table_privilege('anon','public.' || x.table_name,'UPDATE')
       OR has_table_privilege('anon','public.' || x.table_name,'DELETE');

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: anon has base-table privileges on % tables',
            v_count;
    END IF;

    -- No direct anon policies on protected base tables.
    SELECT COUNT(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY (ARRAY[
          'schools','people','profiles','roles','permissions',
          'user_roles','role_permissions','teachers','staff','students',
          'classes','media','pages','news','announcements','events',
          'galleries','gallery_media','documents','site_settings',
          'achievements','achievement_recipients'
      ])
      AND 'anon' = ANY(roles);

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: anon RLS policies exist on base tables';
    END IF;

    IF has_function_privilege(
        'anon',
        'public.has_permission(text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: anon can execute has_permission()';
    END IF;

    IF has_function_privilege(
        'anon',
        'public._public_school_id()',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: anon can directly execute _public_school_id()';
    END IF;

    IF has_function_privilege(
        'anon',
        'public._public_media_json(uuid)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: anon can directly execute _public_media_json()';
    END IF;

    -- Essential public RPC grants.
    IF NOT has_function_privilege('anon','public.get_public_school()','EXECUTE') THEN
        RAISE EXCEPTION 'SECURITY TEST FAILED: get_public_school not public';
    END IF;

    IF NOT has_function_privilege('anon','public.list_public_teachers()','EXECUTE') THEN
        RAISE EXCEPTION 'SECURITY TEST FAILED: list_public_teachers not public';
    END IF;

    IF NOT has_function_privilege(
        'anon',
        'public.list_public_news(integer,integer)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'SECURITY TEST FAILED: list_public_news not public';
    END IF;

    IF NOT has_function_privilege(
        'anon',
        'public.list_public_achievements(integer,integer)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'SECURITY TEST FAILED: list_public_achievements not public';
    END IF;

    -- All required V1 public RPC functions must exist.
    SELECT COUNT(DISTINCT p.proname)
    INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY (ARRAY[
          'get_public_school',
          'list_public_teachers',
          'get_public_page',
          'list_public_news',
          'get_public_news',
          'list_public_announcements',
          'get_public_announcement',
          'list_public_events',
          'get_public_event',
          'list_public_galleries',
          'get_public_gallery',
          'list_public_documents',
          'list_public_achievements'
      ]);

    IF v_count <> 13 THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: expected 13 public RPC names, found %',
            v_count;
    END IF;

    -- Public RPC must be SECURITY DEFINER.
    SELECT COUNT(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY (ARRAY[
          'get_public_school',
          'list_public_teachers',
          'get_public_page',
          'list_public_news',
          'get_public_news',
          'list_public_announcements',
          'get_public_announcement',
          'list_public_events',
          'get_public_event',
          'list_public_galleries',
          'get_public_gallery',
          'list_public_documents',
          'list_public_achievements'
      ])
      AND p.prosecdef = FALSE;

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: % public RPC are not SECURITY DEFINER',
            v_count;
    END IF;

    -- Storage buckets.
    IF NOT EXISTS (
        SELECT 1 FROM storage.buckets
        WHERE id = 'public-media' AND public = TRUE
    ) THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: public-media bucket missing/not public';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM storage.buckets
        WHERE id = 'private-media' AND public = FALSE
    ) THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: private-media bucket missing/not private';
    END IF;

    -- No anon Storage write policy.
    SELECT COUNT(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND 'anon' = ANY(roles)
      AND cmd IN ('INSERT','UPDATE','DELETE','ALL');

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: anon Storage write policy exists';
    END IF;

    -- Direct authenticated public-media upload must require publication authority.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname = 'school_media_authenticated_insert'
          AND position('content.publish' IN COALESCE(with_check, '')) > 0
    ) THEN
        RAISE EXCEPTION
            'SECURITY TEST FAILED: public-media upload is not gated by publication authority';
    END IF;

    RAISE NOTICE 'STATIC SECURITY POSTURE: PASS';
END
$$;

SELECT 'PASS' AS static_security_posture, NOW() AS checked_at;

-- Dynamic behavioral tests still required with real JWT sessions:
-- anon base-table query denied
-- approved public RPC allowed
-- draft/archived content not returned
-- Operator cannot publish by default
-- School Admin can publish
-- Achievement verify/publish lifecycle enforced
-- duplicate active assignments denied
-- private Storage object denied to anon
-- content using required private Media cannot publish

ROLLBACK;

-- END OF 0010_security_tests.sql
