
import React, { useState, useMemo } from 'react';
import { appStore } from '../store/appStore';
import { Flashcard, KeyTerm, Session, Event } from '../types';
import { SortIcon, BookIcon, ChevronRightIcon, MicIcon, PlusIcon, LightbulbIcon } from '../components/Icons';

interface InsightsViewProps {
  onSessionSelect: (id: string) => void;
}

// Fixed: Using React.FC to properly handle reserved props like 'key'
const FlashcardItem: React.FC<{ card: Flashcard }> = ({ card }) => {
  const [flipped, setFlipped] = useState(false);
  return (
    <div 
      onClick={(e) => { e.stopPropagation(); setFlipped(!flipped); }}
      className={`p-6 rounded-2xl border transition-soft cursor-pointer relative overflow-hidden group ${flipped ? 'bg-[#222222] border-[#222222] text-white' : 'bg-gray-50 border-gray-100 text-[#222222]'}`}
    >
      <div className="flex justify-between items-start mb-3">
        <p className={`text-[10px] font-black uppercase tracking-[0.1em] ${flipped ? 'text-rose-400' : 'text-[#FF385C]'}`}>
          {flipped ? 'Revealed' : 'Flashcard'}
        </p>
        {(card.isUserCreated || card.isEdited) && <span className="text-[9px] font-bold text-[#717171]">Personal Entry</span>}
      </div>
      <p className="text-lg font-bold leading-tight min-h-[3rem]">
        {flipped ? card.a : card.q}
      </p>
      <div className="mt-4 pt-4 border-t border-gray-200/50 flex justify-between items-center">
        <span className="text-xs font-bold underline opacity-60">Tap to flip</span>
        <div className={`w-2 h-2 rounded-full ${flipped ? 'bg-rose-500' : 'bg-gray-300'}`} />
      </div>
    </div>
  );
};

