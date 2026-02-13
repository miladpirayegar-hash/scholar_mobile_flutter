
import React, { useState, useMemo, useEffect } from 'react';
import { appStore } from '../store/appStore';
import { Priority, Task } from '../types';
import { SortIcon, PlusIcon, TrashIcon, CheckSquareIcon, EditIcon, CalendarIcon, SparkIcon } from '../components/Icons';
import ConfirmationModal from '../components/ConfirmationModal';

const TasksView: React.FC = () => {
  const [tasks, setTasks] = useState(appStore.getTasks());
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<'pending' | 'completed' | 'all'>('pending');
  const [sortBy, setSortBy] = useState<'date' | 'priority' | 'text'>('date');
  const [modalState, setModalState] = useState<{ mode: 'create' | 'edit', show: boolean }>({ mode: 'create', show: false });
  const [deleteModal, setDeleteModal] = useState<{ isOpen: boolean, taskId: string | null }>({ isOpen: false, taskId: null });
  
  const [editingTaskId, setEditingTaskId] = useState<string | null>(null);
  const [taskText, setTaskText] = useState('');
  const [taskPriority, setTaskPriority] = useState<Priority>(Priority.MEDIUM);
  const [taskDate, setTaskDate] = useState('');

  useEffect(() => {
    const unsubscribe = appStore.subscribe(() => {
      setTasks(appStore.getTasks());
    });
    return unsubscribe;
  }, []);

  const sortedAndFilteredTasks = useMemo(() => {
    let result = [...tasks];
    
    // Filter by Tab
    if (activeTab === 'pending') result = result.filter(t => !t.completed);
    else if (activeTab === 'completed') result = result.filter(t => t.completed);

    // Search query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(t => t.text.toLowerCase().includes(q));
    }

    // Sort: Pinned first
    result.sort((a, b) => {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      if (sortBy === 'date') {
        const dateA = a.dueDate || '9999-12-31';
        const dateB = b.dueDate || '9999-12-31';
        return dateA.localeCompare(dateB);
      } else if (sortBy === 'priority') {
        const priorityMap = { [Priority.HIGH]: 3, [Priority.MEDIUM]: 2, [Priority.LOW]: 1 };
        return priorityMap[b.priority] - priorityMap[a.priority];
      } else {
        return a.text.localeCompare(b.text);
      }
    });
    return result;
  }, [tasks, activeTab, sortBy, searchQuery]);

  const handleEditClick = (task: Task) => {
    setEditingTaskId(task.id);
    setTaskText(task.text);
    setTaskPriority(task.priority);
    setTaskDate(task.dueDate || '');
    setModalState({ mode: 'edit', show: true });
  };

  const handleSaveTask = () => {
    if (!taskText.trim()) return;
    if (modalState.mode === 'create') {
      appStore.addTask({
        id: `task-${Date.now()}`,
        text: taskText,
        dueDate: taskDate || null,
        completed: false,
        priority: taskPriority,
        createdAt: new Date().toISOString(),
        isPinned: false
      });
    } else if (editingTaskId) {
      const existing = tasks.find(t => t.id === editingTaskId);
      if (existing) {
        appStore.updateTask({ ...existing, text: taskText, priority: taskPriority, dueDate: taskDate || null });
      }
    }
    setModalState({ mode: 'create', show: false });
    resetForm();
  };

  const resetForm = () => {
    setTaskText('');
    setTaskPriority(Priority.MEDIUM);
    setTaskDate('');
    setEditingTaskId(null);
  };

  const getPriorityStyle = (p: Priority) => {
    switch(p) {
      case Priority.HIGH: return 'text-[#FF385C] bg-rose-50';
      case Priority.MEDIUM: return 'text-orange-500 bg-orange-50';
      case Priority.LOW: return 'text-emerald-500 bg-emerald-50';
      default: return 'text-gray-500 bg-gray-50';
    }
  };

  return (
    <div className="p-6 pt-16 max-w-2xl mx-auto space-y-8 pb-40 min-h-screen bg-white">
      <header className="flex justify-between items-start">
        <div>
          <h1 className="text-3xl font-extrabold text-[#222222] tracking-tight">Academic Tasks</h1>
          <p className="text-[#717171] text-lg font-medium">Outcome management</p>
        </div>
        <button 
          onClick={() => { resetForm(); setModalState({ mode: 'create', show: true }); }}
          className="bg-[#222222] text-white w-12 h-12 rounded-full flex items-center justify-center airbnb-shadow active:scale-95 transition-soft"
        >
          <PlusIcon size={20} />
        </button>
      </header>

      <div className="space-y-4">
        <div className="relative">
          <input 
            type="text"
            placeholder="Search tasks..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-[#F7F7F7] border border-transparent focus:border-gray-200 rounded-2xl px-5 py-3.5 font-medium outline-none transition-soft"
          />
        </div>
        
        <div className="flex items-center space-x-2 overflow-x-auto pb-1 scrollbar-hide">
          <div className="flex bg-gray-100 p-1 rounded-xl">
             <button onClick={() => setActiveTab('all')} className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all ${activeTab === 'all' ? 'bg-white text-[#222222] shadow-sm' : 'text-[#717171]'}`}>All</button>
             <button onClick={() => setActiveTab('pending')} className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all ${activeTab === 'pending' ? 'bg-white text-[#222222] shadow-sm' : 'text-[#717171]'}`}>Active</button>
             <button onClick={() => setActiveTab('completed')} className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all ${activeTab === 'completed' ? 'bg-white text-[#222222] shadow-sm' : 'text-[#717171]'}`}>Done</button>
          </div>
          <div className="h-6 w-[1px] bg-gray-200 mx-2" />
          <button 
            onClick={() => {
              const orders: ('date' | 'priority' | 'text')[] = ['date', 'priority', 'text'];
              const nextIdx = (orders.indexOf(sortBy) + 1) % orders.length;
              setSortBy(orders[nextIdx]);
            }}
            className="px-4 py-2.5 rounded-xl border border-gray-100 flex items-center space-x-2 text-xs font-bold text-[#222222] bg-white transition-soft"
          >
            <SortIcon size={14} />
            <span className="capitalize">{sortBy}</span>
          </button>
        </div>
      </div>

      <div className="space-y-4">
        {sortedAndFilteredTasks.map((task) => (
          <div 
            key={task.id}
            className="group bg-white p-6 rounded-[1.5rem] border border-gray-100 airbnb-card-shadow flex items-start space-x-5 transition-soft hover:bg-gray-50 relative"
          >
            <button 
              onClick={() => appStore.toggleTask(task.id)}
              className={`mt-1 w-7 h-7 rounded-full border-2 flex items-center justify-center transition-soft ${task.completed ? 'bg-[#FF385C] border-[#FF385C]' : 'border-gray-200 bg-white'}`}
            >
              {task.completed && <CheckSquareIcon size={16} className="text-white" />}
            </button>
            <div className="flex-1 min-w-0" onClick={() => handleEditClick(task)}>
              <div className="flex items-center space-x-2 mb-1">
                <p className={`text-lg font-bold leading-tight cursor-pointer ${task.completed ? 'text-[#717171] line-through' : 'text-[#222222]'}`}>
                  {task.text}
                </p>
                {task.isPinned && <SparkIcon size={14} className="text-[#FF385C]" />}
              </div>
              <div className="flex items-center space-x-4 mt-2">
                <span className={`text-[10px] font-black uppercase tracking-[0.1em] px-3 py-1 rounded-full ${getPriorityStyle(task.priority)}`}>
                  {task.priority} Priority
                </span>
                {task.dueDate && (
                  <span className="text-xs text-[#717171] font-medium flex items-center">
                    <CalendarIcon size={12} className="mr-1" />
                    {new Date(task.dueDate).toLocaleDateString()}
                  </span>
                )}
              </div>
            </div>
            <div className="flex flex-col space-y-2 opacity-0 group-hover:opacity-100 transition-soft">
              <button 
                onClick={(e) => { e.stopPropagation(); appStore.togglePinTask(task.id); }}
                className={`p-2 transition-soft ${task.isPinned ? 'text-[#FF385C]' : 'text-[#717171] hover:text-[#222222]'}`}
              >
                <SparkIcon size={18} />
              </button>
              <button onClick={(e) => { e.stopPropagation(); handleEditClick(task); }} className="p-2 text-[#717171] hover:text-[#222222] transition-soft">
                <EditIcon size={18} />
              </button>
              <button onClick={(e) => { e.stopPropagation(); setDeleteModal({ isOpen: true, taskId: task.id }); }} className="p-2 text-[#717171] hover:text-[#FF385C] transition-soft">
                <TrashIcon size={18} />
              </button>
            </div>
          </div>
        ))}

        {sortedAndFilteredTasks.length === 0 && (
          <div className="py-24 text-center airbnb-surface rounded-[2rem] border border-gray-100">
            <CheckSquareIcon className="mx-auto text-gray-200 mb-4" size={48} />
            <p className="text-[#717171] font-bold text-lg">No matches found</p>
          </div>
        )}
      </div>

      {modalState.show && (
        <div className="fixed inset-0 z-[110] bg-black/50 flex items-end sm:items-center justify-center animate-in fade-in duration-300">
          <div className="bg-white w-full max-md rounded-t-[2rem] sm:rounded-[2rem] p-10 animate-in slide-in-from-bottom duration-300">
            <h2 className="text-2xl font-extrabold text-[#222222] mb-8">{modalState.mode === 'create' ? 'New Goal' : 'Edit Goal'}</h2>
            <div className="space-y-6">
              <textarea 
                autoFocus
                placeholder="What needs to be done?"
                className="w-full bg-white border border-gray-300 p-5 rounded-2xl font-bold text-lg outline-none focus:border-[#222222]"
                rows={3}
                value={taskText}
                onChange={e => setTaskText(e.target.value)}
              />
              <div className="grid grid-cols-2 gap-4">
                <select 
                  value={taskPriority}
                  onChange={e => setTaskPriority(e.target.value as any)}
                  className="w-full border border-gray-300 p-4 rounded-2xl font-bold text-sm bg-white"
                >
                  <option value={Priority.LOW}>Low Priority</option>
                  <option value={Priority.MEDIUM}>Med Priority</option>
                  <option value={Priority.HIGH}>High Priority</option>
                </select>
                <input 
                  type="date"
                  value={taskDate}
                  onChange={e => setTaskDate(e.target.value)}
                  className="w-full border border-gray-300 p-4 rounded-2xl font-bold text-sm bg-white"
                />
              </div>
              <div className="flex space-x-4 pt-4">
                <button onClick={() => { setModalState({ ...modalState, show: false }); resetForm(); }} className="flex-1 py-4 font-bold text-[#717171]">Cancel</button>
                <button onClick={handleSaveTask} className="flex-[2] bg-[#FF385C] text-white py-4 rounded-2xl font-bold airbnb-shadow">
                  {modalState.mode === 'create' ? 'Add Task' : 'Save Changes'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      <ConfirmationModal 
        isOpen={deleteModal.isOpen}
        title="Remove Task?"
        message="This will delete the task from your list."
        onConfirm={() => { appStore.deleteTask(deleteModal.taskId!); setDeleteModal({ isOpen: false, taskId: null }); }}
        onCancel={() => setDeleteModal({ isOpen: false, taskId: null })}
      />
    </div>
  );
};

export default TasksView;
