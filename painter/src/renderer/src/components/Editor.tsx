import { useState, useEffect, useRef } from 'react';
import {
  Move,
  Brush,
  Square,
  Wand2,
  Eraser,
  Info,
  Image as ImageIcon,
  PencilLine,
  LandPlot,
  Plus,
  Circle,
  X,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import BiomeCanvas, { BiomeCanvasHandle } from './BiomeCanvas';
import { Tab, Biome } from '../types';

// --- Sub-Components ---

const Topbar = ({
  tabs,
  activeTabId,
  onSwitch,
  onClose,
  onPlus,
}: {
  tabs: Tab[];
  activeTabId: string | null;
  onSwitch: (id: string) => void;
  onClose: (e: React.MouseEvent, id: string) => void;
  onPlus: () => void;
}) => (
  <div className="h-10 w-full flex items-center bg-[#1a1a1a] border-b border-[#444] overflow-hidden">
    <div className="flex items-center h-full flex-1 overflow-x-auto no-scrollbar">
      {tabs.map((tab) => (
        <div
          key={tab.id}
          onClick={() => onSwitch(tab.id)}
          className={`h-full pl-4 pr-2 flex items-center gap-6 text-[14px] font-semibold cursor-pointer border-r border-[#333] transition-colors relative group min-w-fit whitespace-nowrap ${
            activeTabId === tab.id
              ? 'bg-[#222] text-white shadow-[inset_0_-2px_0_var(--accent-color)]'
              : 'text-[#555] hover:bg-[#111] hover:text-[#888]'
          }`}
        >
          <span>{tab.name}</span>

          <div className="flex items-center gap-3">
            {tab.isModified && (
              <div className="w-2 h-2 rounded-full bg-[var(--accent-color)] opacity-80" />
            )}
            <X
              size={24}
              className={`hover:bg-[#ffffff11] rounded-md p-1 transition-all ${
                activeTabId === tab.id ? 'text-white' : 'text-[#444]'
              }`}
              onClick={(e) => onClose(e, tab.id)}
            />
          </div>
        </div>
      ))}
      <button
        onClick={onPlus}
        className="px-3 h-full flex items-center hover:bg-[#222] text-[#666] hover:text-[#aaa] transition-colors border-r border-[#333]"
        title="New Project (Ctrl+N)"
      >
        <Plus size={14} />
      </button>
    </div>
  </div>
);

const SidebarLeft = ({ activeTab, setActiveTab }: any) => (
  <div className="w-10 h-full flex flex-col items-center py-2 bg-[#1a1a1a] border-r border-[#444] gap-1.5">
    <button
      onClick={() => activeTab !== 'inspector' && setActiveTab('biomes')}
      className={`p-2 rounded transition-all duration-200 group relative ${activeTab === 'biomes' ? 'bg-[#378add22] text-[#378add]' : 'text-[#555] hover:text-[#999]'} ${activeTab === 'inspector' ? 'opacity-30 cursor-not-allowed' : ''}`}
      title="Biomes"
      disabled={activeTab === 'inspector'}
    >
      <LandPlot size={16} />
    </button>
    <button
      className={`p-2 rounded transition-all duration-200 group relative ${activeTab === 'inspector' ? 'bg-[#378add22] text-[#378add]' : 'text-[#555] opacity-50 cursor-not-allowed'}`}
      title="Biome Inspector (Use Inspector Tool I)"
      disabled
    >
      <Info size={16} />
    </button>
  </div>
);

const ToolOptionsBar = ({
  currentTool,
  brushSize,
  setBrushSize,
  brushShape,
  setBrushShape,
  selectionMode,
  setSelectionMode,
}: {
  currentTool: string;
  brushSize: number;
  setBrushSize: (v: number) => void;
  brushShape: 'round' | 'square';
  setBrushShape: (v: 'round' | 'square') => void;
  selectionMode: 'replace' | 'add' | 'subtract' | 'intersect';
  setSelectionMode: (v: 'replace' | 'add' | 'subtract' | 'intersect') => void;
}) => {
  if (currentTool === 'move') return null;

  return (
    <div className="h-11 w-full flex items-center px-4 bg-[#1a1a1a] border-b border-[#444] gap-4">
      {(currentTool === 'brush' || currentTool === 'eraser') && (
        <>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setBrushShape('round')}
              className={`p-1 w-7 h-7 flex items-center justify-center rounded transition-colors ${brushShape === 'round' ? 'bg-[#264f78] text-[#378add]' : 'bg-[#222] text-[#666] hover:bg-[#2a2a2a]'}`}
            >
              <Circle size={12} fill={brushShape === 'round' ? 'currentColor' : 'none'} />
            </button>
            <button
              onClick={() => setBrushShape('square')}
              className={`p-1 w-7 h-7 flex items-center justify-center rounded transition-colors ${brushShape === 'square' ? 'bg-[#264f78] text-[#378add]' : 'bg-[#222] text-[#666] hover:bg-[#2a2a2a]'}`}
            >
              <Square size={12} fill={brushShape === 'square' ? 'currentColor' : 'none'} />
            </button>
          </div>
          <div className="w-[1px] h-4 bg-[#333]" />
          <div className="flex items-center gap-2">
            <span className="text-[10px] font-bold text-[#555] uppercase">Size</span>
            <input
              type="text"
              className="w-12 h-7 bg-[#0a0a0a] border border-[#333] text-[11px] text-white text-center outline-none rounded"
              value={brushSize}
              onChange={(e) => setBrushSize(parseInt(e.target.value) || 1)}
            />
          </div>
        </>
      )}
      {(currentTool === 'rect' || currentTool === 'poly_lasso' || currentTool === 'wand') && (
        <div className="flex gap-1 items-center">
          <button
            onClick={() => setSelectionMode('replace')}
            className={`p-1 w-7 h-7 flex items-center justify-center rounded transition-colors ${selectionMode === 'replace' ? 'bg-[#264f78] text-[#378add]' : 'bg-[#222] text-[#666] hover:bg-[#2a2a2a]'}`}
            title="Replace Selection"
          >
            <Square size={12} fill={selectionMode === 'replace' ? 'currentColor' : 'none'} />
          </button>
          <button
            onClick={() => setSelectionMode('add')}
            className={`p-1 w-7 h-7 flex items-center justify-center rounded transition-colors ${selectionMode === 'add' ? 'bg-[#264f78] text-[#378add]' : 'bg-[#222] text-[#666] hover:bg-[#2a2a2a]'}`}
            title="Add to Selection"
          >
            <Plus size={14} />
          </button>
          <button
            onClick={() => setSelectionMode('subtract')}
            className={`p-1 w-7 h-7 flex items-center justify-center rounded transition-colors ${selectionMode === 'subtract' ? 'bg-[#264f78] text-[#378add]' : 'bg-[#222] text-[#666] hover:bg-[#2a2a2a]'}`}
            title="Subtract from Selection"
          >
            <div className="w-3 h-0.5 bg-current" />
          </button>
          <button
            onClick={() => setSelectionMode('intersect')}
            className={`p-1 w-7 h-7 flex items-center justify-center rounded transition-colors ${selectionMode === 'intersect' ? 'bg-[#264f78] text-[#378add]' : 'bg-[#222] text-[#666] hover:bg-[#2a2a2a]'}`}
            title="Intersect Selection"
          >
            <div className="w-3 h-3 border border-current border-dashed" />
          </button>
        </div>
      )}
      {currentTool === 'move' && (
        <div className="text-[10px] font-bold text-[#555] uppercase italic">
          Move & Zoom viewport
        </div>
      )}
    </div>
  );
};

