# Python Rules (Conditional)

**Apply when:** Python detected (see `stack-detection.md`). **Skip** for TypeScript/JavaScript-only projects.

---

## Type Hints

```python
# ALWAYS use type hints for function signatures
def process_data(items: list[dict[str, Any]], limit: int = 100) -> list[Result]:
    ...

# Use TypedDict for complex dict structures
class UserData(TypedDict):
    id: str
    email: str
    role: Literal["admin", "user"]

# Use Protocol for duck typing
class Serializable(Protocol):
    def to_dict(self) -> dict[str, Any]: ...
```

- Use `from __future__ import annotations` for forward references
- Prefer `list[str]` over `List[str]` (Python 3.9+)
- Use `X | None` over `Optional[X]` (Python 3.10+)

## Common Pitfalls

### Mutable Default Arguments
```python
# WRONG — shared mutable default
def add_item(item: str, items: list[str] = []) -> list[str]:
    items.append(item)  # Mutates across calls!
    return items

# CORRECT
def add_item(item: str, items: list[str] | None = None) -> list[str]:
    if items is None:
        items = []
    items.append(item)
    return items
```

### Async Pitfalls
```python
# WRONG — blocking call in async context
async def fetch_data():
    result = requests.get(url)  # Blocks the event loop!

# CORRECT
async def fetch_data():
    async with httpx.AsyncClient() as client:
        result = await client.get(url)
```

### Exception Handling
```python
# WRONG — bare except or too broad
try:
    process()
except:  # Catches SystemExit, KeyboardInterrupt!
    pass

except Exception:  # Still too broad, and swallows silently
    pass

# CORRECT — specific exceptions, log the error
try:
    process()
except ValueError as e:
    logger.error("Invalid value: %s", e)
    raise
except (ConnectionError, TimeoutError) as e:
    logger.warning("Network issue: %s", e)
    return fallback_value
```

## Testing (pytest)

```python
# File naming: test_module_name.py
# Function naming: test_descriptive_behavior()

def test_process_data_returns_empty_list_for_no_input():
    result = process_data([])
    assert result == []

def test_process_data_raises_on_invalid_input():
    with pytest.raises(ValueError, match="items cannot be None"):
        process_data(None)

# Use fixtures for shared setup
@pytest.fixture
def sample_data():
    return [{"id": "1", "name": "Test"}]

# Use parametrize for multiple cases
@pytest.mark.parametrize("input,expected", [
    ("hello", "HELLO"),
    ("", ""),
    ("123", "123"),
])
def test_upper(input, expected):
    assert upper(input) == expected
```

## Code Style

- Follow PEP 8 (enforced by ruff/black/flake8)
- Max line length: 88 (black default) or 120
- Use f-strings over `.format()` or `%`
- Use pathlib over os.path
- Use dataclasses or Pydantic for data structures
- Never use `eval()`, `exec()`, or `pickle` with untrusted data

## Project Structure

```
src/
├── models/          # Data models (Pydantic/dataclass)
├── services/        # Business logic
├── repositories/    # Database access
├── utils/           # Pure utility functions
└── tests/           # Mirror source structure
    ├── test_models/
    ├── test_services/
    └── conftest.py  # Shared fixtures
```
