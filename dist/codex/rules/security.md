# Security Rules (All Projects)

Security requirements regardless of stack. OWASP-aware.

---

## Input Validation

- **Validate at system boundaries:** API endpoints, form inputs, webhooks, URL params
- **Use schema validation** (Zod, Joi, or equivalent) on ALL incoming data
- **Never trust client-side validation alone** -- always validate server-side
- **Sanitize before rendering** -- especially user-generated HTML content

## XSS Prevention

```typescript
// NEVER render unsanitized user input
<div dangerouslySetInnerHTML={{ __html: userInput }} /> // DANGEROUS

// ALWAYS sanitize first
import DOMPurify from "isomorphic-dompurify";
const clean = DOMPurify.sanitize(html, {
  ALLOWED_TAGS: ["b", "i", "em", "strong", "a"],
  ALLOWED_ATTR: ["href"],
});
```

- React auto-escapes JSX -- but `dangerouslySetInnerHTML` bypasses this
- Template literals in HTML contexts (email templates, iframe srcDoc) need manual escaping
- Escape backticks in user content rendered in template literals

## SSRF Prevention

- **Allowlist external hosts** -- never let user input control full URL without validation
- **Block private IP ranges** in outbound requests: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `127.0.0.0/8`
- **Block dangerous protocols**: `file://`, `gopher://`, `dict://`, `ftp://` -- allow only `https://`
- **Use URL parsing** (`new URL()`) before making requests -- never concatenate user input into URLs
- **Set timeouts** on all outbound HTTP requests (prevent SSRF-based DoS)

```typescript
// NEVER: fetch user-controlled URL directly
const response = await fetch(userInput); // DANGEROUS

// ALWAYS: validate against allowlist
const url = new URL(userInput);
if (!ALLOWED_HOSTS.includes(url.hostname)) throw new Error("Host not allowed");
if (url.protocol !== "https:") throw new Error("Only HTTPS allowed");
```

## Path Traversal Prevention

- **Never use user input directly in file paths** -- use IDs/keys to lookup files
- **Always normalize paths** with `path.resolve()` or `path.normalize()` and verify they stay within allowed directory
- **Block `..` sequences** in any user-supplied path component
- **Prefer database-stored references** (file ID -> storage path) over user-supplied filenames

```typescript
// NEVER: path from user input
const filePath = path.join(uploadDir, req.params.filename); // DANGEROUS

// ALWAYS: normalize and verify containment
const resolved = path.resolve(uploadDir, req.params.filename);
if (!resolved.startsWith(path.resolve(uploadDir))) throw new Error("Path traversal");
```

## File Upload Security

- **Limit file size** server-side (not just client-side) -- set max in middleware (e.g., 10MB)
- **Never trust Content-Type header** -- validate MIME type by reading file magic bytes
- **Generate random filenames** server-side -- never use the original filename
- **Store uploads outside web root** -- serve via signed URLs or proxy endpoint
- **Scan for malware** if accepting user uploads in high-risk contexts (e.g., clamav)
- **Restrict allowed file types** to explicit allowlist (e.g., `.jpg`, `.png`, `.pdf`)

## SQL Injection Prevention

- **Never use raw SQL with string concatenation**
- Use parameterized queries or ORM/query builders (Supabase client, Prisma, etc.)
- If raw SQL is unavoidable: use parameterized `$1, $2` placeholders, never string interpolation

## Environment Variables & Secrets

```bash
# MUST be in .gitignore
.env
.env.local
.env.production
*.key
*.pem
secrets/

# NEVER ignore .env.example (commit it as documentation)
!.env.example
```

- **Validate env vars at startup** (fail fast with clear error)
- **Never hardcode secrets** in source code
- **Never expose server secrets to client** (no `NEXT_PUBLIC_` for API keys, no `VITE_` for server tokens)
- **Never commit .env files** -- if leaked, rotate ALL secrets immediately

## Authentication & Authorization

- Check auth on EVERY mutation endpoint / server action
- Use middleware for auth checks where possible (not per-handler)
- Validate JWT signatures -- don't just decode
- Auth tokens in httpOnly, Secure, SameSite cookies (not localStorage)
- **Cookie auth pattern**: `SameSite=Lax` (or `Strict`) + CSRF token (double-submit or synchronizer token) for POST/PUT/DELETE
- **Bearer token pattern**: store in memory (not localStorage), send via `Authorization` header, never in URL params
- Rate limit auth endpoints (login, register, password reset)

## API Security Checklist

- [ ] Rate limiting on public endpoints
- [ ] CORS whitelist (production domains only, not `*`)
- [ ] Security headers (Helmet, CSP, HSTS)
- [ ] Input validation on all endpoints (Zod/schema)
- [ ] CSRF protection for mutations
- [ ] No sensitive data in URL params or logs -- mask tokens, passwords, emails, IPs in log output
- [ ] Database RLS policies on all tables (if using Supabase/Postgres)

## Threat -> Controls -> Required Tests

| Threat | Control | Required Test |
|--------|---------|---------------|
| XSS | DOMPurify / auto-escape | Render user HTML -> verify sanitized output |
| SQL injection | Parameterized queries / ORM | Pass `'; DROP TABLE--` -> verify no raw exec |
| SSRF | Host allowlist + protocol check | Pass `http://169.254.169.254` -> verify 400/blocked |
| Path traversal | `path.resolve` + containment check | Pass `../../etc/passwd` -> verify 400 |
| Auth bypass | Middleware auth check | Request without token -> verify 401 |
| Tenant isolation | orgId/ownerId filter | Request with wrong orgId -> verify 403 + `service.not.toHaveBeenCalled()` |
| CSRF | SameSite cookie + CSRF token | POST without CSRF token -> verify 403 |
| Rate limiting | Rate limiter middleware | N+1 requests -> verify 429 |
| File upload abuse | Size limit + MIME check | Upload 50MB / `.exe` -> verify rejected |
| Log leakage | PII masking | Trigger error with PII -> verify logs are masked |

## Cryptographic Randomness

- **Never use `Math.random()` for tokens, secrets, or security-sensitive IDs** -- use `crypto.randomUUID()`, `crypto.getRandomValues()`, or `crypto.randomBytes()`
- **Never use predictable seeds** for session IDs or CSRF tokens
- Python: use `secrets` module, not `random`

## Deserialization Safety

- **Never `eval()` or `new Function()` on untrusted input**
- **Never `pickle.loads()` on untrusted data** (Python) -- use JSON or schema-validated formats
- **`JSON.parse()` on external input** must be followed by schema validation (Zod/etc.)

## Security Event Logging

- **Log all failed authentication attempts** with IP, timestamp, username (not password)
- **Log authorization failures** (403s) with user ID, resource, action
- **Rate limit + alert** on repeated auth failures from same IP/user

## Dependency Security

- Run `npm audit` / `pip audit` regularly
- Update dependencies with known CVEs promptly
- Prefer well-maintained packages with active security response
- Lock dependency versions (lockfile committed)