const NewFileModal = ({
  isOpen,
  onClose,
  onCreate,
}: {
  isOpen: boolean;
  onClose: () => void;
  onCreate: (name: string, w: number, h: number) => void;
}) => {
  const [name, setName] = useState('Untitled');
  const [width, setWidth] = useState(1024);
  const [height, setHeight] = useState(1024);

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
        >
          <motion.div
            initial={{ scale: 0.9, y: 20 }}
            animate={{ scale: 1, y: 0 }}
            exit={{ scale: 0.9, y: 20 }}
            className="w-[340px] bg-[var(--bg-sidebar)] border border-[var(--border-color)] rounded-xl shadow-2xl p-6"
          >
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-lg font-bold text-white">New Project</h2>
              <X
                size={18}
                className="text-[#555] cursor-pointer hover:text-white"
                onClick={onClose}
              />
            </div>
            <div className="space-y-4">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-[#888]">Project Name</label>
                <input
                  type="text"
                  className="w-full h-10 bg-[#111] border border-[var(--border-color)] rounded-lg px-4 text-sm text-white focus:border-[var(--accent-color)] outline-none"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-[#888]">Width</label>
                  <input
                    type="number"
                    className="w-full h-10 bg-[#111] border border-[var(--border-color)] rounded-lg px-4 text-sm text-white outline-none"
                    value={width}
                    onChange={(e) => setWidth(parseInt(e.target.value) || 0)}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-[#888]">Height</label>
                  <input
                    type="number"
                    className="w-full h-10 bg-[#111] border border-[var(--border-color)] rounded-lg px-4 text-sm text-white outline-none"
                    value={height}
                    onChange={(e) => setHeight(parseInt(e.target.value) || 0)}
                  />
                </div>
              </div>
            </div>
            <div className="flex gap-3 mt-8">
              <button
                className="flex-1 h-10 rounded-lg hover:bg-[var(--bg-btn-hover)] text-sm font-semibold transition-colors"
                onClick={onClose}
              >
                Cancel
              </button>
              <button
                onClick={() => onCreate(name, width, height)}
                className="flex-1 h-10 rounded-lg bg-[var(--bg-btn-active)] border border-[var(--accent-color)] text-white text-sm font-semibold shadow-[0_0_15px_rgba(55,138,221,0.3)]"
              >
                Create
              </button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

const BIOME_GROUPS = [
  {
    name: 'VÙNG LẠNH / CỰC',
    biomes: [
      { id: 'tundra', name: 'Vùng tuyết', desc: 'Nơi băng giá vĩnh cửu', color: '#8aabb8' },
      {
        id: 'pine_forest',
        name: 'Vùng rừng cây pine',
        desc: 'Rừng thông bạt ngàn',
        color: '#4a7a5a',
      },
    ],
  },
  {
    name: 'VÙNG ÔN ĐỚI',
    biomes: [
      { id: 'plains', name: 'Đồng bằng', desc: 'Thảm cỏ xanh mướt', color: '#7ab648' },
      {
        id: 'maple_forest',
        name: 'Vùng rừng cây maple',
        desc: 'Vùng rừng cây maple',
        color: '#a0522d',
      },
      { id: 'oak_forest', name: 'Vùng rừng cây oak', desc: 'Rừng sồi già cỗi', color: '#556b2f' },
    ],
  },
  {
    name: 'VÙNG NHIỆT ĐỚI',
    biomes: [
      { id: 'rainforest', name: 'Rừng nhiệt đới', desc: 'Rừng rậm ẩm ướt', color: '#2d5a27' },
      {
        id: 'coffee',
        name: 'Vùng rừng cây cà phê',
        desc: 'Rừng cà phê thơm ngát',
        color: '#6f4e37',
      },
    ],
  },
  {
    name: 'VÙNG KHÔ HẠN',
    biomes: [
      { id: 'desert', name: 'Sa mạc', desc: 'Cát vàng mênh mông', color: '#d4ac0d' },
      {
        id: 'salt_desert',
        name: 'Sa mạc muối',
        desc: 'Cánh đồng muối trắng xóa',
        color: '#ddeef8',
      },
    ],
  },
  {
    name: 'ĐẶC BIỆT & NƯỚC',
    biomes: [
      { id: 'volcano', name: 'Vùng núi lửa', desc: 'Dòng lava nóng bỏng', color: '#9a3020' },
      {
        id: 'deep_sea',
        name: 'Vùng đại dương',
        desc: 'Đại dương xanh thăm thẳm',
        color: '#1a3a6b',
      },
      { id: 'beach', name: 'Vùng sông, hồ', desc: 'Ven nước ngọt hiền hòa', color: '#2a6896' },
    ],
  },
];

const allBiomes = BIOME_GROUPS.flatMap((g) => g.biomes);

export default function Editor() {
  const canvasRef = useRef<BiomeCanvasHandle>(null);
  const [tabs, setTabs] = useState<Tab[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | null>(null);
  const [currentTool, setCurrentTool] = useState('brush');
  const [currentTab, setCurrentTab] = useState('biomes');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [brushSize, setBrushSize] = useState(20);
  const [brushShape, setBrushShape] = useState<'round' | 'square'>('round');
  const [selectionMode, setSelectionMode] = useState<'replace' | 'add' | 'subtract' | 'intersect'>(
    'replace',
  );
  const [status, setStatus] = useState({ x: 0, y: 0, zoom: 100 });
  const [currentBiome, setCurrentBiome] = useState(allBiomes[0]);

  const activeTab = tabs.find((t) => t.id === activeTabId);

  // Helper to update active tab state
  const updateActiveTab = (patch: Partial<Tab>) => {
    if (!activeTabId) return;
    setTabs((prev) => prev.map((t) => (t.id === activeTabId ? { ...t, ...patch } : t)));
  };

  const handleSave = async () => {
    if (!canvasRef.current || !activeTab) return;

    let path = activeTab.path;
    if (!path) {
      const result = await window.api.fileSystem.showSaveDialog({
        defaultPath: activeTab.name,
        filters: [{ name: 'Biome Map', extensions: ['entmap'] }],
      });
      if (result.canceled || !result.filePath) return;
      path = result.filePath;

      // Ensure file has .entmap extension
      if (!path.endsWith('.entmap')) {
        path += '.entmap';
      }
    }

    if (!path) return;

    const data = {
      version: '1.0',
      pixel_data: canvasRef.current.getDataURL(),
      biomes: allBiomes,
      reference: activeTab.refImage,
    };

    await window.api.fileSystem.writeFile(path, JSON.stringify(data, null, 2));
    updateActiveTab({
      path,
      name: path.split(/[/\\]/).pop() || 'Untitled',
      isModified: false,
    });
  };

  const handleSaveAs = async () => {
    if (!canvasRef.current || !activeTab) return;

    const result = await window.api.fileSystem.showSaveDialog({
      defaultPath: activeTab.name,
      filters: [{ name: 'Biome Map', extensions: ['entmap'] }],
    });

    if (result.canceled || !result.filePath) return;
    let path = result.filePath;
    if (!path.endsWith('.entmap')) {
      path += '.entmap';
    }

    const data = {
      version: '1.0',
      pixel_data: canvasRef.current.getDataURL(),
      biomes: allBiomes,
      reference: activeTab.refImage,
    };

    await window.api.fileSystem.writeFile(path, JSON.stringify(data, null, 2));
    updateActiveTab({
      path,
      name: path.split(/[/\\]/).pop() || 'Untitled',
      isModified: false,
    });
  };

  const handleOpen = async () => {
    const result = await window.api.fileSystem.showOpenDialog({
      filters: [{ name: 'Biome Map', extensions: ['entmap'] }],
      properties: ['openFile'],
    });

    if (result.canceled || result.filePaths.length === 0) return;

    const path = result.filePaths[0];
    const content = await window.api.fileSystem.readFile(path);
    const data = JSON.parse(content);

    const newTab: Tab = {
      id: Math.random().toString(36).substr(2, 9),
      name: path.split(/[/\\]/).pop() || 'Untitled',
      path: path,
      isModified: false,
      refImage: data.reference || {
        path: null,
        dataURL: null,
        pos: { x: 0, y: 0 },
        scale: 1.0,
        opacity: 50,
      },
      canvasData: data.pixel_data,
    };

    setTabs((prev) => [...prev, newTab]);
    setActiveTabId(newTab.id);
  };

  const handleLoadReference = async () => {
    const result = await window.api.fileSystem.showOpenDialog({
      filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'svg'] }],
      properties: ['openFile'],
    });

    if (result.canceled || result.filePaths.length === 0 || !activeTab) return;

    const path = result.filePaths[0];
    const base64 = await window.api.fileSystem.readFileBase64(path);
    const dataURL = `data:image/${path.split('.').pop()};base64,${base64}`;

    updateActiveTab({
      refImage: {
        ...activeTab.refImage,
        path: path,
        dataURL: dataURL,
      },
    });
    setCurrentTool('reference');
  };

  // Handle shortcuts
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      const key = e.key.toLowerCase();
      if (e.ctrlKey && key === 's') {
        e.preventDefault();
        if (e.shiftKey) handleSaveAs();
        else handleSave();
      }
      if (e.ctrlKey && key === 'o') {
        e.preventDefault();
        handleOpen();
      }
      if (e.ctrlKey && key === 'd') {
        e.preventDefault();
        canvasRef.current?.clearSelection();
      }
      if (e.ctrlKey && key === 'n') {
        setIsModalOpen(true);
        e.preventDefault();
      }
      if (e.ctrlKey && e.key === 'z') {
        e.preventDefault();
        canvasRef.current?.undo();
      }
      if (key === 'b') setCurrentTool('brush');
      if (key === 'm') setCurrentTool('rect');
      if (key === 'l') setCurrentTool('poly_lasso');
      if (key === 'w') setCurrentTool('wand');
      if (key === 'e') setCurrentTool('eraser');
      if (key === 'v') setCurrentTool('move');
      if (key === 'r') handleLoadReference();
      if (key === 'i') setCurrentTool('inspector');
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [activeTab, tabs, activeTabId, brushSize, currentBiome, currentTool]);

  // Load canvas data when switching tabs
  useEffect(() => {
    if (activeTabId && activeTab?.canvasData && canvasRef.current) {
      canvasRef.current.clearCanvas();
      canvasRef.current.loadImage(activeTab.canvasData);
    } else if (activeTabId && !activeTab?.canvasData && canvasRef.current) {
      canvasRef.current.clearCanvas();
    }
  }, [activeTabId]);

  return (
    <div className="flex h-screen w-screen flex-col bg-[#050505] select-none overflow-hidden text-[#aaa]">
      <Topbar
        tabs={tabs}
        activeTabId={activeTabId}
        onPlus={() => setIsModalOpen(true)}
        onSwitch={async (id) => {
          if (id === activeTabId) return;
          if (activeTabId && canvasRef.current) {
            const currentData = canvasRef.current.getDataURL();
            setTabs((prev) =>
              prev.map((t) => (t.id === activeTabId ? { ...t, canvasData: currentData } : t)),
            );
          }
          setActiveTabId(id);
        }}
        onClose={(e, id) => {
          e.stopPropagation();
          setTabs((prev) => {
            const newTabs = prev.filter((t) => t.id !== id);
            if (activeTabId === id) {
              setActiveTabId(newTabs.length > 0 ? newTabs[newTabs.length - 1].id : null);
            }
            return newTabs;
          });
        }}
      />

      <div className="flex flex-1 overflow-hidden relative">
        <SidebarLeft activeTab={currentTab} setActiveTab={setCurrentTab} />

        {currentTab === 'biomes' && (
          <div className="w-[440px] h-full flex flex-col bg-[#1a1a1a] border-r border-[#444]">
            <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
              {BIOME_GROUPS.map((group, idx) => (
                <div key={idx} className="mb-8 last:mb-0">
                  <div className="text-[10px] font-bold text-[#444] mb-4 tracking-wider uppercase">
                    {group.name}
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    {group.biomes.map((biome) => (
                      <div
                        key={biome.id}
                        onClick={() => setCurrentBiome(biome)}
                        className={`group relative flex flex-col gap-1 p-3 px-4 rounded-xl cursor-pointer transition-all border ${currentBiome.id === biome.id ? 'border-current shadow-lg' : 'bg-[#1c1c1c] border-[#222] hover:border-[#333] hover:bg-[#1e1e1e]'}`}
                        style={
                          currentBiome.id === biome.id
                            ? {
                                backgroundColor: `${biome.color}33`,
                                borderColor: biome.color,
                                color: biome.color,
                              }
                            : {}
                        }
                      >
                        <div className="flex items-center gap-3">
                          <div
                            className={`w-3.5 h-3.5 rounded-full shadow-inner ring-2 ring-black/30`}
                            style={{ backgroundColor: biome.color }}
                          />
                          <div className="flex flex-col">
                            <span
                              className={`text-[12px] font-bold leading-tight ${currentBiome.id === biome.id ? 'text-white' : 'text-white/90 group-hover:text-white'}`}
                            >
                              {biome.name}
                            </span>
                            <span
                              className={`text-[10px] leading-tight truncate w-32 ${currentBiome.id === biome.id ? 'text-white/60' : 'text-[#888]'}`}
                            >
                              {biome.desc}
                            </span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {currentTab === 'inspector' && (
          <div className="w-80 h-full flex flex-col bg-[#1a1a1a] border-r border-[#444] p-4 text-[#aaa]">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-[10px] font-bold uppercase tracking-wider text-[#555]">
                BIOME INSPECTOR
              </h3>
              <X
                size={14}
                className="text-[#444] hover:text-white cursor-pointer"
                onClick={() => setCurrentTab('biomes')}
              />
            </div>
            <div className="flex flex-col gap-4">
              <div className="flex flex-col gap-1">
                <div className="text-[14px] font-bold text-[#378add]">{currentBiome.name}</div>
                <div className="text-[11px] text-[#555]">ID: {currentBiome.id}</div>
              </div>
              <div className="w-full h-[1px] bg-[#333]" />
              <div className="flex flex-col gap-2">
                <div className="flex justify-between text-[11px] text-[#555]">
                  <span>Area:</span>
                  <span className="text-white">12,450 px</span>
                </div>
                <div className="flex justify-between text-[11px] text-[#555]">
                  <span>Coverage:</span>
                  <span className="text-white">12.5 %</span>
                </div>
              </div>
              <div className="w-full h-[1px] bg-[#333]" />
              <div className="flex flex-col gap-2 text-[#555]">
                <div className="text-[11px] font-bold uppercase">Projected Ores:</div>
                <div className="flex flex-col gap-1 opacity-60">
                  <div className="text-[11px] flex justify-between">
                    <span>Iron:</span> <span className="text-white">Low</span>
                  </div>
                  <div className="text-[11px] flex justify-between">
                    <span>Gold:</span> <span className="text-white">None</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        <div className="flex-1 flex flex-col min-w-0 bg-[#1a1a1a]">
          <ToolOptionsBar
            currentTool={currentTool}
            brushSize={brushSize}
            setBrushSize={setBrushSize}
            brushShape={brushShape}
            setBrushShape={setBrushShape}
            selectionMode={selectionMode}
            setSelectionMode={setSelectionMode}
          />
          <div className="flex-1 relative flex items-center justify-center overflow-hidden bg-[#090909]">
            {activeTabId ? (
              <BiomeCanvas
                ref={canvasRef}
                currentTool={currentTool}
                currentBiome={currentBiome}
                brushSize={brushSize}
                brushShape={brushShape}
                refImage={activeTab!.refImage}
                setRefImage={(patch) =>
                  updateActiveTab({ refImage: { ...activeTab!.refImage, ...patch } })
                }
                setBrushSize={setBrushSize}
                onStatusUpdate={(x, y, zoom) => setStatus({ x, y, zoom: Math.round(zoom * 100) })}
                onInspect={(hex) => {
                  const found = allBiomes.find((b) => b.color.toLowerCase() === hex.toLowerCase());
                  if (found) {
                    setCurrentBiome(found);
                    setCurrentTab('inspector');
                  }
                }}
                onModified={() => {
                  if (activeTab && !activeTab.isModified) {
                    updateActiveTab({ isModified: true });
                  }
                }}
              />
            ) : (
              <div className="flex flex-col items-center gap-6 opacity-20">
                <LandPlot size={120} strokeWidth={1} />
                <div className="text-sm font-bold uppercase tracking-[0.2em]">
                  Open or create a project to begin
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="w-10 h-full flex flex-col items-center py-2 bg-[#1a1a1a] border-l border-[#444] gap-1.5 focus-panel">
          {[
            { id: 'move', icon: Move, label: 'Move (V)' },
            { id: 'brush', icon: Brush, label: 'Brush (B)' },
            { id: 'rect', icon: Square, label: 'Rectangular Marquee (M)' },
            { id: 'poly_lasso', icon: PencilLine, label: 'Polygonal Lasso (L)' },
            { id: 'wand', icon: Wand2, label: 'Magic Wand (W)' },
            { id: 'eraser', icon: Eraser, label: 'Eraser (E)' },
            { id: 'sep' },
            { id: 'inspector', icon: Info, label: 'Inspector (I)' },
            { id: 'reference', icon: ImageIcon, label: 'Reference (R)' },
          ].map((tool: any, idx) => {
            if (tool.id === 'sep') return <div key={idx} className="w-6 h-[1px] bg-[#222] my-1" />;
            const Icon = tool.icon;
            return (
              <button
                key={tool.id}
                onClick={() => {
                  if (tool.id === 'reference') handleLoadReference();
                  else setCurrentTool(tool.id);
                }}
                className={`p-2 rounded transition-all duration-200 group relative ${currentTool === tool.id ? 'bg-[#378add22] text-[#378add]' : 'text-[#555] hover:text-[#999]'}`}
                title={tool.label}
              >
                <Icon size={16} />
              </button>
            );
          })}
        </div>
      </div>

      <div className="h-6 w-full flex items-center px-4 bg-[#1a1a1a] border-t border-[#444] text-[10px] text-[#444] font-bold gap-6">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-[#378add]" />
          <span>TOOL: {currentTool.replace('_', ' ').toUpperCase()}</span>
        </div>
        <div className="w-[1px] h-3 bg-[#333]" />
        <span>BIOME: {currentBiome.name.toUpperCase()}</span>
        <div className="w-[1px] h-3 bg-[#333]" />
        <div className="ml-auto flex items-center gap-3">
          <div className="flex items-center gap-2 w-48">
            <span className="opacity-60 text-[9px]">ZOOM</span>
            <div className="h-1.5 flex-1 bg-[#222] rounded-full overflow-hidden">
              <div
                className="h-full bg-[#378add] transition-all duration-200"
                style={{
                  width: `${Math.max(0, Math.min(100, ((status.zoom - 10) / (5000 - 10)) * 100))}%`,
                }}
              />
            </div>
            <span className="opacity-60 w-10 text-right">{status.zoom}%</span>
          </div>
          <div className="w-[1px] h-3 bg-[#333]" />
          <span className="opacity-80">1024 x 1024</span>
        </div>
        <span className="w-20 text-right">
          X: {status.x} Y: {status.y}
        </span>
      </div>

      <NewFileModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onCreate={(name) => {
          const newTab: Tab = {
            id: Math.random().toString(36).substr(2, 9),
            name: name || 'Untitled',
            path: null,
            isModified: false,
            refImage: {
              path: null,
              dataURL: null,
              pos: { x: 0, y: 0 },
              scale: 1.0,
              opacity: 50,
            },
          };
          setTabs((prev) => [...prev, newTab]);
          setActiveTabId(newTab.id);
          setIsModalOpen(false);
        }}
      />
    </div>
  );
}
