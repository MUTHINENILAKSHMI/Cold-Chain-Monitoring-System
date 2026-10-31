
import streamlit as st
import pandas as pd
import mysql.connector
import plotly.express as px

# --------------------------------------------------
# PAGE CONFIGURATION
# --------------------------------------------------

st.set_page_config(
    page_title="ColdChain Monitor",
    page_icon="❄️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# --------------------------------------------------
# CUSTOM CSS
# --------------------------------------------------

st.markdown("""
<style>

/* Main background */
.stApp {
    background-color: #f1f6fc;
}

/* Main page text - BLACK */
.stApp p,
.stApp label,
.stApp h1,
.stApp h2,
.stApp h3,
.stApp h4,
.stApp li,
[data-testid="stMarkdownContainer"] {
    color: #000000;
}

/* Main content spacing */
.block-container {
    padding-top: 1.5rem;
    padding-bottom: 2rem;
}

/* Sidebar */
[data-testid="stSidebar"] {
    background: linear-gradient(180deg, #06264d, #0b3b70);
}

[data-testid="stSidebar"] * {
    color: white !important;
}

/* Sidebar buttons */
[data-testid="stSidebar"] .stButton button {
    background-color: #123f70;
    color: white !important;
    border: 1px solid #285783;
    border-radius: 10px;
    height: 48px;
    font-weight: 600;
    text-align: left;
}

[data-testid="stSidebar"] .stButton button:hover {
    background-color: #087cf0;
    border-color: #087cf0;
}

/* Main header */
.main-header {
    background: linear-gradient(100deg, #082d59, #087ac1);
    padding: 25px 30px;
    border-radius: 16px;
    margin-bottom: 25px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.12);
}

.main-header h1,
.main-header p {
    color: white !important;
}

.main-header h1 {
    font-size: 34px;
    margin-bottom: 5px;
}

.main-header p {
    font-size: 16px;
    margin-bottom: 0;
}

/* Page headings */
.page-heading {
    color: #000000 !important;
    font-size: 29px;
    font-weight: 750;
    margin-top: 10px;
    margin-bottom: 4px;
}

.page-subtitle {
    color: #000000 !important;
    font-size: 16px;
    margin-bottom: 20px;
}

/* Metric cards */
div[data-testid="stMetric"] {
    background: white;
    padding: 20px;
    border-radius: 13px;
    border: 1px solid #d4e1f0;
    box-shadow: 0 3px 9px rgba(0,0,0,0.05);
}

div[data-testid="stMetric"] label,
div[data-testid="stMetric"] [data-testid="stMetricLabel"] {
    color: #000000 !important;
    font-weight: 650 !important;
}

div[data-testid="stMetric"] [data-testid="stMetricValue"] {
    color: #000000 !important;
    font-weight: 750 !important;
}

/* Section headings */
.section-heading {
    background: #0b3768;
    color: white !important;
    padding: 13px 18px;
    border-radius: 10px 10px 0 0;
    font-size: 19px;
    font-weight: 700;
    margin-top: 15px;
}

/* Data tables */
[data-testid="stDataFrame"] {
    background: white;
    border-radius: 10px;
}

/* Input fields */
.stTextInput input,
.stNumberInput input,
.stTextArea textarea {
    color: #000000 !important;
    background-color: white !important;
}

.stSelectbox div {
    color: #000000;
}

/* Download buttons */
.stDownloadButton button {
    background-color: #087cf0;
    color: white !important;
    border-radius: 9px;
    border: none;
    font-weight: 600;
}

/* General buttons */
.stButton button {
    border-radius: 9px;
    font-weight: 600;
}

/* Footer */
.footer {
    text-align: center;
    color: #000000 !important;
    padding: 25px;
    font-size: 13px;
}

</style>
""", unsafe_allow_html=True)


# --------------------------------------------------
# DATABASE CONNECTION
# --------------------------------------------------

def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="NewPassword@123",
        database="cold_chain_db"
    )


def load_data(query, params=None):
    connection = get_connection()

    try:
        return pd.read_sql(query, connection, params=params)
    finally:
        connection.close()


# --------------------------------------------------
# DATABASE CONNECTION CHECK
# --------------------------------------------------

try:
    connection = get_connection()
    connection.close()

    database_connected = True

except mysql.connector.Error as e:
    database_connected = False
    st.error(f"Database Connection Failed: {e}")
    st.info("Check your MySQL password and database connection.")
    st.stop()


# --------------------------------------------------
# SIDEBAR
# --------------------------------------------------

st.sidebar.markdown(
    """
    <h1 style="color:white;">❄️ ColdChain<br>Monitor</h1>
    <p style="color:#d6eaff;">
    SMART LOGISTICS &<br>TEMPERATURE CONTROL
    </p>
    """,
    unsafe_allow_html=True
)

st.sidebar.success("🟢 Database Connected")

st.sidebar.markdown("---")
st.sidebar.subheader("Dashboard Selection")

if "page" not in st.session_state:
    st.session_state.page = "Dashboard"

pages = [
    ("🏠", "Dashboard"),
    ("🚚", "Shipments"),
    ("🌡️", "Temperature Monitoring"),
    ("⚠️", "Excursion Analysis"),
    ("📋", "Corrective Actions")
]

for emoji, page_name in pages:

    if st.sidebar.button(
        f"{emoji}  {page_name}",
        key=f"nav_{page_name}",
        use_container_width=True
    ):
        st.session_state.page = page_name

page = st.session_state.page

st.sidebar.markdown("---")

st.sidebar.markdown(
    """
    <div style="text-align:center; padding:15px 0;">
        <h2>🚛</h2>
        <p>Cold Chain Monitoring System</p>
        <p>Python | MySQL | Streamlit</p>
    </div>
    """,
    unsafe_allow_html=True
)


# --------------------------------------------------
# MAIN HEADER
# --------------------------------------------------

st.markdown("""
<div class="main-header">
    <h1>❄️ ColdChain Monitor</h1>
    <p>Monitor Shipments | Track Temperatures | Manage Excursions</p>
</div>
""", unsafe_allow_html=True)


# --------------------------------------------------
# COMMON SUMMARY QUERY
# --------------------------------------------------

summary_query = """
SELECT
    (SELECT COUNT(*) FROM products) AS total_products,
    (SELECT COUNT(*) FROM shipments) AS total_shipments,
    (SELECT COUNT(*) FROM containers) AS total_containers,
    (SELECT COUNT(*) FROM sensors) AS total_sensors,
    (SELECT COUNT(*) FROM sensor_readings) AS total_readings,
    (SELECT COUNT(*) FROM excursions) AS total_excursions,
    (SELECT COUNT(*) FROM corrective_actions) AS total_actions
"""

summary = load_data(summary_query).iloc[0]


# --------------------------------------------------
# DASHBOARD PAGE
# --------------------------------------------------

if page == "Dashboard":

    st.markdown(
        '<div class="page-heading">📊 Dashboard Overview</div>',
        unsafe_allow_html=True
    )

    st.markdown(
        '<div class="page-subtitle">Cold chain logistics and monitoring summary.</div>',
        unsafe_allow_html=True
    )

    c1, c2, c3, c4 = st.columns(4)

    c1.metric("Total Shipments", int(summary["total_shipments"]))
    c2.metric("Total Containers", int(summary["total_containers"]))
    c3.metric("Total Sensors", int(summary["total_sensors"]))
    c4.metric("Total Excursions", int(summary["total_excursions"]))

    c5, c6, c7 = st.columns(3)

    c5.metric("Products", int(summary["total_products"]))
    c6.metric("Sensor Readings", int(summary["total_readings"]))
    c7.metric("Corrective Actions", int(summary["total_actions"]))

    st.markdown(
        '<div class="section-heading">📦 Shipment Status</div>',
        unsafe_allow_html=True
    )

    shipment_status = load_data("""
        SELECT status, COUNT(*) AS total
        FROM shipments
        GROUP BY status
    """)

    if not shipment_status.empty:

        fig = px.bar(
            shipment_status,
            x="status",
            y="total",
            color="status",
            text="total",
            title="Shipment Status Distribution",
            color_discrete_sequence=[
                "#087cf0",
                "#16a765",
                "#ff9f1c"
            ]
        )

        fig.update_layout(
            paper_bgcolor="white",
            plot_bgcolor="white",
            font_color="#000000",
            title_font_color="#000000"
        )

        st.plotly_chart(fig, use_container_width=True)

    st.markdown(
        '<div class="section-heading">⚠️ Excursion Severity</div>',
        unsafe_allow_html=True
    )

    severity_data = load_data("""
        SELECT severity, COUNT(*) AS total
        FROM excursions
        GROUP BY severity
    """)

    if not severity_data.empty:

        fig = px.pie(
            severity_data,
            names="severity",
            values="total",
            hole=0.45,
            color="severity",
            color_discrete_map={
                "LOW": "#087cf0",
                "MEDIUM": "#ff9817",
                "HIGH": "#ef4444",
                "CRITICAL": "#7c3aed"
            },
            title="Excursion Severity Distribution"
        )

        fig.update_traces(
            textposition="inside",
            textinfo="percent+value"
        )

        fig.update_layout(
            paper_bgcolor="white",
            font_color="#000000",
            title_font_color="#000000"
        )

        st.plotly_chart(fig, use_container_width=True)


