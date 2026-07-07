# Security Policy

We take the security of Plutonium seriously. Because Plutonium is a framework
that other applications are built on, a vulnerability here can affect many
downstream apps. We appreciate your help in disclosing issues responsibly.

## Supported Versions

Plutonium is pre-1.0 and evolving quickly. Security fixes are released against
the **latest published version** only. If you are running an older release,
please upgrade before reporting an issue to confirm it still reproduces.

| Version | Supported          |
| ------- | ------------------ |
| Latest release (`0.62.x`) | :white_check_mark: |
| Older releases | :x: |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues,
discussions, or pull requests.**

Instead, use one of the following private channels:

- **Preferred:** [Open a private vulnerability report](https://github.com/radioactive-labs/plutonium-core/security/advisories/new)
  via GitHub Security Advisories.
- **Email:** [sfroelich01@gmail.com](mailto:sfroelich01@gmail.com) with the
  subject line `[SECURITY] Plutonium`.

To help us triage quickly, please include as much of the following as you can:

- The Plutonium version (and Rails version) affected.
- A description of the vulnerability and its impact.
- Steps to reproduce, or a proof-of-concept.
- Any known workarounds.

## What to Expect

- **Acknowledgement:** We aim to acknowledge your report within **3 business days**.
- **Assessment:** We will investigate and let you know whether the report is
  accepted, along with our expected timeline for a fix.
- **Disclosure:** We follow a coordinated disclosure process. We will work with
  you to agree on a disclosure date once a fix is available, and we are happy to
  credit you in the advisory unless you prefer to remain anonymous.

Please give us a reasonable opportunity to address the issue before any public
disclosure.

## Scope

Security reports about the Plutonium framework code in this repository are in
scope. Issues in applications *built with* Plutonium, or in third-party
dependencies, should be reported to their respective maintainers — though if you
believe a dependency issue is triggered by how Plutonium uses it, we would like
to hear about it.

Thank you for helping keep Plutonium and its community safe.
