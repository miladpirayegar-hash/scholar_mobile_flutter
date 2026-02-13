import React, { useState, useEffect, useRef } from 'react';
import { Event, Session } from '../types';
import { audioRecorder } from '../services/audioService';
import { appStore } from '../store/appStore';
import { SquareIcon, PauseIcon, PlayIcon } from '../components/Icons';

async function uploadAudioToBackend(blob: Blob, eventId: string) {
  const formData = new FormData();
  formData.append('audio', blob);
  formData.append('eventId', eventId);
  formData.append('title', 'New Capture');

  const response = await fetch('http://localhost:8080/api/sessions', {
    method: 'POST',
    body: formData
  });

  if (!response.ok) {
    throw new Error('Failed to upload audio');
  }

  return response.json();
}

async function fetchSessionStatus(sessionId: string) {
  const res = await fetch(`http://localhost:8080/api/sessions/${sessionId}/status`);
  if (!res.ok) throw new Error('Failed to fetch status');
  return res.json();
}

async function fetchFullSession(sessionId: string) {
  const res = await fetch(`http://localhost:8080/api/sessions/${sessionId}`);
  if (!res.ok) throw new Error('Failed to fetch session');
  return res.json();
}

interface RecordingViewProps {
  event: Event;
  onFinished: () => void;
}

const RecordingView: React.FC<RecordingViewProps> = ({ event, onFinished }) => {
  const [elapsed, setElapsed] = useState(0);
  const [isPaused, setIsPaused] = useState(false);
  const [meter, setMeter] = useState(0);
  
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const requestRef = useRef<number | undefined>(undefined);
  const isPausedRef = useRef(false);

  // Sync ref with state for the animation loop
  useEffect(() => {
    isPausedRef.current = isPaused;
    if (isPaused) {
      audioRecorder.pause();
    } else if (audioRecorder.getState() === 'paused') {
      audioRecorder.resume();
    }
  }, [isPaused]);

  useEffect(() => {
    const start = async () => {
      try {
        await audioRecorder.start('default');
        animate();
      } catch (err) {
        console.error("Failed to start recording", err);
        alert("Could not access microphone. Please check permissions.");
        onFinished();
      }
    };
    start();

    const timer = setInterval(() => {
      // Direct check from recorder state to avoid stale closures and ensure accuracy
      if (audioRecorder.getState() === 'recording' && !isPausedRef.current) {
        setElapsed(prev => prev + 1);
      }
    }, 1000);

    return () => {
      clearInterval(timer);
      if (requestRef.current) cancelAnimationFrame(requestRef.current);
    };
  }, []);

  const animate = () => {
    // We always pull the latest meter/waveform data
    // Even if paused, audioRecorder handles returning "static" data
    const m = audioRecorder.getMeterData();
    const waveform = audioRecorder.getWaveformData();
    
    setMeter(m);
    drawWaveform(waveform);
    
    requestRef.current = requestAnimationFrame(animate);
  };

  const drawWaveform = (data: Uint8Array) => {
    if (!canvasRef.current) return;
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const width = canvas.width;
    const height = canvas.height;
    
    // Clear the canvas
    ctx.clearRect(0, 0, width, height);

    // If paused, we can either keep the last frame or draw a flat line.
    // The current getWaveformData returns 128 (flat) when paused.
    ctx.lineWidth = 3;
    ctx.strokeStyle = '#FF385C';
    ctx.lineCap = 'round';
    ctx.beginPath();

    const sliceWidth = width / data.length;
    let x = 0;

    for (let i = 0; i < data.length; i++) {
      const v = data[i] / 128.0;
      const y = (v * height) / 2;

      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);

      x += sliceWidth;
    }

    ctx.lineTo(width, height / 2);
    ctx.stroke();
  };

