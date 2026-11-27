-- Post-restore check for the anonymised DB (INF-2373).
-- Run after the anonymised dump is loaded, before the DB is snapshotted and shared to stage:
--   psql -v ON_ERROR_STOP=1 -v admin_email="$admin_email" [-v anon_email_base="$anon_email_base"] -f validate-anonymization.sql
-- Each check counts rows that still hold a value the anonymiser should have replaced.
-- Any non-zero count raises an error, so the refresh fails instead of shipping real data.
-- Only counts are printed, never values.

SELECT set_config('anon.admin_email', :'admin_email', false);

-- Optional test inbox (anon_email_base=local@domain): faked emails are then local+anon<n>@domain.
\if :{?anon_email_base}
\else
  \set anon_email_base ''
\endif
SELECT set_config('anon.email_plus_re',
  CASE WHEN :'anon_email_base' LIKE '%_@_%' THEN
    '^' || regexp_replace(split_part(:'anon_email_base', '@', 1), '([.+*?^$()\[\]{}|\\])', '\\\1', 'g')
        || '\+anon[0-9]+@'
        || regexp_replace(split_part(:'anon_email_base', '@', 2), '([.+*?^$()\[\]{}|\\])', '\\\1', 'g') || '$'
  ELSE 'a^' END, false);

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
    -- Faked emails use example.com/.net/.org or the anon_email_base plus address; the admin account is kept on purpose.
    ['accounts.email',                         'SELECT count(*) FROM accounts WHERE email IS NOT NULL AND email !~* ''@example\.(com|net|org)$'' AND email !~* current_setting(''anon.email_plus_re'') AND email <> current_setting(''anon.admin_email'')'],
    ['clinic_infos.contact_email',             'SELECT count(*) FROM clinic_infos WHERE contact_email IS NOT NULL AND contact_email !~* ''@example\.(com|net|org)$'''],
    -- Columns found by the full audit (prod vs anonymised copy).
    ['audits.audited_changes',                 'SELECT count(*) FROM audits WHERE coalesce(audited_changes, ''{}'') <> ''{}'''],
    ['audits.remote_address',                  'SELECT count(*) FROM audits WHERE remote_address IS NOT NULL'],
    ['notification_events.payload',            'SELECT count(*) FROM notification_events WHERE payload <> ''{}'''],
    ['partner_integrations.metadata',          'SELECT count(*) FROM partner_integrations WHERE metadata ?| array[''email'',''name'',''conversation'',''custom'']'],
    ['pay_charges.data/object',                'SELECT count(*) FROM pay_charges WHERE coalesce(data, ''{}'') <> ''{}'' OR coalesce(object, ''{}'') <> ''{}'''],
    ['pay_customers.data/object',              'SELECT count(*) FROM pay_customers WHERE coalesce(data, ''{}'') <> ''{}'' OR coalesce(object, ''{}'') <> ''{}'''],
    ['pay_payment_methods.data',               'SELECT count(*) FROM pay_payment_methods WHERE coalesce(data, ''{}'') <> ''{}'''],
    ['pay_subscriptions.object',               'SELECT count(*) FROM pay_subscriptions WHERE coalesce(object, ''{}'') <> ''{}'''],
    ['pay_webhooks.event',                     'SELECT count(*) FROM pay_webhooks WHERE coalesce(event, ''{}'') <> ''{}'''],
    -- Faked pkeys are 16 hex chars; anything else came from prod.
    ['patients.pkey',                          'SELECT count(*) FROM patients WHERE pkey !~ ''^[0-9a-f]{16}$'''],
    ['patients.bmi',                           'SELECT count(*) FROM patients WHERE bmi IS NOT NULL'],
    ['patients.other_employment_status',       'SELECT count(*) FROM patients WHERE other_employment_status IS NOT NULL'],
    ['single_therapy_plans.therapy_goal',      'SELECT count(*) FROM single_therapy_plans WHERE therapy_goal <> ''Confidential'''],
    ['single_therapy_plans.title',             'SELECT count(*) FROM single_therapy_plans WHERE title <> ''Therapy plan'''],
    ['patient_journal_entries.reflection',     'SELECT count(*) FROM patient_journal_entries WHERE reflection <> ''Confidential'''],
    ['patient_documents.original_filename',    'SELECT count(*) FROM patient_documents WHERE original_filename <> ''document.pdf'''],
    ['patient_documents.s3_key',               'SELECT count(*) FROM patient_documents WHERE s3_key !~ ''^anonymised/'''],
    ['therapy_schedules.event_name',           'SELECT count(*) FROM therapy_schedules WHERE event_name <> ''Therapy session'''],
    ['therapy_schedule_changes.value_changes', 'SELECT count(*) FROM therapy_schedule_changes WHERE coalesce(value_changes, ''{}'') <> ''{}'''],
    ['data_deletion_requests.requested_by',    'SELECT count(*) FROM data_deletion_requests WHERE requested_by IS NOT NULL'],
    ['user_agents.user_agent',                 'SELECT count(*) FROM user_agents WHERE user_agent <> ''Mozilla/5.0 (anonymised)'''],
    ['video_session_attendees.join_url',       'SELECT count(*) FROM video_session_attendees WHERE join_url <> ''https://example.com/anonymised'''],
    ['announcements.attachment_token',         'SELECT count(*) FROM announcements WHERE attachment_token IS NOT NULL'],
    ['announcements.original_filename',        'SELECT count(*) FROM announcements WHERE original_filename <> ''document.pdf''']
  ];
  n bigint;
  failed int := 0;
BEGIN
  FOR i IN 1 .. array_length(checks, 1) LOOP
    BEGIN
      EXECUTE checks[i][2] INTO n;
    EXCEPTION WHEN undefined_table THEN
      -- Table not in this schema version (e.g. an older dump): nothing to check.
      RAISE NOTICE 'skip (table not present): %', checks[i][1];
      CONTINUE;
    END;
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
