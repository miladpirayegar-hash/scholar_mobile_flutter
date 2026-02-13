
import React, { useState, useEffect } from 'react';
import { appStore } from '../store/appStore';
import { MicIcon, ChevronRightIcon, SettingsIcon, UserIcon, BellIcon, DownloadIcon, EditIcon, LogOutIcon } from '../components/Icons';
import { audioRecorder } from '../services/audioService';

interface SettingsViewProps {
  onBack: () => void;
}

const SettingsView: React.FC<SettingsViewProps> = ({ onBack }) => {
  const [settings, setSettings] = useState(appStore.getSettings());
  const [user, setUser] = useState(appStore.getUser());
  const [devices, setDevices] = useState<MediaDeviceInfo[]>([]);
  const [isTesting, setIsTesting] = useState(false);
  const [testLevel, setTestLevel] = useState(0);
  
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [authMode, setAuthMode] = useState<'login' | 'signup'>('signup');
  
  // Auth Form State
  const [emailInput, setEmailInput] = useState('');
  const [nameInput, setNameInput] = useState('');

  // Profile Form State
  const [profileForm, setProfileForm] = useState({
    name: user.name,
    institution: user.institution || '',
    degree: user.degree || '',
    level: user.level || '',
    major: user.major || ''
  });

  useEffect(() => {
    navigator.mediaDevices.enumerateDevices().then(d => {
      setDevices(d.filter(device => device.kind === 'audioinput'));
    });
  }, []);

  const handleUpdate = (updates: Partial<typeof settings>) => {
    const newSettings = { ...settings, ...updates };
    setSettings(newSettings);
    appStore.updateSettings(newSettings);
  };

  const handleAuth = (e: React.FormEvent) => {
    e.preventDefault();
    if (authMode === 'signup') {
      if (emailInput && nameInput) {
        appStore.login(emailInput, nameInput);
        setUser(appStore.getUser());
        setShowAuthModal(false);
      }
    } else {
      if (emailInput) {
        appStore.login(emailInput);
        setUser(appStore.getUser());
        setShowAuthModal(false);
      }
    }
  };

  const handleProfileSave = (e: React.FormEvent) => {
    e.preventDefault();
    appStore.updateUser(profileForm);
    setUser(appStore.getUser());
    setShowProfileModal(false);
  };

  const startMicTest = async () => {
    setIsTesting(true);
    await audioRecorder.start(settings.micConfig.deviceId);
    const interval = setInterval(() => setTestLevel(audioRecorder.getMeterData()), 50);
    setTimeout(async () => {
      clearInterval(interval);
      await audioRecorder.stop();
      setIsTesting(false);
      setTestLevel(0);
    }, 4000);
  };

  const SettingRow = ({ 
    icon: Icon, 
    label, 
    description, 
    action, 
    valueNode 
  }: { 
    icon: any, 
    label: string, 
    description?: string, 
    action?: () => void, 
    valueNode?: React.ReactNode 
  }) => (
    <div 
      onClick={action}
      className={`flex items-center justify-between p-5 border border-gray-100 rounded-[1.5rem] airbnb-card-shadow transition-soft active:scale-[0.98] bg-white cursor-pointer group`}
    >
      <div className="flex items-center space-x-4">
        <div className="w-10 h-10 rounded-xl bg-gray-50 flex items-center justify-center text-[#222222] group-hover:bg-[#FF385C] group-hover:text-white transition-soft">
          <Icon size={18} />
        </div>
        <div>
          <p className="font-bold text-[#222222] text-sm leading-tight">{label}</p>
          {description && <p className="text-[11px] text-[#717171] font-medium mt-0.5">{description}</p>}
        </div>
      </div>
      <div className="flex items-center space-x-2">
        {valueNode}
        {!valueNode && <ChevronRightIcon size={16} className="text-gray-300" />}
      </div>
    </div>
  );

  const Toggle = ({ active, onToggle }: { active: boolean, onToggle: () => void }) => (
    <button 
      onClick={(e) => { e.stopPropagation(); onToggle(); }}
      className={`w-12 h-7 rounded-full transition-soft relative ${active ? 'bg-[#FF385C]' : 'bg-gray-200'}`}
    >
      <div className={`absolute top-1 w-5 h-5 bg-white rounded-full shadow-sm transition-soft ${active ? 'left-6' : 'left-1'}`} />
    </button>
  );

  return (
    <div className="p-6 pt-16 max-w-2xl mx-auto space-y-12 pb-40 bg-white min-h-screen relative">
      <header className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <button onClick={onBack} className="w-10 h-10 border border-gray-200 rounded-full flex items-center justify-center airbnb-card-shadow transition-soft active:scale-90">
            <ChevronRightIcon size={20} className="rotate-180" />
          </button>
          <h1 className="text-3xl font-extrabold text-[#222222] tracking-tight">Settings</h1>
        </div>
        <SettingsIcon size={24} className="text-gray-200" />
      </header>

      {/* Account Section */}
      <section className="space-y-4">
        <div className="flex justify-between items-end px-2">
          <h2 className="text-[10px] font-black uppercase tracking-widest text-[#717171]">Account & Profile</h2>
          {user.isLoggedIn && (
            <button 
              onClick={() => setShowProfileModal(true)}
              className="text-[10px] font-black uppercase tracking-widest text-[#FF385C] underline"
            >
              Edit Academic Info
            </button>
          )}
        </div>
        
        {user.isLoggedIn ? (
          <div className="p-6 bg-gray-900 rounded-[2rem] text-white flex flex-col space-y-6 airbnb-shadow-large">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className="w-14 h-14 bg-[#FF385C] rounded-2xl flex items-center justify-center font-black text-xl shadow-lg">
                  {user.name.charAt(0)}
                </div>
                <div>
                  <p className="font-black text-lg leading-tight">{user.name}</p>
                  <p className="text-xs text-gray-400">{user.email}</p>
                </div>
              </div>
              <button 
                onClick={() => {
                  appStore.logout();
                  setUser(appStore.getUser());
                }} 
                className="w-10 h-10 bg-white/10 rounded-full flex items-center justify-center hover:bg-white/20 transition-soft"
                title="Logout"
              >
                <LogOutIcon size={18} />
              </button>
            </div>
            
            {(user.institution || user.degree || user.major) && (
              <div className="grid grid-cols-2 gap-4 pt-4 border-t border-white/10">
                {user.institution && (
                  <div>
                    <p className="text-[9px] font-bold text-gray-500 uppercase tracking-widest">Institution</p>
                    <p className="text-xs font-bold truncate">{user.institution}</p>
                  </div>
                )}
                {user.major && (
                  <div>
                    <p className="text-[9px] font-bold text-gray-500 uppercase tracking-widest">Major/Field</p>
                    <p className="text-xs font-bold truncate">{user.major}</p>
                  </div>
                )}
                {user.degree && (
                  <div>
                    <p className="text-[9px] font-bold text-gray-500 uppercase tracking-widest">Degree</p>
                    <p className="text-xs font-bold truncate">{user.degree}</p>
                  </div>
                )}
                {user.level && (
                  <div>
                    <p className="text-[9px] font-bold text-gray-500 uppercase tracking-widest">Academic Level</p>
                    <p className="text-xs font-bold truncate">{user.level}</p>
                  </div>
                )}
              </div>
            )}
          </div>
        ) : (
          <div 
            onClick={() => {
              setAuthMode('signup');
              setShowAuthModal(true);
            }}
            className="p-6 bg-gradient-to-br from-[#FF385C] to-[#E31C5F] rounded-[2rem] text-white flex items-center justify-between airbnb-shadow-large cursor-pointer active:scale-95 transition-soft"
          >
            <div className="flex items-center space-x-4">
              <div className="w-12 h-12 bg-white/20 rounded-2xl flex items-center justify-center">
                <UserIcon size={24} />
              </div>
              <div>
                <p className="font-black text-lg leading-tight">Sync & Backup</p>
                <p className="text-xs text-white/80">Login or Sign up to protect data</p>
              </div>
            </div>
            <ChevronRightIcon size={20} />
          </div>
        )}
      </section>

      {/* Hardware & Capture */}
      <section className="space-y-4">
        <h2 className="text-[10px] font-black uppercase tracking-widest text-[#717171] ml-2">Hardware Controls</h2>
        <div className="space-y-3">
          <div className="space-y-1.5 px-1">
            <p className="text-[11px] font-bold text-[#222222]">Preferred Mic</p>
            <div className="relative">
              <select 
                value={settings.micConfig.deviceId}
                onChange={e => handleUpdate({ micConfig: { ...settings.micConfig, deviceId: e.target.value } })}
                className="w-full bg-[#F7F7F7] border border-transparent focus:border-gray-200 p-4 rounded-xl font-bold text-sm outline-none appearance-none pr-10"
              >
                {devices.map(d => <option key={d.deviceId} value={d.deviceId}>{d.label || 'Default Mic'}</option>)}
              </select>
              <div className="absolute right-4 top-1/2 -translate-y-1/2 pointer-events-none">
                <ChevronRightIcon size={14} className="rotate-90 text-gray-400" />
              </div>
            </div>
          </div>

          <SettingRow 
            icon={MicIcon}
            label="Audio Test"
            description="Run 4s hardware diagnostic"
            action={startMicTest}
            valueNode={isTesting && <div className="text-[10px] font-black text-[#FF385C] animate-pulse">LEVEL: {Math.round(testLevel * 100)}%</div>}
          />

          <SettingRow 
            icon={DownloadIcon}
            label="Recording Quality"
            description="High fidelity is recommended"
            valueNode={
              <select 
                value={settings.recordingQuality}
                onChange={e => handleUpdate({ recordingQuality: e.target.value as any })}
                className="font-bold text-xs text-[#FF385C] bg-transparent outline-none cursor-pointer"
              >
                <option value="high">Lossless</option>
                <option value="medium">Standard</option>
                <option value="low">Eco</option>
              </select>
            }
          />
        </div>
      </section>

      {/* Preferences Section */}
      <section className="space-y-4">
        <h2 className="text-[10px] font-black uppercase tracking-widest text-[#717171] ml-2">App Preferences</h2>
        <div className="space-y-3">
          <SettingRow 
            icon={BellIcon}
            label="Push Notifications"
            description="Capture & insight alerts"
            valueNode={<Toggle active={settings.notificationsEnabled} onToggle={() => handleUpdate({ notificationsEnabled: !settings.notificationsEnabled })} />}
          />
        </div>
      </section>

      {/* About */}
      <section className="pt-10 border-t border-gray-100 text-center space-y-2">
        <p className="text-[10px] font-black uppercase tracking-[0.3em] text-gray-400">Syntra Academic Engine</p>
        <div className="flex justify-center space-x-6">
          <button className="text-[10px] font-bold text-[#717171] underline">Privacy Policy</button>
          <button className="text-[10px] font-bold text-[#717171] underline">Terms of Study</button>
        </div>
        <p className="text-[9px] font-bold text-gray-300 mt-4">v2.9.0 Build 1024</p>
      </section>

      {/* Auth Modal (Login / Sign Up) */}
      {showAuthModal && (
        <div className="fixed inset-0 z-[500] bg-black/50 backdrop-blur-md flex items-end sm:items-center justify-center animate-in fade-in duration-300">
          <div className="bg-white w-full max-w-lg rounded-t-[2.5rem] sm:rounded-[2.5rem] p-10 animate-in slide-in-from-bottom duration-500 airbnb-shadow-large">
            <div className="flex justify-between items-center mb-8">
              <div className="flex bg-gray-100 p-1 rounded-2xl w-full mr-4">
                <button 
                  onClick={() => setAuthMode('signup')}
                  className={`flex-1 py-2 text-xs font-black uppercase tracking-wider rounded-xl transition-soft ${authMode === 'signup' ? 'bg-white text-[#FF385C] shadow-sm' : 'text-[#717171]'}`}
                >
                  Sign Up
                </button>
                <button 
                  onClick={() => setAuthMode('login')}
                  className={`flex-1 py-2 text-xs font-black uppercase tracking-wider rounded-xl transition-soft ${authMode === 'login' ? 'bg-white text-[#FF385C] shadow-sm' : 'text-[#717171]'}`}
                >
                  Log In
                </button>
              </div>
              <button onClick={() => setShowAuthModal(false)} className="text-2xl font-bold p-2">×</button>
            </div>
            
            <form onSubmit={handleAuth} className="space-y-6">
              {authMode === 'signup' && (
                <div className="space-y-1.5">
                  <p className="text-[11px] font-black uppercase text-[#717171] ml-1">Full Name</p>
                  <input 
                    autoFocus
                    required
                    type="text" 
                    value={nameInput}
                    onChange={e => setNameInput(e.target.value)}
                    placeholder="e.g. Marie Curie"
                    className="w-full p-5 bg-[#F7F7F7] border border-transparent focus:border-[#222222] rounded-2xl font-bold outline-none transition-soft"
                  />
                </div>
              )}
              <div className="space-y-1.5">
                <p className="text-[11px] font-black uppercase text-[#717171] ml-1">Academic Email</p>
                <input 
                  autoFocus={authMode === 'login'}
                  required
                  type="email" 
                  value={emailInput}
                  onChange={e => setEmailInput(e.target.value)}
                  placeholder="student@university.edu"
                  className="w-full p-5 bg-[#F7F7F7] border border-transparent focus:border-[#222222] rounded-2xl font-bold outline-none transition-soft"
                />
              </div>

              <div className="pt-6 space-y-4">
                <button type="submit" className="w-full bg-[#222222] text-white py-5 rounded-2xl font-black text-lg airbnb-shadow active:scale-95 transition-soft">
                  {authMode === 'signup' ? 'Create Account' : 'Welcome Back'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Profile/Academic Info Modal */}
      {showProfileModal && (
        <div className="fixed inset-0 z-[500] bg-black/50 backdrop-blur-md flex items-end sm:items-center justify-center animate-in fade-in duration-300">
          <div className="bg-white w-full max-w-lg rounded-t-[2.5rem] sm:rounded-[2.5rem] p-10 animate-in slide-in-from-bottom duration-500 airbnb-shadow-large overflow-y-auto max-h-[90vh] scrollbar-hide">
            <div className="flex justify-between items-center mb-8">
              <h2 className="text-2xl font-black text-[#222222]">Academic Profile</h2>
              <button onClick={() => setShowProfileModal(false)} className="text-2xl font-bold p-2">×</button>
            </div>
            
            <form onSubmit={handleProfileSave} className="space-y-5">
              <div className="space-y-1.5">
                <p className="text-[10px] font-black uppercase text-[#717171] ml-1">Preferred Name</p>
                <input 
                  required
                  type="text" 
                  value={profileForm.name}
                  onChange={e => setProfileForm({...profileForm, name: e.target.value})}
                  className="w-full p-4 bg-[#F7F7F7] border border-transparent focus:border-[#FF385C] rounded-xl font-bold outline-none transition-soft"
                />
              </div>

              <div className="space-y-1.5">
                <p className="text-[10px] font-black uppercase text-[#717171] ml-1">University / Institution</p>
                <input 
                  type="text" 
                  value={profileForm.institution}
                  onChange={e => setProfileForm({...profileForm, institution: e.target.value})}
                  placeholder="e.g. Stanford University"
                  className="w-full p-4 bg-[#F7F7F7] border border-transparent focus:border-[#FF385C] rounded-xl font-bold outline-none transition-soft"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <p className="text-[10px] font-black uppercase text-[#717171] ml-1">Degree Type</p>
                  <select 
                    value={profileForm.degree}
                    onChange={e => setProfileForm({...profileForm, degree: e.target.value})}
                    className="w-full p-4 bg-[#F7F7F7] border border-transparent focus:border-[#FF385C] rounded-xl font-bold outline-none transition-soft appearance-none"
                  >
                    <option value="">Select Degree</option>
                    <option value="High School">High School</option>
                    <option value="Associate's">Associate's</option>
                    <option value="Bachelor's">Bachelor's</option>
                    <option value="Master's">Master's</option>
                    <option value="PhD / Doctorate">PhD / Doctorate</option>
                    <option value="Other">Other</option>
                  </select>
                </div>
                <div className="space-y-1.5">
                  <p className="text-[10px] font-black uppercase text-[#717171] ml-1">Academic Level</p>
                  <input 
                    type="text" 
                    value={profileForm.level}
                    onChange={e => setProfileForm({...profileForm, level: e.target.value})}
                    placeholder="e.g. Senior, Year 1"
                    className="w-full p-4 bg-[#F7F7F7] border border-transparent focus:border-[#FF385C] rounded-xl font-bold outline-none transition-soft"
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <p className="text-[10px] font-black uppercase text-[#717171] ml-1">Major / Field of Study</p>
                <input 
                  type="text" 
                  value={profileForm.major}
                  onChange={e => setProfileForm({...profileForm, major: e.target.value})}
                  placeholder="e.g. Computer Science"
                  className="w-full p-4 bg-[#F7F7F7] border border-transparent focus:border-[#FF385C] rounded-xl font-bold outline-none transition-soft"
                />
              </div>

              <div className="pt-6">
                <button type="submit" className="w-full bg-[#FF385C] text-white py-5 rounded-2xl font-black text-lg airbnb-shadow active:scale-95 transition-soft">
                  Update Academic Profile
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default SettingsView;
