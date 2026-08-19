-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
-- File: 0005_functions_triggers.sql
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.has_permission(required_permission TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles p
        JOIN public.people pe ON pe.id = p.person_id
        JOIN public.schools s ON s.id = pe.school_id
        JOIN public.user_roles ur ON ur.profile_id = p.id
        JOIN public.roles r ON r.id = ur.role_id
        JOIN public.role_permissions rp ON rp.role_id = r.id
        JOIN public.permissions perm ON perm.id = rp.permission_id
        WHERE p.id = auth.uid()
          AND p.is_active = TRUE
          AND pe.is_active = TRUE
          AND s.is_active = TRUE
          AND r.is_active = TRUE
          AND perm.is_active = TRUE
          AND (ur.start_date IS NULL OR ur.start_date <= CURRENT_DATE)
          AND (ur.end_date IS NULL OR ur.end_date >= CURRENT_DATE)
          AND perm.code = required_permission
    );
$$;

CREATE OR REPLACE FUNCTION public.assert_media_reference(
    p_media_id UUID,
    p_school_id UUID,
    p_require_public BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_ok BOOLEAN;
BEGIN
    IF p_media_id IS NULL THEN
        RETURN;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.media m
        WHERE m.id = p_media_id
          AND m.school_id = p_school_id
          AND (
              p_require_public = FALSE
              OR (
                  m.is_public = TRUE
                  AND m.archived_at IS NULL
                  AND m.storage_bucket = 'public-media'
              )
          )
    )
    INTO v_ok;

    IF NOT v_ok THEN
        RAISE EXCEPTION
            'Invalid media reference %, school %, require_public=%',
            p_media_id, p_school_id, p_require_public
            USING ERRCODE = '23514';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_media_same_school()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_media_id UUID;
    v_school_id UUID;
BEGIN
    v_media_id := NULLIF(to_jsonb(NEW) ->> TG_ARGV[0], '')::UUID;
    v_school_id := NULLIF(to_jsonb(NEW) ->> TG_ARGV[1], '')::UUID;

    PERFORM public.assert_media_reference(v_media_id, v_school_id, FALSE);
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_job_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_person_school UUID;
    v_position_school UUID;
    v_kind TEXT;
BEGIN
    SELECT pe.school_id INTO v_person_school
    FROM public.people pe
    WHERE pe.id = NEW.person_id;

    SELECT jp.school_id, jp.position_kind
    INTO v_position_school, v_kind
    FROM public.job_positions jp
    WHERE jp.id = NEW.job_position_id;

    IF v_person_school IS NULL
       OR v_position_school IS NULL
       OR v_person_school <> v_position_school THEN
        RAISE EXCEPTION
            'Person and job position must belong to the same school'
            USING ERRCODE = '23514';
    END IF;

    IF v_kind <> 'GENERAL' THEN
        RAISE EXCEPTION
            'job_assignments only accepts GENERAL positions'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_leadership_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_person_school UUID;
    v_position_school UUID;
    v_kind TEXT;
BEGIN
    SELECT pe.school_id INTO v_person_school
    FROM public.people pe
    WHERE pe.id = NEW.person_id;

    SELECT jp.school_id, jp.position_kind
    INTO v_position_school, v_kind
    FROM public.job_positions jp
    WHERE jp.id = NEW.job_position_id;

    IF v_person_school IS NULL
       OR v_position_school IS NULL
       OR v_person_school <> v_position_school THEN
        RAISE EXCEPTION
            'Person and leadership position must belong to the same school'
            USING ERRCODE = '23514';
    END IF;

    IF v_kind <> 'LEADERSHIP' THEN
        RAISE EXCEPTION
            'school_leadership_assignments only accepts LEADERSHIP positions'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_homeroom_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_teacher_school UUID;
    v_class_school UUID;
