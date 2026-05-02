CREATE OR REPLACE TRIGGER customerdata.trg_cr_insp_new_to_wot_updated AFTER
    INSERT OR UPDATE OF feed_status ON customerdata.epsewerai_cr_inspect
    FOR EACH ROW
    WHEN ( new.feed_status = 'NEW' )
BEGIN
    MERGE INTO customerdata.epsewerai_wot_stg stg
    USING (
              SELECT
                  t.uuid              AS task_uuid,
                  wo.uuid             AS workorder_uuid,
                  wo.wonumber         AS wonumber,
                  t.tasknumber        AS tasknumber,
                  nvl(
                      t.wotasktitle, wo.title
                  )                   AS wotasktitle,
                  wo.reqcompdate_dttm AS plndcompdate_dttm,
                  nvl(
                      t.plndstrtdate_dttm, wo.plndstrtdate_dttm
                  )                   AS plndstrtdate_dttm,
                  t.workclassifi_oi   AS workclassifi_oi
              FROM
                  mnt.workordertask t
                  JOIN mnt.workorders wo ON wo.workordersoi = t.workorder_oi
              WHERE
                  t.uuid = hextoraw(
                      upper(
                          replace(
                              :new.project_sid, '-', ''
                          )
                      )
                  )
                  AND wo.uuid = hextoraw(
                      upper(
                          replace(
                              :new.work_order_uuid, '-', ''
                          )
                      )
                  )
                  AND wo.site_oi = 58
                  AND t.workclassifi_oi IN ( 209, 211, 215, 266, 442, 462, 183, 196, 207, 256, 263 )
          )
    src ON ( stg.task_uuid = src.task_uuid
             AND stg.workorder_uuid = src.workorder_uuid )
    WHEN MATCHED THEN UPDATE
    SET stg.wonumber = src.wonumber,
        stg.tasknumber = src.tasknumber,
        stg.wotasktitle = src.wotasktitle,
        stg.plndcompdate_dttm = src.plndcompdate_dttm,
        stg.plndstrtdate_dttm = src.plndstrtdate_dttm,
        stg.workclassifi_oi = src.workclassifi_oi,
        stg.feed_status = 'UPDATED'
    WHEN NOT MATCHED THEN
    INSERT (
        task_uuid,
        workorder_uuid,
        wonumber,
        tasknumber,
        wotasktitle,
        plndcompdate_dttm,
        plndstrtdate_dttm,
        workclassifi_oi,
        feed_status )
    VALUES
        ( src.task_uuid,
          src.workorder_uuid,
          src.wonumber,
          src.tasknumber,
          src.wotasktitle,
          src.plndcompdate_dttm,
          src.plndstrtdate_dttm,
          src.workclassifi_oi,
        'UPDATED' );

END;