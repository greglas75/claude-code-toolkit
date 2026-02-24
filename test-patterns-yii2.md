# Test Patterns — Yii2 + Codeception

> Loaded when stack = **Yii2** and writing/auditing tests.
> Core protocol (Q1-Q17, scoring): `~/.claude/test-patterns.md`
> General patterns (G-1–G-40, P-1–P-46): `~/.claude/test-patterns-catalog.md`
> PHP/Yii2 code rules: `~/.claude/conditional-rules/php-yii2.md`

---

## Test Type Classification (Yii2-specific Step 1)

Before selecting patterns, classify the test type:

| Type | When to use | Actor | Speed |
|------|-------------|-------|-------|
| **UNIT** | Model validation, AR methods, behaviors, pure logic, helpers | `UnitTester` | Fast |
| **FUNCTIONAL** | Controller actions, forms, redirects, sessions, RBAC | `FunctionalTester` | Medium |
| **ACCEPTANCE** | Critical user flows (login, payment, registration) — browser required | `AcceptanceTester` | Slow |

**Rule:** Business logic and validation → UNIT. HTTP layer → FUNCTIONAL. Never test controller responses in unit tests (use functional), never test model logic in acceptance tests (use unit).

---

## Lookup Table (Yii2 code types → patterns)

| Code Type | Good patterns | Gap patterns |
|-----------|--------------|--------------|
| **MODEL** (AR, validation, scenarios) | G-46, G-47, G-4, G-2, G-52 | P-47, P-48, P-49, P-51, P-1, P-58, P-59 |
| **CONTROLLER** (actions, access control) | G-48, G-50, G-32, G-2 | P-47, P-50, P-52, P-5, P-59, P-60 |
| **BEHAVIOR** | G-46, G-49, G-2 | P-49, P-28, P-58 |
| **SERVICE/COMPONENT** | G-4, G-2, G-50 | P-5, P-28, P-1, P-60, P-61 |
| **FUNCTIONAL (HTTP)** | G-48, G-50, G-2, G-52 | P-47, P-50, P-52, P-59, P-60 |
| **AR QUERY/SCOPE** | G-46, G-2 | P-48, P-1, P-61 |

---

## Good Patterns

### G-46: ActiveFixture for Isolated DB State
- **When:** Any test that touches the database
- **Do:**
  ```php
  // Fixture class
  class OrderFixture extends ActiveFixture {
      public $modelClass = Order::class;
      public $dataFile   = '@tests/fixtures/data/order.php';
      public $depends    = [UserFixture::class];  // FK order

      const PENDING_ID  = 1;
      const APPROVED_ID = 2;
  }

  // Fixture data
  return [
      'pending'  => ['id' => 1, 'userId' => UserFixture::ADMIN_ID, 'status' => Order::STATUS_PENDING],
      'approved' => ['id' => 2, 'userId' => UserFixture::USER_ID,  'status' => Order::STATUS_APPROVED],
  ];

  // In test:
  public function _fixtures(): array {
      return ['orders' => OrderFixture::class, 'users' => UserFixture::class];
  }
  ```
  - Always declare `$depends` for FK relationships — wrong load order causes constraint violations
  - Use named constants (`OrderFixture::PENDING_ID`) not magic integers in assertions
  - Keep fixture data minimal — only what tests need
- **Why:** Tests relying on dev DB state fail in CI. Fixtures guarantee known state per test run.
- **Source:** Yii2 best practice — tests without fixtures average 3.0/10 in audits (P-48 trigger)

### G-47: Model Scenario Coverage
- **When:** AR model has multiple scenarios with different validation rules
- **Do:** Test EACH scenario independently:
  ```php
  public function testCreateScenarioRequiresPassword(): void {
      $user = new User(['scenario' => User::SCENARIO_CREATE]);
      $user->name  = 'John';
      $user->email = 'john@test.com';
      // password missing
      $this->assertFalse($user->validate());
      $this->assertArrayHasKey('password', $user->errors);
  }

  public function testUpdateScenarioDoesNotRequirePassword(): void {
      $user = new User(['scenario' => User::SCENARIO_UPDATE]);
      $user->name  = 'John Updated';
      $user->email = 'john@test.com';
      // no password — should be OK on update
      $this->assertTrue($user->validate());
      $this->assertArrayNotHasKey('password', $user->errors);
  }
  ```
  - Matrix to cover: `[scenario × required_field × optional_field]`
  - Always set `$model->scenario` explicitly — default is `SCENARIO_DEFAULT` which may differ
