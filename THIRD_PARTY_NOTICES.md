# Third-Party Notices

## Mbed TLS 3.6.7

iPad1MailBox v0.3-alpha1 can bootstrap and compile Mbed TLS 3.6.7 from the official Mbed TLS repository for its modern TLS 1.2 transport probe.

Upstream: https://github.com/Mbed-TLS/mbedtls
Pinned tag: `mbedtls-3.6.7`
License: Apache-2.0 OR GPL-2.0-or-later (see the upstream repository for the complete license texts).

The bootstrapped source is stored under `Vendor/mbedtls/` and is intentionally not committed to this repository.

## ISRG Root X1

The bootstrap script downloads the ISRG Root X1 trust anchor from Let's Encrypt and packages it as an application resource for certificate-chain validation by the Mbed TLS probe.
