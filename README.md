# Cascalho server

The Cascalho API: payment profiles, invoices and NFS-e for people in Brazil
paid by companies abroad. It is JSON only (no pages). Signing and submitting
to the RFB happen in the Cascalho agent on the user's computer, which holds
the A3 certificate. The server builds each DPS, keeps the numbers, and
records what the RFB answered.

## Setup

You need Ruby 3.3 and SQLite, plus the two native libraries:

- `libnfse` from [drimotta/nfse](https://github.com/drimotta/nfse): `cargo build --release`
- `libinvoices` from [drimotta/invoices](https://github.com/drimotta/invoices): `make lib`

```sh
bundle install
cp .env.example .env   # then edit
bundle exec hanami db prepare
bundle exec hanami server
```

| Variable | Meaning |
| --- | --- |
| `DATABASE_URL` | SQLite database, such as `sqlite://db/cascalho.sqlite` |
| `ICP_TRUST_DIR` | Directory with `roots/`, `intermediates/` and `crls/` PEM files. Only these roots are trusted; refresh the CRLs on a schedule |
| `NFSE_LIB` | Path to `libnfse.so` or `libnfse.dylib` |
| `INVOICES_LIB` | Path to `libinvoices.so` or `libinvoices.dylib` |
| `SESSION_TTL_HOURS` | Session length (12) |
| `APPROVAL_WAIT_HOURS` | How long a new certificate for a known CPF waits before it can log in unapproved (72) |

Both libraries are loaded into the process, so run Puma as a single process
(`HANAMI_WEB_CONCURRENCY` unset or 0).

## Tests

```sh
HANAMI_ENV=test bundle exec hanami db prepare   # once, and after new migrations
bundle exec rspec
```

The specs look for sibling checkouts of `nfse` and `invoices` next to this
repository (`../../nfse`, `../../invoices` from `spec/`) with their libraries
built in debug mode (`target/debug/libnfse.*`, `build/libinvoices.*`).
Override with `NFSE_DIR`, `INVOICES_DIR`, `NFSE_LIB` or `INVOICES_LIB`.

## API

Every call except logging in needs `Authorization: Bearer <token>`. Errors
are `{"error": {"code": "...", "message": "..."}}`.

### Logging in

| Call | What it does |
| --- | --- |
| `POST /session/challenge` | Returns `challenge_id` and `challenge_b64`; the agent signs it |
| `POST /session` | `challenge_id`, `certificate_b64`, `signature_b64`. The certificate must be an ICP-Brasil A3 that chains to a pinned root and is not revoked. The user is the CPF in the certificate. 201 with `token`; 202 `pending_approval` for a new certificate of a known CPF |
| `DELETE /session` | Logs out |
| `GET /me` | The user and their profiles |
| `GET /certificates`, `POST /certificates/:id/approve` | See and approve the user's certificates |

### Profiles and templates

A profile is a CPF or CNPJ the user issues as. Profiles come from the
certificates the user logs in with.

| Call | What it does |
| --- | --- |
| `GET /profiles` | The user's profiles |
| `PATCH /profiles/:id` | `name`, `settings` (such as `{"dps_serie": "1"}`) |
| `POST /profiles/:id/templates` | `kind` (`invoice` or `dps`), `name`, `body`. An invoice body is invoice params; a DPS body has `reuse_xml` (an earlier NFS-e or DPS) and/or `content` |

### Invoices

| Call | What it does |
| --- | --- |
| `POST /profiles/:id/invoices` | `params` (as `invoices_render` takes them), optional `template_id`. The params are merged over the template field by field. The number is the profile's next one. 201 `{id, number}`; 422 if the params are invalid, and the number is not used |
| `GET /invoices/:id` | The invoice and its params |
| `GET /invoices/:id/pdf` | The PDF |

### NFS-e

| Call | What it does |
| --- | --- |
| `POST /invoices/:id/dps` | `environment` (`staging` or `production`), `content`, optional `template_id`. Builds the unsigned DPS with the next number of the profile's series. The issuer is always the profile. 201 with `dps_id` and `unsigned_xml` for the agent; 409 if the invoice has a DPS that was not rejected; 422 if the content is invalid, and the number is not used |
| `POST /dps/:id/result` | What the agent got from the RFB. `outcome`: `issued` (`signed_xml`, `chave_acesso`, `nfse_xml`, optional `pdf_b64`), `rejected` (`messages`), or `unknown` (`signed_xml`). The signed DPS must contain the infDPS built here, byte for byte. 409 once issued or rejected |
| `GET /dps/:id` | The DPS, its state and the NFS-e |
| `GET /dps/:id/pdf` | The DANFSe |

A DPS goes from `built` to `issued`, `rejected` or `unknown`, and from
`unknown` to `issued` or `rejected`. An unknown DPS is never built again with
a new number: the agent looks it up and resends the same signed bytes.
