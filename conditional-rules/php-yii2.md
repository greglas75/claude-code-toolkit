# PHP / Yii2 Rules (Conditional)

**Apply when:** Yii2 detected (`yiisoft/yii2` in `composer.json`). Base PHP rules apply to any PHP stack.

**PHP version gate:** Check `composer.json` → `require.php` or `config.platform.php`. Minimum: PHP 7.4. Use `match` only if ≥8.0. Use `enum`/`readonly`/named args only if ≥8.1. Never generate syntax above the project's declared version.

---

## PHP Type Safety

```php
// ALWAYS declare return types and parameter types (PHP 7.4+)
public function findByEmail(string $email): ?User { ... }
public function getActiveOrders(): array { ... }  // or better: Order[]

// ALWAYS use typed properties (PHP 7.4+)
class Order extends ActiveRecord {
    public int $userId;
    public ?string $comment = null;
    public OrderStatus $status;   // enum (PHP 8.1+)
}

// NEVER use @param/@return as the ONLY type declaration — add actual PHP types
// NEVER suppress null errors with @ operator — handle null explicitly
$user = User::findOne($id);
if ($user === null) {
    throw new NotFoundHttpException("User not found: $id");
}
```

- Use `match` (PHP 8.0+) over `switch` for exhaustive matching
- Use named arguments for clarity: `array_slice(array: $items, offset: 0, length: 10)`
- Use `readonly` properties (PHP 8.1+) for value objects

## Yii2 — Common Anti-Patterns (flag these)

### Save Without Validate
```php
// DANGEROUS — saves invalid data silently
$model->save(false);  // false = skip validation

// CORRECT — validate first, save only if valid
if ($model->load(Yii::$app->request->post()) && $model->validate()) {
    $model->save(false);  // safe: already validated
} else {
    return $this->render('form', ['model' => $model]);
}
```

### Transaction Without Rollback
```php
// DANGEROUS — partial save on exception
$user->save();
$profile->save();

// CORRECT
$transaction = Yii::$app->db->beginTransaction();
try {
    $user->save(false);
    $profile->save(false);
    $transaction->commit();
} catch (\Exception $e) {
    $transaction->rollBack();
    throw $e;
}
```

### Direct AR Query in Controller
```php
// BAD — business logic in controller
public function actionIndex() {
    $orders = Order::find()->where(['status' => Order::STATUS_ACTIVE])->all();
    return $this->render('index', ['orders' => $orders]);
}

// GOOD — query in model/service
class Order extends ActiveRecord {
    public static function findActive(): ActiveQuery {
        return static::find()->where(['status' => self::STATUS_ACTIVE]);
    }
}
```

### Logic / IO in rules() or Getters
```php
// DANGEROUS — rules() calls DB (non-deterministic, breaks cache, slows tests)
public function rules(): array {
    $maxSize = Setting::findOne(['key' => 'max_file_size'])->value;  // DB call!
    return [
        ['file', 'file', 'maxSize' => $maxSize],
    ];
}

// CORRECT — rules() must be pure, deterministic, no I/O
public function rules(): array {
    return [
        ['file', 'file', 'maxSize' => self::MAX_FILE_SIZE],  // constant
    ];
}

// DANGEROUS — AR getter with hidden DB query
public function getFullName(): string {
    $profile = Profile::findOne(['userId' => $this->id]);  // N+1 if called in loop!
    return $profile->firstName . ' ' . $profile->lastName;
}

// CORRECT — use relation, let with() handle eager loading
public function getProfile(): ActiveQuery {
    return $this->hasOne(Profile::class, ['userId' => 'id']);
}
public function getFullName(): string {
    return $this->profile->firstName . ' ' . $this->profile->lastName;
}
```

**Rule:** `rules()` must be deterministic — no `findOne()`, no `Yii::$app->request`, no config lookups. Getters that access related data must use declared relations (not inline queries).

### Yii::$app->user->identity Without Null Check
```php
// DANGEROUS — crashes if not logged in
$userId = Yii::$app->user->identity->id;

// CORRECT
$identity = Yii::$app->user->identity;
if ($identity === null) {
    throw new ForbiddenHttpException();
}
$userId = $identity->id;
```

## Yii2 Security

### RBAC / Access Control
```php
// ALWAYS check permission before action
public function behaviors(): array {
    return [
        'access' => [
            'class' => AccessControl::class,
            'rules' => [
                ['allow' => true, 'roles' => ['@']],  // logged in
                ['allow' => true, 'actions' => ['view'], 'roles' => ['admin']],
            ],
        ],
    ];
}

// For fine-grained: check ownership
public function actionUpdate(int $id): Response {
    $model = $this->findModel($id);
    if ($model->userId !== Yii::$app->user->id && !Yii::$app->user->can('admin')) {
        throw new ForbiddenHttpException();
    }
    // ...
}
```

