# ❄️ Cold Chain Monitoring System

## Temperature & Humidity Monitoring for Smart Logistics

### 1. Project Overview

The Cold Chain Monitoring System is a data-driven application developed to monitor temperature and humidity conditions during the storage and transportation of temperature-sensitive products.

The system helps users monitor shipments, track sensor readings, identify temperature excursions, and manage corrective actions. It provides visibility into shipment conditions and helps maintain product quality throughout the transportation process.

### 2. Objectives

- Monitor temperature and humidity readings.
- Track shipments and containers.
- Identify abnormal temperature conditions.
- Detect and analyze temperature excursions.
- Maintain shipment custody and event records.
- Track corrective actions.
- Generate monitoring and validation reports.

### 3. Technologies Used

- **Programming Language:** Python
- **Database:** MySQL
- **Frontend / Dashboard:** Streamlit
- **Libraries:** Pandas, NumPy
- **Data Format:** CSV

### 4. Key Features

- Interactive dashboard displaying shipment and monitoring information.
- Temperature and humidity summaries.
- Shipment and container tracking.
- Sensor reading analysis.
- Excursion monitoring and severity analysis.
- Corrective action tracking.
- Database validation and downloadable reports.

### 5. Database Entities

The database contains the following entities:

1. Product
2. Shipment
3. Container
4. Sensor
5. Sensor Reading
6. Route Stop
7. Threshold Policy
8. Excursion
9. Custody Event
10. Corrective Action

Primary keys and foreign keys are used to maintain relationships and data integrity.

### 6. Synthetic Data Generation

The project uses a Python-based synthetic data generator with a fixed random seed (`20261022`) to support reproducible testing.

The generated dataset includes:

- 1,000 shipments
- 300 containers
- Sensor readings at five-minute intervals
- Product-specific temperature thresholds
- Temperature and humidity measurements
- Labelled edge cases and ground-truth records

### 7. Validation and Testing

The project includes validation checks for:

- Primary key uniqueness
- Foreign key integrity
- Missing values
- Shipment date consistency
- Route-stop timestamp consistency
- Shipment and custody event matching
- Physical temperature range violations
- Sensor reading quality

Reproducibility and labelled edge cases are also tested using separate Python scripts.

### 8. Project Structure

```text
Cold_Chain_Monitoring/
│
├── app.py
├── database.sql
├── schema.sql
├── ground_truth.csv
├── requirements.txt
├── validate_project.py
├── validation_report.csv
├── validation_details.csv
├── README.md
│
└── data_generator/
    ├── generate_data.py
    ├── generate_data_test.py
    ├── check_reproducibility.py
    ├── detect_excursions.py
    ├── validate_edge_cases.py
    ├── final_validation.py
    └── output/
```

### 9. Installation and Execution

**Step 1: Clone the repository**

```bash
git clone YOUR_GITHUB_REPOSITORY_URL
cd Cold_Chain_Monitoring
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure MySQL**

Create the database and import the provided SQL schema and seed data. Configure database connection settings before running the application.

**Step 4: Run the application**

```bash
streamlit run app.py
```

Open the local URL displayed in the terminal, usually:

```text
http://localhost:8501
```

### 10. Validation

Run the database validation script:

```bash
python validate_project.py
```

The script generates:

- `validation_report.csv`
- `validation_details.csv`

### 11. Expected Outcome

The application provides a centralized dashboard to monitor shipment conditions, analyze temperature and humidity readings, identify excursions, and track corrective actions.

### 12. Author

Developed as a Cold Chain Monitoring System project using Python, MySQL, and Streamlit.
