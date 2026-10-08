/**
 * Pure server-config resolver for vite.config.js, kept separate so the
 * environment-driven proxy/port decision is unit-testable without booting Vite.
 */
export function resolveServerConfig(env) {
	if (env.DOCKER_COMPOSE === "true") {
		return {
			host: "0.0.0.0",
			port: 80,
			proxy: {
				"/api/dev": {
					target: "http://dashboard-be:8080",
					changeOrigin: true,
					rewrite: (path) => path.replace("/dev", "/v1"),
				},
			},
		};
	}

	return {
		host: "127.0.0.1",
		port: 8080,
		strictPort: true,
		proxy: {
			"/api/dev": {
				target: env.VITE_LOCAL_BE_URL || "http://localhost:8088",
				changeOrigin: true,
				rewrite: (path) => path.replace("/dev", "/v1"),
			},
		},
	};
}

/**
 * Merges the Vite-loaded local environment files (mode-aware, all keys) under
 * the process environment (which wins) and resolves the server config.
 * `loadEnv` is injected so tests need no Vite installation.
 */
export function buildServerConfig({ mode, root, processEnv, loadEnv }) {
	return resolveServerConfig({ ...loadEnv(mode, root, ""), ...processEnv });
}
