# Neoquest DB Server Installation & Migration Guide

This guide provides a step-by-step procedure to install dependencies and run database migrations for the Neoquest project.

---

## 🧰 Prerequisites

Ensure you have the following installed:
- **postgres** v17.4 (or higher)
- **pgAdmin** v9.5 (or higher)  
- **Node.js** v22.18.0  
- **npm** v10.9.3 (or higher recommended)
- Access to the project folders

---

## ⚙️ Setup Steps

### 1. Verify Node.js and npm Installation

```bash
node -v
# v22.18.0

npm -v
# 10.9.3
```

---

### 2. Update npm to the Latest Version (Optional but Recommended)

```bash
npm install -g npm@11.5.2
```

---

### 3. Install PostgreSQL Driver

```bash
npm install pg
```

---

### 4. Navigate to the Database Directory

```bash
cd .../neoquest/neoquest_db
```

Verify the directory contents using:

```bash
dir
```

You should see the following structure:

```
neoquest_db/
├── .env                # Environment variables (DB credentials, etc.)
├── database.json       # Database connection config (used by db-migrate and setup)
├── package.json        # Contains project metadata and npm scripts
├── scripts/            # Utility scripts
│   └── setup-database.js  # Creates DB, user, schema, permissions
└── migrations/         # All migration scripts for db-migrate
```

If your database does not exist yet, you can **automatically create it** along with the user and schema by running:

```bash
node scripts/setup-database.js
```

This script performs the following:

- Connects to PostgreSQL as superuser
- Creates the `neoquest` database (if it doesn't exist)
- Creates the user `neoquest_app` with password `neoquest_secure_2024`
- Sets up the schema and required privileges
- Shows the migration status

You may also run:

```bash
node scripts/setup-database.js status
```

To only show the current migration state.

---

### 5. Install `db-migrate` CLI Tool Globally

```bash
npm install -g db-migrate
```

---

### 6. Install PostgreSQL Adapter for db-migrate

```bash
npm install -g db-migrate-pg
```

---

### 7. Run Database Migrations

Once the `neoquest` database exists, run:

```bash
npm run migrate:up
```

> ℹ️ If you encounter an error like:
>  
> `No such driver found`  
> Make sure `db-migrate-pg` is installed globally.

> If you see:
>  
> `database "neoquest" does not exist`  
> You must create the database manually or via `setup-database.js`.

---

## ✅ Expected Successful Output

You should see logs like:

```
[INFO] Processed migration 19920214000001-init-new-quest-schema
[INFO] Processed migration 19920214000002-add-indexes
...
🎉 Game session management system migration completed successfully!
[INFO] Done
```

---

## 🧪 Troubleshooting

| Error Message | Solution |
|---------------|----------|
| `Missing script: "migrate:up"` | Ensure `scripts` section in `package.json` includes `"migrate:up": "db-migrate up"` |
| `No such driver found` | Run: `npm install -g db-migrate-pg` |
| `database "neoquest" does not exist` | Create the database before running the migration |
| `npn run migrate:up` typo | Correct it to `npm run migrate:up` |

---

## 🏁 Done

Your Neoquest database is now fully migrated and ready to use!