# --------------------------------------------------
# SHIPMENTS PAGE
# --------------------------------------------------

elif page == "Shipments":

    st.markdown(
        '<div class="page-heading">🚚 Shipment Management</div>',
        unsafe_allow_html=True
    )

    st.markdown(
        '<div class="page-subtitle">View and search shipment information.</div>',
        unsafe_allow_html=True
    )

    shipment_query = """
        SELECT
            s.shipment_id,
            p.product_name,
            s.origin,
            s.destination,
            s.status,
            s.planned_departure,
            s.actual_delivery
        FROM shipments s
        JOIN products p ON s.product_id = p.product_id
        ORDER BY s.shipment_id DESC
    """

    shipments = load_data(shipment_query)

    a, b = st.columns(2)

    a.metric("Total Shipments", len(shipments))

    b.metric(
        "Delivered Shipments",
        int((shipments["status"] == "DELIVERED").sum())
    )

    st.markdown("### 🔎 Search Shipment")

    shipment_id = st.text_input("Enter Shipment ID")

    if st.button("Search Shipment"):

        if shipment_id.strip():

            search_query = """
                SELECT
                    s.shipment_id,
                    p.product_name,
                    s.origin,
                    s.destination,
                    s.status,
                    s.planned_departure,
                    s.actual_delivery
                FROM shipments s
                JOIN products p ON s.product_id = p.product_id
                WHERE s.shipment_id = %s
            """

            result = load_data(
                search_query,
                (shipment_id.strip(),)
            )

            if not result.empty:
                st.success("Shipment found!")
                st.dataframe(result, use_container_width=True)

            else:
                st.warning("No shipment found with this ID.")

        else:
            st.warning("Please enter a Shipment ID.")

    st.markdown("### 📦 All Shipments")

    st.dataframe(
        shipments,
        use_container_width=True,
        hide_index=True
    )

    st.download_button(
        "⬇️ Download Shipments Report",
        shipments.to_csv(index=False),
        "shipments_report.csv",
        "text/csv"
    )


# --------------------------------------------------
# TEMPERATURE MONITORING PAGE
# --------------------------------------------------