BEGIN
    SELECT pe.school_id INTO v_teacher_school
    FROM public.teachers t
    JOIN public.people pe ON pe.id = t.person_id
    WHERE t.id = NEW.teacher_id;

    SELECT c.school_id INTO v_class_school
    FROM public.classes c
    WHERE c.id = NEW.class_id;

    IF v_teacher_school IS NULL
       OR v_class_school IS NULL
       OR v_teacher_school <> v_class_school THEN
        RAISE EXCEPTION
            'Homeroom teacher and class must belong to the same school'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_document_relationships()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_category_school UUID;
BEGIN
    IF NEW.category_id IS NOT NULL THEN
        SELECT dc.school_id INTO v_category_school
        FROM public.document_categories dc
        WHERE dc.id = NEW.category_id;

        IF v_category_school IS NULL
           OR v_category_school <> NEW.school_id THEN
            RAISE EXCEPTION
                'Document category must belong to the same school'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_achievement_relationships()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_school UUID;
BEGIN
    IF NEW.achievement_type_id IS NOT NULL THEN
        SELECT at.school_id INTO v_school
        FROM public.achievement_types at
        WHERE at.id = NEW.achievement_type_id;

        IF v_school IS NULL OR v_school <> NEW.school_id THEN
            RAISE EXCEPTION
                'Achievement type must belong to the same school'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    IF NEW.achievement_level_id IS NOT NULL THEN
        SELECT al.school_id INTO v_school
        FROM public.achievement_levels al
        WHERE al.id = NEW.achievement_level_id;

        IF v_school IS NULL OR v_school <> NEW.school_id THEN
            RAISE EXCEPTION
                'Achievement level must belong to the same school'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_school_id_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.school_id IS DISTINCT FROM OLD.school_id THEN
        RAISE EXCEPTION
            'school_id is immutable after creation in the one-project-one-school V1 model'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.media_has_public_dependency(
    p_media_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.schools s
        WHERE s.logo_media_id = p_media_id
          AND s.is_active = TRUE

        UNION ALL

        SELECT 1
        FROM public.site_settings ss
        JOIN public.schools s ON s.id = ss.school_id
        WHERE ss.favicon_media_id = p_media_id
          AND s.is_active = TRUE

        UNION ALL

        SELECT 1 FROM public.pages p
        WHERE p.featured_media_id = p_media_id
          AND p.status = 'published'

        UNION ALL

        SELECT 1 FROM public.news n
        WHERE n.featured_media_id = p_media_id
          AND n.status = 'published'

        UNION ALL

        SELECT 1 FROM public.announcements a
        WHERE a.featured_media_id = p_media_id
          AND a.status = 'published'
          AND (a.expires_at IS NULL OR a.expires_at > NOW())

        UNION ALL

        SELECT 1 FROM public.events e
        WHERE e.featured_media_id = p_media_id
          AND e.status = 'published'

        UNION ALL

        SELECT 1 FROM public.galleries g
        WHERE g.cover_media_id = p_media_id
          AND g.status = 'published'

        UNION ALL

        SELECT 1
        FROM public.gallery_media gm
        JOIN public.galleries g ON g.id = gm.gallery_id
        WHERE gm.media_id = p_media_id
          AND g.status = 'published'

        UNION ALL

        SELECT 1 FROM public.documents d
        WHERE d.media_id = p_media_id
          AND d.status = 'published'
          AND d.visibility = 'public'

        UNION ALL

        SELECT 1 FROM public.achievements a
        WHERE a.featured_media_id = p_media_id
          AND a.status = 'published'
    );
$$;

CREATE OR REPLACE FUNCTION public.enforce_people_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_old_payload JSONB;
    v_new_payload JSONB;
