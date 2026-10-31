# ❄️ Cold Chain Monitoring System

## 1. Project Overview

The Cold Chain Monitoring System is a database-driven application developed to monitor and analyze shipment information, sensor temperature readings, temperature excursions, and corrective actions.

The system uses Python, MySQL, and Streamlit to provide an interactive dashboard for viewing shipment details, analyzing temperature data, identifying excursions, and tracking corrective actions.

**Note:** This project uses synthetic sensor data for demonstration purposes. It is not connected to live IoT sensors.

## 2. Objectives

- Manage shipment, product, container, and sensor information.
- Store and analyze sensor temperature readings.
- Identify temperature excursions.
- Analyze excursion severity and status.
- Track corrective actions.
- Generate reports and download data as CSV files.

## 3. Technologies Used

- **Python** – Application development and data processing.
- **MySQL** – Database management and storage.
- **Streamlit** – Interactive web application.
- **Pandas** – Data handling and analysis.
- **Plotly** – Interactive charts and visualizations.
- **MySQL Connector** – Python and MySQL connectivity.

## 4. Database Structure

The project uses the following 12 MySQL tables:

1. products
2. shipments
3. containers
4. sensors
5. threshold_policies
6. shipment_containers
7. route_stops
8. container_sensor_assignments
9. sensor_readings
10. excursions
11. custody_events
12. corrective_actions

## 5. Application Modules

### Dashboard
- Displays total shipments and other key statistics.
- Shows shipment status and excursion severity charts.

### Shipments
- Displays shipment information.
- Supports searching and downloading shipment records.

### Temperature Monitoring
- Displays available sensor temperature readings.
- Provides temperature trend charts.
- Supports CSV data downloads.

### Excursion Analysis
- Displays temperature excursion details.
- Analyzes excursion severity and status.

### Corrective Actions
- Displays corrective action records.
- Tracks action status and related information.

## 6. Project Structure

```text
Cold_Chain_Monitoring/
│
├── app.py
├── README.md
└── requirements.txt
```

## 7. Installation and Setup

### Step 1: Install Python Dependencies

Open the terminal in the project folder and run:

```bash
pip install -r requirements.txt
```

### Step 2: Create the MySQL Database

Open MySQL Workbench and execute the SQL scripts to create the database and tables and insert the sample data.

Database name:

```sql
cold_chain_db
```

### Step 3: Configure Database Connection

Open `app.py` and update the MySQL connection details with your local credentials.

```python
def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="YOUR_MYSQL_PASSWORD",
        database="cold_chain_db"
    )
```

Replace `YOUR_MYSQL_PASSWORD` with your own MySQL password. Do not upload your actual password to GitHub.

### Step 4: Run the Application

Execute the following command:

```bash
streamlit run app.py
```

The application will open in your browser at:

```text
http://localhost:8501
```

## 8. Key Features

- Interactive dashboard.
- Shipment information management and analysis.
- Sensor temperature monitoring.
- Temperature excursion analysis.
- Corrective action tracking.
- Interactive charts and visualizations.
- CSV report downloads.
- MySQL database integration.

## 9. Sample Dataset Information

The project contains sample synthetic data:

- 10 products
- 1,000 shipments
- 300 containers
- 300 sensors
- 5,760 sensor readings
- 39 excursions
- 39 corrective actions

**Data limitations:** Sensor readings are available for the first 10 shipments only. Humidity readings are currently NULL. The data is synthetic and is used for project demonstration.

## 10. Future Enhancements

- Integration with real-time IoT sensors.
- Live temperature and humidity monitoring.
- Email and SMS alerts for temperature excursions.
- Advanced analytics and predictive models.
- Deployment to a cloud platform.

## 11. Conclusion

The Cold Chain Monitoring System provides an interactive platform to manage shipment information, analyze sensor temperature data, identify temperature excursions, and track corrective actions. It demonstrates the integration of Python, MySQL, and Streamlit to build a database-driven monitoring application.