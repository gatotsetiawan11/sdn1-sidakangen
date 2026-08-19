-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
-- File: 0003_cms.sql
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    excerpt TEXT,
    content TEXT NOT NULL,
    featured_media_id UUID,
    status public.content_status NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    created_by_profile_id UUID,
    updated_by_profile_id UUID,
    published_by_profile_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pages_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT pages_featured_media_fk
        FOREIGN KEY (featured_media_id) REFERENCES public.media(id) ON DELETE SET NULL,
    CONSTRAINT pages_created_by_profile_fk
        FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT pages_updated_by_profile_fk
        FOREIGN KEY (updated_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT pages_published_by_profile_fk
        FOREIGN KEY (published_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT pages_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT pages_slug_not_empty CHECK (length(trim(slug)) > 0),
    CONSTRAINT pages_content_not_empty CHECK (length(trim(content)) > 0),
    CONSTRAINT pages_publication_metadata CHECK (
        status <> 'published'
        OR (published_at IS NOT NULL AND published_by_profile_id IS NOT NULL)
    ),
    CONSTRAINT pages_school_slug_unique UNIQUE (school_id, slug)
);

CREATE TABLE IF NOT EXISTS public.news (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    excerpt TEXT,
    content TEXT NOT NULL,
    featured_media_id UUID,
    status public.content_status NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    created_by_profile_id UUID,
    updated_by_profile_id UUID,
    published_by_profile_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT news_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT news_featured_media_fk
        FOREIGN KEY (featured_media_id) REFERENCES public.media(id) ON DELETE SET NULL,
    CONSTRAINT news_created_by_profile_fk
        FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT news_updated_by_profile_fk
        FOREIGN KEY (updated_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT news_published_by_profile_fk
        FOREIGN KEY (published_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT news_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT news_slug_not_empty CHECK (length(trim(slug)) > 0),
    CONSTRAINT news_content_not_empty CHECK (length(trim(content)) > 0),
    CONSTRAINT news_publication_metadata CHECK (
        status <> 'published'
        OR (published_at IS NOT NULL AND published_by_profile_id IS NOT NULL)
    ),
    CONSTRAINT news_school_slug_unique UNIQUE (school_id, slug)
);

CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    excerpt TEXT,
    content TEXT NOT NULL,
    featured_media_id UUID,
    priority INTEGER NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    status public.content_status NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    created_by_profile_id UUID,
    updated_by_profile_id UUID,
    published_by_profile_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT announcements_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT announcements_featured_media_fk
        FOREIGN KEY (featured_media_id) REFERENCES public.media(id) ON DELETE SET NULL,
    CONSTRAINT announcements_created_by_profile_fk
        FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT announcements_updated_by_profile_fk
        FOREIGN KEY (updated_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT announcements_published_by_profile_fk
        FOREIGN KEY (published_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT announcements_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT announcements_slug_not_empty CHECK (length(trim(slug)) > 0),
    CONSTRAINT announcements_content_not_empty CHECK (length(trim(content)) > 0),
    CONSTRAINT announcements_priority_valid CHECK (priority >= 0),
    CONSTRAINT announcements_publication_metadata CHECK (
        status <> 'published'
        OR (published_at IS NOT NULL AND published_by_profile_id IS NOT NULL)
    ),
    CONSTRAINT announcements_school_slug_unique UNIQUE (school_id, slug)
);

CREATE TABLE IF NOT EXISTS public.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    location TEXT,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ,
    is_all_day BOOLEAN NOT NULL DEFAULT FALSE,
    featured_media_id UUID,
    status public.content_status NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    created_by_profile_id UUID,
    updated_by_profile_id UUID,
    published_by_profile_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT events_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT events_featured_media_fk
        FOREIGN KEY (featured_media_id) REFERENCES public.media(id) ON DELETE SET NULL,
    CONSTRAINT events_created_by_profile_fk
        FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT events_updated_by_profile_fk
        FOREIGN KEY (updated_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT events_published_by_profile_fk
        FOREIGN KEY (published_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT events_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT events_slug_not_empty CHECK (length(trim(slug)) > 0),
    CONSTRAINT events_time_order CHECK (ends_at IS NULL OR ends_at >= starts_at),
    CONSTRAINT events_publication_metadata CHECK (
        status <> 'published'
        OR (published_at IS NOT NULL AND published_by_profile_id IS NOT NULL)
    ),
    CONSTRAINT events_school_slug_unique UNIQUE (school_id, slug)
);

CREATE TABLE IF NOT EXISTS public.galleries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    cover_media_id UUID,
    status public.content_status NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    created_by_profile_id UUID,
    updated_by_profile_id UUID,
    published_by_profile_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT galleries_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT galleries_cover_media_fk
        FOREIGN KEY (cover_media_id) REFERENCES public.media(id) ON DELETE SET NULL,
    CONSTRAINT galleries_created_by_profile_fk
        FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT galleries_updated_by_profile_fk
        FOREIGN KEY (updated_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT galleries_published_by_profile_fk
        FOREIGN KEY (published_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT galleries_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT galleries_slug_not_empty CHECK (length(trim(slug)) > 0),
    CONSTRAINT galleries_publication_metadata CHECK (
        status <> 'published'
        OR (published_at IS NOT NULL AND published_by_profile_id IS NOT NULL)
    ),
    CONSTRAINT galleries_school_slug_unique UNIQUE (school_id, slug)
);

CREATE TABLE IF NOT EXISTS public.gallery_media (
    gallery_id UUID NOT NULL,
    media_id UUID NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    caption TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (gallery_id, media_id),

    CONSTRAINT gallery_media_gallery_fk
        FOREIGN KEY (gallery_id) REFERENCES public.galleries(id) ON DELETE CASCADE,
    CONSTRAINT gallery_media_media_fk
        FOREIGN KEY (media_id) REFERENCES public.media(id) ON DELETE RESTRICT,
    CONSTRAINT gallery_media_sort_order_valid CHECK (sort_order >= 0)
);

CREATE TABLE IF NOT EXISTS public.document_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT document_categories_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT document_categories_code_not_empty CHECK (length(trim(code)) > 0),
    CONSTRAINT document_categories_name_not_empty CHECK (length(trim(name)) > 0),
    CONSTRAINT document_categories_school_code_unique UNIQUE (school_id, code),
    CONSTRAINT document_categories_school_name_unique UNIQUE (school_id, name)
);

CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    category_id UUID,
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    media_id UUID NOT NULL,
    visibility TEXT NOT NULL DEFAULT 'public',
    status public.content_status NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    created_by_profile_id UUID,
    updated_by_profile_id UUID,
    published_by_profile_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT documents_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT documents_category_fk
        FOREIGN KEY (category_id) REFERENCES public.document_categories(id) ON DELETE SET NULL,
    CONSTRAINT documents_media_fk
        FOREIGN KEY (media_id) REFERENCES public.media(id) ON DELETE RESTRICT,
    CONSTRAINT documents_created_by_profile_fk
        FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT documents_updated_by_profile_fk
        FOREIGN KEY (updated_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT documents_published_by_profile_fk
        FOREIGN KEY (published_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT documents_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT documents_slug_not_empty CHECK (length(trim(slug)) > 0),
    CONSTRAINT documents_visibility_valid CHECK (
        visibility IN ('public', 'authenticated', 'private')
    ),
    CONSTRAINT documents_publication_metadata CHECK (
        status <> 'published'
        OR (published_at IS NOT NULL AND published_by_profile_id IS NOT NULL)
    ),
    CONSTRAINT documents_school_slug_unique UNIQUE (school_id, slug)
);

CREATE TABLE IF NOT EXISTS public.site_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL UNIQUE,
    tagline TEXT,
    site_description TEXT,
    favicon_media_id UUID,
    homepage_config JSONB NOT NULL DEFAULT '{}'::jsonb,
    social_links JSONB NOT NULL DEFAULT '{}'::jsonb,
    theme_config JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT site_settings_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT site_settings_favicon_media_fk
        FOREIGN KEY (favicon_media_id) REFERENCES public.media(id) ON DELETE SET NULL,
    CONSTRAINT site_settings_homepage_object CHECK (jsonb_typeof(homepage_config) = 'object'),
    CONSTRAINT site_settings_social_links_object CHECK (jsonb_typeof(social_links) = 'object'),
    CONSTRAINT site_settings_theme_object CHECK (jsonb_typeof(theme_config) = 'object')
);

CREATE INDEX IF NOT EXISTS pages_listing_idx
    ON public.pages (status, published_at DESC);

CREATE INDEX IF NOT EXISTS news_listing_idx
    ON public.news (status, published_at DESC);

CREATE INDEX IF NOT EXISTS announcements_listing_idx
    ON public.announcements (status, priority DESC, published_at DESC);

CREATE INDEX IF NOT EXISTS announcements_expiry_idx
    ON public.announcements (expires_at)
    WHERE expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS events_listing_idx
    ON public.events (status, starts_at);

CREATE INDEX IF NOT EXISTS galleries_listing_idx
    ON public.galleries (status, published_at DESC);

CREATE INDEX IF NOT EXISTS gallery_media_sort_idx
    ON public.gallery_media (gallery_id, sort_order);

CREATE INDEX IF NOT EXISTS gallery_media_media_idx
    ON public.gallery_media (media_id);

CREATE INDEX IF NOT EXISTS document_categories_school_idx
    ON public.document_categories (school_id);

CREATE INDEX IF NOT EXISTS documents_listing_idx
    ON public.documents (status, visibility, published_at DESC);

CREATE INDEX IF NOT EXISTS documents_category_idx
    ON public.documents (category_id);

COMMENT ON TABLE public.pages IS
'CMS static/editorial pages. Dynamic listings use dedicated domain tables.';

COMMENT ON TABLE public.news IS
'Internal CMS news records. Anonymous delivery occurs only through approved public API functions.';

COMMENT ON TABLE public.announcements IS
'Internal announcements. Expiry affects public eligibility without requiring a scheduler.';

COMMENT ON TABLE public.events IS
'School events. Upcoming/ongoing/past is derived from timestamps.';

COMMENT ON TABLE public.galleries IS
'Internal gallery albums. Public publication requires eligible media.';

COMMENT ON TABLE public.documents IS
'Website documents with public/authenticated/private visibility.';

COMMENT ON TABLE public.site_settings IS
'Website presentation configuration only. Official School master fields must not be duplicated here.';

COMMIT;

-- END OF 0003_cms.sql