### XSS Prevention
```php
// DANGEROUS — raw user input in view
echo $model->comment;

// CORRECT — always encode
echo Html::encode($model->comment);
// In template: <?= Html::encode($model->comment) ?>
// NEVER: <?= $model->comment ?> for user-supplied content
```

### Mass Assignment Protection
```php
// DANGEROUS — allows overwriting any attribute
$model->attributes = Yii::$app->request->post();

// CORRECT — use load() which respects safe attributes from rules()
$model->load(Yii::$app->request->post());

// In model, explicitly list safe attributes per scenario:
public function rules(): array {
    return [
        [['name', 'email'], 'safe', 'on' => self::SCENARIO_PROFILE_UPDATE],
    ];
}
```

## Yii2 Model Validation

### Scenarios
```php
// ALWAYS define scenarios when validation differs by context
class User extends ActiveRecord {
    const SCENARIO_CREATE = 'create';
    const SCENARIO_UPDATE = 'update';
    const SCENARIO_LOGIN  = 'login';

    public function scenarios(): array {
        return [
            self::SCENARIO_CREATE => ['username', 'email', 'password'],
            self::SCENARIO_UPDATE => ['username', 'email'],
            self::SCENARIO_LOGIN  => ['username', 'password'],
        ];
    }
}

// HARD RULE: Set scenario BEFORE load(), not just before validate():
$model->scenario = User::SCENARIO_CREATE;  // FIRST — controls which fields are "safe"
$model->load(Yii::$app->request->post());  // load() uses scenario to filter safe attributes
$model->validate();                         // validate() uses scenario to select rules
```

### Validation Rules
```php
public function rules(): array {
    return [
        [['name', 'email'], 'required'],
        ['email', 'email'],
        ['email', 'unique', 'targetClass' => User::class],
        ['age', 'integer', 'min' => 18, 'max' => 120],
        ['status', 'in', 'range' => [self::STATUS_ACTIVE, self::STATUS_INACTIVE]],
    ];
}
```

## CQ Self-Eval Adjustments for Yii2

When running CQ1-CQ20 on Yii2 code, apply these stack-specific interpretations:

| CQ | Yii2-specific check |
|----|---------------------|
| CQ2 | Public function without return type = fail. Bare `array` without `@return` shape or DTO = fail. See "PHP strict_types" section |
| CQ3 | Validation = `rules()` + scenario set before `load()` + `validate()` called. Missing any = fail. `rules()` must be pure (no DB calls) |
| CQ4 | RBAC = `AccessControl` behavior OR `Yii::$app->user->can()` AND query filter `where(['userId' => $userId])`. Guard-only without query filter = fail. See "Multi-Tenant Isolation" section |
| CQ5 | Any `Yii::info/warning/error` with `$_POST`, `$request->post()`, password fields, or full JWT = fail. See "Logging & PII" section |
| CQ6 | Any `->all()` in controller/service without `->limit()` = fail. See "Bounded Queries" section |
| CQ7 | Any list endpoint without pagination = fail |
| CQ8 | `$transaction->rollBack()` in catch block. Missing = fail for multi-model mutations. Side effects must be AFTER commit |
| CQ9 | `Yii::$app->db->beginTransaction()` required for multi-model writes |
| CQ10 | `findOne()` returns `null` — always null-check before accessing properties |
| CQ12 | Status constants (`STATUS_ACTIVE = 1`) — never magic integers in business logic |
| CQ14 | Repeated `find()->where(['status' => ...])->all()` in 3+ places = extract to named scope |
| CQ17 | Any relation accessed in loop without `with()` or `joinWith()` = fail. See "N+1 Prevention" section |

## Test Runner: Codeception

### Actors and Test Types

| Type | Actor | Use for |
|------|-------|---------|
| Unit | `UnitTester` | Pure logic, model methods, validation, behaviors |
| Functional | `FunctionalTester` | Controller actions, form submission, redirects, sessions |
| Acceptance | `AcceptanceTester` | Full browser (Selenium) — critical user flows only |

### Basic Structure