BEGIN
    IF v_uid IS NULL THEN
        RETURN NEW;
    END IF;

    IF OLD.is_active = TRUE AND NEW.is_active = FALSE THEN
        IF NOT public.has_permission('people.archive') THEN
            RAISE EXCEPTION 'Missing permission: people.archive'
                USING ERRCODE = '42501';
        END IF;

        v_old_payload := to_jsonb(OLD) - ARRAY['is_active','updated_at'];
        v_new_payload := to_jsonb(NEW) - ARRAY['is_active','updated_at'];

        IF v_old_payload IS DISTINCT FROM v_new_payload THEN
            RAISE EXCEPTION
                'Archive operation may not modify other People fields'
                USING ERRCODE = '42501';
        END IF;

        RETURN NEW;
    END IF;

    IF NOT public.has_permission('people.update') THEN
        RAISE EXCEPTION 'Missing permission: people.update'
            USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_media_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_old_payload JSONB;
    v_new_payload JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF v_uid IS NOT NULL THEN
            IF NOT public.has_permission('media.upload') THEN
                RAISE EXCEPTION 'Missing permission: media.upload'
                    USING ERRCODE = '42501';
            END IF;

            -- A public bucket bypasses read RLS for asset delivery.
            -- Therefore normal operators may create private Media only.
            -- V1 public Media creation is restricted to users who also
            -- hold publication authority.
            IF NEW.is_public = TRUE
               AND NOT public.has_permission('content.publish') THEN
                RAISE EXCEPTION
                    'Creating public Media requires publication authority'
                    USING ERRCODE = '42501';
            END IF;

            NEW.uploaded_by_profile_id := v_uid;

            IF NEW.archived_at IS NOT NULL THEN
                RAISE EXCEPTION
                    'New media cannot be created archived'
                    USING ERRCODE = '23514';
            END IF;
        END IF;

        RETURN NEW;
    END IF;

    NEW.uploaded_by_profile_id := OLD.uploaded_by_profile_id;

    -- Storage identity and public/private classification describe the
    -- physical object. Replacement/promotion uses a new Media row rather
    -- than mutating an existing object's bucket/path/classification.
    IF NEW.school_id IS DISTINCT FROM OLD.school_id
       OR NEW.storage_bucket IS DISTINCT FROM OLD.storage_bucket
       OR NEW.storage_path IS DISTINCT FROM OLD.storage_path
       OR NEW.is_public IS DISTINCT FROM OLD.is_public THEN
        RAISE EXCEPTION
            'Media school, bucket, path, and public/private classification are immutable; create a new Media row instead'
            USING ERRCODE = '23514';
    END IF;

    IF v_uid IS NULL THEN
        RETURN NEW;
    END IF;

    IF OLD.archived_at IS NOT NULL THEN
        RAISE EXCEPTION
            'Archived media is immutable in normal workflow'
            USING ERRCODE = '42501';
    END IF;

    IF OLD.archived_at IS NULL AND NEW.archived_at IS NOT NULL THEN
        IF NOT public.has_permission('media.archive') THEN
            RAISE EXCEPTION 'Missing permission: media.archive'
                USING ERRCODE = '42501';
        END IF;

        v_old_payload := to_jsonb(OLD) - ARRAY['archived_at','updated_at'];
        v_new_payload := to_jsonb(NEW) - ARRAY['archived_at','updated_at'];

        IF v_old_payload IS DISTINCT FROM v_new_payload THEN
            RAISE EXCEPTION
                'Media archive transition must be performed separately from metadata changes'
                USING ERRCODE = '42501';
        END IF;

        IF public.media_has_public_dependency(OLD.id) THEN
            RAISE EXCEPTION
                'Media is still required by a currently public resource; detach or unpublish the resource first'
                USING ERRCODE = '23514';
        END IF;

        NEW.archived_at := NOW();
        RETURN NEW;
    END IF;

    IF NOT public.has_permission('media.update') THEN
        RAISE EXCEPTION 'Missing permission: media.update'
            USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_content_publication(
    p_table_name TEXT,
    p_row JSONB
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_school_id UUID;
    v_media_id UUID;
    v_gallery_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_visibility TEXT;
BEGIN
    v_school_id := NULLIF(p_row ->> 'school_id', '')::UUID;

    IF p_table_name IN ('pages', 'news', 'events') THEN
        v_media_id := NULLIF(p_row ->> 'featured_media_id', '')::UUID;
        PERFORM public.assert_media_reference(v_media_id, v_school_id, TRUE);

    ELSIF p_table_name = 'announcements' THEN
        v_media_id := NULLIF(p_row ->> 'featured_media_id', '')::UUID;
        PERFORM public.assert_media_reference(v_media_id, v_school_id, TRUE);

        v_expires_at := NULLIF(p_row ->> 'expires_at', '')::TIMESTAMPTZ;
        IF v_expires_at IS NOT NULL AND v_expires_at <= NOW() THEN
            RAISE EXCEPTION
                'Expired announcement cannot be published'
                USING ERRCODE = '23514';
        END IF;

    ELSIF p_table_name = 'galleries' THEN
        v_media_id := NULLIF(p_row ->> 'cover_media_id', '')::UUID;
        PERFORM public.assert_media_reference(v_media_id, v_school_id, TRUE);

        v_gallery_id := NULLIF(p_row ->> 'id', '')::UUID;

        IF EXISTS (
            SELECT 1
            FROM public.gallery_media gm
            JOIN public.media m ON m.id = gm.media_id
            WHERE gm.gallery_id = v_gallery_id
              AND (
                  m.school_id <> v_school_id
                  OR m.is_public = FALSE
                  OR m.archived_at IS NOT NULL
                  OR m.storage_bucket <> 'public-media'
              )
        ) THEN
            RAISE EXCEPTION
                'All gallery media must be public-eligible before publication'
                USING ERRCODE = '23514';
        END IF;

    ELSIF p_table_name = 'documents' THEN
        v_visibility := p_row ->> 'visibility';

        IF v_visibility = 'public' THEN
            v_media_id := NULLIF(p_row ->> 'media_id', '')::UUID;
            PERFORM public.assert_media_reference(v_media_id, v_school_id, TRUE);
        END IF;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_content_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_old_payload JSONB;
    v_new_payload JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF v_uid IS NOT NULL THEN
            IF NOT public.has_permission('content.create') THEN
                RAISE EXCEPTION 'Missing permission: content.create'
                    USING ERRCODE = '42501';
            END IF;

            IF NEW.status <> 'draft' THEN
                RAISE EXCEPTION
                    'Authenticated CMS content must be created as draft'
                    USING ERRCODE = '23514';
            END IF;

            NEW.created_by_profile_id := v_uid;
            NEW.updated_by_profile_id := NULL;
            NEW.published_by_profile_id := NULL;
            NEW.published_at := NULL;
        END IF;

        RETURN NEW;
    END IF;

    NEW.created_by_profile_id := OLD.created_by_profile_id;

    IF v_uid IS NOT NULL THEN
        NEW.updated_by_profile_id := v_uid;
    END IF;

    IF OLD.status = 'archived' THEN
        RAISE EXCEPTION
            'Archived CMS content is terminal in V1'
            USING ERRCODE = '42501';
    END IF;

    IF OLD.status = 'published' AND NEW.status = 'published' THEN
        RAISE EXCEPTION
            'Published content must be unpublished before editing'
            USING ERRCODE = '42501';
    END IF;

    IF OLD.status <> NEW.status THEN
        v_old_payload :=
            to_jsonb(OLD)
            - ARRAY[
                'status',
                'published_at',
                'published_by_profile_id',
                'updated_by_profile_id',
                'updated_at'
            ];

        v_new_payload :=
            to_jsonb(NEW)
            - ARRAY[
                'status',
                'published_at',
                'published_by_profile_id',
                'updated_by_profile_id',
                'updated_at'
            ];

        IF v_old_payload IS DISTINCT FROM v_new_payload THEN
            RAISE EXCEPTION
                'Lifecycle transition must be separate from editorial changes'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF OLD.status = 'draft' AND NEW.status = 'draft' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('content.update') THEN
            RAISE EXCEPTION 'Missing permission: content.update'
                USING ERRCODE = '42501';
        END IF;

    ELSIF OLD.status = 'draft' AND NEW.status = 'published' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('content.publish') THEN
            RAISE EXCEPTION 'Missing permission: content.publish'
                USING ERRCODE = '42501';
        END IF;

        PERFORM public.validate_content_publication(TG_TABLE_NAME, to_jsonb(NEW));

        IF v_uid IS NOT NULL THEN
            NEW.published_at := NOW();
            NEW.published_by_profile_id := v_uid;
        END IF;

    ELSIF OLD.status = 'published' AND NEW.status = 'draft' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('content.unpublish') THEN
            RAISE EXCEPTION 'Missing permission: content.unpublish'
                USING ERRCODE = '42501';
        END IF;

    ELSIF OLD.status = 'draft' AND NEW.status = 'archived' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('content.archive') THEN
            RAISE EXCEPTION 'Missing permission: content.archive'
                USING ERRCODE = '42501';
        END IF;

    ELSIF OLD.status = 'published' AND NEW.status = 'archived' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('content.archive') THEN
            RAISE EXCEPTION 'Missing permission: content.archive'
                USING ERRCODE = '42501';
        END IF;

    ELSE
        RAISE EXCEPTION
            'Invalid CMS lifecycle transition: % -> %',
            OLD.status, NEW.status
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_gallery_media_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_gallery_id UUID;
    v_media_id UUID;
    v_gallery_school UUID;
    v_media_school UUID;
    v_status public.content_status;
    v_uid UUID := auth.uid();
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_gallery_id := OLD.gallery_id;
        v_media_id := OLD.media_id;
    ELSE
        v_gallery_id := NEW.gallery_id;
        v_media_id := NEW.media_id;
    END IF;

    SELECT g.school_id, g.status
    INTO v_gallery_school, v_status
    FROM public.galleries g
    WHERE g.id = v_gallery_id;

    SELECT m.school_id
    INTO v_media_school
    FROM public.media m
    WHERE m.id = v_media_id;

    IF v_gallery_school IS NULL
       OR v_media_school IS NULL
       OR v_gallery_school <> v_media_school THEN
        RAISE EXCEPTION
            'Gallery and media must belong to the same school'
            USING ERRCODE = '23514';
    END IF;

    IF v_status <> 'draft' THEN
        RAISE EXCEPTION
            'Gallery items may only be modified while Gallery is draft'
            USING ERRCODE = '42501';
    END IF;

    IF v_uid IS NOT NULL
       AND NOT public.has_permission('content.update') THEN
        RAISE EXCEPTION 'Missing permission: content.update'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_achievement_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_old_payload JSONB;
    v_new_payload JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF v_uid IS NOT NULL THEN
            IF NOT public.has_permission('achievement.create') THEN
                RAISE EXCEPTION 'Missing permission: achievement.create'
                    USING ERRCODE = '42501';
            END IF;

            IF NEW.status <> 'draft' THEN
                RAISE EXCEPTION
                    'Authenticated Achievement must be created as draft'
                    USING ERRCODE = '23514';
            END IF;

            NEW.created_by_profile_id := v_uid;
            NEW.updated_by_profile_id := NULL;
            NEW.verified_by_profile_id := NULL;
            NEW.verified_at := NULL;
            NEW.published_by_profile_id := NULL;
            NEW.published_at := NULL;
            NEW.archived_at := NULL;
        END IF;

        RETURN NEW;
    END IF;

    NEW.created_by_profile_id := OLD.created_by_profile_id;

    IF v_uid IS NOT NULL THEN
        NEW.updated_by_profile_id := v_uid;
    END IF;

    IF OLD.status = 'archived' THEN
        RAISE EXCEPTION
            'Archived Achievement is terminal in V1'
            USING ERRCODE = '42501';
    END IF;

    IF OLD.status IN ('verified', 'published')
       AND NEW.status = OLD.status THEN
        RAISE EXCEPTION
            'Verified/published Achievement must be reopened before editing'
            USING ERRCODE = '42501';
    END IF;

    IF OLD.status <> NEW.status THEN
        v_old_payload :=
            to_jsonb(OLD)
            - ARRAY[
                'status',
                'verified_at',
                'verified_by_profile_id',
                'published_at',
                'published_by_profile_id',
                'archived_at',
                'updated_by_profile_id',
                'updated_at'
            ];

        v_new_payload :=
            to_jsonb(NEW)
            - ARRAY[
                'status',
                'verified_at',
                'verified_by_profile_id',
                'published_at',
                'published_by_profile_id',
                'archived_at',
                'updated_by_profile_id',
                'updated_at'
            ];

        IF v_old_payload IS DISTINCT FROM v_new_payload THEN
            RAISE EXCEPTION
                'Achievement lifecycle transition must be separate from data changes'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF OLD.status = 'draft' AND NEW.status = 'draft' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('achievement.update') THEN
            RAISE EXCEPTION 'Missing permission: achievement.update'
                USING ERRCODE = '42501';
        END IF;

    ELSIF OLD.status = 'draft' AND NEW.status = 'verified' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('achievement.verify') THEN
            RAISE EXCEPTION 'Missing permission: achievement.verify'
                USING ERRCODE = '42501';
        END IF;

        IF v_uid IS NOT NULL THEN
            NEW.verified_at := NOW();
            NEW.verified_by_profile_id := v_uid;
        END IF;

    ELSIF OLD.status = 'verified' AND NEW.status = 'published' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('achievement.publish') THEN
            RAISE EXCEPTION 'Missing permission: achievement.publish'
                USING ERRCODE = '42501';
        END IF;

        PERFORM public.assert_media_reference(
            NEW.featured_media_id,
            NEW.school_id,
            TRUE
        );

        IF v_uid IS NOT NULL THEN
            NEW.published_at := NOW();
            NEW.published_by_profile_id := v_uid;
        END IF;

    ELSIF OLD.status = 'published' AND NEW.status = 'verified' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('achievement.unpublish') THEN
            RAISE EXCEPTION 'Missing permission: achievement.unpublish'
                USING ERRCODE = '42501';
        END IF;

    ELSIF OLD.status = 'verified' AND NEW.status = 'draft' THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('achievement.correct') THEN
            RAISE EXCEPTION 'Missing permission: achievement.correct'
                USING ERRCODE = '42501';
        END IF;

    ELSIF NEW.status = 'archived'
          AND OLD.status IN ('draft', 'verified', 'published') THEN
        IF v_uid IS NOT NULL
           AND NOT public.has_permission('achievement.archive') THEN
            RAISE EXCEPTION 'Missing permission: achievement.archive'
                USING ERRCODE = '42501';
        END IF;

        NEW.archived_at := NOW();

    ELSE
        RAISE EXCEPTION
            'Invalid Achievement lifecycle transition: % -> %',
            OLD.status, NEW.status
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_achievement_recipient_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_achievement_id UUID;
    v_student_id UUID;
    v_achievement_school UUID;
    v_student_school UUID;
    v_status public.achievement_status;
    v_uid UUID := auth.uid();
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_achievement_id := OLD.achievement_id;
        v_student_id := OLD.student_id;
    ELSE
        v_achievement_id := NEW.achievement_id;
        v_student_id := NEW.student_id;
    END IF;

    SELECT a.school_id, a.status
    INTO v_achievement_school, v_status
    FROM public.achievements a
    WHERE a.id = v_achievement_id;

    SELECT pe.school_id
    INTO v_student_school
    FROM public.students s
    JOIN public.people pe ON pe.id = s.person_id
    WHERE s.id = v_student_id;

    IF v_achievement_school IS NULL
       OR v_student_school IS NULL
       OR v_achievement_school <> v_student_school THEN
        RAISE EXCEPTION
            'Achievement and Student must belong to the same school'
            USING ERRCODE = '23514';
    END IF;

    IF v_status <> 'draft' THEN
        RAISE EXCEPTION
            'Achievement recipients may only be modified while parent Achievement is draft'
            USING ERRCODE = '42501';
    END IF;

    IF v_uid IS NOT NULL
       AND NOT public.has_permission('achievement_recipient.manage') THEN
        RAISE EXCEPTION
            'Missing permission: achievement_recipient.manage'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

-- school_id immutability for one-project-one-school V1.
DO $$
DECLARE
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'people','classes','job_positions','media',
        'pages','news','announcements','events','galleries',
        'document_categories','documents','site_settings',
        'achievement_types','achievement_levels','achievements'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS a0_%I_school_id_immutable ON public.%I',
            v_table, v_table
        );
        EXECUTE format(
            'CREATE TRIGGER a0_%I_school_id_immutable
             BEFORE UPDATE OF school_id ON public.%I
             FOR EACH ROW EXECUTE FUNCTION public.enforce_school_id_immutable()',
            v_table, v_table
        );
    END LOOP;
