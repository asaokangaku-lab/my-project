# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

This repository hosts a PowerShell script that exports payment-request PDFs
from MJSFX4Web (menu FLW300200, "支払申請書 個人及び法人源泉対象取引").

## Tech Stack

- PowerShell 5.1 / 7+ (no external dependencies)

## Entry point

- `Export-PaymentRequestPdf.ps1` — CLI that logs into MJSFX4Web and
  downloads the PDF for a given request number. See `README.md` for usage.

## Conventions

- The MJS WebAPI request/response shapes are not officially documented in
  this repo; placeholders are marked with `TODO` comments and must be
  adjusted to match the deployed FX4 environment.
- Passwords are taken as `SecureString` (or prompted) — never hard-code
  credentials in the script or commit them.