```php
// Unit test (tests/unit/models/UserTest.php)
class UserTest extends \Codeception\Test\Unit {
    protected UnitTester $tester;

    public function testValidationRequiresEmail(): void {
        $user = new User(['scenario' => User::SCENARIO_CREATE]);
        $user->name = 'John';
        // no email
        $this->assertFalse($user->validate());
        $this->assertArrayHasKey('email', $user->errors);
    }
}

// Functional test (tests/functional/UserCest.php)
class UserCest {
    public function _before(FunctionalTester $I): void {
        $I->amLoggedInAs(UserFixture::ADMIN_ID);
    }

    public function testCreateUserSuccessfully(FunctionalTester $I): void {
        $I->amOnRoute('user/create');
        $I->submitForm('#user-form', ['User[name]' => 'John', 'User[email]' => 'j@test.com']);
        $I->seeRecord(User::class, ['email' => 'j@test.com']);
        $I->seeResponseCodeIs(200);
    }
}
```

### Fixtures (Yii2 + Codeception)

```php
// tests/fixtures/UserFixture.php
class UserFixture extends ActiveFixture {
    public $modelClass = User::class;
    public $dataFile   = '@tests/fixtures/data/user.php';

    const ADMIN_ID = 1;
    const USER_ID  = 2;
}

// tests/fixtures/data/user.php
return [
    'admin' => ['id' => 1, 'name' => 'Admin', 'email' => 'admin@test.com', 'role' => 'admin'],
    'user'  => ['id' => 2, 'name' => 'User',  'email' => 'user@test.com',  'role' => 'user'],
];

// In test:
public function _fixtures(): array {
    return [
        'users' => UserFixture::class,
    ];
}
```

## SSRF Prevention (curl / Guzzle / file_get_contents)

Any code that makes HTTP requests to user-supplied URLs MUST apply all three layers:

**Layer 1: Protocol allowlist**
```php
$url = new Uri($userInput);
$scheme = strtolower($url->getScheme());
if (!in_array($scheme, ['https', 'http'], true)) {
    throw new InvalidArgumentException("Protocol not allowed: $scheme");
}
// BLOCK: file://, gopher://, ftp://, php://, dict://, ldap://
```

**Layer 2: Private IP range block (after DNS resolution)**
```php
$host = gethostbyname($url->getHost());  // resolve DNS -> IP
$ip   = inet_pton($host);
if ($ip === false) {
    throw new InvalidArgumentException("Cannot resolve host");
}
// Block private + loopback + link-local ranges:
$blocked = [
    '127.0.0.0/8',      // loopback
    '10.0.0.0/8',       // private
    '172.16.0.0/12',    // private
    '192.168.0.0/16',   // private
    '169.254.0.0/16',   // link-local (metadata services)
    '::1/128',          // IPv6 loopback
    'fc00::/7',         // IPv6 private
];
foreach ($blocked as $range) {
    if (NetUtils::ipInRange($host, $range)) {
        throw new ForbiddenHttpException("Target host not allowed");
    }
}
```

**Layer 3: Timeout on all outbound requests**
```php
$client = new \GuzzleHttp\Client([
    'timeout'         => 5,      // total
    'connect_timeout' => 2,      // connection
    'allow_redirects' => ['max' => 3, 'strict' => true],
]);
```

**CQ gate:** Any function accepting user-supplied URL without all 3 layers = CQ4=0 (security critical).

## File Upload Security

Rule: NEVER trust the browser. Validate server-side only.

```php
// Size limit -- enforce in server code, not just nginx config
public function rules(): array {
    return [
        ['file', 'file',
            'maxSize'    => 10 * 1024 * 1024,    // 10 MB
            'maxFiles'   => 5,
            'extensions' => ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'xlsx', 'csv'],
            'checkExtensionByMimeType' => true,   // cross-check MIME vs extension
        ],
    ];
}

// MIME sniffing -- read magic bytes, don't trust Content-Type header
$finfo = new \finfo(FILEINFO_MIME_TYPE);
$mime  = $finfo->file($file->tempName);
$allowed = ['image/jpeg', 'image/png', 'image/gif', 'application/pdf'];
if (!in_array($mime, $allowed, true)) {
    throw new InvalidArgumentException("File type not allowed: $mime");
}

// Storage outside webroot
$basePath = Yii::getAlias('@app') . '/storage/uploads/';  // NOT @webroot

// Random filename -- never use original name
$safeName = Yii::$app->security->generateRandomString(32) . '.' . $file->extension;
$file->saveAs($basePath . $safeName);

// NEVER allow executable extensions even if MIME looks OK:
$blocked = ['php', 'php3', 'php4', 'phtml', 'phar', 'asp', 'aspx', 'sh', 'exe', 'bat'];
if (in_array(strtolower($file->extension), $blocked, true)) {
    throw new ForbiddenHttpException("Extension not allowed");
}
```

