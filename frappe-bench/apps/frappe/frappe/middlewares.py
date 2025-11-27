# Copyright (c) 2015, Frappe Technologies Pvt. Ltd. and Contributors
# License: MIT. See LICENSE

from pathlib import Path

from werkzeug.exceptions import NotFound, HTTPException
from werkzeug.middleware.shared_data import SharedDataMiddleware

import frappe
from frappe.utils import cstr, get_site_name


class StaticDataMiddleware(SharedDataMiddleware):
	def __call__(self, environ, start_response):
		self.environ = environ
		try:
			return super().__call__(environ, start_response)
		except NotFound:
			# Catch NotFound from the loader and return proper 404 response
			# This prevents it from being logged as a 500 error
			not_found = NotFound()
			return not_found(environ, start_response)
		except HTTPException as e:
			# Handle other HTTP exceptions properly
			return e(environ, start_response)

	def get_directory_loader(self, directory):
		def loader(path):
			try:
				site = get_site_name(frappe.app._site or self.environ.get("HTTP_HOST"))
				files_path = Path(directory) / site / "public" / "files"
				requested_path = Path(cstr(path))
				
				# Resolve the full path
				try:
					full_path = (files_path / requested_path).resolve()
				except (OSError, ValueError):
					# Path resolution failed (e.g., contains .. or invalid characters)
					raise NotFound
				
				# Check if path is relative to files_path (security check)
				try:
					if not full_path.is_relative_to(files_path):
						raise NotFound
				except AttributeError:
					# Python < 3.9 doesn't have is_relative_to
					# Fallback: check if files_path is a prefix
					try:
						full_path.relative_to(files_path)
					except ValueError:
						raise NotFound
				
				# Check if file exists
				if not full_path.is_file():
					# File doesn't exist - raise NotFound (this is correct behavior)
					# Don't log as error - missing files are expected and should return 404
					raise NotFound
				
				return full_path.name, self._opener(full_path)
			except NotFound:
				# Re-raise NotFound as-is (it's an HTTPException with status 404)
				# This should be handled by the application and return 404, not 500
				raise
			except Exception as e:
				# Any other exception should also result in NotFound
				# This prevents 500 errors from path resolution issues
				# Log the actual error for debugging but return NotFound to user
				if frappe.conf.developer_mode:
					frappe.logger().debug(f"File middleware error for {path}: {e}")
				raise NotFound

		return loader