END
$$;

-- Media-reference same-school triggers
DROP TRIGGER IF EXISTS a_schools_logo_media_school ON public.schools;
CREATE TRIGGER a_schools_logo_media_school
BEFORE INSERT OR UPDATE OF logo_media_id ON public.schools
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('logo_media_id', 'id');

DROP TRIGGER IF EXISTS a_people_photo_media_school ON public.people;
CREATE TRIGGER a_people_photo_media_school
BEFORE INSERT OR UPDATE OF photo_media_id, school_id ON public.people
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('photo_media_id', 'school_id');

DROP TRIGGER IF EXISTS a_pages_media_school ON public.pages;
CREATE TRIGGER a_pages_media_school
BEFORE INSERT OR UPDATE OF featured_media_id, school_id ON public.pages
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('featured_media_id', 'school_id');

DROP TRIGGER IF EXISTS a_news_media_school ON public.news;
CREATE TRIGGER a_news_media_school
BEFORE INSERT OR UPDATE OF featured_media_id, school_id ON public.news
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('featured_media_id', 'school_id');

DROP TRIGGER IF EXISTS a_announcements_media_school ON public.announcements;
CREATE TRIGGER a_announcements_media_school
BEFORE INSERT OR UPDATE OF featured_media_id, school_id ON public.announcements
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('featured_media_id', 'school_id');

