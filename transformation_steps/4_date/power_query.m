// Step 4: Power Query replacement for Month Map.
//
// Paste this into the Advanced Editor of the Month Map query after
// bi_reporting.io_4_date_mv has been created.

let
    Source = PostgreSQL.Database("SERVER_NAME", "DATABASE_NAME"),
    Step4Date = Value.NativeQuery(
        Source,
        "
        select
            ""Month"",
            ""Quarter"",
            ""Year"",
            ""Half""
        from bi_reporting.io_4_date_mv
        ",
        null,
        [EnableFolding = true]
    ),
    #"Changed Type" = Table.TransformColumnTypes(
        Step4Date,
        {
            {"Month", Int64.Type},
            {"Quarter", type text},
            {"Year", Int64.Type},
            {"Half", type text}
        }
    )
in
    #"Changed Type"
