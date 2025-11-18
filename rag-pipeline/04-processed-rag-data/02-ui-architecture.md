# Portfolio UI Architecture Documentation

## Overview

The Portfolio UI is a modern React-based single-page application (SPA) built with **Vite**, **TypeScript**, **Tailwind CSS**, and **Material-UI**. It serves as the frontend for the Sheyla AI assistant—a RAG-powered chatbot that provides intelligent responses about Jimmie Coleman's DevSecOps and AI/ML expertise.

**Key Characteristics:**
- Modern React 18 with TypeScript type safety
- Vite-powered build system with HMR (Hot Module Replacement)
- Tailwind CSS v4 for styling with custom color palettes
- Material-UI components for polished UI elements
- Real-time chat interface with streaming response handling
- Responsive design optimized for desktop and mobile
- Production deployment via Docker + Nginx
- Playwright E2E testing suite

**Tech Stack Summary:**
- **Runtime:** Node.js (18-Alpine for Docker)
- **Framework:** React 18.2.0
- **Build Tool:** Vite 5.1.0
- **Language:** TypeScript 4.5+ (ES2020 target)
- **Styling:** Tailwind CSS 4.1.12 + PostCSS
- **UI Library:** Material-UI (Emotion-based)
- **Testing:** Playwright (E2E automation)
- **Package Manager:** npm with lock file

---

## Project Structure

### Directory Layout

```
ui/
├── src/                          # Source code
│   ├── main.jsx                 # React root entry point
│   ├── App.jsx                  # Root component
│   ├── index.css                # Global Tailwind imports
│   ├── debug.css                # Debug mode styles
│   ├── debugToggle.ts           # Debug utility
│   ├── components/
│   │   ├── ChatBoxFixed.tsx      # Main chat interface (core)
│   │   ├── ChatPanel.tsx         # Chat container with health check
│   │   └── Projects.tsx          # Projects & skills showcase
│   ├── pages/
│   │   └── Landing.jsx           # Main landing page (layout)
│   └── lib/
│       └── api.ts               # API client & type definitions
│
├── public/                       # Static assets
│   ├── avatar.jpg              # Avatar image
│   ├── intro.mp3               # Intro sound
│   └── avatars/                # Avatar variants
│
├── tests/                        # Playwright E2E tests
│   ├── global-setup.ts         # Test infrastructure setup
│   ├── utils.ts                # Test utilities
│   ├── ui-chat.spec.ts         # Chat interface tests
│   ├── ui-clean.spec.ts        # Basic UI tests
│   ├── api.spec.ts             # API integration tests
│   └── portfolio-e2e.spec.ts   # Full portfolio tests
│
├── index.html                   # HTML entry point
├── vite.config.js              # Vite configuration
├── tsconfig.json               # TypeScript compiler options
├── tailwind.config.js          # Tailwind theme customization
├── postcss.config.js           # PostCSS configuration
├── eslint.config.js            # ESLint rules
├── .prettierrc                 # Code formatting rules
├── playwright.config.ts        # Playwright configuration
├── Dockerfile                  # Multi-stage production build
├── package.json                # Dependencies & scripts
├── components.json             # shadcn/ui configuration
└── .env.example                # Environment template
```

### Key Directories Explained

**`src/`** - Application source code with clear separation of concerns:
- Components are modular and reusable
- Pages handle top-level routing/layout
- Lib contains API client logic and utilities

**`tests/`** - Playwright-based E2E testing:
- Global setup for Kubernetes port-forwarding
- Utilities for selecting elements via `data-dev` attributes
- Multiple test suites covering different aspects

**Configuration Files** - Build and tooling setup:
- `vite.config.js` - Dev server, API proxy, build optimization
- `tsconfig.json` - Strict type checking enabled
- `tailwind.config.js` - Custom color palette (Jade, Crystal, Gold)
- `postcss.config.js` - Tailwind CSS processing

---

## React Component Structure

### Component Hierarchy

```
App
└── Landing
    ├── Header (hardcoded intro)
    ├── Main Content Grid (2 columns)
    │   ├── Left Column
    │   │   ├── Welcome Section
    │   │   │   └── (Professional Overview - hardcoded)
    │   │   └── Chat Section
    │   │       └── ChatPanel
    │   │           └── ChatBoxFixed
    │   │               ├── Message Display Area
    │   │               ├── Quick Prompts
    │   │               ├── Input Form
    │   │               └── Connection Status
    │   └── Right Column
    │       ├── Projects Section
    │       │   └── Projects
    │       │       ├── ProjectCard (multiple)
    │       │       ├── CategorySection (multiple)
    │       │       └── CategorySection > ToolItem
    │       └── Platform Metrics
    └── Background Effects
```

### Component Responsibilities

#### **App.jsx** (Root Component)
- Minimal wrapper component
- Passes `Landing` as the main page
- File: 6 lines of code

