import React from 'react';
import { TrashIcon } from './Icons';

interface ConfirmationModalProps {
  isOpen: boolean;
  title: string;
  message: string;
  onConfirm: () => void;
  onCancel: () => void;
}

const ConfirmationModal: React.FC<ConfirmationModalProps> = ({ isOpen, title, message, onConfirm, onCancel }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[1000] flex items-center justify-center p-8 bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white w-full max-w-sm rounded-[2.5rem] p-10 airbnb-shadow-large animate-in zoom-in-95 duration-200">
        <div className="w-20 h-20 bg-rose-50 text-[#FF385C] rounded-full flex items-center justify-center mx-auto mb-8 airbnb-shadow">
          <TrashIcon size={36} />
        </div>
        <h2 className="text-2xl font-extrabold text-[#222222] text-center mb-3">{title}</h2>
        <p className="text-[#717171] text-center mb-10 font-medium leading-relaxed">
          {message}
        </p>
        <div className="flex flex-col space-y-3">
          <button 
            onClick={onConfirm}
            className="w-full bg-[#FF385C] text-white py-4 rounded-2xl font-bold text-lg airbnb-shadow active:scale-95 transition-soft"
          >
            Confirm
          </button>
          <button 
            onClick={onCancel}
            className="w-full py-4 text-[#222222] font-bold text-lg hover:bg-gray-100 rounded-2xl transition-soft"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmationModal;