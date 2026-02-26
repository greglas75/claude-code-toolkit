# Test Patterns -- Redux (Domain-Specific)

> Loaded when code type = **REDUX-SLICE** (detected in Step 1 of `~/.codex/test-patterns.md`).
> Core protocol (Q1-Q17, scoring): `~/.codex/test-patterns.md`
> General patterns (G-1-G-40, P-1-P-46): `~/.codex/test-patterns-catalog.md`

---

## Good Patterns

### G-41: Redux Slice -- createInitialState + reduceFrom Helpers
- **When:** Testing Redux Toolkit slice reducers (pending/fulfilled/rejected transitions)
- **Do:**
  ```typescript
  const createInitialState = (overrides = {}) => ({
    profiles: [], profile: {}, filters: null, loading: false, error: undefined,
    ...overrides
  });
  const reduceFrom = (action, stateOverrides = {}) =>
    reducer(createInitialState(stateOverrides), action);
  ```
  - Use `it.each` for all pending states: `it.each([['fetchProfiles', fetchProfiles.pending.type], ...])('%s.pending sets loading', ...)`
  - After `fulfilled`: assert **state content** (`.profiles`, `.filters`, `.industry`), not just `.loading === false`
  - After `rejected`: assert `.error` has the **specific error message** -- different per action to prove correct routing
  - Edge case: `payload: undefined` on rejected -- verifies no crash on empty error body
- **Anti-pattern:** `reducer({ initialState: {} }, action)` -- `{ initialState: {} }` is NOT real slice state; `loading=false` is just the default value, not a meaningful transition
- **Source:** audit 2026-02-24, Industry.test.tsx -- score 4.5->7.5 with this pattern

### G-42: MSW Request Body Capture for Thunk Verification
- **When:** Testing Redux thunks (createAsyncThunk) backed by MSW server -- need to verify what was SENT to the API, not just what came back
- **Do:**
  ```typescript
  it('addIndustry sends correct payload to API', async () => {
    let sentBody = null;
    server.use(
      rest.post(industryEP, async (req, res, ctx) => {
        sentBody = await req.json();
        return res(ctx.json({ id: 99, ...sentBody }), ctx.delay(50));
      })
    );
    await store.dispatch(addIndustry({ payload: FORM_PAYLOAD }));
    expect(sentBody).toEqual(FORM_PAYLOAD);          // <- what was sent TO API
    expect(lastAction.payload.industry_name).toBe('Finance'); // <- what came back
  });
  ```
  - Capture URL for edit/delete: `sentUrl = req.url.pathname` -> `expect(sentUrl).toContain(`/${ENTITY_ID}`)`
  - Verify delete ID array: `expect(sentBody).toEqual({ id: [ENTITY_ID] })`
- **Why:** Without sentBody capture, thunk tests only verify mock returns. If `FORM_PAYLOAD` was never sent (or wrong fields), test still passes.
- **Source:** audit 2026-02-24, Industry.test.tsx -- score 7.5->8.5 with sentBody capture on add/edit/delete

### G-43: vi.mock Thunk for Component Dispatch Payload Verification
- **When:** Testing React component that dispatches a Redux thunk on user interaction (search, submit, filter)
- **Do:**
  ```typescript
  vi.mock('../profileSlice', async () => {
    const actual = await vi.importActual('../profileSlice');
    return {
      ...actual,
      fetchProfiles: vi.fn(args => () => ({ type: 'profiles/fetch-mock', payload: args }))
    };
  });

  beforeEach(() => { vi.mocked(fetchProfiles).mockClear(); });

  it('dispatches fetchProfiles with first_name on submit', async () => {
    await userEvent.type(screen.getByPlaceholderText(/first_name/i), 'moon');
    await userEvent.click(screen.getByRole('button', { name: /search/i }));
    expect(fetchProfiles).toHaveBeenCalledWith({
      searchParams: expect.objectContaining({ first_name: 'moon' })
    });
  });
  ```
  - Test combined filters: type in 3 fields -> verify ALL appear in one `CalledWith` assertion
  - Test empty submit: `expect(fetchProfiles).toHaveBeenCalledWith({})` (no searchParams key)
  - Add negative: `expect(fetchProfiles).not.toHaveBeenCalledWith(expect.objectContaining({ searchParams: expect.anything() }))` for empty submit
- **Replaces:** opaque `dispatchSpy` pattern where `typeof === 'function'` proves only "a thunk was dispatched" -- not which thunk or with what payload
- **Source:** audit 2026-02-24, ClientProfileFilter -- score 6.5->8.5 with vi.mock thunk pattern

### G-44: vi.mock with importActual for Selective Slice Mocking
- **When:** Component test needs to mock specific thunks while keeping reducers, selectors, and other exports working
- **Empirical:** Universal pattern in 103/106 files in Offer Module -- strongest single structural predictor of test quality
- **Do:**
  ```typescript
  vi.mock('../profileSlice', async () => {
    const actual = await vi.importActual('../profileSlice');
    return {
      ...actual,                          // keeps reducers, selectors, initialState
      fetchProfiles: vi.fn(),             // only replaces thunks you control
      addProfile: vi.fn(),
    };
  });
  // In beforeEach:
  vi.mocked(fetchProfiles).mockImplementation(() => () => {});
  ```
  - Spread `actual` first -- avoids breaking selectors used in component
  - Only override what you need to control in the test
  - `mockClear()` or `mockReset()` in `beforeEach`, not between tests