```jsx
import Landing from './pages/Landing.jsx';

export default function App() {
  return <Landing />;
}
```

**Role:** Simple app router/entry point.

---

#### **Landing.jsx** (Main Layout Page)
- **Lines:** 200
- **Purpose:** Full-page layout composition with two-column design
- **Content:**
  - Header section with profile info (hardcoded: "Jimmie Coleman")
  - Social links (LinkedIn, GitHub)
  - Two-column grid layout:
    - **Left:** Welcome card + Chat section
    - **Right:** Projects card + Platform metrics card
  - Background gradient effects (decorative blobs)

**Key Features:**
- Uses Tailwind's `grid lg:grid-cols-2` for responsive 2-column layout
- Consistent styling with `bg-snow/5 backdrop-blur-sm` cards
- Custom color classes: `text-gojo-primary`, `text-gojo-secondary`, `text-crystal-400`
- Professional overview hardcoded with bullet points
- Platform metrics display (Deploy time, CI/CD time, etc.)

**Structure:**
```jsx
<div className="min-h-screen bg-gradient-to-br from-ink via-ink to-crystal-900">
  {/* Header */}
  {/* Main Content: Grid with 2 columns */}
  {/* Left: Welcome + Chat */}
  {/* Right: Projects + Metrics */}
  {/* Background Effects */}
</div>
```

---

#### **ChatPanel.tsx** (Chat Container)
- **Lines:** 35
- **Purpose:** Wrapper for chat interface with backend health monitoring
- **State:**
  ```typescript
  health: {
    llm_model?: string;
    llm_provider?: string;
    rag_namespace?: string;
    status?: string;
  }
  ```

**Lifecycle:**
- On mount: Fetches `/health` endpoint to verify backend connectivity
- Maps backend response to expected format
- Renders `ChatBoxFixed` component inside

**Key Method:**
```typescript
useEffect(() => {
  fetch(`${API_BASE}/health`)
    .then(r => r.json())
    .then(data => {
      setHealth({
        llm_model: data.model || 'gpt-4o-mini',
        llm_provider: 'openai',
        rag_namespace: 'portfolio',
        status: data.status,
      });
    })
    .catch(console.error);
}, []);
```

---

#### **ChatBoxFixed.tsx** (Core Chat Interface)
- **Lines:** 202
- **Purpose:** Main chat component with message display, input form, and quick prompts
- **This is the primary user interaction point for the AI assistant**

**State Management:**
```typescript
const [message, setMessage] = useState('');          // Current input
const [messages, setMessages] = useState<ChatMessage[]>([]); // Message history
const [loading, setLoading] = useState(false);       // Request in-flight
const [error, setError] = useState<string | null>(null); // Error display
```

**Type Definitions:**
```typescript
interface ChatMessage {
  id: string;                    // Unique identifier (timestamp-based)
  text: string;                  // Message content
  sender: 'user' | 'sheyla';     // Message origin
  timestamp: Date;               // When message was created
}
```

**Core Features:**

1. **Message Sending:**
   ```typescript
   const sendMessage = async (text: string) => {
     // 1. Add user message to UI
     // 2. Clear input field
     // 3. POST /api/chat with message
     // 4. Handle response and add assistant message
     // 5. Handle errors gracefully
   }
   ```

2. **API Integration:**
   - Endpoint: `POST ${API_BASE}/api/chat`
   - Request body:
     ```json
     {
       "message": "user's question",
       "audience_type": "general"
     }
     ```
   - Response mapping (handles multiple field names):
     ```javascript
     data.answer || data.response || "I'm having trouble..."
     ```

3. **Quick Prompts:**
   - Hardcoded suggestions:
     - "Tell me about Jimmie's DevSecOps experience"
     - "What is LinkOps AI-BOX?"
     - "What technologies does Jimmie use?"
     - "How was the CI/CD pipeline built?"
     - "What security tools were implemented?"
   - Clicking a prompt sends it via `sendMessage()`

4. **UI Sections:**
   - **Message Display:** Scrollable area with max-height constraint
   - **Loading State:** Animated spinner with "Sheyla is thinking..." text
   - **Error Display:** Red alert box showing error messages
   - **Input Form:** Text input with "Ask" button
   - **Connection Status:** Backend URL and status indicator

**Styling Details:**
- User messages: Right-aligned with blue background (`bg-blue-600`)
- Assistant messages: Left-aligned with gray background (`bg-gray-100`)
- Messages have rounded corners with `rounded-lg`
- Max width: `max-w-xs lg:max-w-md` (responsive)
- Timestamp shown in `text-xs opacity-70`

**Error Handling:**
- Try-catch wrapper around fetch
- HTTP error checking: `if (!response.ok)`
- JSON parsing error fallback: `catch(() => ({ detail: 'Unknown error' }))`
- User-friendly error messages in chat

**Loading State:**
- Disables input and quick prompts while loading
- Shows spinning indicator animation
- Sets `disabled` class on buttons to visual feedback

