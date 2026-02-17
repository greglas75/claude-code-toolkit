# Security Rules (All Projects)

Security requirements regardless of stack. OWASP-aware.

---

## Input Validation

- **Validate at system boundaries:** API endpoints, form inputs, webhooks, URL params
- **Use schema validation** (Zod, Joi, or equivalent) on ALL incoming data
- **Never trust client-side validation alone** — always validate server-side
- **Sanitize before rendering** — especially user-generated HTML content

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

- React auto-escapes JSX — but `dangerouslySetInnerHTML` bypasses this
- Template literals in HTML contexts (email templates, iframe srcDoc) need manual escaping
- Escape backticks in user content rendered in template literals

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
- **Never commit .env files** — if leaked, rotate ALL secrets immediately
- **Use httpOnly cookies** for auth tokens, never localStorage

## Authentication & Authorization

- Check auth on EVERY mutation endpoint / server action
- Use middleware for auth checks where possible (not per-handler)
- Validate JWT signatures — don't just decode
- Auth tokens in httpOnly, Secure, SameSite cookies (not localStorage)
- Rate limit auth endpoints (login, register, password reset)

## API Security Checklist

- [ ] Rate limiting on public endpoints
- [ ] CORS whitelist (production domains only, not `*`)
- [ ] Security headers (Helmet, CSP, HSTS)
- [ ] Input validation on all endpoints (Zod/schema)
- [ ] CSRF protection for mutations
- [ ] No sensitive data in URL params or logs
- [ ] Database RLS policies on all tables (if using Supabase/Postgres)

## Dependency Security

- Run `npm audit` / `pip audit` regularly
- Update dependencies with known CVEs promptly
- Prefer well-maintained packages with active security response
- Lock dependency versions (lockfile committed)
