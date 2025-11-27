#!/usr/bin/env python3
"""Bootstrap database using existing connection"""
import os
import sys

# Ensure we're in the bench directory
bench_path = os.path.dirname(os.path.abspath(__file__))
os.chdir(bench_path)

# Add to Python path
sys.path.insert(0, os.path.join(bench_path, 'apps', 'frappe'))

import frappe

def main():
    try:
        # Get site name from environment or use default
        site_name = os.environ.get('SITE_NAME', 'vgi.local')
        
        print(f"Initializing site: {site_name}...")
        sites_path = os.path.join(bench_path, 'sites')
        frappe.init(site_name, sites_path=sites_path)
        
        print("Connecting to database...")
        frappe.connect()
        
        print("Bootstrapping database...")
        frappe.flags.in_install_db = True
        
        # Import and run bootstrap
        from frappe.database import bootstrap_database
        bootstrap_database(verbose=True)
        
        print("Creating essential tables...")
        frappe.db.create_auth_table()
        frappe.db.create_global_search_table()
        frappe.db.create_user_settings_table()
        
        frappe.flags.in_install_db = False
        
        print("Committing changes...")
        frappe.db.commit()
        
        site_name = os.environ.get('SITE_NAME', 'vgi.local')
        print(f"\n✅ Database bootstrapped successfully!")
        print(f"You can now run: bench --site {site_name} migrate")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        frappe.destroy()

if __name__ == '__main__':
    main()