elif page == "Temperature Monitoring":

    st.markdown(
        '<div class="page-heading">🌡️ Temperature Monitoring</div>',
        unsafe_allow_html=True
    )

    st.markdown(
        '<div class="page-subtitle">Analyze recorded sensor temperatures.</div>',
        unsafe_allow_html=True
    )

    temperature_data = load_data("""
        SELECT
            shipment_id,
            COUNT(*) AS total_readings,
            ROUND(AVG(temperature_c), 2) AS average_temperature,
            ROUND(MIN(temperature_c), 2) AS minimum_temperature,
            ROUND(MAX(temperature_c), 2) AS maximum_temperature
        FROM sensor_readings
        WHERE temperature_c IS NOT NULL
        GROUP BY shipment_id
        ORDER BY shipment_id
    """)

    if not temperature_data.empty:

        c1, c2, c3 = st.columns(3)

        c1.metric(
            "Recorded Shipments",
            len(temperature_data)
        )

        c2.metric(
            "Average Temperature",
            f"{temperature_data['average_temperature'].mean():.2f} °C"
        )

        c3.metric(
            "Maximum Temperature",
            f"{temperature_data['maximum_temperature'].max():.2f} °C"
        )

        st.markdown("### 📈 Temperature by Shipment")

        fig = px.bar(
            temperature_data,
            x="shipment_id",
            y="average_temperature",
            color="average_temperature",
            color_continuous_scale="Blues",
            text="average_temperature",
            labels={
                "shipment_id": "Shipment ID",
                "average_temperature": "Average Temperature (°C)"
            }
        )

        fig.update_layout(
            paper_bgcolor="white",
            plot_bgcolor="white",
            font_color="#000000",
            title_font_color="#000000"
        )

        st.plotly_chart(fig, use_container_width=True)

        st.markdown("### 🌡️ Temperature Summary")

        st.dataframe(
            temperature_data,
            use_container_width=True,
            hide_index=True
        )

        st.download_button(
            "⬇️ Download Temperature Report",
            temperature_data.to_csv(index=False),
            "temperature_report.csv",
            "text/csv"
        )

    else:
        st.info("No temperature readings available.")


# --------------------------------------------------
# EXCURSION ANALYSIS PAGE
# --------------------------------------------------

elif page == "Excursion Analysis":

    st.markdown(
        '<div class="page-heading">⚠️ Excursion Analysis</div>',
        unsafe_allow_html=True
    )

    st.markdown(
        '<div class="page-subtitle">Analyze temperature and humidity excursions.</div>',
        unsafe_allow_html=True
    )

    excursion_query = """
        SELECT
            e.excursion_id,
            e.shipment_id,
            p.product_name,
            e.sensor_id,
            e.excursion_type,
            e.start_time,
            e.end_time,
            e.duration_minutes,
            e.severity,
            e.excursion_status
        FROM excursions e
        JOIN shipments s ON e.shipment_id = s.shipment_id
        JOIN products p ON s.product_id = p.product_id
        ORDER BY e.excursion_id DESC
    """

    excursions = load_data(excursion_query)

    # Total Excursions
    st.markdown(f"""
    <div style="
        background:linear-gradient(100deg,#ffe1e4,#fff0f1);
        border-radius:15px;
        padding:22px;
        margin:15px 0 20px 0;
        border:1px solid #ffc8cf;
    ">
        <h3 style="color:#000000;margin:0;">⚠️ Total Excursions</h3>
        <h1 style="color:#000000;font-size:48px;margin:0;">
            {len(excursions)}
        </h1>
    </div>
    """, unsafe_allow_html=True)

    col1, col2 = st.columns(2)

    # Severity chart
    with col1:

        st.markdown(
            '<div class="section-heading">📊 Severity Distribution</div>',
            unsafe_allow_html=True
        )

        severity_data = (
            excursions["severity"]
            .value_counts()
            .reset_index()
        )

        severity_data.columns = ["severity", "total"]

        if not severity_data.empty:

            fig = px.pie(
                severity_data,
                names="severity",
                values="total",
                hole=0.45,
                color="severity",
                color_discrete_map={
                    "LOW": "#087cf0",
                    "MEDIUM": "#ff9817",
                    "HIGH": "#ef4444",
                    "CRITICAL": "#7c3aed"
                }
            )

            fig.update_traces(
                textposition="inside",
                textinfo="label+percent+value",
                textfont=dict(color="white", size=13)
            )

            fig.update_layout(
                paper_bgcolor="white",
                plot_bgcolor="white",
                font=dict(color="#000000", size=14),
                legend=dict(font=dict(color="#000000"))
            )

            st.plotly_chart(fig, use_container_width=True)

        else:
            st.info("No severity records available.")

    # Status chart
    with col2:

        st.markdown(
            '<div class="section-heading">🟢 Excursion Status</div>',
            unsafe_allow_html=True
        )

        status_data = (
            excursions["excursion_status"]
            .fillna("UNKNOWN")
            .value_counts()
            .reset_index()
        )

        status_data.columns = ["excursion_status", "total"]

        if not status_data.empty:

            fig = px.pie(
                status_data,
                names="excursion_status",
                values="total",
                hole=0.45,
                color="excursion_status",
                color_discrete_map={
                    "OPEN": "#ef4444",
                    "UNDER_REVIEW": "#ff9817",
                    "RESOLVED": "#16a765",
                    "UNKNOWN": "#64748b"
                }
            )

            fig.update_traces(
                textposition="inside",
                textinfo="label+percent+value",
                textfont=dict(color="black", size=13)
            )

            fig.update_layout(
                paper_bgcolor="white",
                plot_bgcolor="white",
                font=dict(color="#000000", size=14),
                legend=dict(font=dict(color="#000000"))
            )

            st.plotly_chart(fig, use_container_width=True)

        else:
            st.info("No status records available.")

    # Excursion records
    st.markdown(
        '<div class="section-heading">📋 Excursion Records</div>',
        unsafe_allow_html=True
    )

    st.dataframe(
        excursions,
        use_container_width=True,
        hide_index=True
    )

    st.download_button(
        "⬇️ Download Excursion Report",
        excursions.to_csv(index=False),
        "excursion_report.csv",
        "text/csv"
    )


