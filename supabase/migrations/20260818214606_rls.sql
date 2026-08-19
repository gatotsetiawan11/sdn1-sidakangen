-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
-- File: 0006_rls.sql
-- ============================================================

BEGIN;

GRANT USAGE ON SCHEMA public TO anon, authenticated;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;

-- Harden future objects created by the migration owner.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

GRANT SELECT, INSERT, UPDATE
ON public.roles, public.permissions, public.user_roles
TO authenticated;

GRANT SELECT, INSERT, DELETE
ON public.role_permissions
TO authenticated;

GRANT SELECT, INSERT, UPDATE
ON public.profiles
TO authenticated;

GRANT SELECT, UPDATE
ON public.schools
TO authenticated;

GRANT SELECT, INSERT, UPDATE
ON public.people, public.teachers, public.staff, public.students,
   public.classes, public.job_positions, public.job_assignments,
   public.homeroom_assignments, public.school_leadership_assignments,
   public.media, public.pages, public.news, public.announcements,
   public.events, public.galleries, public.document_categories,
   public.documents, public.site_settings, public.achievement_types,
   public.achievement_levels, public.achievements
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.gallery_media, public.achievement_recipients
TO authenticated;

-- Enable RLS
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.people ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homeroom_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_leadership_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.galleries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gallery_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievement_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievement_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievement_recipients ENABLE ROW LEVEL SECURITY;

-- Authorization configuration
DROP POLICY IF EXISTS roles_select ON public.roles;
CREATE POLICY roles_select ON public.roles
FOR SELECT TO authenticated
USING (public.has_permission('authorization.view'));

DROP POLICY IF EXISTS roles_insert ON public.roles;
CREATE POLICY roles_insert ON public.roles
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('authorization.manage'));

DROP POLICY IF EXISTS roles_update ON public.roles;
CREATE POLICY roles_update ON public.roles
FOR UPDATE TO authenticated
USING (public.has_permission('authorization.manage'))
WITH CHECK (public.has_permission('authorization.manage'));

DROP POLICY IF EXISTS permissions_select ON public.permissions;
CREATE POLICY permissions_select ON public.permissions
FOR SELECT TO authenticated
USING (public.has_permission('authorization.view'));

DROP POLICY IF EXISTS permissions_insert ON public.permissions;
CREATE POLICY permissions_insert ON public.permissions
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('authorization.manage'));

DROP POLICY IF EXISTS permissions_update ON public.permissions;
CREATE POLICY permissions_update ON public.permissions
FOR UPDATE TO authenticated
USING (public.has_permission('authorization.manage'))
WITH CHECK (public.has_permission('authorization.manage'));

DROP POLICY IF EXISTS user_roles_select ON public.user_roles;
CREATE POLICY user_roles_select ON public.user_roles
FOR SELECT TO authenticated
USING (public.has_permission('authorization.view'));

DROP POLICY IF EXISTS user_roles_insert ON public.user_roles;
CREATE POLICY user_roles_insert ON public.user_roles
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('authorization.manage'));

DROP POLICY IF EXISTS user_roles_update ON public.user_roles;
CREATE POLICY user_roles_update ON public.user_roles
FOR UPDATE TO authenticated
USING (public.has_permission('authorization.manage'))
WITH CHECK (public.has_permission('authorization.manage'));

DROP POLICY IF EXISTS role_permissions_select ON public.role_permissions;
CREATE POLICY role_permissions_select ON public.role_permissions
FOR SELECT TO authenticated
USING (public.has_permission('authorization.view'));

DROP POLICY IF EXISTS role_permissions_insert ON public.role_permissions;
CREATE POLICY role_permissions_insert ON public.role_permissions
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('authorization.manage'));

DROP POLICY IF EXISTS role_permissions_delete ON public.role_permissions;
CREATE POLICY role_permissions_delete ON public.role_permissions
FOR DELETE TO authenticated
USING (public.has_permission('authorization.manage'));

-- Profiles
DROP POLICY IF EXISTS profiles_self_select ON public.profiles;
CREATE POLICY profiles_self_select ON public.profiles
FOR SELECT TO authenticated
USING (id = auth.uid());

