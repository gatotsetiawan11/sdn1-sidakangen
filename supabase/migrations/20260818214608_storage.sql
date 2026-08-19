-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
-- File: 0008_storage.sql
-- ============================================================

BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES
    ('public-media', 'public-media', TRUE),
    ('private-media', 'private-media', FALSE)
ON CONFLICT (id)
DO UPDATE SET
    name = EXCLUDED.name,
    public = EXCLUDED.public;

DROP POLICY IF EXISTS school_media_authenticated_insert ON storage.objects;
DROP POLICY IF EXISTS school_media_authenticated_select ON storage.objects;

CREATE POLICY school_media_authenticated_insert
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    public.has_permission('media.upload')
    AND (
        bucket_id = 'private-media'
        OR (
            bucket_id = 'public-media'
            AND public.has_permission('content.publish')
        )
    )
);


-- V1 rule:
--   OPERATOR/media.upload users upload draft/internal assets to private-media.
--   Direct browser upload to public-media additionally requires content.publish.
--   This prevents media.upload alone from making an object publicly retrievable.

CREATE POLICY school_media_authenticated_select
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id IN ('public-media', 'private-media')
    AND public.has_permission('media.view')
);

-- Intentionally absent:
--   anon INSERT
--   normal UPDATE/upsert
--   normal browser DELETE
--
-- Replacement:
--   upload new object -> update Media reference -> archive old Media.
-- Physical cleanup is trusted maintenance.

COMMIT;

-- END OF 0008_storage.sql