- **Why:** Yii2 scenarios are the most common source of "valid in one flow, invalid in another" bugs.
- **Source:** Yii2 production audit — 8/10 scenario-related bugs were in untested non-default scenarios

### G-48: Functional Test Actor Helpers
- **When:** Multiple functional tests share the same setup flow (login, navigate to section)
- **Do:**
  ```php
  // _support/Helper/Functional.php
  class Functional extends Module {
      public function loginAsAdmin(): void {
          $this->getModule('Yii2')->amLoggedInAs(UserFixture::ADMIN_ID);
      }

      public function loginAsUser(int $userId): void {
          $this->getModule('Yii2')->amLoggedInAs($userId);
      }

      public function seeFlashMessage(string $type, string $text): void {
          $this->getModule('Yii2')->seeInSession(['__flash' => [$type => [$text]]]);
      }
  }

  // In Cest:
  public function _before(FunctionalTester $I): void {
      $I->loginAsAdmin();
  }

  public function testCreateOrderSucceeds(FunctionalTester $I): void {
      $I->amOnRoute('order/create');
      $I->submitForm('#order-form', ['Order[amount]' => 100]);
      $I->seeFlashMessage('success', 'Order created');
      $I->seeRecord(Order::class, ['userId' => UserFixture::ADMIN_ID, 'amount' => 100]);
  }
  ```
  - `seeRecord()` is stronger than checking redirect — verifies DB write actually happened
  - Custom helper methods prevent copy-paste across Cest classes
- **Why:** Without helpers, every Cest repeats 5-10 lines of login/navigation setup. One change → N files to update.
- **Source:** Yii2 functional test review — files with custom actor methods averaged 8.2/10 vs 4.1/10 without

### G-49: Behavior Effect Assertions
- **When:** AR model uses a Behavior (TimestampBehavior, SoftDeleteBehavior, BlameableBehavior, etc.)
- **Do:**
  ```php
  // TimestampBehavior: created_at and updated_at set automatically
  public function testTimestampSetOnCreate(): void {
      $order = new Order(['scenario' => Order::SCENARIO_CREATE, 'amount' => 100]);
      $order->userId = UserFixture::ADMIN_ID;
      $order->save(false);

      $this->assertNotNull($order->created_at);
      $this->assertNotNull($order->updated_at);
      $this->assertEqualsWithDelta(time(), $order->created_at, 2);
  }

  // SoftDeleteBehavior: deleted_at set, record stays in DB
  public function testSoftDeleteSetsDeletedAt(): void {
      $order = Order::findOne(OrderFixture::PENDING_ID);
      $order->softDelete();

      $this->assertNotNull($order->deleted_at);
      // Record still exists in DB:
      $this->assertNotNull(Order::findOne(OrderFixture::PENDING_ID));
      // But excluded from default scope:
      $this->assertNull(Order::findActive()->id(OrderFixture::PENDING_ID)->one());
  }
  ```
  - Test BOTH the behavior's effect AND its integration with queries/scopes
  - Test attach/detach if behavior is conditional
- **Why:** Behaviors run in AR event hooks (beforeSave/afterDelete). If hook order changes or behavior is detached, silent data corruption. Tests catch it.
- **Source:** Yii2 audit — 12/15 projects with custom behaviors had zero behavior effect tests

### G-50: Component Mock via Yii::$app->set()
- **When:** Controller or service uses Yii components (`mailer`, `queue`, `cache`, `authManager`) that should not run in tests
- **Do:**
  ```php
  protected function setUp(): void {
      parent::setUp();

      // Mock mailer — don't send real emails
      $mailerMock = $this->createMock(MailerInterface::class);
      $mailerMock->expects($this->any())
                 ->method('compose')
                 ->willReturnSelf();
      Yii::$app->set('mailer', $mailerMock);

      // Mock queue — don't push real jobs
      $queueMock = $this->createMock(QueueInterface::class);
      Yii::$app->set('queue', $queueMock);
  }

  public function testRegistrationSendsWelcomeEmail(): void {
      $mailerMock = Yii::$app->mailer;
      $mailerMock->expects($this->once())
                 ->method('compose')
                 ->with('welcome', $this->arrayHasKey('user'))
                 ->willReturnSelf();

      $service = new RegistrationService();
      $service->register(['email' => 'new@test.com', 'password' => 'secret']);
  }
  ```
  - Always restore original component in `tearDown()` (or use test config override)
  - Verify CalledWith — not just Called