---

#### **Projects.tsx** (Skills & Projects Showcase)
- **Lines:** 356
- **Purpose:** Display featured projects, tool categories, and certifications
- **No API calls** - All data is hardcoded

**State Management:**
```typescript
const [selectedCategory, setSelectedCategory] = useState<CategoryKey | null>(null);
const [selectedProject, setSelectedProject] = useState<ProjectKey | null>('gpcopilot');
```

**Data Structure:**

**Featured Projects:**
```typescript
type ProjectKey = 'gpcopilot' | 'interview' | 'jade';

const FEATURED_PROJECTS: Record<ProjectKey, Project> = {
  gpcopilot: {
    title: 'GP-Copilot - AI Security Automation',
    description: '6-phase consulting workflow with 20+ integrated scanners',
    status: 'Production',
    icon: '🔒',
    highlights: [...],
    repoUrl?: string,
  },
  // ... more projects
}
```

**Tool Categories:**
```typescript
type CategoryKey = 'languages' | 'aiml' | 'cloud' | 'security' | 'devops';

const TOOL_CATEGORIES: Record<CategoryKey, ToolCategory> = {
  languages: {
    title: 'Languages & Frameworks',
    icon: '💻',
    tools: [
      { name: 'Python', description: '...', level: 'Expert' },
      // ... more tools
    ],
  },
  // ... more categories
}
```

**Sub-Components:**

1. **ProjectCard** - Individual project display with expandable details
   - Props: `{ project, projectKey, isSelected, onToggle }`
   - Shows title, description, status
   - Expands to show highlights and repo link
   - Colors: `bg-crystal-500/20 border-crystal-500/30` when selected

2. **CategorySection** - Collapsible tool category
   - Props: `{ category, categoryKey, isSelected, onToggle }`
   - Shows category title and tool count
   - Expands to list all tools with difficulty badges

3. **ToolItem** - Individual tool entry
   - Props: `{ tool }`
   - Shows name, description, and proficiency level
   - Level-based styling via `useMemo`:
     - Expert: `bg-crystal-500/20 text-crystal-300`
     - Advanced: `bg-gold-500/20 text-gold-300`
     - Intermediate: `bg-jade-500/20 text-jade-300`

**Features:**
- Certifications banner at top
- Toggle behavior using `prev === key ? null : key` pattern
- Two-column tool grid (responsive)
- Best practices section at bottom
- All styling uses custom Tailwind colors

---

## State Management

### Patterns Used

**1. Local Component State (Preferred)**
- Uses React hooks: `useState()`, `useEffect()`, `useMemo()`
- No external state management library (Redux/Zustand)
- State is local to components and lifted where needed

**2. ChatBoxFixed State Example:**
```typescript
// Message state
const [message, setMessage] = useState('');
const [messages, setMessages] = useState<ChatMessage[]>([]);

// UI state
const [loading, setLoading] = useState(false);
const [error, setError] = useState<string | null>(null);
```

**3. Landing/Page Level State:**
- Landing page has no state (all hardcoded)
- Projects component manages its own expand/collapse state

**4. No Context API or Providers:**
- Unnecessary for current scope
- Could be added if global theme switching or user preferences needed

### State Flow

```
ChatBoxFixed
├── message (input value)
├── messages (history array)
├── loading (request state)
└── error (error state)
     ↓ (on message send)
   API Call
     ↓ (response received)
   Update messages array
```

---

## API Integration

### API Client (`src/lib/api.ts`)

**Constants:**
```typescript
export const API_BASE = import.meta.env.VITE_API_BASE_URL || '';
```

**Type Definitions:**
```typescript
export type ChatRequest = {
  message: string;
  namespace?: string;
  k?: number;
  filters?: Record<string, unknown>;
};

export type Citation = {
  text: string;
  score: number;
  metadata?: Record<string, unknown>;
};

export type ChatResponse = {
  answer: string;
  citations: Citation[];
  model: string;
};
```

**Primary Function:**
```typescript
export async function chat(
  req: ChatRequest,
  signal?: AbortSignal
): Promise<ChatResponse>
```

**Implementation Details:**
- Maps frontend request to backend format (adds `audience_type: 'general'`)
- Handles multiple response field names: `answer`, `response`, `text_response`
- Provides fallback message on error
- Supports abort signals for cancellation
- Uses `safeJson()` utility for error-safe JSON parsing

### API Endpoints Used

**1. Health Check (ChatPanel.tsx)**
- **Endpoint:** `GET /health`
- **Used For:** Verify backend availability and model info
- **Response:**
  ```json
  {
    "status": "ok|error",
    "model": "model-name"
  }
  ```

**2. Chat Endpoint (ChatBoxFixed.tsx)**
- **Endpoint:** `POST /api/chat`
- **Request:**
  ```json
  {
    "message": "user question",
    "audience_type": "general"
  }
  ```
