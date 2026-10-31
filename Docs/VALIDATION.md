# Integration preparation — 31 October 2026

- Offline core suite: 26 passed; two credential-dependent cloud tests skipped.
- iOS package tests and UI library compilation passed locally.
- Branded layout captures are tested at accessibility size with a nonblank-image guard.
  ImageRenderer cannot render native text inputs; these attachments are layout evidence only.
- Offline example app built, installed and launched on iPhone 11 / iOS 27.0.
  Actual ShowBook screen inspected; screenshot included in this directory.
- The initial complete GitHub CI run passed on abc4c82. Final rendering/demo follow-up
  requires its own successful run before release consumption.

Provider OAuth and email-recovery acceptance need a configured Supabase project,
registered per-app callbacks and provider credentials. These were not available in
this shell. No production credentials or service-role key are stored in the repository.

The host apps themselves have not been modified by this package preparation.