- **Alternative (lighter):** Use `useFileTransport = true` in test config instead of full mock:
  ```php
  // tests/_app/config/test.php
  'mailer' => ['useFileTransport' => true],
  // Then assert file was written:
  $messages = glob(Yii::getAlias('@runtime/mail') . '/*.eml');
  $this->assertCount(1, $messages);
  $this->assertStringContainsString('Welcome', file_get_contents($messages[0]));
  ```
  Use fileTransport for "was email sent?" checks. Use `createMock()` (above) for "with what args?" checks.
- **Why:** Real mailer/queue in tests = slow CI, side effects, flaky failures. Mock at the component level, not function level.
- **Source:** Yii2 audit — email tests without mocking averaged 2.5/10 (slow + side-effects)

### G-52: Database Constraint Tests (Defense in Depth)
- **When:** Model has `unique` validator OR unique DB constraint (email, slug, hash, composite key)
- **Do:** Test BOTH layers separately:
  ```php
  // Layer 1: Model validation (unique validator in rules())
  public function testDuplicateEmailFailsModelValidation(): void {
      $existing = User::findOne(UserFixture::ADMIN_ID);
      $duplicate = new User(['scenario' => User::SCENARIO_CREATE]);
      $duplicate->email = $existing->email;
      $duplicate->name  = 'Other Name';

      $this->assertFalse($duplicate->validate());
      $this->assertArrayHasKey('email', $duplicate->errors);
  }

  // Layer 2: DB constraint (when save(false) bypasses validation)
  public function testDuplicateEmailFailsAtDbLevel(): void {
      $existing = User::findOne(UserFixture::ADMIN_ID);
      $duplicate = new User();
      $duplicate->email = $existing->email;
      $duplicate->name  = 'Other Name';

      $this->expectException(\yii\db\IntegrityException::class);
      $duplicate->save(false);  // bypasses validation — DB constraint is last defense
  }
  ```
- **Why:** Model validation is the first layer; DB constraints are the second. If someone calls `save(false)` to skip validation (common in migrations, fixtures, imports), DB constraint catches it. Testing only model validation misses this.
- **Note:** Layer 2 test requires a real DB fixture — don't use it in unit tests, use it in functional/integration tests with `_fixtures()`.
- **Source:** Yii2 multi-tenant audit — duplicate hash bugs always reached DB level because batch import used `save(false)`

---

## Gap Patterns

### P-47: Missing RBAC / Access Control Tests
- **When:** Controller action has `AccessControl` behavior OR calls `Yii::$app->user->can()`
- **Problem:** The most common Yii2 security gap — RBAC is configured but never tested. Behavior misconfiguration silently grants access to everyone.
  ```php
  // Controller has this — but is it tested?
  'rules' => [
      ['allow' => true, 'roles' => ['admin']],
      ['allow' => false],  // deny all others
  ]
  ```
- **Required tests per guarded action:**
  ```php
  public function testGuestCannotAccessAdminPanel(FunctionalTester $I): void {
      $I->amOnRoute('admin/index');
      $I->seeResponseCodeIs(403);  // or redirect to login
  }

  public function testAdminCanAccessAdminPanel(FunctionalTester $I): void {
      $I->loginAsAdmin();
      $I->amOnRoute('admin/index');
      $I->seeResponseCodeIs(200);
  }

  public function testRegularUserCannotAccessAdminPanel(FunctionalTester $I): void {
      $I->loginAsUser(UserFixture::USER_ID);
      $I->amOnRoute('admin/index');
      $I->seeResponseCodeIs(403);
  }
  ```
