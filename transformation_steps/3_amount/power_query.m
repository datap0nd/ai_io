// Step 3: Power Query replacement for Global_Inflow_Outflow.
//
// Paste this into the Advanced Editor of the Global_Inflow_Outflow query
// after bi_reporting.io_3_amount_mv has been created.

let
    Source = PostgreSQL.Database("SERVER_NAME", "DATABASE_NAME"),
    Step3Amount = Value.NativeQuery(
        Source,
        "
        select
            ""Source Side"",
            ""Sell-in Region"",
            ""Sell-in Sub"",
            ""Sell-in AP1"",
            ""Sell-in Account"",
            ""Sell-out Region"",
            ""Sell-out Sub"",
            ""Sell-out Country"",
            ""Current Region"",
            ""Current Sub"",
            ""Current Country"",
            ""Biz Sub"",
            ""Series"",
            ""MKT Name"",
            ""Memory"",
            ""Storage"",
            ""Item Code"",
            ""Month"",
            ""Year"",
            ""ItemID"",
            ""Grand total"",
            ""ASP"",
            ""Biz Grp"",
            ""Sell-in Channel"",
            ""Sell-in Country"",
            ""SKU"",
            ""In/Out"",
            ""Region"",
            ""Subsidiary"",
            ""Active Qty"",
            ""Total Inflow"",
            ""From MENA"",
            ""From Non-MENA"",
            ""Total Outflow"",
            ""To MENA Outflow"",
            ""To Non-MENA"",
            ""S/O SCM"",
            ""Domestic Demand"",
            ""S/O that Stays"",
            ""2nd Activation In"",
            ""2nd Activation Out"",
            ""CI In"",
            ""CI Out""
        from bi_reporting.io_3_amount_mv
        ",
        null,
        [EnableFolding = true]
    )
in
    Step3Amount
