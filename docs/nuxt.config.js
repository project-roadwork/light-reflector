"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
// https://nuxt.com/docs/api/configuration/nuxt-config
exports.default = defineNuxtConfig({
    devtools: { enabled: true },
    extends: ["shadcn-docs-nuxt"],
    i18n: {
        defaultLocale: "en",
        locales: [
            {
                code: "en",
                name: "English",
                language: "en-US",
            },
        ],
    },
    css: ["~/assets/css/tailwind.css"],
    vite: {
        optimizeDeps: {
            include: [
                "debug", // CJS
                "mermaid",
                "@vue/devtools-core",
                "@vue/devtools-kit",
            ],
        },
    },
    ssr: true,
    nitro: {
        preset: "static",
        prerender: {
            failOnError: false,
        },
    },
    content: {
        experimental: {
            clientDB: false,
        },
    },
    mdc: {
        highlight: {
            langs: ["ts", "js", "json", "bash", "html", "css", "luau", "toml"],
        },
    },
    ogImage: {
        enabled: true,
        zeroRuntime: true,
    },
    app: {
        baseURL: "/light-reflector/",
    },
    image: {
        provider: "ipxStatic",
    },
    compatibilityDate: "2024-07-06",
});
