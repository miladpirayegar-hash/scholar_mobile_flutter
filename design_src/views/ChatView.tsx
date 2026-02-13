
import React, { useState, useEffect, useRef } from 'react';
import { appStore } from '../store/appStore';
import { ChatMessage, Session, Task } from '../types';
import { SendIcon, SparkIcon, MicIcon } from '../components/Icons';
import { GoogleGenAI } from "@google/genai";

const ChatView: React.FC = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const chatInstance = useRef<any>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  const initChat = async () => {
    const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
    const sessions = appStore.getSessions();
    const tasks = appStore.getTasks();

    // Prepare context
    const knowledgeBase = sessions.map(s => ({
      title: s.title,
      date: s.date,
      summary: s.insights?.summary.text || 'No summary available',
      keyTerms: s.insights?.keyTerms.map(t => t.term).join(', ') || 'N/A'
    }));

    const taskSummary = tasks.filter(t => !t.completed).map(t => t.text).join(', ');

    const systemInstruction = `
      You are "Syntra", a specialized academic mentor. 
      You help the student synthesize knowledge from their recorded sessions and archived materials in their Notebook.
      
      Student's Notebook Overview:
      ${JSON.stringify(knowledgeBase, null, 2)}
      
      Active To-Do List:
      ${taskSummary || 'No pending tasks.'}
      
      Guidelines:
      1. Be concise, intellectually challenging, and encouraging.
      2. When discussing content, refer specifically to the sessions in their Notebook.
      3. Use academic terminology but explain complex concepts simply if asked.
      4. Help prioritize tasks from their list.
      5. Maintain a clean, professional, and sophisticated tone.
    `;

    chatInstance.current = ai.chats.create({
      model: 'gemini-3-flash-preview',
      config: {
        systemInstruction: systemInstruction,
      },
    });

    if (messages.length === 0) {
      setMessages([{
        id: 'initial',
        role: 'model',
        text: knowledgeBase.length > 0 
          ? "I am Syntra. I've analyzed your Notebook archives. Which academic thread shall we pull today?"
          : "I am Syntra. Once you populate your Notebook with captures, I can help you synthesize deep connections. How can I assist you for now?",
        timestamp: new Date().toISOString()
      }]);
    }
  };

  useEffect(() => {
    initChat();
  }, []);

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;

    const userMsg: ChatMessage = {
      id: `u-${Date.now()}`,
      role: 'user',
      text: input,
      timestamp: new Date().toISOString()
    };

    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setIsLoading(true);

    try {
      if (!chatInstance.current) await initChat();
      
      const response = await chatInstance.current.sendMessage({ message: input });
      const modelMsg: ChatMessage = {
        id: `m-${Date.now()}`,
        role: 'model',
        text: response.text || "Apologies, I couldn't synthesize a response.",
        timestamp: new Date().toISOString()
      };
      setMessages(prev => [...prev, modelMsg]);
    } catch (err) {
      console.error("Chat Error:", err);
      const errorMsg: ChatMessage = {
        id: `e-${Date.now()}`,
        role: 'model',
        text: "My processing core is currently unreachable. Please check your connection.",
        timestamp: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMsg]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-full bg-white max-w-2xl mx-auto">
      <header className="px-6 pt-16 pb-6 border-b border-gray-100 bg-white/90 backdrop-blur-md sticky top-0 z-10">
        <h1 className="text-3xl font-extrabold text-[#222222] tracking-tight">Syntra</h1>
        <p className="text-[#717171] text-lg font-medium">Academic Mentor</p>
      </header>

      <div 
        ref={scrollRef}
        className="flex-1 overflow-y-auto p-6 space-y-6 scrollbar-hide"
      >
        {messages.map((msg) => (
          <div 
            key={msg.id}
            className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-[85%] rounded-[1.8rem] px-6 py-4 airbnb-card-shadow ${
              msg.role === 'user' 
                ? 'bg-[#222222] text-white rounded-tr-none' 
                : 'bg-[#F7F7F7] text-[#222222] rounded-tl-none border border-gray-100'
            }`}>
              <p className="text-[15px] leading-relaxed font-medium whitespace-pre-wrap">{msg.text}</p>
              <p className={`text-[10px] mt-2 font-bold opacity-40 ${msg.role === 'user' ? 'text-right' : 'text-left'}`}>
                {new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
              </p>
            </div>
          </div>
        ))}
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-[#F7F7F7] rounded-[1.8rem] rounded-tl-none px-6 py-4 airbnb-card-shadow">
              <div className="flex space-x-1.5">
                <div className="w-2 h-2 bg-[#FF385C] rounded-full animate-bounce" style={{ animationDelay: '0s' }} />
                <div className="w-2 h-2 bg-[#FF385C] rounded-full animate-bounce" style={{ animationDelay: '0.2s' }} />
                <div className="w-2 h-2 bg-[#FF385C] rounded-full animate-bounce" style={{ animationDelay: '0.4s' }} />
              </div>
            </div>
          </div>
        )}
      </div>

      <div className="p-6 pb-32 bg-white">
        <div className="relative flex items-center">
          <textarea
            rows={1}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                handleSend();
              }
            }}
            placeholder="Review a session or ask a question..."
            className="w-full bg-[#F7F7F7] border border-transparent focus:border-gray-200 rounded-[2rem] pl-6 pr-16 py-4 font-medium text-[#222222] outline-none transition-soft airbnb-card-shadow"
            style={{ resize: 'none' }}
          />
          <button 
            onClick={handleSend}
            disabled={!input.trim() || isLoading}
            className="absolute right-3 top-1/2 -translate-y-1/2 w-11 h-11 bg-[#FF385C] text-white rounded-full flex items-center justify-center airbnb-shadow active:scale-90 disabled:opacity-30 disabled:grayscale transition-soft shadow-rose-200"
          >
            <SendIcon size={20} />
          </button>
        </div>
      </div>
    </div>
  );
};

export default ChatView;
