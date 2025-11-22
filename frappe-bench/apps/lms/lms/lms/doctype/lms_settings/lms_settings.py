# Copyright (c) 2021, FOSS United and contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import get_url_to_list, validate_email_address, validate_url


class LMSSettings(Document):
	def onload(self):
		# Sync disable_signup from Website Settings on load if not set in LMS Settings
		# This ensures backward compatibility if settings were changed in Website Settings
		if self.disable_signup is None:
			website_disable_signup = frappe.db.get_single_value("Website Settings", "disable_signup")
			if website_disable_signup is not None:
				self.disable_signup = website_disable_signup

	def validate(self):
		self.validate_google_settings()
		self.validate_signup()
		self.validate_contact_us_details()

	def validate_google_settings(self):
		if self.send_calendar_invite_for_evaluations:
			google_settings = frappe.get_single("Google Settings")

			if not google_settings.enable:
				frappe.throw(
					_("Enable Google API in Google Settings to send calendar invites for evaluations.")
				)

			if not google_settings.client_id or not google_settings.client_secret:
				frappe.throw(
					_(
						"Enter Client Id and Client Secret in Google Settings to send calendar invites for evaluations."
					)
				)

			calendars = frappe.db.count("Google Calendar")
			if not calendars:
				frappe.throw(
					_(
						"Please add <a href='{0}'>{1}</a> for <a href='{2}'>{3}</a> to send calendar invites for evaluations."
					).format(
						get_url_to_list("Google Calendar"),
						frappe.bold("Google Calendar"),
						get_url_to_list("Course Evaluator"),
						frappe.bold("Course Evaluator"),
					)
				)

	def validate_signup(self):
		# Always sync disable_signup to Website Settings to ensure consistency
		# This ensures that LMS Settings is the source of truth for signup settings
		frappe.db.set_single_value("Website Settings", "disable_signup", self.disable_signup)

	def validate_contact_us_details(self):
		if self.contact_us_email and not validate_email_address(self.contact_us_email):
			frappe.throw(_("Please enter a valid Contact Us Email."))
		if self.contact_us_url and not validate_url(self.contact_us_url, True):
			frappe.throw(_("Please enter a valid Contact Us URL."))


@frappe.whitelist()
def check_payments_app():
	installed_apps = frappe.get_installed_apps()
	if "payments" not in installed_apps:
		return False
	else:
		filters = {
			"doctype_or_field": "DocField",
			"doc_type": "LMS Settings",
			"field_name": "payment_gateway",
		}
		if frappe.db.exists("Property Setter", filters):
			return True

		link_property = frappe.new_doc("Property Setter")
		link_property.update(filters)
		link_property.property = "fieldtype"
		link_property.value = "Link"
		link_property.save()

		options_property = frappe.new_doc("Property Setter")
		options_property.update(filters)
		options_property.property = "options"
		options_property.value = "Payment Gateway"
		options_property.save()

		return True