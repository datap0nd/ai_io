// Step 3: Power Query replacement for Global_Inflow_Outflow.
//
// Paste this into the Advanced Editor of the Global_Inflow_Outflow query
// after bi_reporting.io_3_amount_mv has been created.

let
    Source = PostgreSQL.Database("SERVER_NAME", "DATABASE_NAME"),
    Step3Amount = Value.NativeQuery(
        Source,
        "select * from bi_reporting.io_3_amount_mv",
        null,
        [EnableFolding = true]
    )
in
    Step3Amount