- **Minimum:** guest (403/401) + authorized (200) + unauthorized-role (403) per guarded action
- **Source:** Yii2 security audit — 11/14 projects had guarded routes with zero access tests

### P-48: Tests Without Fixtures (Relying on Dev DB)
- **When:** Test uses hardcoded IDs (`User::findOne(1)`, `Order::find()->where(['id' => 5])`) without declaring fixtures
- **Problem:** Works on developer's machine, fails in CI because record doesn't exist. Or worse: passes in CI against stale test DB state, giving false confidence.
  ```php
  // WRONG — hardcoded ID, requires specific DB state
  public function testFindActiveOrders(): void {
      $orders = Order::findActive()->all();
      $this->assertCount(3, $orders);  // fails unless exactly 3 active orders exist
  }
  ```
- **Fix:** Declare `_fixtures()`, use fixture constants:
  ```php
  public function _fixtures(): array { return ['orders' => OrderFixture::class]; }

  public function testFindActiveOrders(): void {
      $orders = Order::findActive()->all();
      $this->assertCount(2, $orders);  // 2 active in fixture data
      $this->assertEquals(OrderFixture::ACTIVE_ID, $orders[0]->id);
  }
  ```
- **Detection:** Any test with hardcoded integer IDs in AR queries + no `_fixtures()` method = P-48
- **Source:** Yii2 audit — P-48 is the #1 cause of "passes locally, fails CI" in Yii2 projects

### P-49: Behavior Never Tested
- **When:** AR model attaches a custom Behavior in `behaviors()` method
- **Problem:** Built-in behaviors (TimestampBehavior) are reliable, but custom behaviors with `beforeSave`/`afterDelete` hooks have bugs that unit tests for model methods won't catch.
- **Detection:** `grep -rn "behaviors()" src/models/ | grep -v "TimestampBehavior\|BlameableBehavior"` → any custom behavior with no corresponding test = P-49
- **Fix:** For each custom behavior: test the hook triggers at the right time, the effect is correct, and the behavior interacts correctly with default scope queries (see G-49)
- **Source:** Yii2 audit — custom behaviors averaged 2 bugs per project when untested

### P-50: Functional Test With Direct DB Assertion Only
- **When:** Functional Cest submits a form and only checks `seeRecord()` without verifying HTTP response
- **Problem:** `seeRecord()` proves the data was saved but doesn't verify the response (status code, redirect, flash message). Controller could return 500 and still write the record in some cases.
  ```php
  // INCOMPLETE — doesn't verify controller response
  public function testCreateOrder(FunctionalTester $I): void {
      $I->submitForm('#order-form', ['Order[amount]' => 100]);
      $I->seeRecord(Order::class, ['amount' => 100]);  // data saved, but what was the response?
  }
  ```
- **Fix:** Check all three:
  ```php
  $I->submitForm('#order-form', ['Order[amount]' => 100]);
  $I->seeResponseCodeIsSuccessful();                    // no 500
  $I->seeCurrentRouteIs('order/view');                  // redirected to correct page
  $I->seeRecord(Order::class, ['amount' => 100]);       // data persisted
  ```
- **Source:** Yii2 functional test audit — 7/10 Cest files checked DB but never verified HTTP response

### P-51: Missing Scenario-Conditional Validation Tests
- **When:** Model has multiple scenarios with different required fields
- **Problem:** Tests only cover `SCENARIO_DEFAULT` — other scenarios (update, login, register) have different `rules()` and may silently allow or block wrong fields.
- **Detection:** Count unique `SCENARIO_*` constants in model vs distinct scenario-setting lines in test file. Mismatch = P-51.
- **Fix:** See G-47 — test each scenario × each required field combination
- **Source:** Yii2 audit — scenario bugs are the #2 most common model bug after missing null checks

### P-52: Missing Form Validation Error Display Test
- **When:** Controller action renders a form with validation errors
- **Problem:** Tests verify happy path (valid submit → redirect) but never test invalid submit → form re-shown with errors.
  ```php
  // MISSING — what happens when form submitted with invalid data?
  public function testCreateOrderShowsErrors(FunctionalTester $I): void {
      $I->loginAsAdmin();
      $I->amOnRoute('order/create');
      $I->submitForm('#order-form', []);  // empty — should fail validation
      $I->seeResponseCodeIs(200);         // stays on form page
      $I->see('Amount cannot be blank');  // error message shown
      $I->dontSeeRecord(Order::class, ['userId' => UserFixture::ADMIN_ID]);
  }
  ```
