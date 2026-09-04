# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- None

### Changed
- None

### Deprecated
- None

### Removed
- None

### Fixed
- None

### Security
- None

## [0.2.5] - 2026-09-04

### Fixed
- HLTB moved the search endpoint from `/api/bleed` to the nested path `/api/search/site` (around 2026-08-26). Runtime discovery matched the new `fetch("/api/search/site", { method: "POST" })` call but truncated it to the first path segment (`/api/search`), whose `/init` returns 404. Every search and `search_from_id` returned `nil`. The full path is now kept verbatim (mirrors Python package fix for ScrappyCocco/HowLongToBeat-PythonAPI#59).
- Refresh the hardcoded fallbacks (`SEARCH_URL`, the `fetch_search_token` default, and the candidate list) to put `/api/search/site` first.

### Changed
- Discovery now prefers the POST fetch that sends `x-auth-token` (the search call's signature). The HLTB bundle also contains an unrelated `fetch("/api/error", { method: "POST" })` chunk and chunk order is not stable, so stopping on the first POST fetch could pick the wrong endpoint. `SearchInfo#authenticated?` exposes the distinction; a plain POST fetch is still used as a last resort.

## [0.2.4] - 2026-05-07

### Fixed
- HLTB renamed the search endpoint from `/api/finder` to `/api/bleed`. Runtime discovery already adapted, but the hardcoded fallbacks didn't — refresh `SEARCH_URL`, the default in `fetch_search_token`, and the candidate list to put `/api/bleed` first.

### Changed
- Drop the `_app-*.js` script-name filter in `send_website_request_getcode`. The modern HLTB build (Turbopack) ships chunks with opaque names like `0-~-0up.q3_p0.js`, so the filter never matched and forced every search through a redundant retry. Single-pass discovery now iterates all `<script src>` tags directly.
- `send_website_request_getcode` only returns when a `search_url` is found; finding only an `api_key` no longer short-circuits the loop.

## [0.2.3] - 2026-04-15

### Fixed
- Send `x-hp-key` and `x-hp-val` headers extracted from the `/init` response, matching HLTB's updated API authentication (mirrors Python package v1.0.21)
- Inject the dynamic key/value pair from `/init` into the search request payload

## [0.2.2] - 2026-03-24

### Fixed
- Restore search against HowLongToBeat's current API by discovering the POST search endpoint from site scripts (e.g. `/api/finder`) instead of hardcoding `/api/search`
- Obtain the auth token from the same API base as search (`{endpoint}/init`), with fallback candidates when parsing is incomplete
- Tolerate search response shape changes when parsing JSON (alternate root keys, camelCase field names)

### Changed
- Default search endpoint fallback is now `/api/finder`

## [0.2.1] - 2025-12-13

### Fixed
- Added SSL certificate verification fallback for environments with certificate issues
- Added `origin` and `accept` headers to token fetch requests for proper API authentication

## [0.2.0] - 2025-12-13

### Changed
- Updated authentication to use token-based API (`/api/search/init`)
- Improved request headers to match API requirements

### Fixed
- Fixed search functionality to work with HowLongToBeat.com's updated API

## [0.1.2] - 2025-03-06

- Update Ruby requirement version

## [0.1.0] - 2025-03-06

- Initial release
- Basic search functionality
- Search by ID functionality
- Search modifiers support
- Similarity filtering
