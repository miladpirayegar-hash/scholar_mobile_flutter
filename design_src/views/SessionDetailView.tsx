
import React, { useState, useEffect } from 'react';
import { Session, Insights, Event, Flashcard, KeyTerm, TranscriptSegment } from '../types';
import { appStore } from '../store/appStore';
import { generateInsights } from '../services/geminiService';
import { ChevronRightIcon, TrashIcon, SortIcon, CheckSquareIcon, MicIcon, CalendarIcon, EditIcon, PlusIcon, SparkIcon } from '../components/Icons';
import ConfirmationModal from '../components/ConfirmationModal';

interface SessionDetailViewProps {
  sessionId: string;
  onBack: () => void;
}

const FlashcardViewer = ({ 
  flashcards, 
  onEdit, 
  onDelete,
  onTogglePin
}: { 
  flashcards: Flashcard[], 
  onEdit: (idx: number) => void,
  onDelete: (idx: number) => void,
  onTogglePin: (idx: number) => void
}) => {
  const [index, setIndex] = useState(0);
  const [flipped, setFlipped] = useState(false);

  useEffect(() => {
    setFlipped(false);
  }, [index, flashcards.length]);

  if (!flashcards || flashcards.length === 0) return null;

  const current = flashcards[index];

  return (
    <div className="space-y-10">
      <div 
        onClick={() => setFlipped(!flipped)}
        className="relative h-80 w-full perspective-1000 cursor-pointer group"
      >
        <div className={`relative w-full h-full transition-all duration-700 transform-style-3d ${flipped ? 'rotate-y-180' : ''}`}>
          {/* Front */}
          <div className="absolute inset-0 backface-hidden bg-white border border-gray-200 rounded-[2.5rem] p-12 airbnb-card-shadow flex flex-col items-center justify-center text-center overflow-hidden">
             <div className="flex flex-col items-center mb-6">
               <span className="text-[11px] font-black text-[#FF385C] uppercase tracking-[0.2em]">Flashcard</span>
               {current.isUserCreated && <span className="text-[10px] font-bold text-[#717171] uppercase mt-1">Manual Entry</span>}
             </div>
             <p className="text-xl font-bold text-[#222222] leading-relaxed max-h-40 overflow-y-auto w-full px-2">{current.q}</p>
             <div className="mt-auto pt-8">
               <span className="text-xs font-bold text-[#717171] underline group-hover:text-[#222222] transition-colors">Tap to reveal answer</span>
             </div>
          </div>
          {/* Back */}
          <div className="absolute inset-0 backface-hidden bg-[#222222] text-white border border-[#222222] rounded-[2.5rem] p-12 airbnb-shadow-large flex flex-col items-center justify-center text-center rotate-y-180 overflow-hidden">
             <span className="text-[11px] font-black text-rose-500 uppercase tracking-[0.2em] mb-6">Answer</span>
             <p className="text-xl font-bold leading-relaxed max-h-40 overflow-y-auto w-full px-2">{current.a}</p>
             <div className="mt-auto pt-8">
               <span className="text-xs font-bold text-gray-400 underline">Tap to flip back</span>
             </div>
          </div>
        </div>
        
        {/* Hover Actions */}
        <div className="absolute top-6 right-6 flex space-x-2 z-10" onClick={e => e.stopPropagation()}>
          <button 
            onClick={() => onTogglePin(index)} 
            className={`w-10 h-10 bg-white airbnb-card-shadow rounded-full flex items-center justify-center hover:scale-105 transition-soft ${current.isPinned ? 'text-[#FF385C]' : ''}`}
          >
            <SparkIcon size={16} />
          </button>
          <button onClick={() => onEdit(index)} className="w-10 h-10 bg-white airbnb-card-shadow rounded-full flex items-center justify-center hover:scale-105 transition-soft"><EditIcon size={16} /></button>
          <button onClick={() => onDelete(index)} className="w-10 h-10 bg-white airbnb-card-shadow rounded-full flex items-center justify-center hover:scale-105 transition-soft text-rose-500"><TrashIcon size={16} /></button>
        </div>
      </div>
      
      <div className="flex items-center justify-center space-x-12">
        <button 
          disabled={index === 0}
          onClick={(e) => { e.stopPropagation(); setIndex(index - 1); }}
          className="w-14 h-14 rounded-full bg-white border border-gray-200 flex items-center justify-center text-[#222222] disabled:opacity-20 airbnb-card-shadow active:scale-90 transition-soft"
        >
          <ChevronRightIcon size={24} className="rotate-180" />
        </button>
        <div className="text-center">
           <span className="text-lg font-extrabold text-[#222222]">{index + 1} <span className="text-[#717171] mx-1">/</span> {flashcards.length}</span>
        </div>
        <button 
          disabled={index === flashcards.length - 1}
          onClick={(e) => { e.stopPropagation(); setIndex(index + 1); }}
          className="w-14 h-14 rounded-full bg-white border border-gray-200 flex items-center justify-center text-[#222222] disabled:opacity-20 airbnb-card-shadow active:scale-90 transition-soft"
        >
          <ChevronRightIcon size={24} />
        </button>
      </div>
    </div>
  );
};

