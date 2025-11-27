#!/usr/bin/env python3
"""Bootstrap Frappe database when user already exists"""
import sys
import os

# Change to bench directory
bench_path = os.path.dirname(os.path.abspath(__file__))
os.chdir(bench_path)

# Add bench to path
sys.path.insert(0, os.path.join(bench_path, 'apps', 'frappe'))

import frappe

def bootstrap():
    try:
        # Get site name from environment or use default
        site_name = os.environ.get('SITE_NAME', 'vgi.local')
        
        # Set sites path
        sites_path = os.path.join(bench_path, 'sites')
        
        # Initialize site
        frappe.init(site_name, sites_path=sites_path)
        frappe.connect()
        
        print("Connected to database. Bootstrapping...")
        
        # Set install flag
        frappe.flags.in_install_db = True
        
        # Bootstrap database
        from frappe.database import bootstrap_database
        bootstrap_database(verbose=True)
        
        # Create essential tables
        print("Creating auth table...")
        frappe.db.create_auth_table()
        
        print("Creating global search table...")
        frappe.db.create_global_search_table()
        
        print("Creating user settings table...")
        frappe.db.create_user_settings_table()
        
        frappe.flags.in_install_db = False
        
        print("Database bootstrapped successfully!")
        frappe.db.commit()
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        frappe.destroy()

if __name__ == '__main__':
    bootstrap()

