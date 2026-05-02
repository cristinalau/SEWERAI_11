-- scheduled job that:
-- Compares the current values in SEWERAI_INSPECTIONS_V to the latest posted row in EPSEWERAI_CR_INSPECT for the same inspection.
-- If either ASSET_NUMBER or ADDITIONAL_INFORMATION changed and INSPECTION_SID IS NOT NULL, then update that latest feed row’s FEED_STATUS to UPDATED 
-- (and, optionally, refresh those two fields to the current values from the view).
-- If INSPECTION_SID is NULL, it does nothing (i.e., “waits”); on a future run when INSPECTION_SID becomes not null, it will apply the update.


BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'CUSTOMERDATA.SEWERAI_SYNC_FEEDSTATUS_JOB',
    job_type        => 'STORED_PROCEDURE',
    job_action      => 'CUSTOMERDATA.SEWERAI_SYNC_FEEDSTATUS',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=MINUTELY; INTERVAL=5',
    enabled         => TRUE,
    comments        => 'Update FEED_STATUS to UPDATED when view values change and INSPECTION_SID is present'
  );
END;
