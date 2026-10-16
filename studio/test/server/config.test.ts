import { describe, expect, it } from "vitest";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { CONFIG_VARIABLES, loadConfig } from "../../src/server/config.js";

describe("loadConfig", () => {
  it("applies the defaults when no variable is set", () => {
    expect(loadConfig({})).toEqual({
      port: 4490,
      host: "127.0.0.1",
      profilesDir: path.join(os.homedir(), ".kopanda/profiles"),
    });
  });

  it("takes the default for an empty value", () => {
    expect(
      loadConfig({ KOPANDA_STUDIO_PORT: "", KOPANDA_STUDIO_HOST: "", KOPANDA_STUDIO_PROFILES_DIR: "" }),
    ).toEqual({
      port: 4490,
      host: "127.0.0.1",
      profilesDir: path.join(os.homedir(), ".kopanda/profiles"),
    });
  });

  it("reads every variable when set", () => {
    expect(
      loadConfig({
        KOPANDA_STUDIO_PORT: "5000",
        KOPANDA_STUDIO_HOST: "0.0.0.0",
        KOPANDA_STUDIO_PROFILES_DIR: "/opt/profiles",
      }),
    ).toEqual({ port: 5000, host: "0.0.0.0", profilesDir: "/opt/profiles" });
  });

  it("expands ~ to the home directory", () => {
    expect(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: "~" }).profilesDir).toBe(os.homedir());
  });

  it("expands a leading ~/ to the home directory", () => {
    expect(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: "~/x" }).profilesDir).toBe(
      path.join(os.homedir(), "x"),
    );
  });

  it("leaves a ~ that does not start the path alone", () => {
    expect(loadConfig({ KOPANDA_STUDIO_PROFILES_DIR: "/a/~/b" }).profilesDir).toBe("/a/~/b");
  });

  it.each(["0", "65536", "abc", "80.5", "-1"])("refuses port %s, naming the variable and the value", (port) => {
    expect(() => loadConfig({ KOPANDA_STUDIO_PORT: port })).toThrow(
      new Error(`KOPANDA_STUDIO_PORT must be a port number, got "${port}"`),
    );
  });

  it.each([
    ["65535", 65535],
    ["1", 1],
  ])("accepts port %s", (text, port) => {
    expect(loadConfig({ KOPANDA_STUDIO_PORT: text }).port).toBe(port);
  });
});

describe("the repo's .env.example", () => {
  const envExample = fs.readFileSync(
    path.join(import.meta.dirname, "..", "..", "..", ".env.example"),
    "utf8",
  );

  it("lists every variable loadConfig reads", () => {
    expect(CONFIG_VARIABLES).toEqual([
      "KOPANDA_STUDIO_PORT",
      "KOPANDA_STUDIO_HOST",
      "KOPANDA_STUDIO_PROFILES_DIR",
    ]);
    for (const name of CONFIG_VARIABLES) {
      expect(envExample).toMatch(new RegExp(`^${name}=`, "m"));
    }
  });
});
