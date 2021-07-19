# A field-only view for cross view fields between jobs_timeline and date_fill

include: "/views/jobs/jobs.view.lkml"
include: "/views/dynamic_dts/date_fill.view.lkml"

view: jobs_dates {

#   measure: average_slot_rate {
#     type: number
#     sql: ${jobs.total_slot_seconds} / NULLIF(${date_fill.total_interval_duration_s},0) ;;
#     description: "Average rate of slot usage (Total slot seconds divided by period/timerange duration)"
#     value_format_name: decimal_2
#     drill_fields: [jobs.detail*]
#   }
#
  measure: average_job_rate_per_s {
    label: "Average Job Rate (jobs/s)"
    type: number
    sql: ${jobs.count} / NULLIF(${date_fill.total_interval_duration_s},0) ;;
    description: "Average rate of jobs, in jobs/s (Count of jobs divided by the period/timerange duration in seconds)"
    value_format_name: decimal_2
    drill_fields: [jobs.detail*]
  }

  measure: average_processing_rate_gib_per_s {
    group_label: "Processed Bytes"
    label: "Average Processing Rate GiB/s"
    description: "Average processed gigibites (2^30 bytes) per second, over the period/timerange duration"
    type: number
    value_format_name: decimal_2
    sql: ${jobs.total_processed_gib} / NULLIF(${date_fill.total_interval_duration_s},0) ;;
    drill_fields: [jobs.detail*]
  }
}
