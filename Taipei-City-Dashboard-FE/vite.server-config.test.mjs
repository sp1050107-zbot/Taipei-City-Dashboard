import assert from "node:assert/strict";
import { resolveServerConfig } from "./vite.server-config.js";

// Container mode (Phase 1): unchanged. Proxy to the BE container by name, port 80.
{
	const cfg = resolveServerConfig({ DOCKER_COMPOSE: "true" });
	assert.equal(cfg.host, "0.0.0.0");
	assert.equal(cfg.port, 80);
	assert.deepEqual(Object.keys(cfg.proxy), ["/api/dev"]);
	assert.equal(cfg.proxy["/api/dev"].target, "http://dashboard-be:8080");
	assert.equal(cfg.proxy["/api/dev"].changeOrigin, true);
	assert.equal(cfg.proxy["/api/dev"].rewrite("/api/dev/x"), "/api/v1/x");
}

// Native mode default: local BE on 8088, FE on 8080, never production.
{
	const cfg = resolveServerConfig({});
	assert.equal(cfg.port, 8080);
	assert.equal(cfg.proxy["/api/dev"].target, "http://localhost:8088");
	assert.equal(cfg.proxy["/api/dev"].rewrite("/api/dev/x"), "/api/v1/x");
	assert.ok(!JSON.stringify(cfg.proxy).includes("citydashboard.taipei"));
}

// VITE_LOCAL_BE_URL overrides the native default.
{
	const cfg = resolveServerConfig({ VITE_LOCAL_BE_URL: "http://localhost:9999" });
	assert.equal(cfg.proxy["/api/dev"].target, "http://localhost:9999");
}

console.log("PASS");
