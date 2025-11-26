import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'
import frappeui from 'frappe-ui/vite'
import { VitePWA } from 'vite-plugin-pwa'

// Plugin to handle Frappe asset paths
const frappeAssetPaths = () => ({
	name: 'frappe-asset-paths',
	load(id) {
		// Return null for asset paths - they'll be served by Frappe at runtime
		if (id.startsWith('/assets/')) {
			return 'export default null'
		}
		return null
	},
	resolveId(id) {
		// Mark asset paths as external so Vite doesn't try to bundle them
		if (id.startsWith('/assets/')) {
			return { id, external: true }
		}
		return null
	},
})

// https://vitejs.dev/config/
export default defineConfig({
	plugins: [
		frappeAssetPaths(),
		frappeui({
			frappeProxy: true,
			lucideIcons: true,
			jinjaBootData: true,
			frappeTypes: {
				input: {},
			},
			buildConfig: {
				indexHtmlPath: '../lms/www/lms.html',
			},
		}),
		vue({
			script: {
				defineModel: true,
				propsDestructure: true,
			},
		}),
		VitePWA({
			registerType: 'autoUpdate',
			devOptions: {
				enabled: true,
			},
			workbox: {
				cleanupOutdatedCaches: true,
				maximumFileSizeToCacheInBytes: 5 * 1024 * 1024,
			},
			manifest: false,
		}),
	],
	server: {
		host: '0.0.0.0', // Accept connections from any network interface
		allowedHosts: ['ps', 'fs', 'home'], // Explicitly allow this host
	},
	resolve: {
		alias: {
			'@': path.resolve(__dirname, 'src'),
			'tailwind.config.js': path.resolve(__dirname, 'tailwind.config.js'),
		},
	},
	optimizeDeps: {
		include: [
			'feather-icons',
			'showdown',
			'engine.io-client',
			'tailwind.config.js',
			'interactjs',
			'highlight.js',
			'plyr',
		],
	},
})
