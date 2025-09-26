# UI Components (`data-dev` Reference)

## Main Components

### TwoPanelHome  
**File**: `ui/src/components/TwoPanelHome.tsx`  
**Purpose**: Main layout with avatar panel and projects

#### Key Data-Dev Tags:
- `data-dev:content-area` - Main grid layout
- `data-dev:avatar-column` - Left panel container
- `data-dev:projects-panel` - Right panel container
- `data-dev:suggestion-chips` - Suggested questions area
- `data-dev:chat-interface` - Chat input/output section

#### State Management:
```typescript
const [q, setQ] = useState(''); // Chat input
const [a, setA] = useState(''); // Chat response  
const [busy, setBusy] = useState(false); // Loading state
```

### AvatarPanel
**Tag**: `data-dev:ui-avatar-panel`  
**File**: `ui/src/components/AvatarPanel.tsx`  
**Purpose**: Avatar upload, voice selection, and TTS controls

#### Key Data-Dev Tags:
- `data-dev:image-input` - File upload input
- `data-dev:image-preview` - Uploaded image display
- `data-dev:voice-select` - Voice style dropdown
- `data-dev:intro-button` - Play introduction TTS
- `data-dev:talk-button` - Create avatar video
- `data-dev:talk-video` - D-ID video player
- `data-dev:talk-status` - Generation progress text

#### Voice Integration:
```typescript
// data-dev:ui-voice-presets
const VOICE_PRESETS = [
  { id: "default", label: "Default Voice" },
  { id: "giancarlo", label: "Giancarlo Style" },
];
```

#### Avatar Workflow:
1. Upload image → `setImageUrl()`
2. Select voice → `setSelectedVoice()`  
3. Click "Make Avatar Talk" → POST `/api/avatar/talk`
4. Poll for completion → GET `/api/avatar/talk/{id}`
5. Display video when `result_url` ready

### ChatPanel
**Tag**: `data-dev:chat-panel`  
**File**: `ui/src/components/ChatPanel.tsx`  
**Purpose**: Simple chat interface

#### Key Data-Dev Tags:
- `data-dev:chat-input` - Message input field
- `data-dev:send-button` - Submit button  
- `data-dev:chat-answer` - Response display area

#### Chat Flow:
```typescript
// POST /api/chat with message
// Display response in chat-answer div
// Show error if request fails
```

### Projects Display
**Tag**: `data-dev:projects-list`  
**File**: `ui/src/components/Projects.tsx`  
**Purpose**: Static project descriptions

#### Project Tags:
- `data-dev:project-zrs` - ZRS Management project
- `data-dev:project-afterlife` - LinkOps Afterlife project  
- `data-dev:project-portfolio` - This portfolio project

## Intro Snippets

### Suggested Questions
**Tag**: `data-dev:ui-intro-snippets`  
**Location**: `TwoPanelHome.tsx`

```typescript
const suggestedQuestions = [
  "What AI/ML work are you focused on?",
  "Tell me about the Jade project", 
  "What's your current DevOps pipeline?",
  "How does your RAG system work?"
];
```

**Usage**: Click to auto-fill chat input and submit question

## Voice & Audio

### Voice Selection
**Tag**: `data-dev:voice-selection`  
**Purpose**: Choose voice style for TTS and avatar

**Options**:
- `default` - Uses `ELEVENLABS_DEFAULT_VOICE_ID` from env
- `giancarlo` - Giancarlo Esposito style (if voice ID configured)

### TTS Integration
**Endpoint**: `POST /api/voice/tts`  
**Payload**: `{text: string, voice_id?: string}`  
**Response**: `{url: string}` - Audio file URL

### Avatar Talk
**Endpoint**: `POST /api/avatar/talk`  
**Payload**: `{text: string, image_url: string, voice_id?: string}`  
**Response**: `{talk_id: string, status: string, result_url?: string}`

## Styling Conventions

### CSS Classes Used:
- `bg-jade` - Primary green accent
- `text-jade` - Green text color
- `border-jade` - Green borders
- `bg-ink` - Dark background
- `text-zinc-*` - Secondary text colors

### Component Structure:
```tsx
<div data-dev="component-name" className="styling-classes">
  <element data-dev="sub-element" />
  {/* Comments with data-dev context */}
</div>
```

## Error Handling

### UI Error States:
- Chat failures → Display "Sorry, chat failed" 
- Upload failures → Alert with error message
- Avatar generation → Show "Working..." during processing
- Network errors → Console logging via Playwright utils

### Loading States:
- `busy` state disables buttons during operations
- Loading text replaces button labels
- Spinners for long-running operations (avatar generation)