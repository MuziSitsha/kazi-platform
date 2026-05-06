# KAZI Git History Rewrite Plan

This plan removes previously committed secrets from git history after the cleanup commit is already pushed.

## Important Warning

This rewrites published history.

Effects:

- commit SHAs change
- collaborators must re-sync or re-clone
- open branches and pull requests may need repair

Do not run this until all collaborators are informed.

## Targets To Purge

Remove the deleted Firebase native config files from all prior commits:

- `apps/mobile/android/app/google-services.json`
- `apps/mobile/ios/Runner/GoogleService-Info.plist`

Remove previously committed plain-text password strings from tracked docs and env templates.

## Recommended Tool

Use `git filter-repo`.

It is safer and more maintainable than older `filter-branch` flows.

## Preparation

1. Ensure the working tree is clean.
2. Create a backup clone of the repository.
3. Notify anyone else using the repository that history will be rewritten.
4. Close or pause any open work based on old SHAs.

## Rewrite Sequence

Example commands:

```powershell
Set-Location 'c:\path\to\repo'
git clone --mirror https://github.com/MuziSitsha/kazi-platform.git kazi-platform-mirror.git
Set-Location '.\kazi-platform-mirror.git'
git filter-repo --path apps/mobile/android/app/google-services.json --path apps/mobile/ios/Runner/GoogleService-Info.plist --invert-paths
```

If specific strings must also be purged from all historical blobs, create a replacement file locally and do not commit that file.

Example replacement file format:

```text
old-admin-password==>***REMOVED***
old-firebase-key-1==>***REMOVED***
old-firebase-key-2==>***REMOVED***
```

Then run:

```powershell
git filter-repo --replace-text .\replacements.txt
```

In practice, path removal for the native config files plus string replacement for the plain-text password references is the cleanest combination.

## Force Push Sequence

After verifying the rewritten mirror:

```powershell
git push --force --mirror origin
```

## Post-Rewrite Actions

1. Invalidate any remaining exposed vendor credentials anyway.
2. Ask collaborators to delete old local clones or hard-reset to the new remote history.
3. Re-run a repository-wide search for the old password and Firebase keys.
4. Confirm GitHub no longer serves the old blobs or deleted file history.

## Verification Checklist

- old Firebase config files are absent from history
- old password string is absent from history
- old Firebase API keys are absent from history
- `main` still contains the latest cleanup commit content
- collaborators have been notified how to re-sync