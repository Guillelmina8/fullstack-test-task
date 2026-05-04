# Role-Based Access Control (RBAC)

## Setup Instructions

### Prerequisites
- Docker and Docker Compose installed
- Git

### Running the Application

```bash
git clone <your-repo-url>
cd full-stack-fastapi-template

# Build and start all services (first time takes a few minutes)
docker compose up -d --build db prestart backend frontend

# The app will be available at:
# Frontend: http://localhost:5173
# Backend API: http://localhost:8000
# API Docs: http://localhost:8000/docs
```

### Default Admin Credentials
- **Email:** `admin@example.com`
- **Password:** `changethis`

### Running Tests

```bash
docker compose run --rm --no-deps \
  -v "$(pwd)/backend/tests:/app/backend/tests" \
  backend bash -c "python -m pytest tests/ -v"
```

> **Note:** Tests use the live database and clean up after themselves (all users are deleted). Run `docker compose run --rm prestart` after tests to restore the admin user.

---

## Permission Matrix

| Action | Admin | Manager | Member |
|--------|:-----:|:-------:|:------:|
| List all users `GET /users/` | ✅ | ✅ | ❌ |
| Create user `POST /users/` | ✅ | ❌ | ❌ |
| View own profile `GET /users/me` | ✅ | ✅ | ✅ |
| Update own profile `PATCH /users/me` | ✅ | ✅ | ✅ |
| Change own password | ✅ | ✅ | ✅ |
| Delete own account | ❌ | ✅ | ✅ |
| View any user `GET /users/{id}` | ✅ | ✅ | self only |
| Update any user `PATCH /users/{id}` | ✅ | ❌ | ❌ |
| Delete any user `DELETE /users/{id}` | ✅ | ❌ | ❌ |
| View Admin panel (UI) | ✅ | ✅ | ❌ |
| Add User button (UI) | ✅ | ❌ | ❌ |

---

## Authorization Approach

### Role Model

Three roles are defined as a Python `str` enum (`UserRole`) stored as a `VARCHAR` column on the `user` table:

- **admin** — full control over users and settings
- **manager** — read access to user list and individual profiles; no write operations on other users
- **member** — access limited to own profile only

The `role` field lives in `UserBase`, so it is inherited by `UserCreate`, `UserUpdate`, and `UserPublic` — giving consistent exposure across all API operations.

### Enforcement

Authorization is enforced at the FastAPI dependency layer via a `require_role(*roles)` factory in `api/deps.py`. It returns a `Depends(...)` object that resolves the current authenticated user and raises `HTTP 403` if their role is not in the allowed set. Routes declare their access requirements directly in the decorator:

```python
@router.get("/", dependencies=[require_role(UserRole.admin, UserRole.manager)])
@router.post("/", dependencies=[require_role(UserRole.admin)])
```

This keeps authorization logic out of the route handlers themselves, making the permission model easy to read at a glance.

### Frontend

The React frontend reads the `role` field from the `/users/me` response and conditionally renders navigation items and action buttons. The Admin route guard (`beforeLoad`) redirects members to the home page before the component even mounts, so the restriction is enforced at the routing level rather than just hiding elements.

### Relationship to `is_superuser`

The existing `is_superuser` flag is preserved for backward compatibility. The `admin` role is assigned to the first superuser on startup. New role checks use `role` exclusively; `is_superuser` is only retained for the "superuser cannot delete themselves" safety guard.
