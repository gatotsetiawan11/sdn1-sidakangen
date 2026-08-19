-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
-- File: 0004_achievement.sql
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.achievement_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT achievement_types_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT achievement_types_code_not_empty CHECK (length(trim(code)) > 0),
    CONSTRAINT achievement_types_name_not_empty CHECK (length(trim(name)) > 0),
    CONSTRAINT achievement_types_school_code_unique UNIQUE (school_id, code),
    CONSTRAINT achievement_types_school_name_unique UNIQUE (school_id, name)
);

CREATE TABLE IF NOT EXISTS public.achievement_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT achievement_levels_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT achievement_levels_code_not_empty CHECK (length(trim(code)) > 0),
    CONSTRAINT achievement_levels_name_not_empty CHECK (length(trim(name)) > 0),
    CONSTRAINT achievement_levels_sort_order_valid CHECK (sort_order >= 0),
    CONSTRAINT achievement_levels_school_code_unique UNIQUE (school_id, code),
    CONSTRAINT achievement_levels_school_name_unique UNIQUE (school_id, name)
);

CREATE TABLE IF NOT EXISTS public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    achievement_type_id UUID,
    achievement_level_id UUID,
    title TEXT NOT NULL,
    description TEXT,
    competition_name TEXT,
    organizer TEXT,
    achievement_date DATE,
    team_name TEXT,
    featured_media_id UUID,
    status public.achievement_status NOT NULL DEFAULT 'draft',
    verified_at TIMESTAMPTZ,
    verified_by_profile_id UUID,
    published_at TIMESTAMPTZ,
    published_by_profile_id UUID,
    created_by_profile_id UUID,
    updated_by_profile_id UUID,
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT achievements_school_fk
        FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE RESTRICT,
    CONSTRAINT achievements_type_fk
        FOREIGN KEY (achievement_type_id) REFERENCES public.achievement_types(id) ON DELETE SET NULL,
    CONSTRAINT achievements_level_fk
        FOREIGN KEY (achievement_level_id) REFERENCES public.achievement_levels(id) ON DELETE SET NULL,
    CONSTRAINT achievements_featured_media_fk
        FOREIGN KEY (featured_media_id) REFERENCES public.media(id) ON DELETE SET NULL,
    CONSTRAINT achievements_verified_by_profile_fk
        FOREIGN KEY (verified_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT achievements_published_by_profile_fk
        FOREIGN KEY (published_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT achievements_created_by_profile_fk
        FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT achievements_updated_by_profile_fk
        FOREIGN KEY (updated_by_profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT achievements_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT achievements_verified_metadata CHECK (
        status NOT IN ('verified', 'published')
        OR (verified_at IS NOT NULL AND verified_by_profile_id IS NOT NULL)
    ),
    CONSTRAINT achievements_published_metadata CHECK (
        status <> 'published'
        OR (
            published_at IS NOT NULL
            AND published_by_profile_id IS NOT NULL
            AND verified_at IS NOT NULL
            AND verified_by_profile_id IS NOT NULL
        )
    ),
    CONSTRAINT achievements_archived_metadata CHECK (
        status <> 'archived' OR archived_at IS NOT NULL
    )
);

CREATE TABLE IF NOT EXISTS public.achievement_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    achievement_id UUID NOT NULL,
    student_id UUID NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT achievement_recipients_achievement_fk
        FOREIGN KEY (achievement_id) REFERENCES public.achievements(id) ON DELETE CASCADE,
    CONSTRAINT achievement_recipients_student_fk
        FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE RESTRICT,
    CONSTRAINT achievement_recipients_display_order_valid CHECK (display_order >= 0),
    CONSTRAINT achievement_recipients_unique_student UNIQUE (achievement_id, student_id)
);

CREATE INDEX IF NOT EXISTS achievement_types_school_idx
    ON public.achievement_types (school_id);

CREATE INDEX IF NOT EXISTS achievement_levels_school_sort_idx
    ON public.achievement_levels (school_id, sort_order);

CREATE INDEX IF NOT EXISTS achievements_listing_idx
    ON public.achievements (status, published_at DESC);

CREATE INDEX IF NOT EXISTS achievements_date_idx
    ON public.achievements (achievement_date DESC);

CREATE INDEX IF NOT EXISTS achievements_type_idx
    ON public.achievements (achievement_type_id);

CREATE INDEX IF NOT EXISTS achievements_level_idx
    ON public.achievements (achievement_level_id);

CREATE INDEX IF NOT EXISTS achievement_recipients_achievement_idx
    ON public.achievement_recipients (achievement_id, display_order);

CREATE INDEX IF NOT EXISTS achievement_recipients_student_idx
    ON public.achievement_recipients (student_id);

COMMENT ON TABLE public.achievements IS
'Internal canonical Achievement with independent verification/publication lifecycle.';

COMMENT ON TABLE public.achievement_recipients IS
'Student recipients. Identity is resolved through students -> people; names are not duplicated here.';

COMMIT;

-- END OF 0004_achievement.sql
