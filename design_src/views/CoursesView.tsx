
import React, { useState, useEffect } from 'react';
import { appStore } from '../store/appStore';
import { Event, Session } from '../types';
import { PlusIcon, ChevronRightIcon, EditIcon, TrashIcon, BookIcon, CalendarIcon, SortIcon } from '../components/Icons';
import ConfirmationModal from '../components/ConfirmationModal';

interface CoursesViewProps {
  onSessionSelect: (id: string) => void;
  onEventSelect: (id: string) => void;
}

const CoursesView: React.FC<CoursesViewProps> = ({ onSessionSelect, onEventSelect }) => {
  const [events, setEvents] = useState(appStore.getEvents());
  const [sessions, setSessions] = useState(appStore.getSessions());
  const [activeLibraryTab, setActiveLibraryTab] = useState<'units' | 'sessions'>('units');
  
  const [editingEvent, setEditingEvent] = useState<Event | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newCourseName, setNewCourseName] = useState('');
  const [deleteModal, setDeleteModal] = useState<{ isOpen: boolean, eventId: string | null, sessionId: string | null }>({ isOpen: false, eventId: null, sessionId: null });

  useEffect(() => {
    const unsubscribe = appStore.subscribe(() => {
      setEvents(appStore.getEvents());
      setSessions(appStore.getSessions());
    });
    return unsubscribe;
  }, []);

  const handleCreateCourse = () => {
    if (!newCourseName.trim()) return;
    appStore.addEvent({
      id: `evt-${Date.now()}`,
      name: newCourseName,
      description: '',
      color: ['#FF385C', '#222222', '#00A699', '#FC642D', '#484848'][Math.floor(Math.random() * 5)],
      sessionIds: [],
      createdAt: new Date().toISOString(),
      assignments: [],
      exams: [],
      highlights: []
    });
    setNewCourseName('');
    setShowCreateModal(false);
  };

  const handleUpdateCourse = () => {
    if (editingEvent) {
      appStore.updateEvent(editingEvent);
      setEditingEvent(null);
    }
  };

  const handleDelete = () => {
    if (deleteModal.eventId) appStore.deleteEvent(deleteModal.eventId);
    else if (deleteModal.sessionId) appStore.deleteSession(deleteModal.sessionId);
    setDeleteModal({ isOpen: false, eventId: null, sessionId: null });
  };

  const renderUnitCard = (event: Event) => (
    <div 
      key={event.id} 
      onClick={() => onEventSelect(event.id)}
      className="bg-white rounded-[1.5rem] border border-gray-100 airbnb-card-shadow overflow-hidden transition-soft hover:scale-[0.99] group cursor-pointer"
    >
      <div className="p-6">
        <div className="flex justify-between items-start mb-4">
          <div className="w-14 h-14 rounded-2xl flex items-center justify-center text-white text-2xl font-black airbnb-shadow" style={{ backgroundColor: event.color }}>
            {event.name.charAt(0)}
          </div>
          <div className="flex space-x-1 opacity-0 group-hover:opacity-100 transition-soft">
            <button 
              onClick={(e) => { e.stopPropagation(); setEditingEvent(event); }}
              className="p-2 text-[#717171] hover:text-[#222222] hover:bg-gray-100 rounded-full transition-soft"
            >
              <EditIcon size={18} />
            </button>
            <button 
              onClick={(e) => { e.stopPropagation(); setDeleteModal({ isOpen: true, eventId: event.id, sessionId: null }); }}
              className="p-2 text-[#717171] hover:text-[#FF385C] hover:bg-rose-50 rounded-full transition-soft"
            >
              <TrashIcon size={18} />
            </button>
          </div>
        </div>
        <div className="flex justify-between items-center">
          <div>
            <h2 className="text-xl font-extrabold text-[#222222] mb-1">{event.name}</h2>
            <p className="text-sm font-medium text-[#717171]">{event.sessionIds.length} Sessions archived</p>
          </div>
          <ChevronRightIcon size={20} className="text-gray-300" />
        </div>
        
        {event.sessionIds.length > 0 && (
          <div className="mt-6 pt-6 border-t border-gray-50 flex items-center space-x-4">
            <div className="flex -space-x-2">
              {[...Array(Math.min(3, event.sessionIds.length))].map((_, i) => (
                <div key={i} className="w-6 h-6 rounded-full border-2 border-white bg-gray-100 flex items-center justify-center">
                  <BookIcon size={10} className="text-gray-400" />
                </div>
              ))}
            </div>
            <span className="text-[10px] font-black text-[#FF385C] uppercase tracking-widest">Open Subject Dashboard</span>
          </div>
        )}
      </div>
    </div>
  );

  const renderSessionCard = (session: Session) => {
    const event = events.find(e => e.id === session.eventId);
    return (
      <div key={session.id} className="bg-white p-6 rounded-[1.5rem] border border-gray-100 flex items-center hover:bg-gray-50 transition-soft cursor-pointer group" onClick={() => onSessionSelect(session.id)}>
        <div className="w-14 h-14 rounded-xl bg-[#F7F7F7] flex items-center justify-center mr-5 shrink-0 group-hover:bg-white transition-soft border border-transparent group-hover:border-gray-100">
          <CalendarIcon size={22} className="text-[#222222]" />
        </div>
        <div className="flex-1 min-w-0 pr-4">
          <div className="flex items-center space-x-2 mb-1">
            <span className="text-[10px] font-black uppercase tracking-widest text-[#FF385C] bg-rose-50 px-2.5 py-1 rounded-full truncate">
              {event?.name || 'Academic'}
            </span>
          </div>
          <h3 className="text-lg font-bold text-[#222222] truncate leading-tight">{session.title}</h3>
          <p className="text-xs text-[#717171] font-medium mt-1">{new Date(session.date).toLocaleDateString()} • {Math.floor(session.duration / 60)}m</p>
        </div>
        <div className="shrink-0">
          <ChevronRightIcon size={20} className="text-[#222222]" />
        </div>
      </div>
    );
  };

  return (
    <div className="p-6 pt-16 max-w-2xl mx-auto space-y-10 pb-40 min-h-screen bg-white">
      <header className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-extrabold text-[#222222] tracking-tight">Notebook</h1>
          <p className="text-[#717171] text-lg font-medium">Archived academic sessions</p>
        </div>
        <button 
          onClick={() => setShowCreateModal(true)}
          className="bg-[#222222] text-white w-12 h-12 rounded-full flex items-center justify-center airbnb-shadow active:scale-95 transition-soft"
        >
          <PlusIcon size={20} />
        </button>
      </header>

      <div className="flex border-b border-gray-100">
        <button 
          onClick={() => setActiveLibraryTab('units')}
          className={`pb-4 text-sm font-extrabold mr-8 transition-soft ${activeLibraryTab === 'units' ? 'text-[#222222] border-b-2 border-[#222222]' : 'text-[#717171]'}`}
        >
          Units
        </button>
        <button 
          onClick={() => setActiveLibraryTab('sessions')}
          className={`pb-4 text-sm font-extrabold transition-soft ${activeLibraryTab === 'sessions' ? 'text-[#222222] border-b-2 border-[#222222]' : 'text-[#717171]'}`}
        >
          Captures
        </button>
      </div>

      <div className="space-y-6">
        {activeLibraryTab === 'units' ? (
          <div className="grid grid-cols-1 gap-6">
            {events.map(renderUnitCard)}
          </div>
        ) : (
          <div className="space-y-4">
            {sessions.map(renderSessionCard)}
          </div>
        )}
      </div>

      <ConfirmationModal 
        isOpen={deleteModal.isOpen}
        title={deleteModal.eventId ? "Delete Unit?" : "Delete Capture?"}
        message="This action is permanent and cannot be undone."
        onConfirm={handleDelete}
        onCancel={() => setDeleteModal({ isOpen: false, eventId: null, sessionId: null })}
      />

      {editingEvent && (
        <div className="fixed inset-0 z-[110] bg-black/50 flex items-center justify-center p-6 animate-in fade-in duration-300">
          <div className="bg-white w-full max-w-md rounded-[2rem] p-10 airbnb-shadow-large">
            <h2 className="text-2xl font-extrabold text-[#222222] mb-8">Rename Unit</h2>
            <input 
              type="text" 
              value={editingEvent.name}
              onChange={e => setEditingEvent({...editingEvent, name: e.target.value})}
              className="w-full bg-white border border-gray-300 p-5 rounded-2xl font-bold text-lg outline-none focus:border-[#222222] mb-8"
            />
            <div className="flex space-x-4">
              <button onClick={() => setEditingEvent(null)} className="flex-1 py-4 font-bold text-[#222222] hover:bg-gray-100 rounded-2xl transition-soft">Cancel</button>
              <button onClick={handleUpdateCourse} className="flex-[2] bg-[#222222] text-white py-4 rounded-2xl font-bold airbnb-shadow">Save</button>
            </div>
          </div>
        </div>
      )}

      {showCreateModal && (
        <div className="fixed inset-0 z-[110] bg-black/50 flex items-end sm:items-center justify-center animate-in fade-in duration-300">
          <div className="bg-white w-full max-md rounded-t-[2rem] sm:rounded-[2rem] p-10 animate-in slide-in-from-bottom duration-500">
            <h2 className="text-2xl font-extrabold text-[#222222] mb-8">New Unit</h2>
            <div className="space-y-2 mb-10">
              <p className="text-xs font-bold text-[#717171] uppercase tracking-widest ml-1">Identity</p>
              <input 
                autoFocus
                type="text" 
                value={newCourseName}
                onChange={e => setNewCourseName(e.target.value)}
                placeholder="e.g. Architecture 101"
                className="w-full bg-white border border-gray-300 p-5 rounded-2xl font-bold text-lg outline-none focus:border-[#222222]"
              />
            </div>
            <div className="flex flex-col sm:flex-row space-y-3 sm:space-y-0 sm:space-x-4">
              <button onClick={() => setShowCreateModal(false)} className="flex-1 py-4 font-bold text-[#222222] hover:bg-gray-100 rounded-2xl transition-soft">Cancel</button>
              <button onClick={handleCreateCourse} className="flex-[2] bg-[#FF385C] text-white py-4 rounded-2xl font-bold airbnb-shadow">Initialize</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CoursesView;
