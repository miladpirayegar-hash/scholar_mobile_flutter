
import React, { useState, useEffect } from 'react';
import { appStore } from '../store/appStore';
import { Event, Session, AcademicListItem } from '../types';
import { ChevronRightIcon, CalendarIcon, CheckSquareIcon, PlusIcon, TrashIcon, BookIcon, LightbulbIcon, SparkIcon } from '../components/Icons';

interface CourseProfileViewProps {
  eventId: string;
  onBack: () => void;
  onSessionSelect: (id: string) => void;
}

const CourseProfileView: React.FC<CourseProfileViewProps> = ({ eventId, onBack, onSessionSelect }) => {
  const [event, setEvent] = useState<Event | null>(appStore.getEvent(eventId) || null);
  const [sessions, setSessions] = useState<Session[]>(appStore.getSessions().filter(s => s.eventId === eventId));
  const [activeTab, setActiveTab] = useState<'track' | 'content' | 'brief'>('brief');
  
  const [showItemModal, setShowItemModal] = useState<{ type: 'assignments' | 'exams', show: boolean }>({ type: 'assignments', show: false });
  const [newItemText, setNewItemText] = useState('');
  const [newItemDate, setNewItemDate] = useState('');
  const [newHighlight, setNewHighlight] = useState('');

  useEffect(() => {
    const unsub = appStore.subscribe(() => {
      setEvent(appStore.getEvent(eventId) || null);
      setSessions(appStore.getSessions().filter(s => s.eventId === eventId));
    });
    return unsub;
  }, [eventId]);

  if (!event) return null;

  const handleAddItem = () => {
    if (!newItemText.trim()) return;
    appStore.addAcademicItem(eventId, showItemModal.type, {
      id: `item-${Date.now()}`,
      text: newItemText,
      date: newItemDate || null,
      completed: false
    });
    setNewItemText('');
    setNewItemDate('');
    setShowItemModal({ ...showItemModal, show: false });
  };

  const handleAddHighlight = () => {
    if (!newHighlight.trim()) return;
    appStore.addHighlight(eventId, newHighlight);
    setNewHighlight('');
  };

  return (
    <div className="min-h-screen bg-white pb-40">
      <header className="px-6 pt-16 pb-6 sticky top-0 bg-white/95 backdrop-blur-md z-40 border-b border-gray-100">
        <div className="flex justify-between items-center mb-6">
          <button onClick={onBack} className="w-10 h-10 border border-gray-200 rounded-full flex items-center justify-center airbnb-card-shadow active:scale-95 transition-soft">
            <ChevronRightIcon size={20} className="rotate-180" />
          </button>
          <div className="w-10 h-10 rounded-xl airbnb-shadow flex items-center justify-center font-black text-white" style={{ backgroundColor: event.color }}>
            {event.name.charAt(0)}
          </div>
        </div>

        <div className="space-y-1">
          <h1 className="text-3xl font-black text-[#222222] tracking-tight">{event.name}</h1>
          <p className="text-[#717171] font-bold text-sm flex items-center">
            <BookIcon size={14} className="mr-1.5" />
            {sessions.length} archived captures
          </p>
        </div>

        <nav className="mt-8 flex space-x-6">
          <button onClick={() => setActiveTab('brief')} className={`pb-3 text-sm font-black transition-soft ${activeTab === 'brief' ? 'text-[#FF385C] border-b-2 border-[#FF385C]' : 'text-[#717171]'}`}>Course Brief</button>
          <button onClick={() => setActiveTab('track')} className={`pb-3 text-sm font-black transition-soft ${activeTab === 'track' ? 'text-[#FF385C] border-b-2 border-[#FF385C]' : 'text-[#717171]'}`}>Milestones</button>
          <button onClick={() => setActiveTab('content')} className={`pb-3 text-sm font-black transition-soft ${activeTab === 'content' ? 'text-[#FF385C] border-b-2 border-[#FF385C]' : 'text-[#717171]'}`}>Captures</button>
        </nav>
      </header>

      <div className="px-6 mt-8 max-w-2xl mx-auto space-y-10">
        {activeTab === 'brief' && (
          <div className="space-y-10 animate-in fade-in slide-in-from-bottom duration-500">
            {/* Highlights Section */}
            <section className="space-y-6">
              <div className="flex justify-between items-center">
                <h2 className="text-xl font-black text-[#222222]">Subject Highlights</h2>
              </div>
              
              <div className="space-y-4">
                <div className="relative">
                  <textarea 
                    placeholder="Capture a subject-level insight..."
                    className="w-full bg-[#F7F7F7] border border-transparent focus:border-gray-200 rounded-2xl p-5 font-medium text-sm outline-none transition-soft min-h-[100px]"
                    value={newHighlight}
                    onChange={e => setNewHighlight(e.target.value)}
                  />
                  <button 
                    onClick={handleAddHighlight}
                    className="absolute bottom-4 right-4 w-10 h-10 bg-[#222222] text-white rounded-full flex items-center justify-center airbnb-shadow active:scale-90 transition-soft"
                  >
                    <PlusIcon size={18} />
                  </button>
                </div>

                <div className="space-y-3">
                  {event.highlights?.map((h, i) => (
                    <div key={i} className="bg-white border border-gray-100 p-5 rounded-2xl airbnb-card-shadow flex items-start space-x-4 group">
                      <div className="mt-1 w-2 h-2 rounded-full bg-[#FF385C] shrink-0" />
                      <p className="text-sm font-medium text-[#222222] leading-relaxed flex-1">{h}</p>
                      <button 
                        onClick={() => appStore.deleteHighlight(eventId, i)}
                        className="opacity-0 group-hover:opacity-100 transition-soft text-gray-300 hover:text-rose-500"
                      >
                        <TrashIcon size={14} />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            </section>
          </div>
        )}

        {activeTab === 'track' && (
          <div className="space-y-12 animate-in fade-in slide-in-from-bottom duration-500">
            {/* Exams */}
            <section className="space-y-6">
              <div className="flex justify-between items-center">
                <div className="flex items-center space-x-2">
                  <SparkIcon size={18} className="text-[#FF385C]" />
                  <h2 className="text-xl font-black text-[#222222]">Upcoming Exams</h2>
                </div>
                <button 
                  onClick={() => setShowItemModal({ type: 'exams', show: true })}
                  className="bg-[#F7F7F7] p-2 rounded-full text-[#222222] transition-soft hover:bg-gray-100"
                >
                  <PlusIcon size={18} />
                </button>
              </div>

              <div className="space-y-4">
                {event.exams?.length ? event.exams.map(exam => (
                  <div 
                    key={exam.id}
                    className="bg-[#222222] text-white p-5 rounded-2xl airbnb-shadow flex items-center justify-between"
                  >
                    <div className="flex-1 min-w-0 pr-4">
                      <p className="font-bold text-sm truncate">{exam.text}</p>
                      {exam.date && (
                        <p className="text-[10px] font-bold text-rose-400 uppercase mt-1">
                          <CalendarIcon size={10} className="inline mr-1" />
                          {new Date(exam.date).toLocaleDateString()}
                        </p>
                      )}
                    </div>
                    <button 
                      onClick={() => appStore.deleteAcademicItem(eventId, 'exams', exam.id)}
                      className="text-gray-500 hover:text-white transition-soft"
                    >
                      <TrashIcon size={16} />
                    </button>
                  </div>
                )) : (
                  <div className="text-center py-6 border-2 border-dashed border-gray-100 rounded-[2rem]">
                    <p className="text-xs font-bold text-gray-300 uppercase tracking-widest">No exams scheduled</p>
                  </div>
                )}
              </div>
            </section>

            {/* Assignments */}
            <section className="space-y-6">
              <div className="flex justify-between items-center">
                <div className="flex items-center space-x-2">
                  <CheckSquareIcon size={18} className="text-[#222222]" />
                  <h2 className="text-xl font-black text-[#222222]">Assignments</h2>
                </div>
                <button 
                  onClick={() => setShowItemModal({ type: 'assignments', show: true })}
                  className="bg-[#F7F7F7] p-2 rounded-full text-[#222222] transition-soft hover:bg-gray-100"
                >
                  <PlusIcon size={18} />
                </button>
              </div>

              <div className="space-y-4">
                {event.assignments?.length ? event.assignments.map(item => (
                  <div 
                    key={item.id}
                    className="bg-white border border-gray-100 p-5 rounded-2xl airbnb-card-shadow flex items-center justify-between"
                  >
                    <div className="flex items-center space-x-4 flex-1 min-w-0">
                      <button 
                        onClick={() => appStore.toggleAcademicItem(eventId, 'assignments', item.id)}
                        className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-soft ${item.completed ? 'bg-emerald-500 border-emerald-500' : 'border-gray-200'}`}
                      >
                        {item.completed && <div className="w-1.5 h-1.5 rounded-full bg-white" />}
                      </button>
                      <div className="flex-1 min-w-0">
                        <p className={`font-bold text-sm truncate ${item.completed ? 'text-gray-300 line-through' : 'text-[#222222]'}`}>{item.text}</p>
                        {item.date && <p className="text-[10px] font-bold text-[#717171] uppercase mt-0.5">{new Date(item.date).toLocaleDateString()}</p>}
                      </div>
                    </div>
                    <button 
                      onClick={() => appStore.deleteAcademicItem(eventId, 'assignments', item.id)}
                      className="text-gray-300 hover:text-rose-500 transition-soft ml-4"
                    >
                      <TrashIcon size={16} />
                    </button>
                  </div>
                )) : (
                   <div className="text-center py-6 border-2 border-dashed border-gray-100 rounded-[2rem]">
                    <p className="text-xs font-bold text-gray-300 uppercase tracking-widest">Coursework clear</p>
                  </div>
                )}
              </div>
            </section>
          </div>
        )}

        {activeTab === 'content' && (
          <div className="space-y-6 animate-in fade-in slide-in-from-bottom duration-500">
             <h2 className="text-xl font-black text-[#222222]">Subject Timeline</h2>
             <div className="space-y-4">
               {sessions.map(session => (
                 <div 
                   key={session.id}
                   onClick={() => onSessionSelect(session.id)}
                   className="flex items-center space-x-4 p-4 bg-white border border-gray-100 rounded-2xl hover:bg-gray-50 transition-soft cursor-pointer group"
                 >
                   <div className="w-12 h-12 rounded-xl bg-gray-50 flex items-center justify-center text-[#717171] group-hover:text-[#FF385C] transition-soft">
                     <LightbulbIcon size={20} />
                   </div>
                   <div className="flex-1 min-w-0">
                     <h4 className="font-bold text-sm text-[#222222] truncate">{session.title}</h4>
                     <p className="text-[10px] font-bold text-[#717171] uppercase tracking-widest">{new Date(session.date).toLocaleDateString()}</p>
                   </div>
                   <ChevronRightIcon size={16} className="text-gray-300" />
                 </div>
               ))}
             </div>
          </div>
        )}
      </div>

      {/* Modal for adding Items */}
      {showItemModal.show && (
        <div className="fixed inset-0 z-[110] bg-black/50 backdrop-blur-md flex items-end sm:items-center justify-center animate-in fade-in duration-300">
          <div className="bg-white w-full max-w-lg rounded-t-[2.5rem] sm:rounded-[2.5rem] p-10 animate-in slide-in-from-bottom duration-500 airbnb-shadow-large">
            <h2 className="text-2xl font-black text-[#222222] mb-8">Add {showItemModal.type === 'exams' ? 'Exam' : 'Assignment'}</h2>
            <div className="space-y-6">
              <input 
                autoFocus
                type="text"
                placeholder="Description..."
                className="w-full bg-[#F7F7F7] border border-transparent focus:border-[#222222] rounded-2xl p-5 font-bold outline-none"
                value={newItemText}
                onChange={e => setNewItemText(e.target.value)}
              />
              <input 
                type="date"
                className="w-full bg-[#F7F7F7] border border-transparent focus:border-[#222222] rounded-2xl p-5 font-bold outline-none"
                value={newItemDate}
                onChange={e => setNewItemDate(e.target.value)}
              />
              <div className="flex space-x-4 pt-4">
                <button onClick={() => setShowItemModal({ ...showItemModal, show: false })} className="flex-1 py-4 font-bold text-[#717171]">Cancel</button>
                <button onClick={handleAddItem} className="flex-[2] bg-[#FF385C] text-white py-4 rounded-2xl font-bold airbnb-shadow active:scale-95 transition-soft">Save Item</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CourseProfileView;