- **Response:**
  ```json
  {
    "answer": "assistant response",
    "response": "alt field name",
    "text_response": "another alt field name"
  }
  ```

### Network Configuration

**Vite Proxy (Development):**
```javascript
// vite.config.js
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8000',
      changeOrigin: true,
    },
  },
},
```

**Production:**
- API_BASE is set via `VITE_API_BASE_URL` environment variable
- Absolute URLs used in production (no relative paths)

**Error Handling Strategy:**
- HTTP status checks: `if (!response.ok)`
- JSON parsing with fallback: `response.json().catch(() => ({ detail: 'Unknown error' }))`
- User-friendly error messages: "Sorry—something went wrong reaching my brain."

---

## Styling System

### Tailwind CSS v4

**Configuration File:** `tailwind.config.js`

**Custom Color Palettes:**

1. **Jade Palette** (Primary brand color)
   - Default: `#00A86B` (emerald green)
   - Shades: 50, 100, 200, ..., 900
   - Used for: Brand accents, highlights
   - Example classes: `text-jade-400`, `bg-jade-500/20`

2. **Crystal Palette** (Secondary, electric blue)
   - Default: `#0ea5e9` (sky blue)
   - Shades: 50, 100, 200, ..., 900
   - Used for: Links, interactive elements
   - Example classes: `text-crystal-400`, `bg-crystal-500/20`

3. **Gold Palette** (Tertiary, warm accent)
   - Default: `#f59e0b` (amber)
   - Shades: 50, 100, 200, ..., 900
   - Used for: Advanced level badges, secondary accents
   - Example classes: `text-gold-300`, `bg-gold-500/20`

4. **Semantic Colors**
   - `ink`: `#0A0A0A` (almost black, for backgrounds)
   - `snow`: `#FAFAFA` (almost white, for light elements)
   - `text-primary`: `#FFFFFF` (primary text)
   - `text-secondary`: `#B3B3B3` (secondary text)

5. **Gojo Palette** (Character theme)
   - `gojo-primary`: `#FFFFFF` (primary text)
   - `gojo-secondary`: `#0ea5e9` (secondary text, Crystal blue)
   - `gojo-accent`: `#f59e0b` (accent, Gold)

**Key Utilities:**
```css
.jade-glow {
  box-shadow: 0 0 16px rgba(0, 168, 107, 0.35);
}

.btn-brand {
  @apply bg-[#00A36C] text-white hover:bg-[#07885a] rounded-xl px-3 py-2;
}

.chip-brand {
  @apply bg-[#e6faf2] text-[#0b6d4a] rounded-lg px-2 py-1 text-xs;
}
```

**Background Images:**
```javascript
backgroundImage: {
  'ink-gradient': 'radial-gradient(600px 300px at 10% 10%, rgba(0,168,107,0.12), transparent 60%)',
},
```

### PostCSS Pipeline

**File:** `postcss.config.js`
```javascript
plugins: [
  tailwind(),    // Tailwind CSS processing
  autoprefixer,  // Add vendor prefixes
],
```

**Processing Order:**
1. Tailwind CSS processes `@import 'tailwindcss'`
2. Autoprefixer adds `-webkit-`, `-moz-` prefixes
3. Output: Cross-browser compatible CSS

### Global Styles (`src/index.css`)

```css
@import 'tailwindcss';
@import './debug.css';

/* Debug mode activation */
body.debug [data-dev] {
  outline: 1px dashed magenta;
}

/* Custom utilities */
@layer utilities {
  .jade-glow {
    box-shadow: 0 0 16px rgba(0, 168, 107, 0.35);
  }
}
```

### Debug Styles (`src/debug.css`)

**Purpose:** Visual debugging of component boundaries

**Features:**
- Outlines components with dashed magenta border
- Shows component name as label
- Toggled by: `document.body.classList.toggle('debug')`
- Utility function: `toggleDebug()` in `debugToggle.ts`

```css
body.debug [data-dev]::before {
  content: attr(data-dev);
  position: absolute;
  background: magenta;
  color: white;
  z-index: 9999;
}
```

### Material-UI Integration

**Theme Configuration** (`src/main.jsx`):
```javascript
const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: { main: '#8b5cf6' },      // Purple
    secondary: { main: '#fbbf24' },    // Gold
    background: {
      default: '#0f172a',
      paper: 'rgba(255, 255, 255, 0.02)',
    },
  },
  components: {
    MuiCard: { /* custom styles */ },
    MuiButton: { /* custom styles */ },
  },
});
```

**Provider:**
```jsx
<ThemeProvider theme={theme}>
  <CssBaseline />
  <App />
</ThemeProvider>
```

**Note:** MUI is configured but ChatBoxFixed uses Tailwind CSS, not MUI components (lightweight approach).

---

## Build Configuration

### Vite Configuration (`vite.config.js`)

