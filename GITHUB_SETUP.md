# Open and publish from Visual Studio Code

1. Open this entire camino_app_github folder in VS Code (File > Open Folder).
2. Install the recommended Flutter and Dart extensions if prompted.
3. Open a terminal here and run `flutter pub get` then `flutter run -d windows`.
4. Open Source Control, review the files, stage the intended source files and commit.
5. Use Publish Branch / Publish to GitHub, sign in through VS Code, and choose a private or public repository. A private repository is a sensible starting point while reviewing your guide content and distribution rights.

This is an independent source copy with a local Git repository. No remote or commit has been created. Future edits made here are separate from the previous working project.

## Credentials

The local `.env` is ignored by Git. `.env.example` is a safe template that can be committed. The app currently uses no credentials and does not automatically load `.env`; the file is reserved for local developer tooling. Do not add it to pubspec assets. Secrets in a compiled Flutter app, including dart-define values, are recoverable; keep confidential service credentials outside the distributed application. Use VS Code/Git Credential Manager to sign in to GitHub rather than putting a GitHub token in project files. GitHub Actions secrets belong in repository settings if automation is added later.

## Files to publish

Keep pubspec.lock (this is an app), lib, test, platform project files, and assets/database/camino.sqlite. The database is deliberately included so a clone runs with the same stages and accommodation data. Review it before making the repository public. Build outputs, local tooling caches, signing keys and .env files are ignored. Never use git add -f on credentials. Gitignore cannot protect secrets that have already been committed.

Verify exclusions with `git check-ignore .env`. After a clone, copy `.env.example` to `.env` only if needed for local tooling.
