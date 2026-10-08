import { defineConfig, loadEnv } from "vite";
import vue from "@vitejs/plugin-vue";
import viteCompression from "vite-plugin-compression";
import { buildServerConfig } from "./vite.server-config.js";

export default defineConfig(({ mode }) => ({
	plugins: [vue(), viteCompression()],
	build: {
		rollupOptions: {
			output: {
				manualChunks(id) {
					if (id.includes("node_modules")) {
						return id
							.toString()
							.split("node_modules/")[1]
							.split("/")[0]
							.toString();
					}
				},
			},
		},
		chunkSizeWarningLimit: 1600,
	},
	base: "/",
	server: buildServerConfig({
		mode,
		root: process.cwd(), // eslint-disable-line no-undef
		processEnv: process.env, // eslint-disable-line no-undef
		loadEnv,
	}),
}));