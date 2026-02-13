
import React, { useState, useEffect } from 'react';
import { ViewType, Session, Event } from './types';
import { appStore } from './store/appStore';
import { HomeIcon, NotebookIcon, SettingsIcon, MicIcon, SparkIcon, LightbulbIcon, CheckSquareIcon } from './components/Icons';
import HomeView from './views/HomeView';
import CoursesView from './views/CoursesView'; 
import TasksView from './views/TasksView';
import SettingsView from './views/SettingsView';
import RecordingView from './views/RecordingView';
import SessionDetailView from './views/SessionDetailView';
import CourseProfileView from './views/CourseProfileView';
import InsightsView from './views/InsightsView';
import ChatView from './views/ChatView';
import EventPicker from './components/EventPicker';

const App: React.FC = () => {
  const [activeView, setActiveView] = useState<ViewType>(ViewType.HOME);
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(null);
  const [selectedEventId, setSelectedEventId] = useState<string | null>(null);
  const [showEventPicker, setShowEventPicker] = useState(false);
  const [recordingEvent, setRecordingEvent] = useState<Event | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  
  const [sessions, setSessions] = useState(appStore.getSessions());
  const [events, setEvents] = useState(appStore.getEvents());

  useEffect(() => {
    const unsubscribe = appStore.subscribe(() => {
      setSessions(appStore.getSessions());
      setEvents(appStore.getEvents());
    });
    return unsubscribe;
  }, []);

  const handleRecordClick = () => setShowEventPicker(true);

  const startRecording = (event: Event) => {
    setRecordingEvent(event);
    setShowEventPicker(false);
    setIsRecording(true);
    setActiveView(ViewType.RECORDING);
  };

  const handleSessionSelect = (sessionId: string) => {
    setSelectedSessionId(sessionId);
    setActiveView(ViewType.SESSION_DETAIL);
  };

  const handleEventSelect = (eventId: string) => {
    setSelectedEventId(eventId);
    setActiveView(ViewType.COURSE_PROFILE);
  };

  const navigateTo = (view: ViewType) => setActiveView(view);

  const renderView = () => {
    if (isRecording && recordingEvent) {
      return (
        <RecordingView 
          event={recordingEvent} 
          onFinished={() => {
            setIsRecording(false);
            setRecordingEvent(null);
            setActiveView(ViewType.HOME);
          }} 
        />
      );
    }

    switch (activeView) {
      case ViewType.HOME:
        return <HomeView 
          sessions={sessions}
          events={events}
          onSessionSelect={handleSessionSelect} 
          onStartFastRecord={handleRecordClick} 
          onNavigate={navigateTo}
        />;
      case ViewType.LIBRARY:
        return <CoursesView 
          onSessionSelect={handleSessionSelect} 
          onEventSelect={handleEventSelect}
        />;
      case ViewType.COURSE_PROFILE:
        return selectedEventId ? (
          <CourseProfileView 
            eventId={selectedEventId}
            onBack={() => setActiveView(ViewType.LIBRARY)}
            onSessionSelect={handleSessionSelect}
          />
        ) : <CoursesView onSessionSelect={handleSessionSelect} onEventSelect={handleEventSelect} />;
      case ViewType.TASKS:
        return <TasksView />;
      case ViewType.INSIGHTS:
        return <InsightsView onSessionSelect={handleSessionSelect} />;
      case ViewType.CHAT:
        return <ChatView />;
      case ViewType.SETTINGS:
        return <SettingsView onBack={() => setActiveView(ViewType.HOME)} />;
      case ViewType.SESSION_DETAIL:
        return selectedSessionId ? (
          <SessionDetailView 
            sessionId={selectedSessionId} 
            onBack={() => setActiveView(ViewType.HOME)} 
          />
        ) : <HomeView sessions={sessions} events={events} onSessionSelect={handleSessionSelect} onStartFastRecord={handleRecordClick} onNavigate={navigateTo} />;
      default:
        return <HomeView sessions={sessions} events={events} onSessionSelect={handleSessionSelect} onStartFastRecord={handleRecordClick} onNavigate={navigateTo} />;
    }
  };

  return (
    <div className="flex flex-col h-screen bg-white overflow-hidden selection:bg-rose-100">
      <main className="flex-1 overflow-y-auto">
        {renderView()}
      </main>

      {showEventPicker && (
        <EventPicker 
          onSelect={startRecording} 
          onCancel={() => setShowEventPicker(false)} 
        />
      )}

      {!isRecording && activeView !== ViewType.RECORDING && activeView !== ViewType.SETTINGS && (
        <div className="fixed bottom-0 left-0 right-0 z-50">
          <div className="absolute bottom-[80px] left-1/2 -translate-x-1/2 z-[60]">
             <button 
                onClick={handleRecordClick}
                className="w-16 h-16 bg-gradient-to-br from-[#FF385C] to-[#E31C5F] text-white rounded-full flex items-center justify-center airbnb-shadow-large active:scale-90 transition-all duration-300 border-4 border-white relative group"
                aria-label="Start Recording"
             >
                <div className="absolute inset-0 bg-white opacity-0 group-hover:opacity-10 transition-opacity rounded-full"></div>
                <MicIcon size={28} className="drop-shadow-sm" />
                <div className="absolute -inset-2 rounded-full border-2 border-[#FF385C] opacity-0 animate-[ping_3s_infinite] pointer-events-none"></div>
             </button>
          </div>

          <nav className="w-full bg-white/95 backdrop-blur-xl border-t border-gray-100 safe-area-bottom flex items-center justify-around h-[80px] px-1 shadow-[0_-4px_24px_rgba(0,0,0,0.04)]">
            <button 
              onClick={() => setActiveView(ViewType.HOME)}
              className={`flex flex-col items-center justify-center space-y-1 w-full transition-soft ${activeView === ViewType.HOME ? 'text-[#FF385C]' : 'text-[#717171] hover:text-[#222222]'}`}
            >
              <HomeIcon size={20} className={activeView === ViewType.HOME ? 'stroke-[2.5px]' : 'stroke-[2px]'} />
              <span className="text-[9px] font-extrabold uppercase tracking-tight">Explore</span>
            </button>
            
            <button 
              onClick={() => setActiveView(ViewType.LIBRARY)}
              className={`flex flex-col items-center justify-center space-y-1 w-full transition-soft ${activeView === ViewType.LIBRARY || activeView === ViewType.COURSE_PROFILE ? 'text-[#FF385C]' : 'text-[#717171] hover:text-[#222222]'}`}
            >
              <NotebookIcon size={20} className={activeView === ViewType.LIBRARY || activeView === ViewType.COURSE_PROFILE ? 'stroke-[2.5px]' : 'stroke-[2px]'} />
              <span className="text-[9px] font-extrabold uppercase tracking-tight">Notebook</span>
            </button>

            <button 
              onClick={() => setActiveView(ViewType.TASKS)}
              className={`flex flex-col items-center justify-center space-y-1 w-full transition-soft ${activeView === ViewType.TASKS ? 'text-[#FF385C]' : 'text-[#717171] hover:text-[#222222]'}`}
            >
              <CheckSquareIcon size={20} className={activeView === ViewType.TASKS ? 'stroke-[2.5px]' : 'stroke-[2px]'} />
              <span className="text-[9px] font-extrabold uppercase tracking-tight">Tasks</span>
            </button>

            <button 
              onClick={() => setActiveView(ViewType.INSIGHTS)}
              className={`flex flex-col items-center justify-center space-y-1 w-full transition-soft ${activeView === ViewType.INSIGHTS ? 'text-[#FF385C]' : 'text-[#717171] hover:text-[#222222]'}`}
            >
              <LightbulbIcon size={20} className={activeView === ViewType.INSIGHTS ? 'stroke-[2.5px]' : 'stroke-[2px]'} />
              <span className="text-[9px] font-extrabold uppercase tracking-tight">Insights</span>
            </button>

            <button 
              onClick={() => setActiveView(ViewType.CHAT)}
              className={`flex flex-col items-center justify-center space-y-1 w-full transition-soft ${activeView === ViewType.CHAT ? 'text-[#FF385C]' : 'text-[#717171] hover:text-[#222222]'}`}
            >
              <SparkIcon size={20} className={activeView === ViewType.CHAT ? 'stroke-[2.5px]' : 'stroke-[2px]'} />
              <span className="text-[9px] font-extrabold uppercase tracking-tight">Syntra</span>
            </button>
          </nav>
        </div>
      )}
    </div>
  );
};

export default App;
