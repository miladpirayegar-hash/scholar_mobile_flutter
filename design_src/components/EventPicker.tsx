import React, { useState } from 'react';
import { appStore } from '../store/appStore';
import { Event } from '../types';
import { PlusIcon } from './Icons';

interface EventPickerProps {
  onSelect: (event: Event) => void;
  onCancel: () => void;
}

const EventPicker: React.FC<EventPickerProps> = ({ onSelect, onCancel }) => {
  const events = appStore.getEvents();
  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState('');

  const handleCreate = () => {
    if (!newName.trim()) return;
    const newEvent: Event = {
      id: `evt-${Date.now()}`,
      name: newName,
      description: '',
      color: '#FF385C',
      sessionIds: [],
      createdAt: new Date().toISOString()
    };
    appStore.addEvent(newEvent);
    onSelect(newEvent);
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-end justify-center bg-black/50 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="bg-white w-full max-w-lg rounded-t-[2.5rem] p-10 animate-in slide-in-from-bottom duration-500">
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-2xl font-extrabold text-[#222222]">Destination Unit</h2>
          <button onClick={onCancel} className="w-10 h-10 flex items-center justify-center font-bold text-2xl">×</button>
        </div>

        <div className="space-y-4 max-h-96 overflow-y-auto pr-2 scrollbar-hide">
          {events.map(event => (
            <button
              key={event.id}
              onClick={() => onSelect(event)}
              className="w-full flex items-center p-5 bg-white border border-gray-100 rounded-2xl hover:border-[#222222] transition-soft airbnb-card-shadow group"
            >
              <div className="w-12 h-12 rounded-xl flex items-center justify-center mr-5 airbnb-shadow" style={{ backgroundColor: event.color }}>
                <span className="text-white font-black text-lg">{event.name.charAt(0)}</span>
              </div>
              <div className="text-left flex-1 min-w-0">
                <p className="font-bold text-[#222222] text-lg truncate">{event.name}</p>
                <p className="text-sm font-medium text-[#717171]">{event.sessionIds.length} Captures</p>
              </div>
            </button>
          ))}
        </div>

        <div className="mt-8 pt-8 border-t border-gray-100">
          {showCreate ? (
            <div className="space-y-4">
              <input 
                autoFocus
                placeholder="Unit Identity..." 
                value={newName}
                onChange={e => setNewName(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleCreate()}
                className="w-full bg-white border border-gray-300 p-5 rounded-2xl font-bold text-lg outline-none focus:border-[#222222]"
              />
              <div className="flex space-x-4">
                <button onClick={() => setShowCreate(false)} className="flex-1 py-4 font-bold text-[#717171]">Cancel</button>
                <button onClick={handleCreate} className="flex-[2] bg-[#FF385C] text-white py-4 rounded-2xl font-bold airbnb-shadow">Initialize</button>
              </div>
            </div>
          ) : (
            <button 
              onClick={() => setShowCreate(true)}
              className="w-full flex items-center justify-center space-x-3 py-5 bg-[#F7F7F7] rounded-2xl font-bold text-[#222222] transition-soft hover:bg-gray-100"
            >
              <PlusIcon size={20} />
              <span>Create New Unit</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default EventPicker;