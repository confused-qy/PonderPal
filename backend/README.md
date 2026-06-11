# PonderPal Backend

Node.js, Express, PostgreSQL, JWT, and bcrypt backend for the existing iOS app.

## Directory Structure

```text
backend/
  sql/schema.sql
  src/
    app.js
    server.js
    config/env.js
    controllers/
      answerController.js
      authController.js
      friendController.js
    db/
      answers.js
      friendships.js
      pool.js
      users.js
    middleware/
      auth.js
      errorHandler.js
    routes/
      apiRoutes.js
      authRoutes.js
    services/
      answerService.js
      authService.js
      friendService.js
```

## Local Setup

1. Install dependencies:

```sh
cd backend
npm install
```

2. Create a local database:

```sh
createdb ponderpal
psql ponderpal -f sql/schema.sql
```

3. Create `.env`:

```sh
cp .env.example .env
```

Example local values:

```env
PORT=3000
DATABASE_URL=postgres://postgres:postgres@localhost:5432/ponderpal
JWT_SECRET=your-long-random-secret
JWT_EXPIRES_IN=30d
CORS_ORIGIN=*
```

4. Run:

```sh
npm run dev
```

Health check:

```sh
curl http://localhost:3000/health
```

The backend supports both root routes like `/sync` and the current iOS prefix:

```text
/api/daily_reflect/sync
/api/daily_reflect/friends
/api/daily_reflect/friend/link
/api/daily_reflect/friend/:name/answers
/api/daily_reflect/register
/api/daily_reflect/login
```

## API

### `POST /register`

Body:

```json
{
  "username": "alice",
  "password": "secret"
}
```

Response:

```json
{
  "ok": true,
  "user": {
    "id": "...",
    "username": "alice",
    "created_at": "..."
  }
}
```

### `POST /login`

Body:

```json
{
  "username": "alice",
  "password": "secret"
}
```

Response:

```json
{
  "token": "...",
  "user": {
    "id": "...",
    "username": "alice"
  }
}
```

All APIs below require:

```text
Authorization: Bearer <token>
```

### `POST /sync`

Body:

```json
{
  "username": "alice",
  "answers": {
    "1_2026": {
      "content": "Today I felt calm.",
      "visible": true
    }
  }
}
```

### `GET /friends?me=alice`

Response:

```json
{
  "friends": ["bob"]
}
```

### `POST /friend/link`

Body:

```json
{
  "me": "alice",
  "friend": "bob"
}
```

Response:

```json
{
  "friend_answers": {
    "1_2026": {
      "content": "Bob's visible answer"
    }
  }
}
```

### `GET /friend/:name/answers`

Response:

```json
{
  "answers": {
    "1_2026": {
      "content": "Visible answer"
    }
  }
}
```

## Render Deployment

1. Push this repository to GitHub.
2. In Render, create a PostgreSQL database.
3. Copy the database `External Database URL` or `Internal Database URL`.
4. Create a new Web Service from the GitHub repo.
5. Set root directory to `backend`.
6. Build command:

```sh
npm install
```

7. Start command:

```sh
npm start
```

8. Add environment variables:

```env
NODE_ENV=production
DATABASE_URL=<Render PostgreSQL URL>
JWT_SECRET=<long random secret>
JWT_EXPIRES_IN=30d
CORS_ORIGIN=*
```

9. Run the SQL in `sql/schema.sql` against the Render PostgreSQL database. You can use Render's psql connection command locally:

```sh
psql "<DATABASE_URL>" -f sql/schema.sql
```

## Generate `JWT_SECRET`

Use either:

```sh
openssl rand -base64 48
```

or:

```sh
node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"
```

## iOS Changes Needed

Requests requiring `Authorization: Bearer <token>`:

- `POST /sync`
- `GET /friends?me=username`
- `POST /friend/link`
- `GET /friend/:name/answers`

Requests not requiring JWT:

- `POST /register`
- `POST /login`

Store the JWT in Keychain, not `UserDefaults`. `UserDefaults` is fine for low-risk UI preferences like language, but not bearer tokens or passwords.

Suggested `AppState` additions:

```swift
@Published var authToken: String? = nil
@Published var authError: String? = nil
@Published var authBusy: Bool = false
```

Also replace local password storage with backend auth:

- `register(username:password:)` should call `POST /register`, then optionally call `POST /login`.
- `login(username:password:)` should call `POST /login`, save `token` to Keychain, set `username`, set `isLoggedIn = true`.
- `logout()` should remove the token from Keychain and clear in-memory auth state.

`APIService` should add an optional token parameter or a helper:

```swift
req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
```

The current backend preserves the iOS answer dictionary key format (`"qId_year"`) by storing it in `answers.question_id`.
