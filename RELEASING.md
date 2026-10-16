# Releasing

```sh
git tag v0.1.1
git push origin v0.1.1
```

`.github/workflows/publish.yml` publishes the package when its pubspec carries
the tag's version.

## One-time setup

1. Publish it once by hand (`flutter pub publish`), because pub.dev's
   automated-publishing settings exist only after the first upload.
2. On pub.dev: Admin → Automated publishing → GitHub Actions, repository
   `hinata-platform/alarm_kit`, tag pattern `v{{version}}`.
3. Transfer it to the `ahmadre.com` publisher.

## Regenerating the channel

`tool/generate.sh` runs Pigeon and makes its Swift output build in Swift 6.