**High-risk contexts** (user uploads visible to other users): add async antivirus scan (ClamAV or cloud AV API) before making file available. Queue the scan, serve file only after CLEAN verdict.

**CQ gate:** Any upload endpoint without: size limit + MIME check + webroot exclusion + random name = CQ3=0 (boundary validation incomplete).

## Path Traversal Prevention

Rule: NEVER accept filesystem paths from user input. Use ID-to-path mapping server-side.

```php
// WRONG -- user controls path
$path = $request->get('file');
$content = file_get_contents('/app/uploads/' . $path);  // ../../etc/passwd

// CORRECT -- map ID to path server-side
$attachment = Attachment::findOne(['id' => $request->get('id'), 'userId' => Yii::$app->user->id]);
if ($attachment === null) {
    throw new NotFoundHttpException();
}
$content = file_get_contents($attachment->storagePath);  // server-controlled path

// If path construction is unavoidable:
function safePath(string $baseDir, string $filename): string {
    $base     = realpath($baseDir);
    $resolved = realpath($base . DIRECTORY_SEPARATOR . $filename);

    if ($resolved === false || strncmp($resolved, $base, strlen($base)) !== 0) {
        throw new ForbiddenHttpException("Path traversal detected");
    }
    return $resolved;
}
// Block explicitly:
if (str_contains($filename, '..') || str_contains($filename, '/') || str_contains($filename, '\\')) {
    throw new BadRequestHttpException("Invalid filename");
}
```

**CQ gate:** Any `file_get_contents`, `readfile`, `fopen` with user-influenced path without `realpath()` + prefix check = CQ3=0.

## Multi-Tenant Isolation -- Security Hard Gate

This is the most expensive class of bug in multi-tenant systems. Treat as security-critical.

**Rule:** Every query on tenant-scoped resources MUST include a tenant/owner filter at the query level. `AccessControl` behavior is NOT sufficient alone.

```php
// WRONG -- guard only, no query filter
public function actionView(int $id): array {
    $this->checkPermission('view-order');  // guard: checks role only
    return Order::findOne($id);             // returns ANY order, not just user's
}

// CORRECT -- guard + query filter
public function actionView(int $id): array {
    return Order::find()
        ->where(['id' => $id])
        ->andWhere(['userId' => Yii::$app->user->id])  // tenant filter
        ->one() ?? throw new ForbiddenHttpException();
}
```

**CQ4 interpretation for Yii2 (strict):**
- `AccessControl` behavior alone = CQ4=0 (guard without query filter)
- `checkAccess()` alone = CQ4=0
- Guard + `andWhere(['userId' => $userId])` = CQ4=1 (defense in depth)

**Required functional tests (P-47 extended):**
```php
public function testUserCannotViewOtherUserOrder(FunctionalTester $I): void {
    $I->loginAsUser(UserFixture::USER_A_ID);
    $I->sendGET('/order/' . OrderFixture::USER_B_ORDER_ID);
    $I->seeResponseCodeIs(403);
    // If service layer exists: verify it was NOT called
}
```

## Logging & PII -- Never Log Sensitive Data (CQ5)

**NEVER log:**
- Passwords (even hashed)
- Session tokens, JWTs, API keys
- Authorization headers
- Full `$_POST` / `$_REQUEST` dumps (may contain passwords)
- Credit card numbers, national IDs, full dates of birth
- Full email addresses in debug logs (partial only)

**Masking rules:**
```php
// Email: show domain only in logs
'user' => substr($email, 0, 2) . '***@' . explode('@', $email)[1]

// Token: show only prefix + suffix
'token' => substr($token, 0, 4) . '****' . substr($token, -4)

// Card: last 4 digits only
'card' => '****' . substr($cardNumber, -4)
```

**For exceptions:** log `requestId`, `userId`, `route`, `errorCode`. NOT the raw POST body.
```php
Yii::error([
    'requestId' => Yii::$app->request->headers->get('X-Request-Id'),
    'userId'    => Yii::$app->user->id,
    'route'     => Yii::$app->request->pathInfo,
    'error'     => $e->getMessage(),
    // NOT: 'post' => Yii::$app->request->post()
], 'app');
```

**CQ5 for Yii2:** Any `Yii::info/warning/error` with `$_POST`, `$request->post()`, password fields, or full JWT in message = CQ5=0.

## Bounded Queries -- No Unbounded ->all()

**Rule:** No `->all()` on list endpoints without LIMIT. External data = unknown size.

