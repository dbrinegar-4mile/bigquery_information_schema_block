include: "/views/date.view"
include: "/views/jobs.view"

explore: job_slots_datepart_summaries {
  always_filter: {
    filters: [date.date_filter: "1 day ago for 1 day"]
  }
  join: date {
    type: cross
    relationship: many_to_one
    sql_table_name: UNNEST([COALESCE(
      job_slots_datepart_summaries.slot_activity_period
      )]);;
    required_joins: []
  }
}


view: job_slots_datepart_summaries {
  derived_table: {
    sql:
    WITH job_stages as (
      SELECT
        TIMESTAMP_MILLIS(stages.start_ms) as start_ts,
        TIMESTAMP_MILLIS(stages.end_ms) as end_ts,
        stages.slot_ms/NULLIF(stages.end_ms-stages.start_ms,0) as slots
        FROM ${jobs.SQL_TABLE_NAME} as jobs
        LEFT JOIN UNNEST(jobs.job_stages) as stages
        WHERE jobs.creation_time >= TIMESTAMP_SUB({% date_start date.date_filter %}, INTERVAL @{max_job_lookback})
          AND jobs.creation_time <= {% date_end date.date_filter %}
          AND jobs.start_time <= {% date_end date.date_filter %}
          AND jobs.end_time   >= {% date_start date.date_filter %}
          AND stages.start_ms IS NOT NULL
      ),
    slot_changes as (
      -- New entities each month
      SELECT start_ts as ts, +slots as slots_delta, 0 as is_selection_period FROM job_stages UNION ALL
      SELECT   end_ts as ts, -slots as slots_delta, 0 as is_selection_period FROM job_stages UNION ALL
      SELECT        d as ts, 0      as slots_delta, 1 as is_selection_period FROM ${date.SQL_TABLE_NAME}
      ),
    slot_states as (
      SELECT
        ts,
        MAX(CASE WHEN is_selection_period = 1 THEN ts END) OVER (time ROWS UNBOUNDED PRECEDING) as ts_group,
        SUM(slots_delta) OVER time as net_slots,
        --If we want an average, something like LEAD(ts)-ts as duration for weighting
      FROM slot_changes
      WINDOW time as (ORDER BY slot_changes.ts ASC, is_selection_period DESC)
      )
    SELECT
      ts_group as slot_activity_period,
      MAX(net_slots) as max_concurrent_slot_usage,
      MIN(net_slots) as min_concurrent_slot_usage,
    FROM slot_states
    GROUP BY 1
    ;;
  }
  dimension_group: slot_activity_period {
    type: time
    datatype: timestamp
    timeframes: [raw]
    hidden: yes
  }
  measure: min_concurrent_slot_usage {
    type: min
    sql: ${TABLE}.min_concurrent_slot_usage ;;
    value_format_name: decimal_0
  }
  measure: max_concurrent_slot_usage {
    type: max
    sql: ${TABLE}.max_concurrent_slot_usage ;;
    value_format_name: decimal_0
  }
}
