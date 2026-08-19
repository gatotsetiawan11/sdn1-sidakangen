-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
-- File: 0007_public_api.sql
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public._public_school_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT s.id
    FROM public.schools s
    WHERE s.is_active = TRUE
    ORDER BY s.created_at, s.id
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public._public_school_id() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public._public_media_json(p_media_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT jsonb_build_object(
        'media_type', m.media_type::TEXT,
        'mime_type', m.mime_type,
        'width', m.width,
        'height', m.height,
        'alt_text', m.alt_text,
        'caption', m.caption,
        'bucket', m.storage_bucket,
        'path', m.storage_path
    )
    FROM public.media m
    WHERE m.id = p_media_id
      AND m.is_public = TRUE
      AND m.archived_at IS NULL
      AND m.storage_bucket = 'public-media'
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public._public_media_json(UUID) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.get_public_school()
RETURNS TABLE (
    name TEXT,
    slug TEXT,
    description TEXT,
    vision TEXT,
    mission TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    logo JSONB,
    tagline TEXT,
    site_description TEXT,
    favicon JSONB,
    homepage_config JSONB,
    social_links JSONB,
    theme_config JSONB
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        s.name,
        s.slug,
        s.description,
        s.vision,
        s.mission,
        s.address,
        s.phone,
        s.email,
        s.website,
        public._public_media_json(s.logo_media_id),
        ss.tagline,
        ss.site_description,
        public._public_media_json(ss.favicon_media_id),
        COALESCE(ss.homepage_config, '{}'::jsonb),
        COALESCE(ss.social_links, '{}'::jsonb),
        COALESCE(ss.theme_config, '{}'::jsonb)
    FROM public.schools s
    LEFT JOIN public.site_settings ss ON ss.school_id = s.id
    WHERE s.id = public._public_school_id()
    ORDER BY s.created_at
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.list_public_teachers()
RETURNS TABLE (
    display_name TEXT,
    photo JSONB,
    public_position TEXT,
    class_name TEXT,
    display_order INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        pe.full_name,
        public._public_media_json(pe.photo_media_id),
        COALESCE(
            leadership.position_name,
            CASE
                WHEN homeroom.class_name IS NOT NULL
                THEN 'Guru Kelas ' || homeroom.class_name
            END,
            general_position.position_name,
            'Guru'
        ),
        homeroom.class_name,
        COALESCE(leadership.display_order, 9999)
    FROM public.teachers t
    JOIN public.people pe ON pe.id = t.person_id
    JOIN public.schools s ON s.id = pe.school_id
    LEFT JOIN LATERAL (
        SELECT jp.name AS position_name, sla.display_order
        FROM public.school_leadership_assignments sla
        JOIN public.job_positions jp ON jp.id = sla.job_position_id
        WHERE sla.person_id = pe.id
          AND sla.start_date <= CURRENT_DATE
          AND (sla.end_date IS NULL OR sla.end_date >= CURRENT_DATE)
          AND jp.is_active = TRUE
          AND jp.position_kind = 'LEADERSHIP'
        ORDER BY sla.display_order, jp.name
        LIMIT 1
    ) leadership ON TRUE
    LEFT JOIN LATERAL (
        SELECT c.name AS class_name
        FROM public.homeroom_assignments ha
        JOIN public.classes c ON c.id = ha.class_id
        WHERE ha.teacher_id = t.id
          AND ha.start_date <= CURRENT_DATE
          AND (ha.end_date IS NULL OR ha.end_date >= CURRENT_DATE)
          AND c.is_active = TRUE
        ORDER BY c.grade_level, c.name
        LIMIT 1
    ) homeroom ON TRUE
    LEFT JOIN LATERAL (
        SELECT jp.name AS position_name
        FROM public.job_assignments ja
        JOIN public.job_positions jp ON jp.id = ja.job_position_id
        WHERE ja.person_id = pe.id
          AND ja.start_date <= CURRENT_DATE
          AND (ja.end_date IS NULL OR ja.end_date >= CURRENT_DATE)
          AND jp.is_active = TRUE
          AND jp.position_kind = 'GENERAL'
        ORDER BY jp.name
        LIMIT 1
    ) general_position ON TRUE
    WHERE t.is_active = TRUE
      AND pe.is_active = TRUE
      AND s.id = public._public_school_id()
      AND (
          leadership.position_name IS NOT NULL
          OR homeroom.class_name IS NOT NULL
          OR general_position.position_name IS NOT NULL
      )
    ORDER BY
        COALESCE(leadership.display_order, 9999),
        pe.full_name;
$$;

CREATE OR REPLACE FUNCTION public.get_public_page(p_slug TEXT)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    excerpt TEXT,
    content TEXT,
    featured_media JSONB,
    published_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        p.slug,
        p.title,
        p.excerpt,
        p.content,
        public._public_media_json(p.featured_media_id),
        p.published_at
    FROM public.pages p
    JOIN public.schools s ON s.id = p.school_id
    WHERE p.slug = p_slug
      AND p.status = 'published'
      AND s.id = public._public_school_id()
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.list_public_news(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    excerpt TEXT,
    featured_media JSONB,
    published_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        n.slug,
        n.title,
        n.excerpt,
        public._public_media_json(n.featured_media_id),
        n.published_at
    FROM public.news n
    JOIN public.schools s ON s.id = n.school_id
    WHERE n.status = 'published'
      AND s.id = public._public_school_id()
    ORDER BY n.published_at DESC, n.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100))
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

CREATE OR REPLACE FUNCTION public.get_public_news(p_slug TEXT)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    excerpt TEXT,
    content TEXT,
    featured_media JSONB,
    published_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        n.slug,
        n.title,
        n.excerpt,
        n.content,
        public._public_media_json(n.featured_media_id),
        n.published_at
    FROM public.news n
    JOIN public.schools s ON s.id = n.school_id
    WHERE n.slug = p_slug
      AND n.status = 'published'
      AND s.id = public._public_school_id()
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.list_public_announcements(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    excerpt TEXT,
    content TEXT,
    priority INTEGER,
    featured_media JSONB,
    published_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        a.slug,
        a.title,
        a.excerpt,
        a.content,
        a.priority,
        public._public_media_json(a.featured_media_id),
        a.published_at,
        a.expires_at
    FROM public.announcements a
    JOIN public.schools s ON s.id = a.school_id
    WHERE a.status = 'published'
      AND (a.expires_at IS NULL OR a.expires_at > NOW())
      AND s.id = public._public_school_id()
    ORDER BY a.priority DESC, a.published_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100))
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

CREATE OR REPLACE FUNCTION public.get_public_announcement(p_slug TEXT)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    excerpt TEXT,
    content TEXT,
    priority INTEGER,
    featured_media JSONB,
    published_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        a.slug,
        a.title,
        a.excerpt,
        a.content,
        a.priority,
        public._public_media_json(a.featured_media_id),
        a.published_at,
        a.expires_at
    FROM public.announcements a
    JOIN public.schools s ON s.id = a.school_id
    WHERE a.slug = p_slug
      AND a.status = 'published'
      AND (a.expires_at IS NULL OR a.expires_at > NOW())
      AND s.id = public._public_school_id()
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.list_public_events(
    p_from TIMESTAMPTZ DEFAULT NULL,
    p_to TIMESTAMPTZ DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    description TEXT,
    location TEXT,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    is_all_day BOOLEAN,
    featured_media JSONB,
    published_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        e.slug,
        e.title,
        e.description,
        e.location,
        e.starts_at,
        e.ends_at,
        e.is_all_day,
        public._public_media_json(e.featured_media_id),
        e.published_at
    FROM public.events e
    JOIN public.schools s ON s.id = e.school_id
    WHERE e.status = 'published'
      AND s.id = public._public_school_id()
      AND (p_from IS NULL OR COALESCE(e.ends_at, e.starts_at) >= p_from)
      AND (p_to IS NULL OR e.starts_at <= p_to)
    ORDER BY e.starts_at
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100));
$$;