- **Required:** At least 1 invalid submit test per form action, checking: stays on page (200), error message visible, no record created
- **Source:** Yii2 audit — 9/12 Cest files had zero invalid-submit tests

### P-58: afterSave / afterDelete Side Effect Chain Not Fully Tested
- **When:** AR model overrides `afterSave()` or `afterDelete()` with multiple side effects
- **Problem:** Tests verify the first side effect (or none) but miss the full chain:
  ```php
  // Model with 3 side effects in afterSave:
  public function afterSave($insert, $changedAttributes) {
      parent::afterSave($insert, $changedAttributes);
      if ($insert) {
          $this->createDefaultPermissions();   // side effect 1
          Yii::$app->mailer->send(...);         // side effect 2
          $this->owner->updateCounters();       // side effect 3
      }
  }
  // Typical test: only verifies record was saved, not the 3 side effects
  ```
- **Required:** One test per side effect in the chain:
  ```php
  public function testCreateOrderCreatesDefaultPermissions(): void {
      $order = new Order(['scenario' => Order::SCENARIO_CREATE, ...]);
      $order->save();
      $this->tester->seeRecord(OrderPermission::class, ['orderId' => $order->id]);
  }

  public function testCreateOrderSendsConfirmationEmail(): void {
      $mailerMock = $this->mockMailer();
      $mailerMock->expects($this->once())->method('compose')->with('order-confirmation');
      (new Order([...]))->save();
  }

  public function testCreateOrderUpdatesUserOrderCount(): void {
      $userBefore = User::findOne(UserFixture::ADMIN_ID);
      (new Order(['userId' => $userBefore->id, ...]))->save();
      $userAfter = User::findOne(UserFixture::ADMIN_ID);
      $this->assertEquals($userBefore->orderCount + 1, $userAfter->orderCount);
  }
  ```
- **Detection:** Count side effects in `afterSave/afterDelete` → verify each has a test. One-to-one mapping required.
- **Source:** Yii2 audit — afterSave chains averaging 3 side effects, average 0.4 tests per chain

### P-59: Query-Level Authorization Gap (find() Without Tenant Filter)
- **When:** Controller/service retrieves a resource by ID without filtering by owner/tenant
- **Problem:** RBAC behavior checks role but query returns any record with that ID. User A can read User B's resource by guessing the ID.
  ```php
  // WRONG — ID lookup without ownership filter
  public function findUserOrder(int $orderId): ?Order {
      return Order::find()->where(['id' => $orderId])->one();
      // Missing: ->andWhere(['userId' => Yii::$app->user->id])
  }
  ```
- **Required test:** Functional test verifying cross-user access is blocked at query level:
  ```php
  public function testUserCannotViewAnotherUsersOrder(FunctionalTester $I): void {
      // User B's order — fetched by User A
      $I->loginAsUser(UserFixture::USER_A_ID);
      $I->sendGET('/order/view?id=' . OrderFixture::USER_B_ORDER_ID);
      $I->seeResponseCodeIs(403);
      // Additional: verify response body does NOT contain User B's data
      $I->dontSeeResponseContainsJson(['userId' => UserFixture::USER_B_ID]);
  }
  ```
- **Extends P-47 (RBAC):** P-47 = access control behavior. P-59 = query-level filter. Both required.
- **CQ4 link:** This is the test that validates CQ4 evidence — guard + query filter working together
- **Source:** Yii2 multi-tenant security audit — P-59 and P-47 were independent gaps in 6/8 systems tested

### P-60: Missing Idempotency / Reentrancy Test
- **When:** Controller action creates a resource, sends a notification, triggers a sync, or processes a payment — any action that should not produce duplicates on retry
- **Problem:** User double-clicks submit, network retry, queue redelivery → duplicate records, duplicate emails, double charges. No test verifies that the second call is safe.
  ```php
  // ACTION — what happens if called twice with same data?
  public function actionCreatePayment(): Response {
      $payment = new Payment();
      $payment->load(Yii::$app->request->post());
      $payment->save();  // second call = duplicate payment!
      Yii::$app->mailer->send(...);  // second call = duplicate email!
  }
  ```