const InsightsView: React.FC<InsightsViewProps> = ({ onSessionSelect }) => {
  const sessions = appStore.getSessions().filter(s => !!s.insights);
  const events = appStore.getEvents();
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<'concepts' | 'flashcards'>('flashcards');
  const [sortBy, setSortBy] = useState<'date' | 'alphabetical'>('date');
  
  const [showManualEntry, setShowManualEntry] = useState(false);
  const [manualType, setManualType] = useState<'concept' | 'flashcard'>('flashcard');
  const [manualEventId, setManualEventId] = useState(events[0]?.id || '');
  const [manualData, setManualData] = useState({ q: '', a: '', term: '', definition: '' });

  const totalFlashcards = sessions.reduce((acc, s) => acc + (s.insights?.flashcards.length || 0), 0);
  const totalKeyTerms = sessions.reduce((acc, s) => acc + (s.insights?.keyTerms.length || 0), 0);

  const displayedSessions = useMemo(() => {
    let base = [...sessions];
    
    // Sort logic
    if (sortBy === 'date') base.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
    else base.sort((a, b) => a.title.localeCompare(b.title));

    // Search Filtering
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      base = base.map(s => {
        const filteredInsights = { ...s.insights! };
        if (filterType === 'concepts') {
          filteredInsights.keyTerms = filteredInsights.keyTerms.filter(t => t.term.toLowerCase().includes(q) || t.definition.toLowerCase().includes(q));
        } else {
          filteredInsights.flashcards = filteredInsights.flashcards.filter(f => f.q.toLowerCase().includes(q) || f.a.toLowerCase().includes(q));
        }
        return { ...s, insights: filteredInsights };
      }).filter(s => {
        const items = filterType === 'concepts' ? s.insights?.keyTerms : s.insights?.flashcards;
        return items && items.length > 0;
      });
    }

    return base;
  }, [sessions, sortBy, searchQuery, filterType]);

  const handleSaveManual = () => {
    const eventSessions = appStore.getSessions().filter(s => s.eventId === manualEventId);
    let manualSession = eventSessions.find(s => s.title === 'Manual Knowledge Entries');
    
    if (!manualSession) {
      manualSession = {
        id: `sess-manual-${Date.now()}`,
        eventId: manualEventId,
        title: 'Manual Knowledge Entries',
        date: new Date().toISOString(),
        audioUrl: '',
        duration: 0,
        transcript: 'Manually added insights',
        transcriptSegments: [],
        insights: {
          summary: { text: 'Compilation of manually added insights and study cards.', confidence: 1.0, sourceSegments: [] },
          bullets: [],
          notesOutline: [],
          keyTerms: [],
          flashcards: [],
          practiceQuestions: [],
          actionItems: [],
          timeline: [],
          generatedAt: new Date().toISOString()
        },
        status: 'ready'
      };
      appStore.addSession(manualSession);
    }

    const updatedInsights = { ...manualSession.insights! };
    if (manualType === 'flashcard') {
      updatedInsights.flashcards.push({
        q: manualData.q,
        a: manualData.a,
        confidence: 1.0,
        sourceSegments: [],
        isUserCreated: true
      });
    } else {
      updatedInsights.keyTerms.push({
        term: manualData.term,
        definition: manualData.definition,
        confidence: 1.0,
        sourceSegments: [],
        isUserCreated: true
      });
    }

    appStore.updateSession({ ...manualSession, insights: updatedInsights });
    setShowManualEntry(false);
    setManualData({ q: '', a: '', term: '', definition: '' });
  };

  return (
    <div className="min-h-screen bg-white p-6 pt-16 pb-40 max-w-2xl mx-auto space-y-10">
      <header className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-extrabold text-[#222222] tracking-tight">Intelligence</h1>
          <p className="text-[#717171] text-lg font-medium">Aggregated Knowledge</p>
        </div>
        <button 
          onClick={() => setShowManualEntry(true)}
          className="bg-[#222222] text-white w-12 h-12 rounded-full flex items-center justify-center airbnb-shadow active:scale-95 transition-soft"
        >
          <PlusIcon size={20} />
        </button>
      </header>

      {/* Tabs with Counts */}
      <div className="grid grid-cols-2 gap-4">
        <button 
          onClick={() => setFilterType('flashcards')}
          className={`p-6 rounded-3xl transition-all text-left border-2 ${filterType === 'flashcards' ? 'bg-[#FF385C] border-[#FF385C] text-white airbnb-shadow' : 'bg-white text-[#222222] border-gray-100 hover:border-gray-200'}`}
        >
          <span className="text-3xl font-black block mb-1">{totalFlashcards}</span>
          <span className="text-[10px] font-black uppercase tracking-widest opacity-80">Flashcards</span>
        </button>
        <button 
          onClick={() => setFilterType('concepts')}
          className={`p-6 rounded-3xl transition-all text-left border-2 ${filterType === 'concepts' ? 'bg-[#222222] border-[#222222] text-white airbnb-shadow' : 'bg-white text-[#222222] border-gray-100 hover:border-gray-200'}`}
        >
          <span className="text-3xl font-black block mb-1">{totalKeyTerms}</span>
          <span className="text-[10px] font-black uppercase tracking-widest opacity-80">Concepts</span>
        </button>
      </div>

      {/* Search and Sort */}
      <div className="space-y-4">
        <input 
          type="text"
          placeholder={`Search ${filterType}...`}
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full bg-[#F7F7F7] border border-transparent focus:border-gray-200 rounded-2xl px-5 py-3.5 font-medium outline-none transition-soft"
        />
        <div className="flex justify-between items-center">
          <h3 className="text-sm font-black text-[#222222] uppercase tracking-widest">
            {filterType === 'concepts' ? 'Vocabulary & Definitions' : 'Active Learning Cards'}
          </h3>
          <button 
            onClick={() => setSortBy(sortBy === 'date' ? 'alphabetical' : 'date')}
            className="text-xs font-bold text-[#717171] flex items-center hover:text-[#222222] transition-colors"
          >
            <SortIcon size={14} className="mr-1.5" />
            {sortBy === 'date' ? 'By Date' : 'A-Z'}
          </button>
        </div>
      </div>

      <section className="space-y-12">
        {displayedSessions.length > 0 ? (
          displayedSessions.map((session) => {
            const items = filterType === 'concepts' ? session.insights?.keyTerms : session.insights?.flashcards;
            if (!items || items.length === 0) return null;

            return (
              <div key={session.id} className="space-y-5 animate-in fade-in duration-500">
                <div className="flex items-center justify-between group cursor-pointer border-b border-gray-50 pb-2" onClick={() => onSessionSelect(session.id)}>
                  <div className="flex items-center space-x-3">
                    <div className="w-2.5 h-2.5 rounded-full bg-rose-200" />
                    <h4 className="font-bold text-[#222222] text-sm truncate max-w-[220px]">{session.title}</h4>
                  </div>
                  <ChevronRightIcon size={14} className="text-[#717171] transition-transform group-hover:translate-x-1" />
                </div>

                <div className="grid gap-4">
                  {filterType === 'concepts' ? (
                    (items as KeyTerm[]).map((term, i) => (
                      <div key={i} className="bg-white p-6 rounded-2xl border border-gray-100 airbnb-card-shadow">
                        <h5 className="text-lg font-extrabold text-[#FF385C] mb-2">{term.term}</h5>
                        <p className="text-sm font-medium text-[#717171] leading-relaxed">{term.definition}</p>
                      </div>
                    ))
                  ) : (
                    (items as Flashcard[]).map((card, i) => <FlashcardItem key={i} card={card} />)
                  )}
                </div>
              </div>
            );
          })
        ) : (
          <div className="py-24 text-center airbnb-surface rounded-[2rem] border-2 border-dashed border-gray-200">
            <LightbulbIcon size={48} className="mx-auto text-gray-200 mb-4" />
            <p className="text-[#717171] font-bold text-lg">No findings</p>
            <p className="text-[#717171] text-sm font-medium mt-1">Try adjusting your search query</p>
          </div>
        )}
      </section>

      {/* Manual Entry Modal */}
      {showManualEntry && (
        <div className="fixed inset-0 z-[110] bg-black/50 flex items-end sm:items-center justify-center animate-in fade-in duration-300 p-4">
          <div className="bg-white w-full max-w-lg rounded-[2.5rem] p-10 airbnb-shadow-large animate-in slide-in-from-bottom duration-300">
            <h2 className="text-2xl font-extrabold text-[#222222] mb-8">Add Insight</h2>
            
            <div className="space-y-6">
              <div className="flex bg-gray-100 p-1 rounded-2xl">
                <button 
                  onClick={() => setManualType('flashcard')}
                  className={`flex-1 py-3 text-sm font-bold rounded-xl transition-soft ${manualType === 'flashcard' ? 'bg-white text-[#222222] shadow-sm' : 'text-[#717171]'}`}
                >
                  Flashcard
                </button>
                <button 
                  onClick={() => setManualType('concept')}
                  className={`flex-1 py-3 text-sm font-bold rounded-xl transition-soft ${manualType === 'concept' ? 'bg-white text-[#222222] shadow-sm' : 'text-[#717171]'}`}
                >
                  Concept
                </button>
              </div>

              <div>
                <p className="text-xs font-bold text-[#717171] uppercase tracking-widest mb-2 ml-1">Destination Unit</p>
                <select 
                  value={manualEventId}
                  onChange={e => setManualEventId(e.target.value)}
                  className="w-full bg-white border border-gray-300 p-4 rounded-2xl font-bold text-[#222222] outline-none appearance-none"
                >
                  {events.map(e => <option key={e.id} value={e.id}>{e.name}</option>)}
                </select>
              </div>

              {manualType === 'flashcard' ? (
                <>
                  <textarea 
                    placeholder="Question..." 
                    className="w-full bg-white border border-gray-300 p-5 rounded-2xl font-bold text-lg outline-none focus:border-[#222222]"
                    rows={2}
                    value={manualData.q}
                    onChange={e => setManualData({...manualData, q: e.target.value})}
                  />
                  <textarea 
                    placeholder="Answer..." 
                    className="w-full bg-white border border-gray-300 p-5 rounded-2xl font-bold text-lg outline-none focus:border-[#222222]"
                    rows={3}
                    value={manualData.a}
                    onChange={e => setManualData({...manualData, a: e.target.value})}
                  />
                </>
              ) : (
                <>
                  <input 
                    placeholder="Concept Title" 
                    className="w-full bg-white border border-gray-300 p-5 rounded-2xl font-bold text-lg outline-none focus:border-[#222222]"
                    value={manualData.term}
                    onChange={e => setManualData({...manualData, term: e.target.value})}
                  />
                  <textarea 
                    placeholder="Detailed Description" 
                    className="w-full bg-white border border-gray-300 p-5 rounded-2xl font-bold text-lg outline-none focus:border-[#222222]"
                    rows={4}
                    value={manualData.definition}
                    onChange={e => setManualData({...manualData, definition: e.target.value})}
                  />
                </>
              )}

              <div className="flex space-x-4 pt-4">
                <button onClick={() => setShowManualEntry(false)} className="flex-1 py-4 font-bold text-[#717171]">Discard</button>
                <button onClick={handleSaveManual} className="flex-[2] bg-[#FF385C] text-white py-4 rounded-2xl font-bold airbnb-shadow active:scale-95 transition-soft">Save Insight</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default InsightsView;