const handleStop = async () => {
  const { blob, duration } = await audioRecorder.stop();

  // Upload audio to backend
  try {
    const backendSession = await uploadAudioToBackend(blob, event.id);
    console.log('Uploaded to backend:', backendSession);
  } catch (err) {
    console.error('Upload failed', err);
  }

  // Create local session immediately for UI
  const sessionId = `sess-${Date.now()}`;
  const newSession: Session = {
    id: sessionId,
    eventId: event.id,
    title: `Capture ${new Date().toLocaleDateString()}`,
    date: new Date().toISOString(),
    audioUrl: URL.createObjectURL(blob),
    duration: duration,
    transcript: '',
    transcriptSegments: [],
    insights: null,
    status: 'processing'
  };

  appStore.addSession(newSession);
  onFinished();
};

  const formatTime = (s: number) => {
    const mins = Math.floor(s / 60);
    const secs = s % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="fixed inset-0 bg-white z-[200] flex flex-col items-center justify-between p-6 overflow-hidden animate-in fade-in slide-in-from-bottom duration-500">
      <div className="w-full text-center mt-6 sm:mt-10 space-y-2">
        <div className="flex items-center justify-center space-x-2">
          <div className={`w-2 h-2 bg-[#FF385C] rounded-full ${isPaused ? '' : 'animate-pulse'}`}></div>
          <span className="text-[10px] sm:text-xs font-bold text-[#FF385C] uppercase tracking-widest">
            {isPaused ? 'Recording Paused' : 'Live Capture'}
          </span>
        </div>
        <h1 className="text-2xl sm:text-3xl font-black text-[#222222] tracking-tight truncate px-4">{event.name}</h1>
        <p className="text-sm sm:text-base text-[#717171] font-medium">Recording academic content...</p>
      </div>

      <div className="w-full max-w-lg flex flex-col items-center justify-center space-y-8 sm:space-y-12 flex-1">
        <div className="text-[60px] sm:text-[100px] font-black text-[#222222] tabular-nums leading-none tracking-tighter">
          {formatTime(elapsed)}
        </div>

        <div className="w-full h-32 sm:h-40 airbnb-surface rounded-[2rem] relative overflow-hidden flex items-center justify-center border border-gray-100 airbnb-card-shadow mx-4">
          <canvas ref={canvasRef} width={500} height={200} className="w-full h-full" />
          {isPaused && (
            <div className="absolute inset-0 bg-white/40 backdrop-blur-md flex items-center justify-center">
              <span className="text-[#222222] font-black text-sm sm:text-xl uppercase tracking-widest">Suspended</span>
            </div>
          )}
        </div>

        <div className="w-full px-8 sm:px-12 flex flex-col items-center space-y-4">
          <div className="w-full h-1 bg-gray-100 rounded-full overflow-hidden">
            <div 
              className="h-full bg-[#FF385C] transition-all duration-75"
              style={{ width: `${isPaused ? 0 : meter * 100}%` }}
            ></div>
          </div>
          <div className="flex justify-between w-full text-[9px] sm:text-[11px] font-bold text-[#717171] uppercase tracking-widest">
            <span>Input Sensitivity</span>
            <span>{Math.round(meter * 100)}% active</span>
          </div>
        </div>
      </div>

      <div className="flex items-center space-x-8 sm:space-x-12 mb-10 sm:mb-16">
        <button 
          onClick={() => setIsPaused(!isPaused)}
          className={`w-14 h-14 sm:w-20 sm:h-20 rounded-full flex items-center justify-center transition-soft airbnb-shadow active:scale-90 ${isPaused ? 'bg-[#222222] text-white' : 'bg-gray-100 text-[#222222]'}`}
        >
          {isPaused ? <PlayIcon size={24} /> : <PauseIcon size={24} />}
        </button>

        <button 
          onClick={handleStop}
          className="w-16 h-16 sm:w-24 sm:h-24 rounded-full bg-[#FF385C] text-white flex items-center justify-center airbnb-shadow-large transition-soft active:scale-95"
        >
          <SquareIcon size={28} />
        </button>
      </div>
    </div>
  );
};

export default RecordingView;