# The Sylvaris website

A static site built from `docs/`, a landing page and the legal pages. It needs Node.js and, for the demo videos, `ffmpeg`. Nothing is downloaded while it builds.

```sh
cp site/operator.example.json site/operator.json   # once, then fill it in
node site/build.mjs                                  # writes site/dist
python3 -m http.server -d site/dist 8000             # look at it on http://localhost:8000
```

`node site/build.mjs --strict` refuses to finish while the operator details are missing, which is the safe way to build for publishing.

## What goes in operator.json

`site/operator.json` is ignored by git, so it never lands in the public repository.

| Key | What to put there |
|---|---|
| `email` | an address you read, shown as the contact on the legal pages. A separate address for the project works fine |
| `updated` | the date of the last change to the legal pages |

The site is run privately and earns nothing, so it is not a service under art. 2 pkt 6 of the Polish e-services act and does not need your name or address. It also keeps no personal data: the pages store nothing in the browser, and the server below keeps no logs. That is what the privacy policy promises, so keep it true:

- Leave access and error logging off, as in the nginx block below.
- Do not add analytics, fonts, embeds or anything else from other servers. `tests/site.test.mjs` checks the built pages for that.
- If the site ever sells something, shows ads, takes donations as income, adds analytics or accepts content from visitors, the legal pages have to change, and the name and address come back.

This is a careful reading of Polish and EU law, not legal advice.

## Publishing

```sh
node site/build.mjs --strict
rsync -av --delete site/dist/ you@your-vps:/var/www/sylvaris/
```

An nginx server block that matches what the site promises: strict security headers, long caching for fonts and videos, and no logs.

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name sylvaris.example.org;

    root /var/www/sylvaris;
    index index.html;
    error_page 404 /404.html;
    access_log off;
    error_log /dev/null;

    add_header Content-Security-Policy "default-src 'self'; img-src 'self' data:; media-src 'self'; style-src 'self'; script-src 'self'; font-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
    add_header Strict-Transport-Security "max-age=31536000" always;

    location /assets/ { expires 30d; }
    location /media/  { expires 30d; }
}
```

`expires` sets the caching headers without touching the others. Avoid `add_header` inside a `location`: it replaces every header set above it, including the security ones.

## How it is put together

- `build.mjs` renders every page. The docs keep their folder layout, so `docs/parts/island.md` becomes `docs/parts/island.html`, and links to files outside `docs/` point to GitHub.
- `markdown.mjs` is a small Markdown renderer for exactly what the docs use, tested in `tests/site.test.mjs`.
- `content.mjs` holds the site address, the one-paragraph summary, the documentation menu, the parts shown on the landing page and the list of legal pages.
- Every page gets a canonical address, Open Graph and Twitter tags and schema.org data (a `SoftwareApplication` on the home page, `TechArticle` and `BreadcrumbList` on each doc page, `FAQPage` on `docs/faq.html`). The build also writes `sitemap.xml` with each page's last commit date, `robots.txt` and `llms.txt`, a plain-text map of the docs for AI search tools.
- `landing.html` is the home page; `legal/*.md` are the legal pages in Polish and English, with `{{name}}`-style fields filled from `operator.json`.
- `assets/` holds the stylesheet, one script and the fonts. `fonts.sh` rebuilds the font subsets from nixpkgs; their licence is in `assets/fonts/OFL.txt`.
- The demo videos are made from the GIFs in `docs/demo` with `ffmpeg` and cached in `dist/media`.

## Search engines and crawlers

`robots.txt` lets every crawler in, names the search and AI search crawlers (Googlebot, Bingbot, OAI-SearchBot, ChatGPT-User, Claude-SearchBot, PerplexityBot and others) explicitly, keeps GPTBot out and points to the sitemap. Its `Content-Signal` line allows search and AI answers but not training.

If the site sits behind Cloudflare, check two settings in the dashboard, because they act before this file does:

- **Managed robots.txt** puts Cloudflare's own block in front of this file. It disallows Google-Extended, which Gemini also uses for grounding answers in search results, and it leaves `ai-input` unset.
- **Block AI bots** (AI Crawl Control) answers some crawlers with 403 whatever robots.txt says. PerplexityBot is one of them.

After a deploy, submit `https://sylvaris.fatum.cc/sitemap.xml` in Google Search Console and Bing Webmaster Tools.
