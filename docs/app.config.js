"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const logo = "https://codeberg.org/project-roadwork/light-reflector/raw/branch/main/assets/images/internal/branding/icon-logo-compact-svg.svg";
exports.default = defineAppConfig({
    shadcnDocs: {
        site: {
            name: "Light Reflector",
            description: "A light reflector system that simulates long-rage reflections of Decals and BaseParts.",
            ogImageComponent: "ShadcnDocs",
            ogImageColor: "light", // or 'dark'
        },
        theme: {
            customizable: true,
            color: "stone",
            radius: 0.5,
        },
        header: {
            title: "Light Reflector",
            showTitle: true,
            darkModeToggle: true,
            languageSwitcher: {
                enable: false,
                triggerType: "icon",
                dropdownType: "select",
            },
            logo: {
                light: logo,
                dark: logo,
            },
            nav: [],
            links: [
                {
                    icon: "simple-icons:codeberg",
                    to: "https://codeberg.org/project-roadwork/light-reflector.git",
                    target: "_blank",
                },
                {
                    icon: "simple-icons:discord",
                    to: "https://discord.gg/sd4XfAqNF9",
                    target: "_blank",
                },
            ],
        },
        aside: {
            useLevel: true,
            collapse: false,
        },
        main: {
            breadCrumb: true,
            showTitle: true,
            editLink: {
                enable: true,
                pattern: "https://codeberg.org/project-roadwork/light-reflector/_edit/main/docs/content/:path",
                text: "Edit this page",
                icon: "lucide:square-pen",
                placement: ["docsFooter", "toc"],
            },
        },
        footer: {
            credits: "Light Reflector © 2025-2026 Project Roadwork, Illinois_Roadbuff. Source code is licensed under MPL-2.0; documentation content is licensed under CC BY-SA 4.0 unless otherwise noted.",
            links: [
                {
                    icon: "simple-icons:codeberg",
                    to: "https://codeberg.org/project-roadwork/light-reflector.git",
                    target: "_blank",
                },
                {
                    icon: "simple-icons:discord",
                    to: "https://discord.gg/sd4XfAqNF9",
                    target: "_blank",
                },
            ],
        },
        toc: {
            enable: true,
            links: [
                {
                    title: "Star on Codeberg",
                    icon: "lucide:star",
                    to: "https://codeberg.org/project-roadwork/light-reflector.git",
                    target: "_blank",
                },
                {
                    title: "Create Issues",
                    icon: "lucide:circle-dot",
                    to: "https://codeberg.org/project-roadwork/light-reflector/issues",
                    target: "_blank",
                },
            ],
        },
        search: {
            enable: true,
            inAside: false,
        },
    },
});
