
export enum ViewType {
  HOME = 'HOME',
  LIBRARY = 'LIBRARY',
  TASKS = 'TASKS',
  INSIGHTS = 'INSIGHTS',
  SETTINGS = 'SETTINGS',
  RECORDING = 'RECORDING',
  SESSION_DETAIL = 'SESSION_DETAIL',
  CHAT = 'CHAT',
  PROFILE = 'PROFILE',
  COURSE_PROFILE = 'COURSE_PROFILE'
}

export enum Priority {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high'
}

export interface AcademicListItem {
  id: string;
  text: string;
  date: string | null;
  completed: boolean;
}

export interface TranscriptSegment {
  id: string;
  startSec: number;
  endSec: number;
  text: string;
  confidence: number;
}

export interface KeyTerm {
  term: string;
  definition: string;
  confidence: number;
  sourceSegments: string[];
  isUserCreated?: boolean;
  isEdited?: boolean;
  isPinned?: boolean;
  originalContent?: { term: string; definition: string };
}

export interface Flashcard {
  q: string;
  a: string;
  confidence: number;
  sourceSegments: string[];
  isUserCreated?: boolean;
  isEdited?: boolean;
  isPinned?: boolean;
  originalContent?: { q: string; a: string };
}

export interface PracticeQuestion {
  q: string;
  hint: string;
  sourceSegments: string[];
}

export interface ActionItem {
  id: string;
  text: string;
  dueDate: string | null;
  completed: boolean;
  confidence: number;
  sourceSegments: string[];
  priority?: Priority;
}

export interface Task {
  id: string;
  text: string;
  dueDate: string | null;
  completed: boolean;
  priority: Priority;
  sessionId?: string;
  courseId?: string;
  createdAt: string;
  isPinned?: boolean;
}

export interface TimelineEntry {
  startSec: number;
  endSec: number;
  title: string;
  sourceSegments: string[];
}

export interface Insights {
  summary: {
    text: string;
    confidence: number;
    sourceSegments: string[];
    isPinned?: boolean;
  };
  bullets: Array<{
    text: string;
    confidence: number;
    sourceSegments: string[];
  }>;
  notesOutline: Array<{
    heading: string;
    items: string[];
  }>;
  keyTerms: KeyTerm[];
  flashcards: Flashcard[];
  practiceQuestions: PracticeQuestion[];
  actionItems: ActionItem[];
  timeline: TimelineEntry[];
  generatedAt: string;
}

export interface Session {
  id: string;
  eventId: string; 
  title: string;
  date: string;
  audioUrl: string;
  duration: number;
  transcript: string;
  transcriptSegments: TranscriptSegment[];
  insights: Insights | null;
  status: 'recording' | 'processing' | 'ready' | 'error';
  isPinned?: boolean;
}

export interface Event {
  id: string;
  name: string;
  description: string;
  color: string;
  sessionIds: string[];
  createdAt: string;
  assignments?: AcademicListItem[];
  exams?: AcademicListItem[];
  highlights?: string[];
}

export interface MicConfig {
  deviceId: string;
  sampleRate: number;
  echoCancellation: boolean;
  autoGainControl: boolean;
  noiseSuppression: boolean;
}

export interface AppSettings {
  micConfig: MicConfig;
  offlineMode: boolean;
  recordingQuality: 'high' | 'medium' | 'low';
  notificationsEnabled: boolean;
  autoExport: boolean;
  theme: 'light' | 'dark' | 'system';
}

export interface UserProfile {
  name: string;
  email: string;
  avatar?: string;
  institution?: string;
  degree?: string;
  level?: string;
  major?: string;
  isLoggedIn: boolean;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'model';
  text: string;
  timestamp: string;
}