DROP POLICY IF EXISTS profiles_admin_select ON public.profiles;
CREATE POLICY profiles_admin_select ON public.profiles
FOR SELECT TO authenticated
USING (public.has_permission('user.view'));

DROP POLICY IF EXISTS profiles_admin_insert ON public.profiles;
CREATE POLICY profiles_admin_insert ON public.profiles
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('user.manage'));

DROP POLICY IF EXISTS profiles_admin_update ON public.profiles;
CREATE POLICY profiles_admin_update ON public.profiles
FOR UPDATE TO authenticated
USING (public.has_permission('user.manage'))
WITH CHECK (public.has_permission('user.manage'));

-- School
DROP POLICY IF EXISTS schools_select ON public.schools;
CREATE POLICY schools_select ON public.schools
FOR SELECT TO authenticated
USING (public.has_permission('school.view'));

DROP POLICY IF EXISTS schools_update ON public.schools;
CREATE POLICY schools_update ON public.schools
FOR UPDATE TO authenticated
USING (public.has_permission('school.update'))
WITH CHECK (public.has_permission('school.update'));

-- People
DROP POLICY IF EXISTS people_select ON public.people;
CREATE POLICY people_select ON public.people
FOR SELECT TO authenticated
USING (public.has_permission('people.view'));

DROP POLICY IF EXISTS people_insert ON public.people;
CREATE POLICY people_insert ON public.people
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('people.create'));

DROP POLICY IF EXISTS people_update ON public.people;
CREATE POLICY people_update ON public.people
FOR UPDATE TO authenticated
USING (
    public.has_permission('people.update')
    OR public.has_permission('people.archive')
)
WITH CHECK (
    public.has_permission('people.update')
    OR public.has_permission('people.archive')
);

-- Teacher / Staff / Student / Class
DROP POLICY IF EXISTS teachers_select ON public.teachers;
CREATE POLICY teachers_select ON public.teachers
FOR SELECT TO authenticated
USING (public.has_permission('teacher.view'));

DROP POLICY IF EXISTS teachers_insert ON public.teachers;
CREATE POLICY teachers_insert ON public.teachers
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('teacher.manage'));

DROP POLICY IF EXISTS teachers_update ON public.teachers;
CREATE POLICY teachers_update ON public.teachers
FOR UPDATE TO authenticated
USING (public.has_permission('teacher.manage'))
WITH CHECK (public.has_permission('teacher.manage'));

DROP POLICY IF EXISTS staff_select ON public.staff;
CREATE POLICY staff_select ON public.staff
FOR SELECT TO authenticated
USING (public.has_permission('staff.view'));

DROP POLICY IF EXISTS staff_insert ON public.staff;
CREATE POLICY staff_insert ON public.staff
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('staff.manage'));

DROP POLICY IF EXISTS staff_update ON public.staff;
CREATE POLICY staff_update ON public.staff
FOR UPDATE TO authenticated
USING (public.has_permission('staff.manage'))
WITH CHECK (public.has_permission('staff.manage'));

DROP POLICY IF EXISTS students_select ON public.students;
CREATE POLICY students_select ON public.students
FOR SELECT TO authenticated
USING (public.has_permission('student.view'));

DROP POLICY IF EXISTS students_insert ON public.students;
CREATE POLICY students_insert ON public.students
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('student.manage'));

DROP POLICY IF EXISTS students_update ON public.students;
CREATE POLICY students_update ON public.students
FOR UPDATE TO authenticated
USING (public.has_permission('student.manage'))
WITH CHECK (public.has_permission('student.manage'));

DROP POLICY IF EXISTS classes_select ON public.classes;
CREATE POLICY classes_select ON public.classes
FOR SELECT TO authenticated
USING (public.has_permission('class.view'));

DROP POLICY IF EXISTS classes_insert ON public.classes;
CREATE POLICY classes_insert ON public.classes
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('class.manage'));

DROP POLICY IF EXISTS classes_update ON public.classes;
CREATE POLICY classes_update ON public.classes
FOR UPDATE TO authenticated
USING (public.has_permission('class.manage'))
WITH CHECK (public.has_permission('class.manage'));

-- Positions
DROP POLICY IF EXISTS job_positions_select ON public.job_positions;
CREATE POLICY job_positions_select ON public.job_positions
FOR SELECT TO authenticated
USING (public.has_permission('position.view'));