DROP TRIGGER IF EXISTS a_events_media_school ON public.events;
CREATE TRIGGER a_events_media_school
BEFORE INSERT OR UPDATE OF featured_media_id, school_id ON public.events
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('featured_media_id', 'school_id');

DROP TRIGGER IF EXISTS a_galleries_media_school ON public.galleries;
CREATE TRIGGER a_galleries_media_school
BEFORE INSERT OR UPDATE OF cover_media_id, school_id ON public.galleries
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('cover_media_id', 'school_id');

DROP TRIGGER IF EXISTS a_documents_media_school ON public.documents;
CREATE TRIGGER a_documents_media_school
BEFORE INSERT OR UPDATE OF media_id, school_id ON public.documents
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('media_id', 'school_id');

DROP TRIGGER IF EXISTS a_site_settings_media_school ON public.site_settings;
CREATE TRIGGER a_site_settings_media_school
BEFORE INSERT OR UPDATE OF favicon_media_id, school_id ON public.site_settings
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('favicon_media_id', 'school_id');

DROP TRIGGER IF EXISTS a_achievements_media_school ON public.achievements;
CREATE TRIGGER a_achievements_media_school
BEFORE INSERT OR UPDATE OF featured_media_id, school_id ON public.achievements
FOR EACH ROW
EXECUTE FUNCTION public.validate_media_same_school('featured_media_id', 'school_id');