```javascript
export default defineConfig({
  plugins: [react()],
  
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  
  server: {
    host: true,                    // Listen on 0.0.0.0
    port: 5173,
    strictPort: true,
    allowedHosts: 'all',
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
  
  preview: {
    port: 5173,
    strictPort: true,
  },
});
```

**Key Settings:**
- **React Plugin:** Enables JSX transformation and HMR
- **Path Alias:** `@/` maps to `./src/`
- **Dev Port:** 5173 (Vite default)
- **API Proxy:** Proxies `/api/*` to localhost:8000
- **Preview Mode:** Can serve built dist/ for local testing

### TypeScript Configuration (`tsconfig.json`)

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    
    /* Strict Mode */
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    
    /* Path Mapping */
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

**Strict Checks Enabled:**
- `strict: true` - All strict type-checking options
- `noUnusedLocals: true` - Error on unused variables
- `noUnusedParameters: true` - Error on unused function params
- Ensures code quality and catches bugs early

### Build Scripts (`package.json`)

```json
{
  "scripts": {
    "dev": "vite",                    // Start dev server
    "build": "vite build",            // Production build
    "lint": "eslint . --report-unused-disable-directives --max-warnings 0",
    "format": "prettier --write .",   // Auto-format code
    "preview": "vite preview",        // Preview built dist/
    "test:e2e": "playwright test",    // Run all E2E tests
    "test:e2e:ui": "playwright test ui-chat.spec.ts",
    "test:e2e:api": "playwright test api.spec.ts"
  }
}
```

### Production Build (`Dockerfile`)

```dockerfile
# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

ARG VITE_API_BASE_URL=""
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

COPY ui/package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit

COPY ui/ .
RUN npm run build

# Stage 2: Serve
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html

RUN echo 'server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Build Process:**
1. Node.js 18-Alpine: Install deps, build with Vite
2. Nginx Alpine: Copy dist/ to `/usr/share/nginx/html`
3. SPA routing: `try_files $uri $uri/ /index.html` for client-side routing

**Build Arguments:**
- `VITE_API_BASE_URL`: Set at build time for production API URL
- Environment variable substitution into Vite

### Code Quality Tools

**ESLint Configuration** (`eslint.config.js`):
```javascript
rules: {
  ...js.configs.recommended.rules,
  ...react.configs.recommended.rules,
  ...react.configs['jsx-runtime'].rules,
  ...reactHooks.configs.recommended.rules,
  'react/jsx-no-target-blank': 'off',
  'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
}
```

**Prettier Configuration** (`.prettierrc`):
```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 80,
  "tabWidth": 2,
  "useTabs": false,
  "bracketSpacing": true,
  "arrowParens": "avoid",
  "endOfLine": "lf"
}
```

---

## Chat Interface Implementation

### Message Flow Diagram

```
User Types Message
         ↓
[User clicks "Ask" or presses Enter]
         ↓
handleSubmit() → sendMessage(messageText)
         ↓
[Add user message to state]
[Clear input field]
[Set loading = true]
         ↓
POST /api/chat
{
  "message": "user text",
  "audience_type": "general"
}
         ↓
[Wait for response]
         ↓
Response Received
         ↓
Parse response → data.answer || data.response || fallback
         ↓
[Add assistant message to state]
[Set loading = false]
         ↓
