import { defineConfig } from 'vitepress'

// `base` MUST match the GitHub Pages sub-path (the repo name) so assets resolve. (AR-08)
// Dead links are left as build errors (VitePress default) so broken internal links fail CI. (AR-09)
export default defineConfig({
  title: 'CodeOps for Claude Code',
  description:
    'The CodeOps AI-development workflow — skills, commands, and always-on standards for Claude Code.',
  base: '/claude-codeops/',
  lang: 'en-US',
  cleanUrls: true,

  themeConfig: {
    nav: [
      { text: 'Guide', link: '/guide/introduction' },
      { text: 'Skills', link: '/skills/' },
      { text: 'Tutorials', link: '/tutorials/' },
      { text: 'Reference', link: '/reference/standards' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: 'Introduction', link: '/guide/introduction' },
            { text: 'Install', link: '/guide/install' },
            { text: 'Verify', link: '/guide/verify' },
            { text: 'Update', link: '/guide/update' },
            { text: 'Concepts', link: '/guide/concepts' },
            { text: 'Parallel agents', link: '/guide/parallel-agents' },
          ],
        },
      ],
      '/skills/': [
        {
          text: 'Skills',
          items: [
            { text: 'Overview', link: '/skills/' },
            { text: 'make_plan', link: '/skills/make_plan' },
            { text: 'exec_plan', link: '/skills/exec_plan' },
            { text: 'make_requirements', link: '/skills/make_requirements' },
            { text: 'retro_requirements', link: '/skills/retro_requirements' },
            { text: 'grill_me', link: '/skills/grill_me' },
            { text: 'preflight', link: '/skills/preflight' },
            { text: 'techdocs', link: '/skills/techdocs' },
            { text: 'roadmap', link: '/skills/roadmap' },
            { text: 'upgrade_plan', link: '/skills/upgrade_plan' },
            { text: 'setup_routing', link: '/skills/setup_routing' },
            { text: 'setup_codeops', link: '/skills/setup_codeops' },
            { text: 'Commands', link: '/skills/commands' },
          ],
        },
      ],
      '/tutorials/': [
        {
          text: 'Tutorials',
          items: [
            { text: 'Overview', link: '/tutorials/' },
            { text: 'Your first plan', link: '/tutorials/first-plan' },
            { text: 'The full pipeline', link: '/tutorials/full-pipeline' },
            { text: 'Reverse-engineer a codebase', link: '/tutorials/reverse-engineer' },
          ],
        },
      ],
      '/reference/': [
        {
          text: 'Reference',
          items: [
            { text: 'Coding & testing standards', link: '/reference/standards' },
            { text: 'Repository map', link: '/reference/repo-map' },
            { text: 'Troubleshooting', link: '/reference/troubleshooting' },
          ],
        },
      ],
    },

    socialLinks: [{ icon: 'github', link: 'https://github.com/blendsdk/claude-codeops' }],

    editLink: {
      pattern: 'https://github.com/blendsdk/claude-codeops/edit/master/docs/:path',
      text: 'Edit this page on GitHub',
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © blendsdk',
    },
  },
})
