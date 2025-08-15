# Development Workflow

## 🚀 Fast Development Setup

This project uses **Git hooks** for code quality instead of real-time editor checks for maximum performance.

### ⚡ Performance Optimizations

**VS Code/Cursor settings** are configured to disable real-time checks:
- ❌ Auto-format on save
- ❌ Real-time ESLint linting  
- ❌ TypeScript live type-checks
- ❌ Tailwind IntelliSense validation
- ❌ Prettier extension

**Why?** These checks run in Git hooks instead, keeping your editor fast.

### 🔧 Git Hooks

#### Pre-commit Hook
- Runs `lint-staged` on staged files only
- Formats and lints changed files
- Fast feedback before committing

#### Pre-push Hook  
- Runs full project lint + format + security scan
- Ensures code quality before pushing
- Prevents broken code from reaching remote

### 📋 Available Commands

```bash
# Development
npm run dev              # Start with Docker Compose
npm run dev:ui          # Start UI only
npm run dev:api         # Start API only

# Code Quality
npm run lint            # Lint both UI and API
npm run format          # Format both UI and API  
npm run security        # Security audit both UI and API
npm run pre-push        # Run all checks (used by hook)

# Individual components
npm run lint:ui         # Lint UI only
npm run lint:api        # Lint API only
npm run format:ui       # Format UI only
npm run format:api      # Format API only
npm run security:ui     # Security audit UI only
npm run security:api    # Security audit API only
```

### 🛠️ Tools Used

**UI (React/TypeScript):**
- ESLint for linting
- Prettier for formatting
- npm audit for security

**API (Python/FastAPI):**
- Black for formatting
- Flake8 for linting
- Safety for security

### 🔄 Workflow

1. **Code freely** - No real-time checks slowing you down
2. **Stage changes** - `git add .`
3. **Pre-commit runs** - Automatically formats and lints staged files
4. **Commit** - `git commit -m "message"`
5. **Push** - `git push` (triggers pre-push full scan)

### 🚨 If Hooks Fail

**Pre-commit fails:**
```bash
# Fix staged files and try again
npm run format
git add .
git commit -m "message"
```

**Pre-push fails:**
```bash
# Fix all issues and try again
npm run pre-push
git add .
git commit -m "fix: address lint/security issues"
git push
```

### 🔧 Manual Hook Setup

If hooks aren't working:

```bash
# Install dependencies
npm install

# Setup Husky
npx husky install

# Make hooks executable
chmod +x .husky/pre-commit
chmod +x .husky/pre-push
```

### 🎯 Benefits

- **Fast editing** - No lag from real-time checks
- **Consistent code** - Hooks enforce standards
- **Security** - Automated vulnerability scanning
- **Team quality** - Everyone follows same standards
- **CI/CD ready** - Same checks run in pipelines

### 🔍 Troubleshooting

**Hooks not running:**
```bash
# Check if Husky is installed
ls -la .husky/

# Reinstall if needed
npm run prepare
```

**Performance still slow:**
- Check VS Code extensions
- Disable heavy extensions temporarily
- Use the provided `.vscode/settings.json`