-- Domain validation
DROP TRIGGER IF EXISTS a_job_assignments_validate ON public.job_assignments;
CREATE TRIGGER a_job_assignments_validate
BEFORE INSERT OR UPDATE ON public.job_assignments
FOR EACH ROW EXECUTE FUNCTION public.validate_job_assignment();

DROP TRIGGER IF EXISTS a_leadership_assignments_validate ON public.school_leadership_assignments;
CREATE TRIGGER a_leadership_assignments_validate
BEFORE INSERT OR UPDATE ON public.school_leadership_assignments
FOR EACH ROW EXECUTE FUNCTION public.validate_leadership_assignment();

DROP TRIGGER IF EXISTS a_homeroom_assignments_validate ON public.homeroom_assignments;
CREATE TRIGGER a_homeroom_assignments_validate
BEFORE INSERT OR UPDATE ON public.homeroom_assignments
FOR EACH ROW EXECUTE FUNCTION public.validate_homeroom_assignment();

DROP TRIGGER IF EXISTS a_documents_relationships_validate ON public.documents;
CREATE TRIGGER a_documents_relationships_validate
BEFORE INSERT OR UPDATE OF category_id, school_id ON public.documents
FOR EACH ROW EXECUTE FUNCTION public.validate_document_relationships();

DROP TRIGGER IF EXISTS a_achievement_relationships_validate ON public.achievements;
CREATE TRIGGER a_achievement_relationships_validate
BEFORE INSERT OR UPDATE OF achievement_type_id, achievement_level_id, school_id
ON public.achievements
FOR EACH ROW EXECUTE FUNCTION public.validate_achievement_relationships();

