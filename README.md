# Anchor for Cloudron

This repository packages [Anchor](https://github.com/ZhFahim/anchor) as a Cloudron Community App.

The package builds a pinned Anchor release from source, uses the managed Cloudron PostgreSQL service, stores uploads and the JWT secret in `/app/data`, and supports optional Cloudron OpenID Connect. When SSO is selected during installation, local password login is disabled.

The package carries a minimal compatibility patch that exposes Cloudron's separate public PKCE client ID to the Anchor mobile app. The server-side web flow continues to use the confidential client and its secret.

## Install

Add this Community App URL in the Cloudron dashboard:

```text
https://raw.githubusercontent.com/WiseMetalhead/anchor-cloudron/main/CloudronVersions.json
```

The first published release may initially be marked as testing while it completes live Cloudron acceptance.

## Development

Build and install the source package with the Cloudron CLI:

```sh
cloudron install
cloudron update
```

For an isolated Docker smoke test:

```sh
docker build --tag anchor-cloudron:test .
./test/smoke.sh anchor-cloudron:test
```

## Updating Anchor

1. Update `ANCHOR_VERSION` in `Dockerfile` and `upstreamVersion` in `CloudronManifest.json`. Renovate normally opens this pull request.
2. Review upstream release notes and Prisma migrations.
3. Bump the independent package `version` and add a matching section to `CHANGELOG`.
4. Merge after CI passes, then run the `Publish or promote package` workflow with `publish-testing`.
5. Test installation, OIDC, backup/restore, and update on a real Cloudron.
6. Run the same workflow with `promote-published` after acceptance.

Package versions use semver independently of Anchor. Use a patch release for routine upstream and packaging updates, a minor release for significant compatible packaging changes, and a major release only for an incompatible installation or data contract.

## License

Anchor is licensed under the GNU Affero General Public License v3.0. Packaging files in this repository are distributed under the same license; see [LICENSE](LICENSE).
