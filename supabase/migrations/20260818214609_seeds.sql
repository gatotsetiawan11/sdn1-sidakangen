-- ============================================================
-- SD NEGERI 1 SIDAKANGEN
-- FINAL MIGRATION V1
-- File: 0009_seeds.sql
-- ============================================================

BEGIN;

INSERT INTO public.roles (code, name, description, is_active)
VALUES
    ('SCHOOL_ADMIN', 'School Admin', 'Primary school application administrator.', TRUE),
    ('OPERATOR', 'Operator', 'Operational data and CMS draft management.', TRUE),
    ('TEACHER', 'Teacher', 'Teacher role. Academic module is deferred in V1.', TRUE),
    ('FINANCE', 'Finance', 'Finance role. Finance module is not active in V1.', TRUE),
    ('PARENT', 'Parent', 'Parent portal role. Guardian module is deferred in V1.', TRUE)
ON CONFLICT (code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

INSERT INTO public.permissions (code, name, description, is_active)
VALUES
    ('authorization.view', 'View Authorization', 'View authorization configuration.', TRUE),
    ('authorization.manage', 'Manage Authorization', 'Manage roles and permission mappings.', TRUE),
    ('user.view', 'View Users', 'View application profiles.', TRUE),
    ('user.manage', 'Manage Users', 'Create and update application profiles.', TRUE),
    ('school.view', 'View School', 'View internal school master data.', TRUE),
    ('school.update', 'Update School', 'Update school master data.', TRUE),
    ('people.view', 'View People', 'View canonical people records.', TRUE),
    ('people.create', 'Create People', 'Create canonical people records.', TRUE),
    ('people.update', 'Update People', 'Update active people records.', TRUE),
    ('people.archive', 'Archive People', 'Logically deactivate people records.', TRUE),
    ('teacher.view', 'View Teachers', 'View teacher records.', TRUE),
    ('teacher.manage', 'Manage Teachers', 'Create/update teacher records.', TRUE),
    ('staff.view', 'View Staff', 'View staff records.', TRUE),
    ('staff.manage', 'Manage Staff', 'Create/update staff records.', TRUE),
    ('student.view', 'View Students', 'View student records.', TRUE),
    ('student.manage', 'Manage Students', 'Create/update student records.', TRUE),
    ('class.view', 'View Classes', 'View class master data.', TRUE),
    ('class.manage', 'Manage Classes', 'Create/update class master data.', TRUE),
    ('position.view', 'View Positions', 'View job position master data.', TRUE),
    ('position.manage', 'Manage Positions', 'Create/update job position master data.', TRUE),
    ('assignment.view', 'View Assignments', 'View job/homeroom/leadership assignments.', TRUE),
    ('assignment.manage', 'Manage Assignments', 'Create/update assignments.', TRUE),
    ('media.view', 'View Media', 'View internal media metadata and Storage objects.', TRUE),
    ('media.upload', 'Upload Media', 'Upload media and create metadata.', TRUE),
    ('media.update', 'Update Media', 'Update active media metadata.', TRUE),
    ('media.archive', 'Archive Media', 'Logically archive media.', TRUE),
    ('content.view', 'View Content', 'View internal CMS content.', TRUE),
    ('content.create', 'Create Content', 'Create CMS drafts.', TRUE),
    ('content.update', 'Update Content', 'Edit CMS drafts.', TRUE),
    ('content.publish', 'Publish Content', 'Publish eligible CMS content.', TRUE),
    ('content.unpublish', 'Unpublish Content', 'Return published content to draft.', TRUE),
    ('content.archive', 'Archive Content', 'Archive CMS content.', TRUE),
    ('site.view', 'View Site Settings', 'View website presentation settings.', TRUE),
    ('site.update', 'Update Site Settings', 'Update website presentation settings.', TRUE),
    ('achievement.view', 'View Achievements', 'View internal Achievements.', TRUE),
    ('achievement.create', 'Create Achievement', 'Create Achievement drafts.', TRUE),
    ('achievement.update', 'Update Achievement', 'Edit draft Achievements/master data.', TRUE),
    ('achievement.verify', 'Verify Achievement', 'Verify Achievement facts.', TRUE),
    ('achievement.publish', 'Publish Achievement', 'Publish verified Achievements.', TRUE),
    ('achievement.unpublish', 'Unpublish Achievement', 'Return published Achievement to verified.', TRUE),
    ('achievement.archive', 'Archive Achievement', 'Archive Achievement.', TRUE),
    ('achievement.correct', 'Correct Achievement', 'Reopen verified Achievement to draft.', TRUE),
    ('achievement_recipient.view', 'View Achievement Recipients', 'View internal recipients.', TRUE),
    ('achievement_recipient.manage', 'Manage Achievement Recipients', 'Manage recipients while draft.', TRUE)
ON CONFLICT (code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

-- SCHOOL_ADMIN gets every current V1 permission.
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.code = 'SCHOOL_ADMIN'
ON CONFLICT DO NOTHING;

-- OPERATOR baseline.
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.code IN (
    'school.view',
    'people.view','people.create','people.update','people.archive',
    'teacher.view','teacher.manage',
    'staff.view','staff.manage',
    'student.view','student.manage',
    'class.view','class.manage',
    'position.view','position.manage',
    'assignment.view','assignment.manage',
    'media.view','media.upload','media.update','media.archive',
    'content.view','content.create','content.update',
    'site.view','site.update',
    'achievement.view','achievement.create','achievement.update',
    'achievement_recipient.view','achievement_recipient.manage'
)
WHERE r.code = 'OPERATOR'
ON CONFLICT DO NOTHING;

-- TEACHER, FINANCE, and PARENT intentionally have no V1
-- module-management permissions by default.

COMMIT;

-- END OF 0009_seeds.sql