DROP POLICY IF EXISTS job_positions_insert ON public.job_positions;
CREATE POLICY job_positions_insert ON public.job_positions
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('position.manage'));

DROP POLICY IF EXISTS job_positions_update ON public.job_positions;
CREATE POLICY job_positions_update ON public.job_positions
FOR UPDATE TO authenticated
USING (public.has_permission('position.manage'))
WITH CHECK (public.has_permission('position.manage'));

-- Assignments
DO $$
DECLARE
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'job_assignments',
        'homeroom_assignments',
        'school_leadership_assignments'
    ]
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I_select ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_select ON public.%I
             FOR SELECT TO authenticated
             USING (public.has_permission(''assignment.view''))',
            v_table, v_table
        );

        EXECUTE format('DROP POLICY IF EXISTS %I_insert ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_insert ON public.%I
             FOR INSERT TO authenticated
             WITH CHECK (public.has_permission(''assignment.manage''))',
            v_table, v_table
        );

        EXECUTE format('DROP POLICY IF EXISTS %I_update ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_update ON public.%I
             FOR UPDATE TO authenticated
             USING (public.has_permission(''assignment.manage''))
             WITH CHECK (public.has_permission(''assignment.manage''))',
            v_table, v_table
        );
    END LOOP;
END
$$;

-- Media
DROP POLICY IF EXISTS media_select ON public.media;
CREATE POLICY media_select ON public.media
FOR SELECT TO authenticated
USING (public.has_permission('media.view'));

DROP POLICY IF EXISTS media_insert ON public.media;
CREATE POLICY media_insert ON public.media
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('media.upload'));

DROP POLICY IF EXISTS media_update ON public.media;
CREATE POLICY media_update ON public.media
FOR UPDATE TO authenticated
USING (
    public.has_permission('media.update')
    OR public.has_permission('media.archive')
)
WITH CHECK (
    public.has_permission('media.update')
    OR public.has_permission('media.archive')
);

-- CMS content
DO $$
DECLARE
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY ARRAY[
        'pages','news','announcements','events','galleries','documents'
    ]
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I_select ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_select ON public.%I
             FOR SELECT TO authenticated
             USING (public.has_permission(''content.view''))',
            v_table, v_table
        );

        EXECUTE format('DROP POLICY IF EXISTS %I_insert ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_insert ON public.%I
             FOR INSERT TO authenticated
             WITH CHECK (public.has_permission(''content.create''))',
            v_table, v_table
        );

        EXECUTE format('DROP POLICY IF EXISTS %I_update ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_update ON public.%I
             FOR UPDATE TO authenticated
             USING (
                 public.has_permission(''content.update'')
                 OR public.has_permission(''content.publish'')
                 OR public.has_permission(''content.unpublish'')
                 OR public.has_permission(''content.archive'')
             )
             WITH CHECK (
                 public.has_permission(''content.update'')
                 OR public.has_permission(''content.publish'')
                 OR public.has_permission(''content.unpublish'')
                 OR public.has_permission(''content.archive'')
             )',
            v_table, v_table
        );
    END LOOP;
END
$$;

DROP POLICY IF EXISTS gallery_media_select ON public.gallery_media;
CREATE POLICY gallery_media_select ON public.gallery_media
FOR SELECT TO authenticated
USING (public.has_permission('content.view'));

DROP POLICY IF EXISTS gallery_media_insert ON public.gallery_media;
CREATE POLICY gallery_media_insert ON public.gallery_media
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('content.update'));

DROP POLICY IF EXISTS gallery_media_update ON public.gallery_media;
CREATE POLICY gallery_media_update ON public.gallery_media
FOR UPDATE TO authenticated
USING (public.has_permission('content.update'))
WITH CHECK (public.has_permission('content.update'));

DROP POLICY IF EXISTS gallery_media_delete ON public.gallery_media;
CREATE POLICY gallery_media_delete ON public.gallery_media
FOR DELETE TO authenticated
USING (public.has_permission('content.update'));

-- Document categories
DROP POLICY IF EXISTS document_categories_select ON public.document_categories;
CREATE POLICY document_categories_select ON public.document_categories
FOR SELECT TO authenticated
USING (public.has_permission('content.view'));

