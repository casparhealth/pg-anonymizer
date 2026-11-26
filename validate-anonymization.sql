-- Post-restore check for the anonymised DB (INF-2373).
-- Run after the anonymised dump is loaded, before the DB is snapshotted and shared to stage:
--   psql -v ON_ERROR_STOP=1 -v admin_email="$admin_email" -f validate-anonymization.sql
-- Each check counts rows that still hold a value the anonymiser should have replaced.
-- Any non-zero count raises an error, so the refresh fails instead of shipping real data.
-- Only counts are printed, never values.

SELECT set_config('anon.admin_email', :'admin_email', false);

DO $$
DECLARE
  checks text[][] := ARRAY[
    ['patients.insurance_number',              'SELECT count(*) FROM patients WHERE insurance_number IS NOT NULL'],
    ['patients.therapy_particularities',       'SELECT count(*) FROM patients WHERE therapy_particularities IS NOT NULL'],
    ['patients.treatment_explanations',        'SELECT count(*) FROM patients WHERE treatment_explanations IS NOT NULL'],
    ['patients.other_aftercare_goals',         'SELECT count(*) FROM patients WHERE other_aftercare_goals IS NOT NULL'],
    ['patients.external_info',                 'SELECT count(*) FROM patients WHERE external_info <> ''{}''::jsonb'],
    ['patients.therapy_goal',                  'SELECT count(*) FROM patients WHERE coalesce(therapy_goal, '''') <> '''''],
    ['patients.therapist_recommendations',     'SELECT count(*) FROM patients WHERE coalesce(therapist_recommendations, '''') <> '''''],
    ['patients.other_information',             'SELECT count(*) FROM patients WHERE coalesce(other_information, '''') <> '''''],
    ['import_histories.parsed_content',        'SELECT count(*) FROM import_histories WHERE coalesce(parsed_content::text, ''{}'') <> ''{}'''],
    ['user_feedbacks.feedback',                'SELECT count(*) FROM user_feedbacks WHERE coalesce(feedback::text, ''{}'') <> ''{}'''],
    ['document_extractions.fields',            'SELECT count(*) FROM document_extractions WHERE fields <> ''{}'''],
    ['single_therapy_plans.termination_reason','SELECT count(*) FROM single_therapy_plans WHERE termination_reason IS NOT NULL'],
    ['announcements.message',                  'SELECT count(*) FROM announcements WHERE message <> ''Confidential'''],
    ['phase_notes.body',                       'SELECT count(*) FROM phase_notes WHERE body <> ''Confidential'''],
    ['therapy_task_configs.extra_note',        'SELECT count(*) FROM therapy_task_configs WHERE extra_note IS NOT NULL'],
    -- therapy_tasks has ~300M rows: stop at the first hit instead of counting all of them.
    ['therapy_tasks.extra_note',               'SELECT count(*) FROM (SELECT 1 FROM therapy_tasks WHERE extra_note IS NOT NULL LIMIT 1) t'],
    ['video_sessions.note',                    'SELECT count(*) FROM video_sessions WHERE note IS NOT NULL'],
    ['copilot_exercise_reviews.patient_comment','SELECT count(*) FROM copilot_exercise_reviews WHERE patient_comment IS NOT NULL'],
    ['audits.comment',                         'SELECT count(*) FROM audits WHERE comment IS NOT NULL'],
    ['data_deletion_requests.confirmation_email','SELECT count(*) FROM data_deletion_requests WHERE confirmation_email IS NOT NULL'],
    ['partner_integrations.access_token',      'SELECT count(*) FROM partner_integrations WHERE access_token IS NOT NULL'],
    -- Faked tokens are 48 hex chars; anything else came from prod.
    ['self_pay_patient_invites.token',         'SELECT count(*) FROM self_pay_patient_invites WHERE token !~ ''^[0-9a-f]{48}$'''],
    ['push_tokens.token',                      'SELECT count(*) FROM push_tokens WHERE token !~ ''^[0-9a-f]{48}$'''],
    -- Faked emails use example.com/.net/.org; the configured admin account is kept on purpose.
    ['accounts.email',                         'SELECT count(*) FROM accounts WHERE email IS NOT NULL AND email !~* ''@example\.(com|net|org)$'' AND email <> current_setting(''anon.admin_email'')'],
    ['clinic_infos.contact_email',             'SELECT count(*) FROM clinic_infos WHERE contact_email IS NOT NULL AND contact_email !~* ''@example\.(com|net|org)$''']
  ];
  n bigint;
  failed int := 0;
BEGIN
  FOR i IN 1 .. array_length(checks, 1) LOOP
    EXECUTE checks[i][2] INTO n;
    IF n > 0 THEN
      failed := failed + 1;
      RAISE WARNING 'NOT ANONYMISED: % (% rows)', checks[i][1], n;
    ELSE
      RAISE NOTICE 'ok: %', checks[i][1];
    END IF;
  END LOOP;

  IF failed > 0 THEN
    RAISE EXCEPTION 'Anonymisation check failed for % column(s). Do not snapshot or share this DB.', failed;
  END IF;
END
$$;