```php
// WRONG -- could return millions of records
$orders = Order::find()->where(['status' => Order::STATUS_ACTIVE])->all();

// CORRECT -- paginate
$query  = Order::find()->where(['status' => Order::STATUS_ACTIVE]);
$pages  = new Pagination(['totalCount' => $query->count(), 'pageSize' => 50]);
$orders = $query->offset($pages->offset)->limit($pages->limit)->all();

// For internal batch processing -- cursor-based:
$lastId = 0;
do {
    $batch = Order::find()
        ->where(['>', 'id', $lastId])
        ->orderBy('id ASC')
        ->limit(1000)
        ->all();
    foreach ($batch as $order) { /* process */ }
    $lastId = end($batch)->id ?? null;
} while (!empty($batch));
```

**N+1 Prevention:**
```php
// WRONG -- N+1: separate query per order
foreach ($orders as $order) {
    echo $order->user->name;  // separate SELECT per order
}

// CORRECT -- eager load with with()
$orders = Order::find()->with('user')->all();
foreach ($orders as $order) {
    echo $order->user->name;  // from cache
}
```

**CQ6 for Yii2:** Any `->all()` in a controller/service endpoint without `->limit()` = CQ6=0.
**CQ7 for Yii2:** Any list endpoint without pagination = CQ7=0.
**CQ17 for Yii2:** Any relation accessed in loop without `with()` or `joinWith()` = CQ17=0.

## Transaction Rules -- Atomicity

**Transaction required when:**
- 2+ models are saved (any combination)
- Save + side effect (email, queue push) -- side effect MUST happen AFTER commit
- Delete + cascade update (not handled by DB foreign key)

**Side effects AFTER commit only:**
```php
// WRONG -- email sent inside transaction; if commit fails, email already sent
$transaction = Yii::$app->db->beginTransaction();
$order->save(false);
Yii::$app->mailer->send(...);  // side effect inside transaction!
$transaction->commit();

// CORRECT -- side effect after commit
$transaction = Yii::$app->db->beginTransaction();
try {
    $order->save(false);
    $transaction->commit();
} catch (\Exception $e) {
    $transaction->rollBack();
    throw $e;
}
// Safe: only reached if commit succeeded
Yii::$app->queue->push(new SendOrderConfirmationJob(['orderId' => $order->id]));
```

**Retry-safe side effects:** Use queue/outbox pattern for side effects that might be retried. Never fire-and-forget async calls inside `try` block before commit.

## PHP strict_types + Static Analysis

**New files MUST have:**
```php
<?php
declare(strict_types=1);
```
`strict_types=1` makes PHP enforce parameter types at call sites -- prevents silent type coercion bugs (e.g., `"5"` passed as `int` parameter).

**PHPStan / Psalm:**
```
# phpstan.neon (minimum baseline for any project)
parameters:
    level: 5  # minimum; target 7+ for critical modules
    paths:
        - src/
        - models/
        - services/
    ignoreErrors: []  # no baseline exclusions in new code
```

**Forbidden in typed code:**
```php
// FORBIDDEN -- array without shape
function processData(array $data): array { ... }

// CORRECT -- typed DTO or array shape
/** @param array{name: string, email: string, age?: int} $data */
function processData(array $data): UserDTO { ... }
// Or: use a DTO class with typed properties
```

**CQ2 for PHP:** Any public function without return type declaration = CQ2=0. `mixed` and bare `array` in function signatures without PHPDoc shape = CQ2=0.

## Session / Cookie / CSRF Security

**Cookie settings (web/config/main.php):**
```php
'components' => [
    'session' => [
        'class'       => 'yii\web\Session',
        'cookieParams' => [
            'httponly' => true,
            'secure'   => YII_ENV_PROD,   // HTTPS only in prod
            'samesite' => 'Lax',          // or 'Strict' for high-security
        ],
    ],
    'request' => [
        'enableCsrfValidation' => true,   // DEFAULT ON -- never disable globally
        'cookieValidationKey'  => getenv('COOKIE_KEY'),  // never hardcode
    ],
],
```

**CSRF rules:**
- Cookies-based auth = CSRF required for ALL mutation routes (POST/PUT/PATCH/DELETE)
- `enableCsrfValidation = false` on a controller = MUST document why + restrict to API-only controllers using Bearer token auth
- AJAX requests: include `_csrf` param or `X-CSRF-Token` header

**Cache-Control for sensitive pages:**
```php
// Controller action returning sensitive data
Yii::$app->response->headers->set('Cache-Control', 'no-store, no-cache, must-revalidate');
Yii::$app->response->headers->set('Pragma', 'no-cache');
```

**CQ gate:** Any mutation endpoint with `enableCsrfValidation = false` without Bearer-token auth justification = CQ4=0.