- **Required tests:**
  ```php
  public function testDuplicatePaymentIsRejected(FunctionalTester $I): void {
      $I->loginAsUser(UserFixture::USER_ID);
      $payload = ['Payment[orderId]' => OrderFixture::PENDING_ID, 'Payment[amount]' => 100];

      // First call — succeeds
      $I->sendPOST('/payment/create', $payload);
      $I->seeResponseCodeIs(200);
      $I->seeRecord(Payment::class, ['orderId' => OrderFixture::PENDING_ID]);

      // Second call — same data, must be rejected or idempotent
      $I->sendPOST('/payment/create', $payload);
      $I->seeResponseCodeIs(409);  // or 200 if idempotent (returns existing)
      // Verify no duplicate:
      $count = Payment::find()->where(['orderId' => OrderFixture::PENDING_ID])->count();
      $this->assertEquals(1, $count);
  }

  public function testDuplicateInviteDoesNotSendSecondEmail(FunctionalTester $I): void {
      $I->loginAsAdmin();
      $I->sendPOST('/invite/send', ['email' => 'new@test.com']);
      $I->sendPOST('/invite/send', ['email' => 'new@test.com']);
      // Assert: only 1 invite record, only 1 email sent
  }
  ```
- **Detection:** Any `save()` or `queue->push()` in action without unique constraint / idempotency key = P-60
- **Source:** Yii2 payment/invite audit — double-click bugs in 4/6 projects tested

### P-61: N+1 Query in View / Service Loop
- **When:** Code iterates over AR models and accesses a relation without eager loading
- **Problem:** Each `$model->relation` in the loop fires a separate SQL query. 100 orders × 1 user query = 101 queries instead of 2.
  ```php
  // WRONG — N+1: one query per iteration
  $orders = Order::find()->where(['status' => Order::STATUS_ACTIVE])->all();
  foreach ($orders as $order) {
      echo $order->user->name;      // SELECT * FROM user WHERE id = ? (per order!)
      echo $order->items[0]->name;  // SELECT * FROM item WHERE orderId = ? (per order!)
  }
  ```
- **Fix:** Eager load with `with()`:
  ```php
  $orders = Order::find()
      ->where(['status' => Order::STATUS_ACTIVE])
      ->with('user', 'items')  // 2 queries total, not N+1
      ->all();
  ```
- **Required test:** Verify query count or assert eager loading:
  ```php
  public function testFindActiveOrdersUsesEagerLoading(): void {
      $orders = Order::findActiveWithRelations();
      // Access relations without triggering queries:
      foreach ($orders as $order) {
          $this->assertNotNull($order->getRelatedRecords()['user'] ?? null,
              'User relation should be eager-loaded');
      }
  }
  ```
- **Detection:** `grep -rn '->all()' src/ | xargs grep -l 'foreach'` → check if loop body accesses `->relation` without prior `with()`
- **CQ17 link:** This is the test pattern for CQ17 enforcement in Yii2
- **Source:** Yii2 performance audit — N+1 found in 9/12 projects, avg 50-200 extra queries per page

---

## Stack Adjustments (Codeception-specific — each missed = -1)

| Check | Trigger |
|-------|---------|
| Uses `_fixtures()` not hardcoded IDs? | Any test touching DB |
| Functional test checks response code + redirect + DB? | `submitForm` or `amOnRoute` |
| RBAC tested: guest + auth + wrong-role? | Any `AccessControl` behavior on controller |
| `Yii::$app->set()` used for component mocks (not real mailer/queue)? | Any service using mailer/queue/SMS |
| Scenario set explicitly before `validate()`? | Any model unit test |
| Custom behavior has at least 1 effect test? | Any custom `behaviors()` returning non-built-in behavior |
| `tearDown()` restores Yii::$app components if overridden? | Any test using `Yii::$app->set()` |
| afterSave/afterDelete overrides tested for ALL side effects? | Any custom afterSave/afterDelete |
| Query filters include tenant/owner on all resource lookups? | Any find() by ID in controller/service |
| DB constraint test exists alongside model validation test? | Any unique validator in rules() |
| Idempotency tested for create/send/sync actions? | Any action that creates resources or sends notifications |
| Eager loading (`with()`) used when iterating AR with relations? | Any `->all()` followed by loop accessing relations |