- **Why:** Partial mocking lets you test the component's dispatch behavior while the rest of the slice stays real. Full module mock (`vi.mock('../profileSlice')` with no factory) breaks selectors and crashes the component.
- **Source:** audit 2026-02-24, Offer Module 106-file scan -- 103/106 files use this pattern; the 3 without it scored avg 4.2/10

### G-45: preloadedState Factory for Component Tests
- **When:** Testing React component connected to Redux -- need specific store state without dispatching thunks
- **Empirical:** Used in 49/106 files; avg score 8.1/10 vs 5.3/10 for files relying on thunk-driven setup
- **Do:**
  ```typescript
  const setup = (stateOverrides: Partial<ProfileState> = {}) =>
    renderWithProviders(<ClientProfile />, {
      preloadedState: {
        profiles: {
          ...profileInitialState,     // real slice initialState as base
          profiles: PROFILE_FIXTURES,
          loading: false,
          ...stateOverrides           // per-test overrides
        }
      }
    });

  it('shows loading spinner while fetching', () => {
    setup({ loading: true, profiles: [] });
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  it('shows profiles after load', () => {
    setup({ profiles: PROFILE_FIXTURES });
    expect(screen.getAllByRole('row')).toHaveLength(PROFILE_FIXTURES.length + 1); // +1 header
  });
  ```
  - Always spread real `initialState` -- don't construct minimal `{}` (hits P-40)
  - Name the helper `setup()` or `renderWithState()` -- stays consistent across the suite
- **Why:** `preloadedState` skips async thunk dispatch entirely. Tests run instantly and deterministically -- no MSW server needed for state-based rendering tests.
- **Source:** audit 2026-02-24, Offer Module 106-file scan -- 49/106 files use preloadedState pattern; faster and more reliable than thunk-driven setup

---

## Gap Patterns

### P-40: Redux Reducer Wrong Initial State
- **When:** Testing Redux Toolkit slice reducer -- passing non-slice state to `reducer()` call
- **Problem:**
  ```typescript
  // WRONG -- { initialState: {} } is not the real slice state
  const state = reducer({ initialState: {} }, { type: addProfile.fulfilled.type, payload });
  expect(state.loading).toEqual(false);  // <- always false, this is just the JS default for missing key
  ```
  The reducer receives malformed state. `state.loading === false` is the default value, NOT a meaningful transition from `true`.
- **Fix:** Use `createInitialState()` with the real shape (see G-41), or import `initialState` from the slice:
  ```typescript
  const state = reducer(
    createInitialState({ loading: true }),  // start from loading state
    { type: addProfile.fulfilled.type, payload }
  );
  expect(state.loading).toBe(false);  // now a real transition
  expect(state.profiles).toContainEqual(expect.objectContaining({ id: 29 }));  // data in store
  ```
- **Source:** audit 2026-02-24, profileSlice + industrySlice pre-fix -- score held at 5.5 because of this pattern

### P-41: Loading-Only Redux Assertions
- **When:** Testing Redux slice fulfilled/rejected actions
- **Problem:** Test only checks `state.loading === false` -- never verifies data was actually stored, updated, or removed:
  ```typescript
  // INCOMPLETE -- loading flipped but data never verified
  expect(state.loading).toEqual(false);  // <- that's it. Where's the data?
  ```
- **Required checks by action type:**
  - `add.fulfilled` -> `.profiles` contains new entity with correct fields (not just `.id`)
  - `fetch.fulfilled` -> `.profiles` equals fixture array; `.filters` extracted from thunk args
  - `edit.fulfilled` -> correct entity updated in collection; old values replaced
  - `delete.fulfilled` -> entity REMOVED from collection (verify absence, not just loading)
  - `*.rejected` -> `.error` contains SPECIFIC message for this action (not same `unauthorizedPayload` for every action)
- **Source:** audit 2026-02-24, profileSlice pre-fix -- 16 reducer tests, all end with `loading === false`, zero data checks

### P-44: Redux Thunk Rejected State Coverage Gap
- **When:** Testing Redux Toolkit slice with `createAsyncThunk`
- **Problem:** Only 9/106 files in real-world audit tested `.rejected` state. Rejected path covers API 401/403/500, network timeout, and backend validation errors -- exactly the paths that fail in production.
  ```typescript
  // MISSING -- no rejected test anywhere in the suite
  // Code that runs when server returns 500: never verified
  ```
- **Required per thunk:** At least 1 `rejected` test with a **specific** error message assertion (not same generic payload for every action)
  ```typescript
  it('fetchProfiles.rejected sets specific error message', () => {
    const state = reduceFrom(
      { type: fetchProfiles.rejected.type, error: { message: 'Network error' } }
    );
    expect(state.error).toBe('Network error');
    expect(state.loading).toBe(false);
    expect(state.profiles).toEqual([]);  // data unchanged
  });
  ```
- **Related:** P-41 (loading-only assertions), G-41 (createInitialState helpers)
- **Source:** audit 2026-02-24, Offer Module 106-file scan -- only 9/106 test rejected state; 97 files have zero error path coverage for thunks