-- Write/lifecycle triggers
DROP TRIGGER IF EXISTS b_people_update_enforce ON public.people;
CREATE TRIGGER b_people_update_enforce
BEFORE UPDATE ON public.people
FOR EACH ROW EXECUTE FUNCTION public.enforce_people_update();

DROP TRIGGER IF EXISTS b_media_write_enforce ON public.media;
CREATE TRIGGER b_media_write_enforce
BEFORE INSERT OR UPDATE ON public.media
FOR EACH ROW EXECUTE FUNCTION public.enforce_media_write();

DO $$
DECLARE
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'pages','news','announcements','events','galleries','documents'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS b_%I_lifecycle ON public.%I',
            v_table, v_table
        );
        EXECUTE format(
            'CREATE TRIGGER b_%I_lifecycle
             BEFORE INSERT OR UPDATE ON public.%I
             FOR EACH ROW EXECUTE FUNCTION public.enforce_content_lifecycle()',
            v_table, v_table
        );
    END LOOP;
END
$$;

DROP TRIGGER IF EXISTS b_gallery_media_write_validate ON public.gallery_media;
CREATE TRIGGER b_gallery_media_write_validate
BEFORE INSERT OR UPDATE OR DELETE ON public.gallery_media
FOR EACH ROW EXECUTE FUNCTION public.validate_gallery_media_write();

