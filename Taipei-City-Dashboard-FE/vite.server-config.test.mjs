import assert from "node:assert/strict";
import { resolveServerConfig, buildServerConfig } from "./vite.server-config.js";

// Container mode (Phase 1): unchanged. Proxy to the BE container by name, port 80.
{
	const cfg = resolveServerConfig({ DOCKER_COMPOSE: "true" });
	assert.equal(cfg.host, "0.0.0.0");
	assert.equal(cfg.port, 80);
	assert.equal(cfg.strictPort, undefined);
	assert.deepEqual(Object.keys(cfg.proxy), ["/api/dev"]);
	assert.equal(cfg.proxy["/api/dev"].target, "http://dashboard-be:8080");
	assert.equal(cfg.proxy["/api/dev"].changeOrigin, true);
	assert.equal(cfg.proxy["/api/dev"].rewrite("/api/dev/x"), "/api/v1/x");
}

// Native mode default: local BE on 8088, FE on 8080, never production.
{
	const cfg = resolveServerConfig({});
	assert.equal(cfg.port, 8080);
	assert.equal(cfg.host, "127.0.0.1");
	assert.equal(cfg.strictPort, true);
	assert.equal(cfg.proxy["/api/dev"].target, "http://localhost:8088");
	assert.equal(cfg.proxy["/api/dev"].rewrite("/api/dev/x"), "/api/v1/x");
	assert.ok(!JSON.stringify(cfg.proxy).includes("citydashboard.taipei"));
}

// VITE_LOCAL_BE_URL overrides the native default.
{
	const cfg = resolveServerConfig({ VITE_LOCAL_BE_URL: "http://localhost:9999" });
	assert.equal(cfg.proxy["/api/dev"].target, "http://localhost:9999");
}

// buildServerConfig: local env file values (via the injected loader) take effect.
{
	const calls = [];
	const loadEnv = (mode, root, prefix) => {
		calls.push([mode, root, prefix]);
		return { VITE_LOCAL_BE_URL: "http://localhost:7777" };
	};
	const cfg = buildServerConfig({ mode: "development", root: "/app", processEnv: {}, loadEnv });
	assert.equal(cfg.proxy["/api/dev"].target, "http://localhost:7777");
	assert.deepEqual(calls, [["development", "/app", ""]]);
}

// Process environment wins over the env file.
{
	const loadEnv = () => ({ VITE_LOCAL_BE_URL: "http://localhost:7777" });
	const cfg = buildServerConfig({
		mode: "development",
		root: "/app",
		processEnv: { VITE_LOCAL_BE_URL: "http://localhost:6666" },
		loadEnv,
	});
	assert.equal(cfg.proxy["/api/dev"].target, "http://localhost:6666");
}

// DOCKER_COMPOSE from the process environment still selects container mode.
{
	const loadEnv = () => ({ VITE_LOCAL_BE_URL: "http://localhost:7777" });
	const cfg = buildServerConfig({
		mode: "development",
		root: "/app",
		processEnv: { DOCKER_COMPOSE: "true" },
		loadEnv,
	});
	assert.equal(cfg.host, "0.0.0.0");
	assert.equal(cfg.port, 80);
	assert.equal(cfg.proxy["/api/dev"].target, "http://dashboard-be:8080");
}

console.log("PASS");