[Display message in chat]
```

### Message Display Logic

**Empty State:**
```jsx
{messages.length === 0 && (
  <div className="text-center text-gray-500 py-8">
    <p>👋 Hi! I'm Sheyla, Jimmie's AI assistant.</p>
    <p className="text-sm mt-1">Ask me about his DevSecOps or AI/ML work...</p>
  </div>
)}
```

**Message Rendering:**
```jsx
{messages.map(msg => (
  <div key={msg.id} className={`flex ${msg.sender === 'user' ? 'justify-end' : 'justify-start'}`}>
    <div className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
      msg.sender === 'user'
        ? 'bg-blue-600 text-white'
        : 'bg-gray-100 text-gray-800'
    }`}>
      <p className="text-sm whitespace-pre-wrap">{msg.text}</p>
      <p className="text-xs opacity-70 mt-1">
        {msg.timestamp.toLocaleTimeString()}
      </p>
    </div>
  </div>
))}
```

**Key Styling:**
- User messages: Right-aligned (`justify-end`), blue background
- Assistant messages: Left-aligned (`justify-start`), gray background
- Timestamp shown in smaller text with reduced opacity
- Text wrapping: `whitespace-pre-wrap` preserves line breaks
- Max width responsive: `max-w-xs lg:max-w-md`

### Quick Prompts

**Data:**
```typescript
const quickPrompts = [
  "Tell me about Jimmie's DevSecOps experience",
  'What is LinkOps AI-BOX?',
  'What technologies does Jimmie use?',
  'How was the CI/CD pipeline built?',
  'What security tools were implemented?',
];
```

**Rendering:**
```jsx
{quickPrompts.slice(0, 3).map((prompt, index) => (
  <button
    key={index}
    onClick={() => handleQuickPrompt(prompt)}
    disabled={loading}
    className="text-xs bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-1 rounded-full transition-colors disabled:opacity-50"
  >
    {prompt.length > 25 ? prompt.substring(0, 25) + '...' : prompt}
  </button>
))}
```

**Features:**
- Only shows first 3 prompts (`slice(0, 3)`)
- Truncates long text with ellipsis
- Disabled during loading
- Button styling: gray with hover effect

### Input Form

```jsx
<form onSubmit={handleSubmit} className="space-y-2">
  <div className="flex space-x-2">
    <input
      type="text"
      value={message}
      onChange={e => setMessage(e.target.value)}
      placeholder="Ask about my AI/ML or DevSecOps work..."
      disabled={loading}
      className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
    />
    <button
      type="submit"
      disabled={loading || !message.trim()}
      className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
    >
      Ask
    </button>
  </div>
</form>
```

**Features:**
- Input text controlled by state
- Placeholder text guides users
- Form submission on Enter or button click
- Submit button disabled when:
  - Loading (`loading === true`)
  - Input empty (`!message.trim()`)
- Focus ring styling for accessibility

---

## Testing Strategy

### Playwright E2E Tests

**Configuration** (`playwright.config.ts`):
```typescript
export default defineConfig({
  testDir: './tests',
  timeout: 90_000,
  expect: { timeout: 30_000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  retries: process.env.CI ? 2 : 0,
  globalSetup: './tests/global-setup.ts',
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
});
```

**Key Options:**
- Test timeout: 90 seconds
- Assertion timeout: 30 seconds
- Reports: CLI list + HTML report
- CI retries: 2 attempts on failure
- Trace retention: Only save on failure (cost optimization)

### Test Files

**1. `ui-chat.spec.ts` - Chat Interface Test**
```typescript
test('Chat endpoint responds via UI', async ({ page }) => {
  await page.goto('/');
  await page
    .getByPlaceholder('Ask about my AI/ML or DevSecOps work…')
    .fill('Tell me about the Jade project');
  await page.getByRole('button', { name: 'Ask' }).click();

  await expect(page.locator("[data-dev='chat-box']")).toBeVisible();
  await expect(page.getByText(/Jade|ZRS|RAG/i)).toBeVisible({ timeout: 20000 });
});
```

**Purpose:** Verify chat input, submission, and response display

**Steps:**
1. Navigate to home page
2. Fill input with "Tell me about the Jade project"
3. Click Ask button
4. Wait for response (20s timeout)
5. Assert chat box visible and response contains keywords

**2. `global-setup.ts` - Test Infrastructure**
```typescript
export default async function globalSetup(_config: FullConfig) {
  if (!process.env.API_URL) {
    pf = spawn(
      'kubectl',
      ['-n', 'portfolio', 'port-forward', 'svc/portfolio-api', '8001:80'],
      { stdio: 'inherit' }
    );
    process.env.API_URL = 'http://localhost:8001';
    await wait(1500);
  }
}
```

**Purpose:** Set up Kubernetes port-forward for API access

**Features:**
- Auto-forwards K8s service if not already running
- Sets API_URL environment variable
- Waits 1.5s for port-forward to establish

**3. `utils.ts` - Test Helpers**
```typescript
export function byDev(page: Page, name: string): Locator {
  return page.locator(`[data-dev="${name}"]`);
}

export async function hookConsoleAndNetwork(page: Page) {
  page.on('console', msg => { /* log messages */ });
  page.on('pageerror', err => { /* log errors */ });
  page.on('requestfailed', req => { /* log failures */ });
}
```

**Purpose:** Reusable test utilities

**Utilities:**
- `byDev()` - Select elements by data-dev attribute
- `hookConsoleAndNetwork()` - Monitor browser console, errors, network

### Testing Best Practices

**1. Element Selection Strategy:**
- Primary: `data-dev` attributes (semantic, stable)
- Secondary: Accessibility role queries
- Fallback: Placeholder text, visible text

**2. Wait Strategies:**
- Explicit timeouts: `{ timeout: 20000 }` for API calls
- Built-in retries: Playwright retries assertions
- Global setup: Ensures preconditions ready

**3. CI/CD Integration:**
- Retries: 2x on CI, 0x locally
- Screenshots/Video: Only on failure
- Traces: Retained on failure for debugging

**4. Data Attributes:**
- Used throughout codebase: `data-dev="component-name"`
- Enables reliable E2E testing without coupling to implementation

---

## Deployment

### Local Development

**Start Dev Server:**
```bash
cd ui
npm install
npm run dev
```

**Access:** `http://localhost:5173`

**API Proxy:** `/api` calls routed to `http://localhost:8000` (via Vite config)

**Dev Features:**
- Hot Module Replacement (HMR): Changes refresh instantly
- Source maps: Debugging with original TypeScript
- Console errors: Clear feedback in browser DevTools
- Network debugging: Chrome DevTools network tab

### Production Build

**Build Process:**
```bash
npm run build
```

**Output:** `dist/` directory with minified static files

**Optimization:**
- Code splitting: Components bundled efficiently
- Tree-shaking: Unused code removed
- Asset optimization: Images, fonts compressed
- Source map generation: Optional for debugging

### Docker Deployment

**Build Image:**
```bash
docker build -t portfolio-ui:latest .
```

**Build Arguments:**
```bash
docker build \
  --build-arg VITE_API_BASE_URL="https://api.example.com" \
  -t portfolio-ui:latest \
  .
```

**Run Container:**
```bash
docker run -p 80:80 portfolio-ui:latest
```

**Container Details:**
- Base image: `nginx:alpine` (lightweight, ~12MB)
- Port: 80 (HTTP)
- SPA routing configured: All routes serve `index.html`
- No volume mounting needed (static files embedded)

### Kubernetes Deployment

**Example Manifest:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio-ui
spec:
  replicas: 2
  selector:
    matchLabels:
      app: portfolio-ui
  template:
    metadata:
      labels:
        app: portfolio-ui
    spec:
      containers:
      - name: ui
        image: portfolio-ui:latest
        ports:
        - containerPort: 80
        env:
        - name: VITE_API_BASE_URL
          value: "https://api.linksmlm.com"
```

**Service Exposure:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: portfolio-ui
spec:
  selector:
    app: portfolio-ui
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

### Environment Variables

**Development:**
- `VITE_API_BASE_URL`: Set to `http://localhost:8000` or empty (uses relative URLs)

**Production:**
- `VITE_API_BASE_URL`: Set to production API domain (e.g., `https://api.linksmlm.com`)

**Build-time Substitution:**
- Vite reads `import.meta.env.VITE_*` variables at build time
- Values must be set before `npm run build`

---

## Data Attributes for Testing

### Component Data Attributes

The UI uses `data-dev` attributes throughout for reliable E2E testing:

**Landing Page:**
```jsx
<div data-dev="landing"> {/* Full page */}
<div data-dev="projects"> {/* Projects section */}
```

**ChatBoxFixed:**
```jsx
<div data-dev="chat-box"> {/* Would be added if needed */}
```

**Debug Mode:**
```javascript
// Toggle debug visualization
document.body.classList.toggle('debug');

// Shows component boundaries and names
// Useful for debugging layout issues
```

---

## Performance Optimizations

### 1. Code Splitting
- Vite automatically splits code by route
- Reduces initial bundle size

### 2. CSS Optimization
- Tailwind v4: Only includes used CSS classes
- PostCSS: Autoprefixer adds vendor prefixes efficiently

### 3. Asset Caching
- Static files served with cache headers (Nginx config)
- SPA app shell cached, content updates on demand

### 4. Lazy Loading
- Components not implemented yet, but could add with React.lazy()

### 5. Image Optimization
- Public assets: Optimized PNG/JPG files
- Served from static directory

---

## Accessibility Considerations

### Current Implementation

**1. Semantic HTML:**
- Form elements: `<form>`, `<input>`, `<button>`
- Headings: `<h1>`, `<h2>`, `<h3>`, `<h4>`
- Lists: Not used yet

**2. ARIA Attributes:**
- Not explicitly used (could be added)
- Role queries work via implicit roles

**3. Keyboard Navigation:**
- Input field: Tab to focus
- Buttons: Tab to focus, Enter/Space to activate
- Form submission: Enter key supported

**4. Color Contrast:**
- Text colors meet WCAG AA standards
- Dark backgrounds with light text
- Blue and gray message bubbles have sufficient contrast

**5. Text Sizing:**
- Responsive font sizes
- Uses `text-xs`, `text-sm`, `text-base` Tailwind classes
- Readable on all device sizes

### Potential Improvements

1. Add `aria-label` to icon buttons
2. Add `aria-live="polite"` to message container (screen reader updates)
3. Add `aria-busy="true"` to loading state
4. Implement focus management on chat message receipt
5. Add skip links for navigation

---

## Security Practices

### 1. Input Sanitization
- Chat messages accepted as plain text
- No HTML/Script injection risk (React auto-escapes)
- Backend responsible for response validation

### 2. API Communication
- Uses HTTPS in production (enforced at deployment level)
- No credentials stored in localStorage
- CORS headers managed by backend

### 3. Content Security Policy
- Should be configured at Nginx/Cloudflare level
- Example header: `script-src 'self' 'unsafe-inline' cdn.example.com`

### 4. Environment Secrets
- No secrets in code
- API base URL set via build argument
- Local dev uses `.env.example` template (never committed)

### 5. Dependency Management
- `package-lock.json` pinned versions
- Regular npm updates
- No high-severity vulnerabilities (ideally)

---

## Browser Support

### Target Browsers
- Modern browsers (ES2020 JavaScript)
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

### Build Output
- ES2020 modules in `dist/`
- Polyfills: Not included (for modern browsers)
- Could add `@vitejs/plugin-legacy` for older browser support

---

## Development Workflow

### Getting Started

```bash
# 1. Install dependencies
npm install

# 2. Start dev server
npm run dev

# 3. Open browser
# Navigate to http://localhost:5173

# 4. API proxy configured
# /api calls automatically forwarded to http://localhost:8000
```

### Making Changes

**React Components:**
```bash
# Edit src/components/ChatBoxFixed.tsx
# Save file → Vite HMR updates browser automatically
# No full page reload needed
```

**Styles:**
```bash
# Edit tailwind.config.js or component classNames
# Changes reflected instantly
# Unused Tailwind classes pruned automatically
```

**API Integration:**
```bash
# Edit src/lib/api.ts
# Update types if backend schema changes
# TypeScript catches errors before runtime
```

### Code Quality

```bash
# Format code
npm run format

# Lint (show issues)
npm run lint

# Both (fix where possible)
npm run lint -- --fix && npm run format
```

### Testing

```bash
# Run all E2E tests
npm run test:e2e

# Run specific test
npm run test:e2e:ui

# View HTML report
# Open playwright-report/index.html
```

---

## Common Tasks & Solutions

### Add a New Quick Prompt

**File:** `src/components/ChatBoxFixed.tsx`

**Current Quick Prompts:**
```typescript
const quickPrompts = [
  "Tell me about Jimmie's DevSecOps experience",
  'What is LinkOps AI-BOX?',
  'What technologies does Jimmie use?',
  'How was the CI/CD pipeline built?',
  'What security tools were implemented?',
];
```

**To Add:**
```typescript
const quickPrompts = [
  // ... existing
  'Tell me about your AWS certifications',  // Add new
];
```

### Change Chat Colors

**File:** `src/components/ChatBoxFixed.tsx`

**Current User Message Style:**
```jsx
? 'bg-blue-600 text-white'  // User: blue
: 'bg-gray-100 text-gray-800' // Assistant: gray
```

**Change To:**
```jsx
? 'bg-jade-600 text-white'  // User: jade green
: 'bg-crystal-100 text-crystal-800' // Assistant: crystal blue
```

### Update Brand Colors

**File:** `tailwind.config.js`

**Add/Modify in `colors` object:**
```javascript
custom: {
  50: '#yourcolor50',
  100: '#yourcolor100',
  // ...
  DEFAULT: '#yourcolordefault',
}
```

### Change API Endpoint

**Development:**
1. Edit `vite.config.js` proxy target
2. Restart dev server

**Production:**
1. Set `--build-arg VITE_API_BASE_URL="https://new-api.com"` in Docker build
2. Rebuild and redeploy

---

## Known Limitations & Future Improvements

### Current Limitations

1. **No Persistent Chat History**
   - Messages only in memory
   - Lost on page refresh
   - Could add localStorage or backend persistence

2. **No User Authentication**
   - No login/user identification
   - Could add Google Auth or custom auth

3. **No Response Streaming**
   - Waits for full response before displaying
   - Could implement Server-Sent Events (SSE) for real-time text streaming

4. **Limited Error Recovery**
   - Doesn't retry failed requests
   - Could add exponential backoff retry logic

5. **No Loading Indicators for Images**
   - Avatar and other images don't show loading state

### Potential Features

1. **Message Search**
   - Search past messages in current session
   - Client-side filtering

2. **Theme Switching**
   - Dark/Light mode toggle
   - Use React Context for theme state

3. **Message Export**
   - Download conversation as PDF or text
   - Share conversation link

4. **Typing Indicators**
   - Show when assistant is "typing"
   - Improve perceived responsiveness

5. **Response Citations**
   - Display source documents used for answer
   - Integrate backend `citations` field

---

## Summary

The Portfolio UI is a modern, production-ready React application showcasing:

- **Clean Architecture:** Modular components with single responsibilities
- **Type Safety:** Full TypeScript with strict checking
- **Modern Tooling:** Vite, Tailwind CSS, Material-UI
- **Testing:** Playwright E2E automation with Kubernetes integration
- **Styling:** Custom color palettes and responsive design
- **Deployment:** Docker multi-stage builds, Nginx serving, K8s ready
- **Performance:** Code splitting, CSS optimization, lazy loading ready

The core `ChatBoxFixed` component demonstrates professional chat UX patterns:
- Real-time message handling
- Loading states and error handling
- Quick prompt suggestions
- Connection status monitoring
- Responsive design

The architecture is scalable and maintainable, with clear patterns for adding new features like persistence, authentication, streaming responses, and advanced RAG features from the backend.
