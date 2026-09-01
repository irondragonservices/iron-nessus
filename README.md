# irondragonservices/iron-nessus

Hardened container for running [Nessus](https://www.tenable.com/products/nessus).

Forked from [ironpeakservices/iron-nessus](https://github.com/ironpeakservices/iron-nessus).

## This image is not published, and should not be

Every other image in this organisation is built by CI, signed and pushed to
GHCR. This one is not, and that is deliberate.

**Nessus is proprietary and licensed per activation.** The build registers an
activation code and downloads the plugin feed, so the resulting image contains
an activated Nessus installation tied to your licence. Publishing it would
redistribute Tenable's software along with your entitlement to it.

**Upstream's build baked the activation code into the image.** It took the
code as `ARG NESSUS_SERIAL`, and an `ARG` referenced in a `RUN` is recorded in
the image history — `docker history` shows it to anyone who pulls the image.
That is a credential leak in every image built that way, and the reason this
repository has no publish workflow.

So: build it yourself, keep it in a registry you control, and do not push it
anywhere public.

## Building it

The activation code goes in as a build secret rather than a build argument, so
it does not end up in the image history:

```sh
export NESSUS_ACTIVATION_CODE=XXXX-XXXX-XXXX-XXXX
docker build \
  --secret id=nessus_code,env=NESSUS_ACTIVATION_CODE \
  -t iron-nessus .
```

Then:

```sh
docker run -p 8834:8834 -v nessus-data:/opt/nessus iron-nessus
```

The web interface is on 8834 over HTTPS with a self-signed certificate.

### Choosing the package

`NESSUS_PACKAGE` selects the Tenable download. Their filenames pin both the
version and the distribution:

```sh
docker build --build-arg NESSUS_PACKAGE=Nessus-latest-debian10_amd64.deb ...
```

Check [Tenable's download page](https://www.tenable.com/downloads/nessus) for
what is current. The default is the Debian package Tenable ships; it is not
necessarily built for the Debian release this image is based on.

## What is different from a plain Nessus install

- runs as an unprivileged user, uid 1000, not root
- `nessusd` gets `cap_net_admin`, `cap_net_raw` and `cap_sys_resource` as file
  capabilities instead
- `/opt/nessus/sbin` is readable and executable by the owner only
- no shell for the runtime user, and `curl` is removed after the download

## Changes from upstream

- **The activation code is a build secret, not a build ARG.** See above; this
  is the change that matters.
- **`debian:10.4-slim` to `debian:13.6-slim`.** Debian 10 left even LTS support
  in 2024.
- **The `setcap` calls were duplicated**, the first pair immediately overwritten
  by the second — `setcap` replaces the whole capability set rather than adding
  to it, so the first two lines did nothing.
- **`adduser` replaced with `useradd`**; `debian:13-slim` no longer ships the
  `adduser` package.
- `wget` replaced with `curl`, and actually purged afterwards rather than
  `apt-get remove`d with its dependencies left behind.
- The download URL moved from the retired `api/v1/public/pages` form to
  Tenable's current `api/v2` endpoint, and is a build argument rather than
  hard-coded to one download ID.
- **No release, refresh or publish workflow.** Only hadolint runs, because
  everything else in this fleet's shared CI ends in a push to GHCR.