CREATE OR REPLACE FUNCTION public.get_public_event(p_slug TEXT)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    description TEXT,
    location TEXT,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    is_all_day BOOLEAN,
    featured_media JSONB,
    published_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        e.slug,
        e.title,
        e.description,
        e.location,
        e.starts_at,
        e.ends_at,
        e.is_all_day,
        public._public_media_json(e.featured_media_id),
        e.published_at
    FROM public.events e
    JOIN public.schools s ON s.id = e.school_id
    WHERE e.slug = p_slug
      AND e.status = 'published'
      AND s.id = public._public_school_id()
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.list_public_galleries(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    description TEXT,
    cover_media JSONB,
    published_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        g.slug,
        g.title,
        g.description,
        public._public_media_json(g.cover_media_id),
        g.published_at
    FROM public.galleries g
    JOIN public.schools s ON s.id = g.school_id
    WHERE g.status = 'published'
      AND s.id = public._public_school_id()
    ORDER BY g.published_at DESC, g.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100))
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

CREATE OR REPLACE FUNCTION public.get_public_gallery(p_slug TEXT)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    description TEXT,
    cover_media JSONB,
    published_at TIMESTAMPTZ,
    items JSONB
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        g.slug,
        g.title,
        g.description,
        public._public_media_json(g.cover_media_id),
        g.published_at,
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'media', public._public_media_json(gm.media_id),
                        'sort_order', gm.sort_order,
                        'caption', gm.caption
                    )
                    ORDER BY gm.sort_order, gm.created_at
                )
                FROM public.gallery_media gm
                JOIN public.media m ON m.id = gm.media_id
                WHERE gm.gallery_id = g.id
                  AND m.is_public = TRUE
                  AND m.archived_at IS NULL
                  AND m.storage_bucket = 'public-media'
            ),
            '[]'::jsonb
        )
    FROM public.galleries g
    JOIN public.schools s ON s.id = g.school_id
    WHERE g.slug = p_slug
      AND g.status = 'published'
      AND s.id = public._public_school_id()
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.list_public_documents(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    slug TEXT,
    title TEXT,
    description TEXT,
    category_name TEXT,
    media JSONB,
    published_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        d.slug,
        d.title,
        d.description,
        dc.name,
        public._public_media_json(d.media_id),
        d.published_at
    FROM public.documents d
    JOIN public.schools s ON s.id = d.school_id
    LEFT JOIN public.document_categories dc ON dc.id = d.category_id
    JOIN public.media m ON m.id = d.media_id
    WHERE d.status = 'published'
      AND d.visibility = 'public'
      AND m.is_public = TRUE
      AND m.archived_at IS NULL
      AND m.storage_bucket = 'public-media'
      AND s.id = public._public_school_id()
    ORDER BY d.published_at DESC, d.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100))
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

