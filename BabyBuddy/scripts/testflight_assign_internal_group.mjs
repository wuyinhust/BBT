#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import process from "node:process";

const API_BASE = "https://api.appstoreconnect.apple.com/v1";

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function base64url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function createToken() {
  const keyId = requireEnv("ASC_KEY_ID");
  const issuerId = requireEnv("ASC_ISSUER_ID");
  const keyPath = requireEnv("ASC_KEY_PATH");
  const privateKey = fs.readFileSync(keyPath, "utf8");
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 20 * 60,
    aud: "appstoreconnect-v1"
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = crypto.sign("sha256", Buffer.from(signingInput), {
    key: privateKey,
    dsaEncoding: "ieee-p1363"
  });
  return `${signingInput}.${base64url(signature)}`;
}

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers ?? {})
    }
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const message = body?.errors?.map(error => error.detail || error.title).join("; ") || response.statusText;
    throw new Error(`${options.method || "GET"} ${path} failed: ${response.status} ${message}`);
  }
  return body;
}

async function paged(path) {
  const output = [];
  let nextPath = path;
  while (nextPath) {
    const page = await request(nextPath);
    output.push(...(page.data ?? []));
    nextPath = page.links?.next ? page.links.next.replace(API_BASE, "") : null;
  }
  return output;
}

function attr(record, key) {
  return record?.attributes?.[key];
}

async function findApp(bundleId) {
  const encoded = encodeURIComponent(bundleId);
  const body = await request(`/apps?filter[bundleId]=${encoded}&limit=1`);
  const app = body.data?.[0];
  if (!app) {
    throw new Error(`No App Store Connect app found for bundle id: ${bundleId}`);
  }
  return app;
}

async function findBetaGroup(appId, groupName) {
  const groups = await paged(`/apps/${appId}/betaGroups?limit=200`);
  const group = groups.find(item => attr(item, "name") === groupName);
  if (!group) {
    const names = groups.map(item => attr(item, "name")).filter(Boolean).join(", ");
    throw new Error(`No beta group named "${groupName}" found. Existing groups: ${names || "(none)"}`);
  }
  return group;
}

async function latestBuild(appId, version, buildNumber) {
  const filters = [`filter[app]=${encodeURIComponent(appId)}`];
  if (version) filters.push(`filter[preReleaseVersion.version]=${encodeURIComponent(version)}`);
  if (buildNumber) filters.push(`filter[version]=${encodeURIComponent(buildNumber)}`);
  const path = `/builds?${filters.join("&")}&sort=-uploadedDate&limit=20`;
  const body = await request(path);
  const build = body.data?.[0];
  if (!build) {
    throw new Error("No matching build found yet.");
  }
  return build;
}

async function waitForProcessedBuild(appId, version, buildNumber) {
  const timeoutMinutes = Number(process.env.TESTFLIGHT_PROCESSING_TIMEOUT_MINUTES || 60);
  const intervalSeconds = Number(process.env.TESTFLIGHT_POLL_INTERVAL_SECONDS || 60);
  const deadline = Date.now() + timeoutMinutes * 60 * 1000;
  let lastState = "UNKNOWN";

  while (Date.now() < deadline) {
    try {
      const build = await latestBuild(appId, version, buildNumber);
      lastState = attr(build, "processingState") || "UNKNOWN";
      const displayVersion = attr(build, "version") || buildNumber || "(unknown build)";
      const displayMarketingVersion = build.relationships?.preReleaseVersion?.data?.id || version || "(unknown version)";
      console.log(`Build ${displayMarketingVersion}/${displayVersion}: ${lastState}`);
      if (lastState === "VALID") {
        return build;
      }
      if (lastState === "FAILED" || lastState === "INVALID") {
        throw new Error(`Build processing ended with state: ${lastState}`);
      }
    } catch (error) {
      if (lastState === "FAILED" || lastState === "INVALID") {
        throw error;
      }
      console.log(`${error.message} Retrying...`);
    }
    await new Promise(resolve => setTimeout(resolve, intervalSeconds * 1000));
  }

  throw new Error(`Timed out waiting for build processing. Last state: ${lastState}`);
}

async function assignBuildToGroup(buildId, groupId) {
  await request(`/betaGroups/${groupId}/relationships/builds`, {
    method: "POST",
    body: JSON.stringify({
      data: [
        {
          type: "builds",
          id: buildId
        }
      ]
    })
  });
}

const token = createToken();
const bundleId = requireEnv("APP_BUNDLE_ID");
const betaGroupName = requireEnv("TESTFLIGHT_INTERNAL_GROUP");
const marketingVersion = process.env.APP_MARKETING_VERSION;
const buildNumber = process.env.APP_BUILD_NUMBER;

try {
  const app = await findApp(bundleId);
  const group = await findBetaGroup(app.id, betaGroupName);
  const build = await waitForProcessedBuild(app.id, marketingVersion, buildNumber);
  await assignBuildToGroup(build.id, group.id);
  console.log(`Assigned build ${attr(build, "version")} to TestFlight group "${betaGroupName}".`);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