DROP POLICY IF EXISTS document_categories_insert ON public.document_categories;
CREATE POLICY document_categories_insert ON public.document_categories
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('content.update'));

DROP POLICY IF EXISTS document_categories_update ON public.document_categories;
CREATE POLICY document_categories_update ON public.document_categories
FOR UPDATE TO authenticated
USING (public.has_permission('content.update'))
WITH CHECK (public.has_permission('content.update'));

-- Site settings
DROP POLICY IF EXISTS site_settings_select ON public.site_settings;
CREATE POLICY site_settings_select ON public.site_settings
FOR SELECT TO authenticated
USING (public.has_permission('site.view'));

DROP POLICY IF EXISTS site_settings_insert ON public.site_settings;
CREATE POLICY site_settings_insert ON public.site_settings
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('site.update'));

DROP POLICY IF EXISTS site_settings_update ON public.site_settings;
CREATE POLICY site_settings_update ON public.site_settings
FOR UPDATE TO authenticated
USING (public.has_permission('site.update'))
WITH CHECK (public.has_permission('site.update'));

-- Achievement masters
DO $$
DECLARE
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY ARRAY['achievement_types','achievement_levels']
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I_select ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_select ON public.%I
             FOR SELECT TO authenticated
             USING (public.has_permission(''achievement.view''))',
            v_table, v_table
        );

        EXECUTE format('DROP POLICY IF EXISTS %I_insert ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_insert ON public.%I
             FOR INSERT TO authenticated
             WITH CHECK (public.has_permission(''achievement.update''))',
            v_table, v_table
        );

        EXECUTE format('DROP POLICY IF EXISTS %I_update ON public.%I', v_table, v_table);
        EXECUTE format(
            'CREATE POLICY %I_update ON public.%I
             FOR UPDATE TO authenticated
             USING (public.has_permission(''achievement.update''))
             WITH CHECK (public.has_permission(''achievement.update''))',
            v_table, v_table
        );
    END LOOP;
END
$$;

DROP POLICY IF EXISTS achievements_select ON public.achievements;
CREATE POLICY achievements_select ON public.achievements
FOR SELECT TO authenticated
USING (public.has_permission('achievement.view'));

DROP POLICY IF EXISTS achievements_insert ON public.achievements;
CREATE POLICY achievements_insert ON public.achievements
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('achievement.create'));

DROP POLICY IF EXISTS achievements_update ON public.achievements;
CREATE POLICY achievements_update ON public.achievements
FOR UPDATE TO authenticated
USING (
    public.has_permission('achievement.update')
    OR public.has_permission('achievement.verify')
    OR public.has_permission('achievement.publish')
    OR public.has_permission('achievement.unpublish')
    OR public.has_permission('achievement.archive')
    OR public.has_permission('achievement.correct')
)
WITH CHECK (
    public.has_permission('achievement.update')
    OR public.has_permission('achievement.verify')
    OR public.has_permission('achievement.publish')
    OR public.has_permission('achievement.unpublish')
    OR public.has_permission('achievement.archive')
    OR public.has_permission('achievement.correct')
);

DROP POLICY IF EXISTS achievement_recipients_select ON public.achievement_recipients;
CREATE POLICY achievement_recipients_select ON public.achievement_recipients
FOR SELECT TO authenticated
USING (
    public.has_permission('achievement_recipient.view')
    OR public.has_permission('achievement_recipient.manage')
);

DROP POLICY IF EXISTS achievement_recipients_insert ON public.achievement_recipients;
CREATE POLICY achievement_recipients_insert ON public.achievement_recipients
FOR INSERT TO authenticated
WITH CHECK (public.has_permission('achievement_recipient.manage'));

DROP POLICY IF EXISTS achievement_recipients_update ON public.achievement_recipients;
CREATE POLICY achievement_recipients_update ON public.achievement_recipients
FOR UPDATE TO authenticated
USING (public.has_permission('achievement_recipient.manage'))
WITH CHECK (public.has_permission('achievement_recipient.manage'));

DROP POLICY IF EXISTS achievement_recipients_delete ON public.achievement_recipients;
CREATE POLICY achievement_recipients_delete ON public.achievement_recipients
FOR DELETE TO authenticated
USING (public.has_permission('achievement_recipient.manage'));

COMMIT;

-- END OF 0006_rls.sql