CREATE OR REPLACE FUNCTION public.list_public_achievements(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    title TEXT,
    description TEXT,
    competition_name TEXT,
    organizer TEXT,
    achievement_date DATE,
    team_name TEXT,
    type_name TEXT,
    level_name TEXT,
    featured_media JSONB,
    published_at TIMESTAMPTZ,
    recipients JSONB
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        a.title,
        a.description,
        a.competition_name,
        a.organizer,
        a.achievement_date,
        a.team_name,
        at.name,
        al.name,
        public._public_media_json(a.featured_media_id),
        a.published_at,
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object('display_name', pe.full_name)
                    ORDER BY ar.display_order, pe.full_name
                )
                FROM public.achievement_recipients ar
                JOIN public.students st ON st.id = ar.student_id
                JOIN public.people pe ON pe.id = st.person_id
                WHERE ar.achievement_id = a.id
                  AND st.is_active = TRUE
                  AND pe.is_active = TRUE
            ),
            '[]'::jsonb
        )
    FROM public.achievements a
    JOIN public.schools s ON s.id = a.school_id
    LEFT JOIN public.achievement_types at ON at.id = a.achievement_type_id
    LEFT JOIN public.achievement_levels al ON al.id = a.achievement_level_id
    WHERE a.status = 'published'
      AND s.id = public._public_school_id()
    ORDER BY a.achievement_date DESC NULLS LAST, a.published_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100))
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

-- Revoke default PUBLIC execution
REVOKE ALL ON FUNCTION public.get_public_school() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_public_teachers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_public_page(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_public_news(INTEGER, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_public_news(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_public_announcements(INTEGER, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_public_announcement(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_public_events(TIMESTAMPTZ, TIMESTAMPTZ, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_public_event(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_public_galleries(INTEGER, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_public_gallery(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_public_documents(INTEGER, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_public_achievements(INTEGER, INTEGER) FROM PUBLIC;

-- Explicit public interface
GRANT EXECUTE ON FUNCTION public.get_public_school() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_teachers() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_page(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_news(INTEGER, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_news(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_announcements(INTEGER, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_announcement(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_events(TIMESTAMPTZ, TIMESTAMPTZ, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_event(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_galleries(INTEGER, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_gallery(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_documents(INTEGER, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_public_achievements(INTEGER, INTEGER) TO anon, authenticated;

COMMIT;

-- END OF 0007_public_api.sql