const SessionDetailView: React.FC<SessionDetailViewProps> = ({ sessionId, onBack }) => {
  const [session, setSession] = useState(appStore.getSession(sessionId));
  const events = appStore.getEvents();
  const [activeTab, setActiveTab] = useState<'insights' | 'transcript'>('insights');
  const [showMoveModal, setShowMoveModal] = useState(false);
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [isEditingName, setIsEditingName] = useState(false);
  const [newName, setNewName] = useState(session?.title || '');
  const [editInsight, setEditInsight] = useState<any | null>(null);

  useEffect(() => {
    const unsub = appStore.subscribe(() => setSession(appStore.getSession(sessionId)));
    return unsub;
  }, [sessionId]);

  if (!session) return null;

  const currentEvent = appStore.getEvent(session.eventId);

  const handleSaveEdit = () => {
    if (!editInsight) return;
    if (editInsight.type === 'transcript') {
      const newSegments = [...session.transcriptSegments];
      newSegments[editInsight.index] = { ...newSegments[editInsight.index], text: editInsight.data.text };
      appStore.updateSession({ ...session, transcriptSegments: newSegments, transcript: newSegments.map(s => s.text).join(' ') });
    } else if (session.insights) {
      const newInsights = { ...session.insights };
      if (editInsight.type === 'flashcard') {
        const cards = [...newInsights.flashcards];
        const cardData = { ...editInsight.data, confidence: 1.0, isUserCreated: editInsight.isNew, isEdited: !editInsight.isNew };
        if (editInsight.isNew) cards.push(cardData);
        else cards[editInsight.index] = cardData;
        newInsights.flashcards = cards;
      } else {
        const terms = [...newInsights.keyTerms];
        const termData = { ...editInsight.data, confidence: 1.0, isUserCreated: editInsight.isNew, isEdited: !editInsight.isNew };
        if (editInsight.isNew) terms.push(termData);
        else terms[editInsight.index] = termData;
        newInsights.keyTerms = terms;
      }
      appStore.updateSession({ ...session, insights: newInsights });
    }
    setEditInsight(null);
  };

  const handleTogglePinInsight = (type: 'flashcard' | 'keyterm', index: number) => {
    if (!session.insights) return;
    const newInsights = { ...session.insights };
    if (type === 'flashcard') {
      newInsights.flashcards[index].isPinned = !newInsights.flashcards[index].isPinned;
    } else {
      newInsights.keyTerms[index].isPinned = !newInsights.keyTerms[index].isPinned;
    }
    appStore.updateSession({ ...session, insights: newInsights });
  };

  const handleDeleteInsight = (type: string, index: number) => {
    if (!session.insights || !confirm("Delete this?")) return;
    const newInsights = { ...session.insights };
    if (type === 'flashcard') newInsights.flashcards = newInsights.flashcards.filter((_, i) => i !== index);
    else newInsights.keyTerms = newInsights.keyTerms.filter((_, i) => i !== index);
    appStore.updateSession({ ...session, insights: newInsights });
  };

  return (
    <div className="min-h-screen bg-white">
      <ConfirmationModal 
        isOpen={isDeleteModalOpen}
        title="Delete Session?"
        message="This action is permanent and cannot be undone."
        onConfirm={() => { appStore.deleteSession(sessionId); onBack(); }}
        onCancel={() => setIsDeleteModalOpen(false)}
      />

      {/* Detail Header - Airbnb Style */}
      <div className="bg-white px-6 pt-12 pb-6 sticky top-0 z-40 border-b border-gray-100">
        <div className="flex justify-between items-center mb-8">
          <button onClick={onBack} className="w-10 h-10 bg-white border border-gray-200 rounded-full flex items-center justify-center airbnb-card-shadow active:scale-95 transition-soft">
            <ChevronRightIcon size={20} className="rotate-180" />
          </button>
          <div className="flex space-x-2">
            <button 
              onClick={() => appStore.togglePinSession(sessionId)} 
              className={`w-10 h-10 border border-gray-200 rounded-full flex items-center justify-center airbnb-card-shadow active:scale-95 transition-soft ${session.isPinned ? 'text-[#FF385C] bg-rose-50 border-rose-100' : 'bg-white'}`}
            >
              <SparkIcon size={18} />
            </button>
            <button onClick={() => setShowMoveModal(true)} className="px-4 py-2 bg-white border border-gray-200 rounded-full text-sm font-bold active:scale-95 transition-soft">Move</button>
            <button onClick={() => setIsDeleteModalOpen(true)} className="w-10 h-10 bg-white border border-gray-200 rounded-full flex items-center justify-center text-rose-500 active:scale-95 transition-soft"><TrashIcon size={18} /></button>
          </div>
        </div>

        <div className="space-y-4">
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: currentEvent?.color }} />
            <span className="text-sm font-bold text-[#717171] uppercase tracking-widest">{currentEvent?.name}</span>
          </div>
          
          {isEditingName ? (
            <input 
              autoFocus
              className="text-3xl font-extrabold text-[#222222] w-full outline-none border-b-2 border-[#222222] pb-1"
              value={newName}
              onChange={e => setNewName(e.target.value)}
              onBlur={() => { appStore.updateSession({...session, title: newName}); setIsEditingName(false); }}
            />
          ) : (
            <h1 onClick={() => setIsEditingName(true)} className="text-3xl font-extrabold text-[#222222] tracking-tight leading-none cursor-text">{session.title}</h1>
          )}

          <div className="flex items-center space-x-4 text-sm font-medium text-[#717171]">
            <span className="flex items-center"><CalendarIcon size={14} className="mr-1.5" /> {new Date(session.date).toLocaleDateString()}</span>
            <span>•</span>
            <span className="flex items-center"><MicIcon size={14} className="mr-1.5" /> {Math.floor(session.duration / 60)}m {Math.floor(session.duration % 60)}s</span>
          </div>
        </div>

        <div className="mt-10 flex space-x-8 border-b border-gray-100">
           <button onClick={() => setActiveTab('insights')} className={`pb-4 text-sm font-extrabold transition-soft ${activeTab === 'insights' ? 'text-[#222222] border-b-2 border-[#222222]' : 'text-[#717171]'}`}>Insights</button>
           <button onClick={() => setActiveTab('transcript')} className={`pb-4 text-sm font-extrabold transition-soft ${activeTab === 'transcript' ? 'text-[#222222] border-b-2 border-[#222222]' : 'text-[#717171]'}`}>Transcript</button>
        </div>
      </div>

      <div className="max-w-3xl mx-auto p-6 pt-10 pb-40">
        {activeTab === 'insights' ? (
          <div className="space-y-16">
            {/* Summary */}
            <section className="space-y-6">
              <h2 className="text-2xl font-extrabold text-[#222222]">Analysis Summary</h2>
              <div className="airbnb-surface p-8 rounded-[2rem] border border-gray-100">
                <p className="text-lg font-medium text-[#222222] leading-relaxed">{session.insights?.summary.text}</p>
              </div>
            </section>

            {/* Flashcards */}
            {session.insights?.flashcards && session.insights.flashcards.length > 0 && (
              <section className="space-y-8">
                <div className="flex justify-between items-center">
                  <h2 className="text-2xl font-extrabold text-[#222222]">Knowledge Cards</h2>
                  <button onClick={() => setEditInsight({ type: 'flashcard', isNew: true, data: { q: '', a: '' } })} className="bg-[#222222] text-white p-2 rounded-full airbnb-shadow active:scale-95 transition-soft"><PlusIcon size={20} /></button>
                </div>
                <FlashcardViewer 
                  flashcards={session.insights.flashcards} 
                  onEdit={(i) => setEditInsight({ type: 'flashcard', index: i, data: session.insights!.flashcards[i] })} 
                  onDelete={(i) => handleDeleteInsight('flashcard', i)} 
                  onTogglePin={(i) => handleTogglePinInsight('flashcard', i)}
                />
              </section>
            )}

            {/* Key Concepts */}
            {session.insights?.keyTerms && session.insights.keyTerms.length > 0 && (
              <section className="space-y-8">
                <div className="flex justify-between items-center">
                  <h2 className="text-2xl font-extrabold text-[#222222]">Key Concepts</h2>
                  <button onClick={() => setEditInsight({ type: 'keyterm', isNew: true, data: { term: '', definition: '' } })} className="bg-[#222222] text-white p-2 rounded-full airbnb-shadow active:scale-95 transition-soft"><PlusIcon size={20} /></button>
                </div>
                <div className="grid gap-6">
                  {session.insights?.keyTerms.map((term, i) => (
                    <div key={i} className="bg-white border border-gray-200 p-8 rounded-[2rem] airbnb-card-shadow relative group">
                      <div className="flex justify-between items-start mb-2">
                         <div className="flex items-center space-x-2">
                           <h4 className="text-xl font-extrabold text-[#FF385C]">{term.term}</h4>
                           {term.isPinned && <SparkIcon size={14} className="text-[#FF385C]" />}
                         </div>
                         <div className="flex space-x-1 opacity-0 group-hover:opacity-100 transition-soft">
                            <button onClick={() => handleTogglePinInsight('keyterm', i)} className={`p-2 hover:bg-gray-100 rounded-full transition-soft ${term.isPinned ? 'text-[#FF385C]' : ''}`}><SparkIcon size={16} /></button>
                            <button onClick={() => setEditInsight({ type: 'keyterm', index: i, data: term })} className="p-2 hover:bg-gray-100 rounded-full transition-soft"><EditIcon size={16} /></button>
                            <button onClick={() => handleDeleteInsight('keyterm', i)} className="p-2 hover:bg-rose-50 text-rose-500 rounded-full transition-soft"><TrashIcon size={16} /></button>
                         </div>
                      </div>
                      <p className="text-lg font-medium text-[#717171] leading-relaxed">{term.definition}</p>
                    </div>
                  ))}
                </div>
              </section>
            )}
          </div>
        ) : (
          <div className="space-y-12">
            {session.transcriptSegments.map((seg, i) => (
              <div key={i} onClick={() => setEditInsight({ type: 'transcript', index: i, data: { text: seg.text } })} className="group cursor-pointer">
                <div className="flex items-center space-x-4 mb-3">
                  <span className="text-xs font-black text-[#FF385C] bg-rose-50 px-3 py-1 rounded-full">{Math.floor(seg.startSec / 60)}:{(seg.startSec % 60).toString().padStart(2, '0')}</span>
                  <EditIcon size={14} className="text-gray-300 opacity-0 group-hover:opacity-100 transition-soft" />
                </div>
                <p className="text-xl font-medium text-[#222222] leading-relaxed">{seg.text}</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Shared Edit Modal */}
      {editInsight && (
        <div className="fixed inset-0 z-[500] bg-black/50 flex items-center justify-center p-6 animate-in fade-in duration-300">
          <div className="bg-white w-full max-w-lg rounded-[2.5rem] p-10 airbnb-shadow-large animate-in zoom-in-95 duration-300">
            <h2 className="text-2xl font-extrabold text-[#222222] mb-10 uppercase tracking-widest">Update {editInsight.type}</h2>
            <div className="space-y-6">
              {editInsight.type === 'flashcard' && (
                <>
                  <textarea placeholder="Question" className="w-full p-6 border border-gray-300 rounded-2xl text-lg font-medium outline-none focus:border-[#222222]" rows={3} value={editInsight.data.q} onChange={e => setEditInsight({...editInsight, data: {...editInsight.data, q: e.target.value}})} />
                  <textarea placeholder="Answer" className="w-full p-6 border border-gray-300 rounded-2xl text-lg font-medium outline-none focus:border-[#222222]" rows={3} value={editInsight.data.a} onChange={e => setEditInsight({...editInsight, data: {...editInsight.data, a: e.target.value}})} />
                </>
              )}
              {editInsight.type === 'keyterm' && (
                <>
                  <input placeholder="Concept" className="w-full p-6 border border-gray-300 rounded-2xl text-lg font-medium outline-none focus:border-[#222222]" value={editInsight.data.term} onChange={e => setEditInsight({...editInsight, data: {...editInsight.data, term: e.target.value}})} />
                  <textarea placeholder="Explanation" className="w-full p-6 border border-gray-300 rounded-2xl text-lg font-medium outline-none focus:border-[#222222]" rows={4} value={editInsight.data.definition} onChange={e => setEditInsight({...editInsight, data: {...editInsight.data, definition: e.target.value}})} />
                </>
              )}
              {editInsight.type === 'transcript' && (
                <textarea className="w-full p-6 border border-gray-300 rounded-2xl text-lg font-medium outline-none focus:border-[#222222]" rows={8} value={editInsight.data.text} onChange={e => setEditInsight({...editInsight, data: {...editInsight.data, text: e.target.value}})} />
              )}
              <div className="flex space-x-4 pt-6">
                <button onClick={() => setEditInsight(null)} className="flex-1 py-4 font-bold text-gray-500 hover:bg-gray-100 rounded-2xl transition-soft">Discard</button>
                <button onClick={handleSaveEdit} className="flex-[2] bg-[#FF385C] text-white py-4 rounded-2xl font-bold airbnb-shadow active:scale-95 transition-soft">Save Changes</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showMoveModal && (
        <div className="fixed inset-0 z-[500] bg-black/50 flex items-end justify-center animate-in fade-in duration-300">
          <div className="bg-white w-full max-w-lg rounded-t-[2.5rem] p-10 animate-in slide-in-from-bottom duration-300">
            <h2 className="text-2xl font-extrabold text-[#222222] mb-10">Select Destination</h2>
            <div className="space-y-4 max-h-96 overflow-y-auto pr-2">
              {events.map(event => (
                <button key={event.id} onClick={() => { appStore.moveSession(sessionId, event.id); setShowMoveModal(false); }} className={`w-full flex items-center p-6 rounded-2xl border-2 transition-soft text-left ${session.eventId === event.id ? 'border-[#FF385C] bg-rose-50' : 'border-gray-100 bg-white hover:border-[#222222]'}`}>
                  <div className="w-4 h-4 rounded-full mr-4" style={{ backgroundColor: event.color }} />
                  <span className="text-lg font-bold text-[#222222]">{event.name}</span>
                </button>
              ))}
            </div>
            <button onClick={() => setShowMoveModal(false)} className="w-full mt-10 py-4 font-bold text-gray-400">Cancel</button>
          </div>
        </div>
      )}
    </div>
  );
};

export default SessionDetailView;
