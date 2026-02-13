
import React, { useState, useEffect } from 'react';
import { ViewType, Session, Event, UserProfile } from '../types';
import { BookIcon, CheckSquareIcon, MicIcon, ChevronRightIcon, PlayIcon, PlusIcon, SettingsIcon, CalendarIcon, LightbulbIcon, UserIcon, SparkIcon } from '../components/Icons';
import { appStore } from '../store/appStore';

interface HomeViewProps {
  sessions: Session[];
  events: Event[];
  onSessionSelect: (id: string) => void;
  onStartFastRecord: () => void;
  onNavigate: (view: ViewType) => void;
}

const HomeView: React.FC<HomeViewProps> = ({ sessions, events, onSessionSelect, onStartFastRecord, onNavigate }) => {
  const [user, setUser] = useState<UserProfile>(appStore.getUser());

  useEffect(() => {
    const unsub = appStore.subscribe(() => setUser(appStore.getUser()));
    return unsub;
  }, []);

  const tasks = appStore.getTasks();
  const pinnedTasks = tasks.filter(t => t.isPinned && !t.completed);
  const pinnedSessions = sessions.filter(s => s.isPinned);
  const recentSessions = sessions.slice(0, 4);
  const pendingTasks = tasks.filter(t => !t.completed).slice(0, 3);
  const pendingTasksCount = tasks.filter(t => !t.completed).length;

  return (
    <div className="min-h-screen bg-white pb-40">
      <div className="px-6 pt-12 pb-4 sticky top-0 bg-white/95 backdrop-blur-md z-40 flex items-center justify-between">
        <div className="flex flex-col">
          <span className="text-[10px] font-black uppercase tracking-widest text-[#FF385C]">
            {user.isLoggedIn ? `Hello, ${user.name.split(' ')[0]}` : 'Welcome'}
          </span>
          <h1 className="text-3xl font-extrabold text-[#222222] tracking-tight">Explore</h1>
        </div>
        
        <button 
          onClick={() => onNavigate(ViewType.SETTINGS)}
          className="relative w-12 h-12 rounded-full border border-gray-100 flex items-center justify-center hover:bg-gray-50 transition-soft active:scale-90 bg-white airbnb-card-shadow overflow-hidden"
        >
          {user.isLoggedIn ? (
            <div className="w-full h-full bg-[#FF385C] flex items-center justify-center text-white font-bold">
              {user.name.charAt(0)}
            </div>
          ) : (
            <UserIcon size={22} className="text-[#717171]" />
          )}
        </button>
      </div>

      <div className="px-6 mt-4 max-w-2xl mx-auto space-y-12">
        {/* Pinned Priority Vault */}
        {(pinnedTasks.length > 0 || pinnedSessions.length > 0) && (
          <section className="space-y-6">
            <div className="flex items-center space-x-2">
              <SparkIcon size={18} className="text-[#FF385C]" />
              <h2 className="text-2xl font-bold text-[#222222]">Priority Vault</h2>
            </div>
            <div className="flex space-x-4 overflow-x-auto pb-4 scrollbar-hide -mx-6 px-6">
              {pinnedSessions.map(session => (
                <div 
                  key={session.id}
                  onClick={() => onSessionSelect(session.id)}
                  className="bg-[#222222] text-white p-6 rounded-[2rem] min-w-[200px] flex flex-col justify-between airbnb-shadow active:scale-95 transition-soft cursor-pointer"
                >
                  <span className="text-[9px] font-black uppercase tracking-widest text-rose-500">Pinned Capture</span>
                  <p className="mt-2 font-bold text-lg line-clamp-2 leading-tight">{session.title}</p>
                  <div className="mt-4 flex items-center text-[10px] font-bold text-gray-400">
                    <CalendarIcon size={12} className="mr-1" />
                    {new Date(session.date).toLocaleDateString()}
                  </div>
                </div>
              ))}
              {pinnedTasks.map(task => (
                <div 
                  key={task.id}
                  onClick={() => onNavigate(ViewType.TASKS)}
                  className="bg-white border-2 border-[#222222] p-6 rounded-[2rem] min-w-[200px] flex flex-col justify-between airbnb-card-shadow active:scale-95 transition-soft cursor-pointer"
                >
                  <span className="text-[9px] font-black uppercase tracking-widest text-[#222222]">Pinned Goal</span>
                  <p className="mt-2 font-bold text-lg text-[#222222] line-clamp-2 leading-tight">{task.text}</p>
                  <div className="mt-4 flex items-center text-[10px] font-bold text-[#717171]">
                    <CheckSquareIcon size={12} className="mr-1" />
                    {task.priority.toUpperCase()} PRIORITY
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {/* Quick Insights Stats */}
        <section className="flex space-x-4 overflow-x-auto pb-2 scrollbar-hide -mx-2 px-2">
          <button 
            onClick={() => onNavigate(ViewType.LIBRARY)}
            className="bg-rose-50 p-6 rounded-[2rem] min-w-[160px] flex-1 text-left transition-all active:scale-95"
          >
             <span className="text-[10px] font-black uppercase tracking-widest text-[#FF385C]">Knowledge</span>
             <p className="text-3xl font-black text-[#222222] mt-1">{events.length}</p>
             <p className="text-xs font-bold text-[#717171]">Units In Notebook</p>
          </button>
          <button 
            onClick={() => onNavigate(ViewType.TASKS)}
            className="bg-gray-50 p-6 rounded-[2rem] min-w-[160px] flex-1 text-left transition-all active:scale-95"
          >
             <span className="text-[10px] font-black uppercase tracking-widest text-[#222222]">Study Tasks</span>
             <p className="text-3xl font-black text-[#222222] mt-1">{pendingTasksCount}</p>
             <p className="text-xs font-bold text-[#717171]">Action Required</p>
          </button>
        </section>

        {/* Actionable Tasks */}
        <section>
           <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-bold text-[#222222]">Academic To-Do</h2>
            <button onClick={() => onNavigate(ViewType.TASKS)} className="text-[#FF385C] font-black text-sm uppercase tracking-widest">Full List</button>
          </div>
          <div className="bg-white rounded-[2rem] p-8 border border-gray-100 space-y-5 airbnb-card-shadow">
            {pendingTasks.length > 0 ? (
              pendingTasks.map(task => (
                <div key={task.id} className="flex items-start space-x-4 group cursor-pointer" onClick={() => appStore.toggleTask(task.id)}>
                  <div 
                    className={`mt-1 w-6 h-6 rounded-full border-2 flex items-center justify-center shrink-0 transition-soft ${task.completed ? 'bg-[#FF385C] border-[#FF385C]' : 'border-gray-200 bg-white group-hover:border-[#FF385C]'}`}
                  >
                    {task.completed && <div className="w-2 h-2 rounded-full bg-white" />}
                  </div>
                  <p className={`text-lg font-bold leading-tight truncate transition-soft ${task.completed ? 'text-gray-400 line-through' : 'text-[#222222]'}`}>{task.text}</p>
                </div>
              ))
            ) : (
              <div className="text-center py-4 space-y-2">
                <CheckSquareIcon className="mx-auto text-gray-200" size={32} />
                <p className="text-gray-400 font-bold">Inbox is clear.</p>
              </div>
            )}
          </div>
        </section>

        {/* Recent Activity */}
        <section className="pb-12">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-bold text-[#222222]">Recent Activity</h2>
            <button onClick={() => onNavigate(ViewType.LIBRARY)} className="text-[#222222] underline font-bold text-sm">Notebook</button>
          </div>

          <div className="space-y-6">
            {recentSessions.length > 0 ? (
              recentSessions.map((session) => {
                const event = events.find(e => e.id === session.eventId);
                const isProcessing = session.status === 'processing';
                
                return (
                  <div 
                    key={session.id}
                    onClick={() => onSessionSelect(session.id)}
                    className="flex space-x-4 items-center cursor-pointer group"
                  >
                    <div className="w-20 h-20 rounded-xl overflow-hidden shrink-0 airbnb-surface flex items-center justify-center relative transition-soft group-hover:scale-95">
                      {isProcessing ? (
                        <div className="w-6 h-6 border-3 border-[#FF385C] border-t-transparent rounded-full animate-spin"></div>
                      ) : (
                        <div className="absolute inset-0" style={{ backgroundColor: event?.color || '#cbd5e1', opacity: 0.2 }} />
                      )}
                      {!isProcessing && <PlayIcon className="text-[#222222] opacity-80" size={20} />}
                    </div>

                    <div className="flex-1 min-w-0 border-b border-gray-100 pb-4">
                      <h4 className="font-bold text-[#222222] text-lg truncate leading-tight mb-1">{session.title}</h4>
                      <div className="flex items-center space-x-2 text-sm text-[#717171]">
                        <span className="font-medium">{event?.name || 'Unit'}</span>
                        <span>•</span>
                        <span>{new Date(session.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}</span>
                      </div>
                    </div>
                  </div>
                );
              })
            ) : (
              <div className="py-16 text-center airbnb-surface rounded-3xl border border-dashed border-gray-200">
                <MicIcon size={40} className="mx-auto text-gray-300 mb-4" />
                <p className="text-[#717171] font-bold">Ready to capture your first session</p>
                <button onClick={onStartFastRecord} className="mt-4 bg-[#FF385C] text-white px-6 py-2.5 rounded-full font-bold airbnb-shadow active:scale-95 transition-soft">Start Now</button>
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
};

export default HomeView;
