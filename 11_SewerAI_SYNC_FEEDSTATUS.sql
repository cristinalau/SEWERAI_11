-- Update the latest feed row per inspection to FEED_STATUS='UPDATED'
-- when either ASSET_NUMBER or ADDITIONAL_INFORMATION differs from the view (SEWERAI_INSPECTIONS_V),
-- but only if INSPECTION_SID is NOT NULL (otherwise we 'wait').
-- In the current procedure, simply updating INSPECTION_SID (e.g., from NULL ? non?NULL) does not cause FEED_STATUS to change.
-- The procedure only updates a row when either:
-- PO_NUMBER (feed) ? ASSET_NUMBER (view), or
-- ADDITIONAL_INFORMATION (feed) ? ADDITIONAL_INFORMATION (view)
-- It also requires INSPECTION_SID IS NOT NULL as a precondition (a filter), but it does not treat a change in INSPECTION_SID itself as a reason to update FEED_STATUS.
-- So, if INSPECTION_SID becomes non?NULL but the two compared fields are unchanged, no update happens and FEED_STATUS remains as-is.
--
--
-- UPDATED:
--   This version now enforces the same allowed WORKCLASSIFI_OI list used in
--   TRG_WOT_TO_STG (#1.2), so disallowed work classes cannot enter or be reset
--   through the SEWERAI_INSPECTIONS_V -> EPSEWERAI_CR_INSPECT sync path.

CREATE OR REPLACE PROCEDURE CUSTOMERDATA.SEWERAI_SYNC_FEEDSTATUS AS
BEGIN
  /* =========================================================
     DELETE rows from EPSEWERAI_CR_INSPECT that no longer exist
     in the current filtered SEWERAI_INSPECTIONS_V
     ========================================================= */
  DELETE FROM CUSTOMERDATA."EPSEWERAI_CR_INSPECT" tgt
   WHERE NOT EXISTS (
     WITH allowed_tasks AS (
       SELECT
         LOWER(
           REGEXP_REPLACE(
             RAWTOHEX(wt."UUID"),
             '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
             '\1-\2-\3-\4-\5'
           )
         ) AS task_uuid_can
       FROM MNT."WORKORDERTASK" wt
       WHERE wt."WORKCLASSIFI_OI" IN (
         209, 211, 215, 266, 442, 462,
         183, 196, 207, 256, 263
       )
     )
     SELECT 1
       FROM CUSTOMERDATA."SEWERAI_INSPECTIONS_V" v
       JOIN allowed_tasks at
         ON at.task_uuid_can = LOWER(
              REGEXP_REPLACE(
                REGEXP_REPLACE(NVL(v."WORK_ORDER_TASK_UUID", ''), '[^0-9A-Fa-f]', ''),
                '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
                '\1-\2-\3-\4-\5'
              )
            )
      WHERE LOWER(
              REGEXP_REPLACE(
                REGEXP_REPLACE(NVL(v."DR_UUID", ''), '[^0-9A-Fa-f]', ''),
                '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
                '\1-\2-\3-\4-\5'
              )
            ) = tgt."INSPECTIONID"
   );

  /* =========================================================
     MERGE #1
     Insert rows that are now in SEWERAI_INSPECTIONS_V
     but do not yet exist in EPSEWERAI_CR_INSPECT

     IMPORTANT:
     Only process rows whose WORK_ORDER_TASK_UUID maps to a WORKORDERTASK
     with an approved WORKCLASSIFI_OI, matching #1.2 logic.
     ========================================================= */
  MERGE INTO CUSTOMERDATA."EPSEWERAI_CR_INSPECT" tgt
  USING (
    WITH allowed_tasks AS (
      SELECT
        LOWER(
          REGEXP_REPLACE(
            RAWTOHEX(wt."UUID"),
            '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
            '\1-\2-\3-\4-\5'
          )
        ) AS task_uuid_can
      FROM MNT."WORKORDERTASK" wt
      WHERE wt."WORKCLASSIFI_OI" IN (
        209, 211, 215, 266, 442, 462,
        183, 196, 207, 256, 263
      )
    )
    SELECT
      LOWER(
        REGEXP_REPLACE(
          REGEXP_REPLACE(NVL(v."WORK_ORDER_TASK_UUID", ''), '[^0-9A-Fa-f]', ''),
          '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
          '\1-\2-\3-\4-\5'
        )
      ) AS project_sid_can,

      v."INSPECTION_TYPE",

      LOWER(
        REGEXP_REPLACE(
          REGEXP_REPLACE(NVL(v."DR_UUID", ''), '[^0-9A-Fa-f]', ''),
          '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
          '\1-\2-\3-\4-\5'
        )
      ) AS inspectionid_can,

      LOWER(
        REGEXP_REPLACE(
          REGEXP_REPLACE(NVL(v."WORK_ORDER_UUID", ''), '[^0-9A-Fa-f]', ''),
          '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
          '\1-\2-\3-\4-\5'
        )
      ) AS work_order_uuid_can,

      v."WORK_ORDERS_NUMBER"        AS workorder_no,
      v."WORK_ORDER_TASK_TITLE"     AS project_name,
      v."ASSET_NUMBER"              AS asset_number,
      v."ADDITIONAL_INFORMATION"    AS addl_info,
      v."PIPE_SEGMENT_REFERENCE",
      v."LATERAL_SEGMENT_REFERENCE",
      v."MANHOLE_NUMBER",
      v."MATERIAL",
      v."PIPE_USE",
      v."COVER_SHAPE",
      v."UPSTREAM_MH",
      v."DOWNSTREAM_MH",
      v."FACILITY_TYPE",
      v."FACILITY_ID",
      v."FACILITYOI",
      v."PIP_TYPE",
      v."SHAPE",
      v."ACCESS_TYPE",
      v."MH_USE",
      v."WALL_MATERIAL",
      v."BENCH_MATERIAL",
      v."CHANNEL_MATERIAL",
      v."WALL_BYSIZE",
      v."WALL_DEPTH",
      v."ELEVATION",
      v."FRAME_MATERIAL",
      v."HEIGHT",
      v."UP_ELEVATION",
      v."UP_GRADE_TO_INVERT",
      v."DOWN_ELEVATION",
      v."DOWN_GRADE_TO_INVERT",
      v."STREET",
      v."TOTAL_LENGTH",
      v."YEAR_CONSTRUCTED",
      v."SIZE",
      v."DRAINAGE_AREA",
      v."UNKNOWN_TYPE",
      v."CREATEDATE_DTTM",
      v."LASTUPDATE_DTTM"
    FROM CUSTOMERDATA."SEWERAI_INSPECTIONS_V" v
    JOIN allowed_tasks at
      ON at.task_uuid_can = LOWER(
           REGEXP_REPLACE(
             REGEXP_REPLACE(NVL(v."WORK_ORDER_TASK_UUID", ''), '[^0-9A-Fa-f]', ''),
             '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
             '\1-\2-\3-\4-\5'
           )
         )
  ) src
  ON (tgt."INSPECTIONID" = src.inspectionid_can)
  WHEN NOT MATCHED THEN
    INSERT (
      "PROJECT_SID",
      "INSPECTION_TYPE",
      "INSPECTIONID",
      "WORK_ORDER_UUID",
      "WORKORDER",
      "PROJECT",
      "PO_NUMBER",
      "ADDITIONAL_INFORMATION",
      "PIPE_SEGMENT_REFERENCE",
      "LATERAL_SEGMENT_REFERENCE",
      "MANHOLE_NUMBER",
      "MATERIAL",
      "PIPE_USE",
      "COVER_SHAPE",
      "UPSTREAM_MH",
      "DOWNSTREAM_MH",
      "FACILITY_TYPE",
      "FACILITY_ID",
      "FACILITYOI",
      "PIP_TYPE",
      "SHAPE",
      "ACCESS_TYPE",
      "MH_USE",
      "WALL_MATERIAL",
      "BENCH_MATERIAL",
      "CHANNEL_MATERIAL",
      "WALL_BYSIZE",
      "WALL_DEPTH",
      "ELEVATION",
      "FRAME_MATERIAL",
      "HEIGHT",
      "UP_ELEVATION",
      "UP_GRADE_TO_INVERT",
      "DOWN_ELEVATION",
      "DOWN_GRADE_TO_INVERT",
      "STREET",
      "TOTAL_LENGTH",
      "YEAR_CONSTRUCTED",
      "SIZE",
      "DRAINAGE_AREA",
      "UNKNOWN_TYPE",
      "CREATEDATE_DTTM",
      "LASTUPDATE_DTTM",
      "FEED_STATUS"
    )
    VALUES (
      src.project_sid_can,
      src."INSPECTION_TYPE",
      src.inspectionid_can,
      src.work_order_uuid_can,
      src.workorder_no,
      src.project_name,
      src.asset_number,
      src.addl_info,
      src."PIPE_SEGMENT_REFERENCE",
      src."LATERAL_SEGMENT_REFERENCE",
      src."MANHOLE_NUMBER",
      src."MATERIAL",
      src."PIPE_USE",
      src."COVER_SHAPE",
      src."UPSTREAM_MH",
      src."DOWNSTREAM_MH",
      src."FACILITY_TYPE",
      src."FACILITY_ID",
      src."FACILITYOI",
      src."PIP_TYPE",
      src."SHAPE",
      src."ACCESS_TYPE",
      src."MH_USE",
      src."WALL_MATERIAL",
      src."BENCH_MATERIAL",
      src."CHANNEL_MATERIAL",
      src."WALL_BYSIZE",
      src."WALL_DEPTH",
      src."ELEVATION",
      src."FRAME_MATERIAL",
      src."HEIGHT",
      src."UP_ELEVATION",
      src."UP_GRADE_TO_INVERT",
      src."DOWN_ELEVATION",
      src."DOWN_GRADE_TO_INVERT",
      src."STREET",
      src."TOTAL_LENGTH",
      src."YEAR_CONSTRUCTED",
      src."SIZE",
      src."DRAINAGE_AREA",
      src."UNKNOWN_TYPE",
      src."CREATEDATE_DTTM",
      src."LASTUPDATE_DTTM",
      'NEW'
    );

  /* =========================================================
     MERGE #2
     Update latest feed row when the view changes
     - normal change                       -> UPDATED
     - 1195313 changed to something else  -> NEW

     IMPORTANT:
     Only process rows whose WORK_ORDER_TASK_UUID maps to an approved
     WORKCLASSIFI_OI, matching #1.2 logic.
     ========================================================= */
  MERGE INTO CUSTOMERDATA."EPSEWERAI_CR_INSPECT" tgt
  USING (
    WITH allowed_tasks AS (
      SELECT
        LOWER(
          REGEXP_REPLACE(
            RAWTOHEX(wt."UUID"),
            '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
            '\1-\2-\3-\4-\5'
          )
        ) AS task_uuid_can
      FROM MNT."WORKORDERTASK" wt
      WHERE wt."WORKCLASSIFI_OI" IN (
        209, 211, 215, 266, 442, 462,
        183, 196, 207, 256, 263
      )
    ),
    v AS (
      SELECT
        LOWER(
          REGEXP_REPLACE(
            REGEXP_REPLACE(NVL(v."DR_UUID", ''), '[^0-9A-Fa-f]', ''),
            '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
            '\1-\2-\3-\4-\5'
          )
        )                          AS inspectionid_can,
        v."ASSET_NUMBER"           AS v_asset_number,
        v."ADDITIONAL_INFORMATION" AS v_addl_info
      FROM CUSTOMERDATA."SEWERAI_INSPECTIONS_V" v
      JOIN allowed_tasks at
        ON at.task_uuid_can = LOWER(
             REGEXP_REPLACE(
               REGEXP_REPLACE(NVL(v."WORK_ORDER_TASK_UUID", ''), '[^0-9A-Fa-f]', ''),
               '(^[0-9A-Fa-f]{8})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})([0-9A-Fa-f]{12}$)',
               '\1-\2-\3-\4-\5'
             )
           )
    ),

    latest_feed AS (
      SELECT *
      FROM (
        SELECT
          t."INSPECTIONID",
          t."INSPECTION_SID",
          t."PO_NUMBER",
          t."ADDITIONAL_INFORMATION",
          t."LASTUPDATE_DTTM",
          t."CREATEDATE_DTTM",
          ROWID AS rid,
          ROW_NUMBER() OVER (
            PARTITION BY t."INSPECTIONID"
            ORDER BY NVL(t."LASTUPDATE_DTTM", t."CREATEDATE_DTTM") DESC, ROWID DESC
          ) AS rn
        FROM CUSTOMERDATA."EPSEWERAI_CR_INSPECT" t
      )
      WHERE rn = 1
    ),

    candidates AS (
      SELECT
        lf.rid,
        v.v_asset_number,
        v.v_addl_info,
        CASE
          WHEN NVL(lf."PO_NUMBER", '?') = '1195313'
           AND NVL(v.v_asset_number, '?') <> '1195313'
          THEN 'NEW'
          ELSE 'UPDATED'
        END AS next_feed_status
      FROM latest_feed lf
      JOIN v
        ON v.inspectionid_can = lf."INSPECTIONID"
      WHERE (
              lf."INSPECTION_SID" IS NOT NULL
              OR NVL(lf."PO_NUMBER", '?') = '1195313'
            )
        AND (
             NVL(lf."PO_NUMBER", '?') <> NVL(v.v_asset_number, '?')
             OR
             CASE
               WHEN lf."ADDITIONAL_INFORMATION" IS NULL AND v.v_addl_info IS NULL THEN 0
               WHEN lf."ADDITIONAL_INFORMATION" IS NULL AND v.v_addl_info IS NOT NULL THEN 1
               WHEN lf."ADDITIONAL_INFORMATION" IS NOT NULL AND v.v_addl_info IS NULL THEN 1
               ELSE DBMS_LOB.COMPARE(lf."ADDITIONAL_INFORMATION", v.v_addl_info)
             END <> 0
        )
    )
    SELECT *
    FROM candidates
  ) src
  ON (tgt.ROWID = src.rid)
  WHEN MATCHED THEN
    UPDATE SET
      tgt."PO_NUMBER"              = src.v_asset_number,
      tgt."ADDITIONAL_INFORMATION" = src.v_addl_info,
      tgt."FEED_STATUS"            = src.next_feed_status,
      tgt."LASTUPDATE_DTTM"        = SYSDATE;

  COMMIT;
END;