# --------------------------------------------------
# CORRECTIVE ACTIONS PAGE
# --------------------------------------------------

elif page == "Corrective Actions":

    st.markdown(
        '<div class="page-heading">🛠️ Corrective Actions</div>',
        unsafe_allow_html=True
    )

    st.markdown(
        '<div class="page-subtitle">Track and manage corrective actions for shipment excursions.</div>',
        unsafe_allow_html=True
    )

    query = """
        SELECT
            action_id,
            shipment_id,
            excursion_id,
            action_type,
            description,
            assigned_to,
            opened_at,
            due_at,
            completed_at,
            action_status,
            resolution_notes
        FROM corrective_actions
        ORDER BY opened_at DESC
    """

    # Load corrective action data
    df = load_data(query)

    # KPI metrics
    total_actions = len(df)

    open_actions = (
        df["action_status"] == "OPEN"
    ).sum()

    in_progress = (
        df["action_status"] == "IN_PROGRESS"
    ).sum()

    completed = (
        df["action_status"] == "COMPLETED"
    ).sum()

    col1, col2, col3, col4 = st.columns(4)

    col1.metric("Total Actions", total_actions)
    col2.metric("Open Actions", int(open_actions))
    col3.metric("In Progress", int(in_progress))
    col4.metric("Completed", int(completed))

    st.divider()

    # Action status chart
    st.markdown(
        '<div class="section-heading">📊 Corrective Actions by Status</div>',
        unsafe_allow_html=True
    )

    status_counts = (
        df["action_status"]
        .fillna("UNKNOWN")
        .value_counts()
        .reset_index()
    )

    status_counts.columns = ["Status", "Count"]

    if not status_counts.empty:

        fig = px.bar(
            status_counts,
            x="Status",
            y="Count",
            color="Status",
            color_discrete_map={
                "OPEN": "#ef4444",
                "IN_PROGRESS": "#f59e0b",
                "COMPLETED": "#16a34a",
                "CANCELLED": "#64748b",
                "UNKNOWN": "#94a3b8"
            },
            text="Count"
        )

        fig.update_traces(
            textposition="outside",
            textfont=dict(color="#000000")
        )

        fig.update_layout(
            plot_bgcolor="white",
            paper_bgcolor="white",
            font_color="#000000",
            xaxis_title="Action Status",
            yaxis_title="Number of Actions",
            showlegend=False
        )

        st.plotly_chart(fig, use_container_width=True)

    else:
        st.info("No corrective action records available.")

    st.divider()

    # Corrective action records
    st.markdown(
        '<div class="section-heading">📋 Corrective Action Records</div>',
        unsafe_allow_html=True
    )

    st.dataframe(
        df,
        use_container_width=True,
        hide_index=True
    )

    # CSV download
    csv = df.to_csv(index=False).encode("utf-8")

    st.download_button(
        label="📥 Download Corrective Actions CSV",
        data=csv,
        file_name="corrective_actions.csv",
        mime="text/csv"
    )


# --------------------------------------------------
# FOOTER
# --------------------------------------------------

st.markdown("""
<div class="footer">
    ❄️ Cold Chain Monitoring System<br>
    Developed using Python | MySQL | Streamlit
</div>
""", unsafe_allow_html=True)
