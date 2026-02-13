
import React from 'react';
import { appStore } from '../store/appStore';
import { PlusIcon, ChevronRightIcon } from '../components/Icons';

interface EventsViewProps {
  onSessionSelect: (id: string) => void;
}

const EventsView: React.FC<EventsViewProps> = ({ onSessionSelect }) => {
  const events = appStore.getEvents();

  return (
    <div className="p-6 pt-12 max-w-2xl mx-auto space-y-8">
      <header className="flex justify-between items-end">
        <div>
          <h1 className="text-3xl font-black text-gray-900 mb-1">Your Events</h1>
          <p className="text-gray-500">Organized study materials</p>
        </div>
        <button className="bg-blue-600 text-white p-3 rounded-2xl shadow-lg shadow-blue-100 active:scale-90 transition-all">
          <PlusIcon size={20} />
        </button>
      </header>

      <div className="grid grid-cols-1 gap-6">
        {events.map(event => (
          <div key={event.id} className="bg-white rounded-[2rem] border border-gray-100 shadow-sm overflow-hidden">
            <div className="p-6 pb-4 flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className="w-12 h-12 rounded-2xl flex items-center justify-center text-white font-black text-xl shadow-lg" style={{ backgroundColor: event.color }}>
                  {event.name.charAt(0)}
                </div>
                <div>
                  <h2 className="text-xl font-black text-gray-800">{event.name}</h2>
                  <p className="text-xs text-gray-400 font-bold uppercase tracking-wider">{event.sessionIds.length} Sessions</p>
                </div>
              </div>
            </div>

            <div className="bg-gray-50/50 p-2 space-y-2">
              {event.sessionIds.length > 0 ? (
                event.sessionIds.slice(0, 3).map(sid => {
                  const session = appStore.getSession(sid);
                  if (!session) return null;
                  return (
                    <button 
                      key={sid}
                      onClick={() => onSessionSelect(sid)}
                      className="w-full flex items-center justify-between p-4 bg-white rounded-2xl border border-gray-100 hover:shadow-sm transition-all text-left"
                    >
                      <div>
                        <p className="text-sm font-bold text-gray-700">{session.title}</p>
                        <p className="text-[10px] text-gray-400">{new Date(session.date).toLocaleDateString()}</p>
                      </div>
                      <ChevronRightIcon size={16} className="text-gray-300" />
                    </button>
                  );
                })
              ) : (
                <div className="py-8 text-center">
                  <p className="text-sm text-gray-400 font-medium">No sessions in this event</p>
                </div>
              )}
              {event.sessionIds.length > 3 && (
                <button className="w-full py-3 text-xs font-black text-blue-600 uppercase tracking-widest">
                  See {event.sessionIds.length - 3} more...
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default EventsView;