---

## Anti-Patterns (Codeception / Yii2 specific)

| AP | Pattern | Fix |
|----|---------|-----|
| AP-Y1 | `$this->assertEquals(1, count($models))` — count-only assertion | Assert content: `$this->assertEquals(OrderFixture::PENDING_ID, $models[0]->id)` |
| AP-Y2 | Testing `$model->save()` return value only (`$this->assertTrue($model->save())`) | Also assert DB state: `$this->assertNotNull(Order::findOne($model->id))` |
| AP-Y3 | Skipping `_fixtures()` + relying on existing DB (P-48) | Use ActiveFixture — see G-46 |
| AP-Y4 | Testing controller via unit test (`new Controller()` directly) | Use FunctionalTester — controllers need HTTP context |
| AP-Y5 | `$I->see('Success')` without verifying redirect or DB | Add `seeRecord()` + `seeCurrentRouteIs()` |
| AP-Y6 | No `tearDown()` cleanup for `Yii::$app->set()` mocks | Restore original component or use test config overlay |
| AP-Y7 | Testing `$model->errors` before calling `validate()` | Always call `$model->validate()` first — errors array is empty before validation |

---

## Security Test Checklist (Yii2 Controller)

Every controller with user data MUST have these functional tests:

| # | Test | Expected |
|---|------|----------|
| S1 | Guest access to protected action | 302 → login page OR 403 |
| S2 | Wrong role access (user → admin action) | 403 Forbidden |
| S3 | Cross-user data access (user A views user B's resource) | 403 + record NOT returned |
| S4 | CSRF token missing on POST | 400 Bad Request |
| S5 | Mass assignment (extra fields in POST) | Extra fields ignored, model unchanged |
| S6 | XSS in user-supplied content displayed back | `Html::encode()` applied — angle brackets escaped |
| S7 | File upload: invalid MIME type or oversized | 422 / 400 |
| S8 | File upload: executable extension (.php, .phar) | 400 + upload rejected |
| S9 | Path traversal in file/resource request (`../etc/passwd`) | 400 / 403 |
| S10 | Unbounded list endpoint (no pagination param) | Response has `pagination` key OR max N records |
| S11 | SSRF: URL pointing to internal IP (if URL input accepted) | 400 / 403 |

S4-S6: skip if not applicable. S1-S3: always required. S7-S11: apply when feature is relevant.

---

## Quick-Reference: Test File Structure

### Unit Test (Model)
```php
// tests/unit/models/OrderTest.php
class OrderTest extends \Codeception\Test\Unit {
    protected UnitTester $tester;

    public function _fixtures(): array {
        return ['orders' => OrderFixture::class, 'users' => UserFixture::class];
    }

    // Happy path
    public function testValidOrderPassesValidation(): void { ... }

    // Error paths (Q7 — CRITICAL)
    public function testMissingAmountFailsValidation(): void { ... }
    public function testNegativeAmountFailsValidation(): void { ... }

    // Scenario coverage (G-47)
    public function testCreateScenarioRequiresUserId(): void { ... }
    public function testUpdateScenarioDoesNotRequireUserId(): void { ... }

    // Behavior effects (G-49)
    public function testTimestampSetOnSave(): void { ... }
}
```

### Functional Test (Controller)
```php
// tests/functional/OrderCest.php
class OrderCest {
    public function _before(FunctionalTester $I): void {
        $I->loginAsAdmin();  // G-48 helper
    }

    public function _fixtures(): array {
        return ['orders' => OrderFixture::class, 'users' => UserFixture::class];
    }

    // Happy path
    public function testCreateOrderSucceeds(FunctionalTester $I): void { ... }

    // Validation errors (P-52)
    public function testCreateOrderShowsErrorsOnEmptySubmit(FunctionalTester $I): void { ... }

    // RBAC (P-47)
    public function testGuestCannotCreateOrder(FunctionalTester $I): void { ... }
    public function testUserRoleCannotDeleteOrder(FunctionalTester $I): void { ... }
}
```
