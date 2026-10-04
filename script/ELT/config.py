# config.py
SETTINGS = {
    "database": {
        "host": "localhost",
        "database": "erp_db",
        "user": "erp_admin",
        "password": "production!",
        "port": 5432
    },

    "config":{
        "host":"localhost",
        "database":"analytic_db",
        "user":"analytic_admin",
        "password":"p2r0o2d6uction!",
        "port":5432
    },

    "data_extension": {
        "format": "csv",
        "path": "data_extension.csv",
        "header": True,
    },

    "product_data": {
        "format": "csv",
        "path": "product_data.csv",
        "header": True,
    },

    "client_data": {
        "format": "csv",
        "path": "client_data.csv",
        "header": True,
    },

    "customer_data": {
        "format": "csv",
        "path": "customer_data.csv",
        "header": True,
    },

    "location_data": {
        "format": "csv",
        "path": "location_data.csv",
        "header": True,
    },

    "vendor_data": {
        "format": "csv",
        "path": "vendor_data.csv",
        "header": True,
    },

    "data": {
        "format": "csv",
        "path": "data.csv",
        "header": True,
    },


    # ✅ List of strings to treat as missing values
    "missing_string_map": [
    "NULL", "null", "NaN", "nan", 
    "N/A", "n/a", "NA", "na", 
    "?", "-", "", " ", ", ",
    "Null", "Null ", " NULL", " NULL "  # <--- Add these variations!
    ],

    # ✅ Schema definition (Column Name -> Expected Type)
    "SCHEMA": {
        "invoice_code":"object",
        "client_code": "Int64",
        "customer_code": "Int64",
        "due_date": "datetime",
        "invoice_date": "datetime",
        "payment_recieved": "float",
        "status": "object",
        "product_code":"Int64",
        "quantity":"Int64",
        "discount":"float",
        "client_name":"object",
        "contact_info":"object",
        "email":"object",
        "address":"object",
        "customer_name":"object",
        "location_code":"Int64",
        "location_name":"object",
        "product_name":"object",
        "description":"object",
        "product_unit":"object",
        "cost":"float",
        "price":"float",
        "purchase_date":"datetime",
        "vendor_code":"Int64",
        "vendor_name":"object",
    }
}