DROP TRIGGER IF EXISTS b_achievements_lifecycle ON public.achievements;
CREATE TRIGGER b_achievements_lifecycle
BEFORE INSERT OR UPDATE ON public.achievements
FOR EACH ROW EXECUTE FUNCTION public.enforce_achievement_lifecycle();

DROP TRIGGER IF EXISTS b_achievement_recipients_write_validate
ON public.achievement_recipients;
CREATE TRIGGER b_achievement_recipients_write_validate
BEFORE INSERT OR UPDATE OR DELETE ON public.achievement_recipients
FOR EACH ROW EXECUTE FUNCTION public.validate_achievement_recipient_write();

-- updated_at triggers
DO $$
DECLARE
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'schools','people','roles','permissions','profiles','user_roles','media',
        'teachers','staff','students','classes','job_positions','job_assignments',
        'homeroom_assignments','school_leadership_assignments',
        'pages','news','announcements','events','galleries',
        'document_categories','documents','site_settings',
        'achievement_types','achievement_levels','achievements'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS z_%I_set_updated_at ON public.%I',
            v_table, v_table
        );
        EXECUTE format(
            'CREATE TRIGGER z_%I_set_updated_at
             BEFORE UPDATE ON public.%I
             FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()',
            v_table, v_table
        );
    END LOOP;
END
$$;

-- Function privileges
REVOKE ALL ON FUNCTION public.set_updated_at() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_permission(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assert_media_reference(UUID, UUID, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_media_same_school() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_job_assignment() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_leadership_assignment() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_homeroom_assignment() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_document_relationships() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_achievement_relationships() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_school_id_immutable() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.media_has_public_dependency(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_people_update() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_media_write() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_content_publication(TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_content_lifecycle() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_gallery_media_write() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_achievement_lifecycle() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_achievement_recipient_write() FROM PUBLIC;

REVOKE ALL ON FUNCTION public.has_permission(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT) TO authenticated;

COMMIT;

-- END OF 0005_functions_triggers.sql
