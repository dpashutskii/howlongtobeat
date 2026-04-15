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
