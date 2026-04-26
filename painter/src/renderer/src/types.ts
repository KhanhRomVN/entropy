export interface Biome {
  id: string;
  name: string;
  color: string;
  desc?: string;
}

export interface Tab {
  id: string;
  name: string;
  path: string | null;
  isModified: boolean;
  refImage: {
    path: string | null;
    dataURL: string | null;
    pos: { x: number; y: number };
    scale: number;
    opacity: number;
  };
  canvasData?: string;
}
