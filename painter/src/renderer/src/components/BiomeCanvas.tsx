import React, {
  useRef,
  useEffect,
  useState,
  useCallback,
  useImperativeHandle,
  forwardRef,
} from 'react';

interface Biome {
  id: string;
  name: string;
  color: string;
}

export interface BiomeCanvasHandle {
  getDataURL: () => string;
  loadImage: (dataURL: string) => void;
  clearSelection: () => void;
  clearCanvas: () => void;
  resetView: () => void;
  undo: () => void;
}

interface BiomeCanvasProps {
  currentTool: string;
  currentBiome: Biome;
  brushSize: number;
  brushShape: 'round' | 'square';
  refImage: {
    dataURL: string | null;
    pos: { x: number; y: number };
    scale: number;
    opacity: number;
  };
  setRefImage?: (v: any) => void;
  setBrushSize?: (v: number) => void;
  onStatusUpdate?: (x: number, y: number, zoom: number) => void;
  onInspect?: (biomeId: string) => void;
  onModified?: () => void;
}

const BiomeCanvas = forwardRef<BiomeCanvasHandle, BiomeCanvasProps>(
  (
    {
      currentTool,
      currentBiome,
      brushSize,
      brushShape,
      refImage,
      setRefImage,
      setBrushSize,
      onStatusUpdate,
      onInspect,
      onModified,
    },
    ref,
  ) => {
    const containerRef = useRef<HTMLDivElement>(null);
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const maskCanvasRef = useRef<HTMLCanvasElement>(document.createElement('canvas')); // Offscreen mask
    const bufferCanvasRef = useRef<HTMLCanvasElement>(document.createElement('canvas')); // Offscreen buffer for drawing
    const selectionCanvasRef = useRef<HTMLCanvasElement>(null); // Visible dotted border

    const [zoom, setZoom] = useState(1);
    const [offset, setOffset] = useState({ x: 0, y: 0 });
    const [isPanning, setIsPanning] = useState(false);
    const [isDrawing, setIsDrawing] = useState(false);
    const [isResizing, setIsResizing] = useState<string | null>(null);
    const [lastMousePos, setLastMousePos] = useState({ x: 0, y: 0 });
    const [lastDrawPos, setLastDrawPos] = useState<{ x: number; y: number } | null>(null);
    const [mouseInCanvas, setMouseInCanvas] = useState(false);
    const [screenCursorPos, setScreenCursorPos] = useState({ x: 0, y: 0 }); // Screen coords
    const [selectionActive, setSelectionActive] = useState(false);
    const [lassoPoints, setLassoPoints] = useState<{ x: number; y: number }[]>([]);
    const [dashOffset, setDashOffset] = useState(0);
    const [panSpeed, setPanSpeed] = useState({ x: 0, y: 0 });
    const [activeSelectionRect, setActiveSelectionRect] = useState<{
      x: number;
      y: number;
      w: number;
      h: number;
    } | null>(null);

    const undoStack = useRef<ImageData[]>([]);
    const canvasSize = { w: 1024, h: 1024 };

    // Initialize canvases
    useEffect(() => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      canvas.width = canvasSize.w;
      canvas.height = canvasSize.h;

      const selection = selectionCanvasRef.current;
      if (selection) {
        selection.width = canvasSize.w;
        selection.height = canvasSize.h;
      }

      const mask = maskCanvasRef.current;
      mask.width = canvasSize.w;
      mask.height = canvasSize.h;

      const buffer = bufferCanvasRef.current;
      buffer.width = canvasSize.w;
      buffer.height = canvasSize.h;

      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      ctx.imageSmoothingEnabled = false;
      // Default to transparent instead of ocean color
      ctx.clearRect(0, 0, canvasSize.w, canvasSize.h);
    }, []);

    // Animate marching ants
    useEffect(() => {
      const interval = setInterval(() => {
        setDashOffset((prev) => (prev + 0.5) % 10);
      }, 50);
      return () => clearInterval(interval);
    }, []);

    // Auto-panning animation
    useEffect(() => {
      if (panSpeed.x === 0 && panSpeed.y === 0) return;

      let animationFrame: number;
      const step = () => {
        setOffset((prev) => ({
          x: prev.x - panSpeed.x * 10,
          y: prev.y - panSpeed.y * 10,
        }));
        animationFrame = requestAnimationFrame(step);
      };

      animationFrame = requestAnimationFrame(step);
      return () => cancelAnimationFrame(animationFrame);
    }, [panSpeed]);

    // Update visible selection border
    useEffect(() => {
      const canvas = selectionCanvasRef.current;
      const ctx = canvas?.getContext('2d');
      if (!canvas || !ctx) return;

      ctx.clearRect(0, 0, canvas.width, canvas.height);

      if (selectionActive) {
        ctx.save();

        ctx.setLineDash([5, 5]);

        const drawMarchingAnts = (drawFn: () => void) => {
          ctx.strokeStyle = '#000';
          ctx.lineDashOffset = -dashOffset;
          drawFn();
          ctx.strokeStyle = '#fff';
          ctx.lineDashOffset = -dashOffset + 5;
          drawFn();
        };

        if (activeSelectionRect) {
          drawMarchingAnts(() => {
            ctx.strokeRect(
              activeSelectionRect.x + 0.5,
              activeSelectionRect.y + 0.5,
              activeSelectionRect.w,
              activeSelectionRect.h,
            );
          });
        } else {
          // Magic Wand or finished Lasso (mask-based border)
          // Technical approach: Draw mask with offset to find edges
          const mask = maskCanvasRef.current;
          const tempCanvas = document.createElement('canvas');
          tempCanvas.width = canvasSize.w;
          tempCanvas.height = canvasSize.h;
          const tctx = tempCanvas.getContext('2d')!;

          // Dilation-based edge extraction
          tctx.drawImage(mask, 1, 0);
          tctx.drawImage(mask, -1, 0);
          tctx.drawImage(mask, 0, 1);
          tctx.drawImage(mask, 0, -1);

          tctx.globalCompositeOperation = 'destination-out';
          tctx.drawImage(mask, 0, 0);

          // Use extracted edge as a clipping mask for marching ants
          ctx.save();
          ctx.beginPath();

          // Animate the edge using a repeating dashed pattern
          const patternCanvas = document.createElement('canvas');
          patternCanvas.width = 10;
          patternCanvas.height = 10;
          const pctx = patternCanvas.getContext('2d')!;

          const drawPattern = (offset: number) => {
            pctx.clearRect(0, 0, 10, 10);
            pctx.fillStyle = 'black';
            pctx.fillRect(0, 0, 10, 10);
            pctx.fillStyle = 'white';
            // Diagonal stripes
            pctx.beginPath();
            pctx.moveTo(offset, 0);
            pctx.lineTo(offset + 5, 0);
            pctx.lineTo(offset + 5 + 10, 10);
            pctx.lineTo(offset + 10, 10);
            pctx.fill();
            pctx.beginPath();
            pctx.moveTo(offset - 10, 0);
            pctx.lineTo(offset - 5, 0);
            pctx.lineTo(offset - 5 + 10, 10);
            pctx.lineTo(offset, 10);
            pctx.fill();
            return ctx.createPattern(patternCanvas, 'repeat')!;
          };

          ctx.globalAlpha = 1.0;
          ctx.drawImage(tempCanvas, 0, 0); // Still black for now

          // To make it look like marching ants, we can use the edge as a mask
          // for an animated pattern.
          tctx.globalCompositeOperation = 'source-in';
          tctx.fillStyle = drawPattern(dashOffset);
          tctx.fillRect(0, 0, canvasSize.w, canvasSize.h);

          ctx.drawImage(tempCanvas, 0, 0);
          ctx.restore();
        }

        ctx.restore();
      }

      // Draw lasso/rect preview
      ctx.save();
      if (currentTool === 'rect' && isDrawing && lastDrawPos) {
        const m = screenToCanvas(lastMousePos.x, lastMousePos.y);
        const x = Math.min(lastDrawPos.x, m.x);
        const y = Math.min(lastDrawPos.y, m.y);
        const w = Math.abs(m.x - lastDrawPos.x);
        const h = Math.abs(m.y - lastDrawPos.y);

        ctx.setLineDash([5, 5]);

        const drawPreview = () => {
          ctx.strokeRect(x + 0.5, y + 0.5, w, h);
        };

        ctx.strokeStyle = '#000';
        ctx.lineDashOffset = -dashOffset;
        drawPreview();
        ctx.strokeStyle = '#fff';
        ctx.lineDashOffset = -dashOffset + 5;
        drawPreview();
      } else if (currentTool === 'poly_lasso' && lassoPoints.length > 0) {
        const m = screenToCanvas(lastMousePos.x, lastMousePos.y);

        ctx.setLineDash([5, 5]);

        const drawLassoPath = () => {
          ctx.beginPath();
          ctx.moveTo(lassoPoints[0].x, lassoPoints[0].y);
          lassoPoints.forEach((p) => ctx.lineTo(p.x, p.y));
          ctx.lineTo(m.x, m.y);
          ctx.stroke();
        };

        ctx.strokeStyle = '#000';
        ctx.lineDashOffset = -dashOffset;
        drawLassoPath();

        ctx.strokeStyle = '#fff';
        ctx.lineDashOffset = -dashOffset + 5;
        drawLassoPath();

        // Draw indicator if over first point
        const dist = Math.sqrt(
          Math.pow(m.x - lassoPoints[0].x, 2) + Math.pow(m.y - lassoPoints[0].y, 2),
        );
        if (dist < 10 / zoom) {
          ctx.fillStyle = '#fff';
          ctx.beginPath();
          ctx.arc(lassoPoints[0].x, lassoPoints[0].y, 4 / zoom, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = '#000';
          ctx.lineWidth = 1 / zoom;
          ctx.stroke();
        }
      }
      ctx.restore();
    }, [
      selectionActive,
      dashOffset,
      lastMousePos,
      currentTool,
      isDrawing,
      lassoPoints,
      zoom,
      canvasSize,
    ]);

    const updateCursorPos = useCallback(
      (clientX: number, clientY: number, currentBrushSize: number, currentZoom: number) => {
        const rect = containerRef.current?.getBoundingClientRect();
        const canvasRect = canvasRef.current?.getBoundingClientRect();
        if (!rect || !canvasRect) return;

        const x = (clientX - canvasRect.left) / (canvasRect.width / canvasSize.w);
        const y = (clientY - canvasRect.top) / (canvasRect.height / canvasSize.h);
        const pos = { x: Math.floor(x), y: Math.floor(y) };

        const snappedWorldPos = {
          x: pos.x + (currentBrushSize % 2 === 0 ? 0 : 0.5),
          y: pos.y + (currentBrushSize % 2 === 0 ? 0 : 0.5),
        };

        const sx =
          snappedWorldPos.x * (canvasRect.width / canvasSize.w) + canvasRect.left - rect.left;
        const sy =
          snappedWorldPos.y * (canvasRect.height / canvasSize.h) + canvasRect.top - rect.top;

        setScreenCursorPos({ x: sx, y: sy });
        onStatusUpdate?.(pos.x, pos.y, currentZoom);
      },
      [onStatusUpdate],
    );

    const finalizeLasso = useCallback(() => {
      const maskCtx = maskCanvasRef.current.getContext('2d');
      if (!maskCtx) return;
      maskCtx.fillStyle = 'white';
      maskCtx.beginPath();
      maskCtx.moveTo(lassoPoints[0].x, lassoPoints[0].y);
      lassoPoints.forEach((p) => maskCtx.lineTo(p.x, p.y));
      maskCtx.closePath();
      maskCtx.fill();
      setSelectionActive(true);
      setLassoPoints([]);
    }, [lassoPoints]);

    const applyRectSelection = useCallback(
      (start: { x: number; y: number }, end: { x: number; y: number }) => {
        const maskCtx = maskCanvasRef.current.getContext('2d');
        if (!maskCtx) return;
        maskCtx.fillStyle = 'white';
        const x = Math.min(start.x, end.x);
        const y = Math.min(start.y, end.y);
        const w = Math.abs(end.x - start.x);
        const h = Math.abs(end.y - start.y);
        maskCtx.fillRect(x, y, w, h);
        setActiveSelectionRect({ x, y, w, h });
        setSelectionActive(true);
      },
      [],
    );

    const applyWand = useCallback(
      (startX: number, startY: number) => {
        const canvas = canvasRef.current;
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        const imgData = ctx.getImageData(0, 0, canvasSize.w, canvasSize.h);
        const pixels = imgData.data;
        const startIdx = (startY * canvasSize.w + startX) * 4;
        const startR = pixels[startIdx];
        const startG = pixels[startIdx + 1];
        const startB = pixels[startIdx + 2];

        const maskCtx = maskCanvasRef.current.getContext('2d');
        if (!maskCtx) return;
        const maskImgData = maskCtx.createImageData(canvasSize.w, canvasSize.h);
        const maskPixels = maskImgData.data;

        // Simple Breadth-First Search Flood Fill
        const queue = [[startX, startY]];
        const visited = new Uint8Array(canvasSize.w * canvasSize.h);

        while (queue.length > 0) {
          const [x, y] = queue.shift()!;
          const idx = y * canvasSize.w + x;
          if (x < 0 || x >= canvasSize.w || y < 0 || y >= canvasSize.h || visited[idx]) continue;

          const pIdx = idx * 4;
          if (
            Math.abs(pixels[pIdx] - startR) < 5 &&
            Math.abs(pixels[pIdx + 1] - startG) < 5 &&
            Math.abs(pixels[pIdx + 2] - startB) < 5
          ) {
            visited[idx] = 1;
            maskPixels[pIdx] = 255;
            maskPixels[pIdx + 1] = 255;
            maskPixels[pIdx + 2] = 255;
            maskPixels[pIdx + 3] = 255;
            queue.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
          }
        }
        maskCtx.putImageData(maskImgData, 0, 0);
        setSelectionActive(true);
      },
      [canvasSize],
    );

    const draw = useCallback(
      (x: number, y: number, from?: { x: number; y: number }) => {
        const ctx = canvasRef.current?.getContext('2d');
        const bufferCtx = bufferCanvasRef.current?.getContext('2d');
        if (!ctx || !bufferCtx) return;
        if (currentTool !== 'brush' && currentTool !== 'eraser') return;

        // Disable image smoothing for crisp pixel drawing
        ctx.imageSmoothingEnabled = false;
        bufferCtx.imageSmoothingEnabled = false;

        bufferCtx.save();
        bufferCtx.clearRect(0, 0, canvasSize.w, canvasSize.h);

        const drawPoint = (px: number, py: number) => {
          const r = brushSize / 2;
          const cx = Math.floor(px) + (brushSize % 2 === 0 ? 0 : 0.5);
          const cy = Math.floor(py) + (brushSize % 2 === 0 ? 0 : 0.5);

          // Always draw solid shape to buffer, composition happens later
          bufferCtx.globalCompositeOperation = 'source-over';
          bufferCtx.fillStyle = currentTool === 'eraser' ? 'white' : currentBiome.color;

          if (brushShape === 'round') {
            const rSq = r * r;
            for (let ky = -Math.ceil(r); ky <= Math.ceil(r); ky++) {
              for (let kx = -Math.ceil(r); kx <= Math.ceil(r); kx++) {
                if (kx * kx + ky * ky <= rSq) {
                  bufferCtx.fillRect(
                    Math.floor(cx + kx - (brushSize % 2 === 0 ? 0.5 : 0)),
                    Math.floor(cy + ky - (brushSize % 2 === 0 ? 0.5 : 0)),
                    1,
                    1,
                  );
                }
              }
            }
          } else {
            bufferCtx.fillRect(Math.floor(cx - r), Math.floor(cy - r), brushSize, brushSize);
          }
        };

        if (from) {
          // Line between points using a simplified Bresenham-like thick line
          const dist = Math.sqrt(Math.pow(x - from.x, 2) + Math.pow(y - from.y, 2));
          const steps = Math.max(1, Math.floor(dist / (brushSize / 4)));
          for (let i = 0; i <= steps; i++) {
            const t = i / steps;
            drawPoint(from.x + (x - from.x) * t, from.y + (y - from.y) * t);
          }
        } else {
          drawPoint(x, y);
        }

        // Apply selection mask
        if (selectionActive) {
          bufferCtx.globalCompositeOperation = 'destination-in';
          bufferCtx.drawImage(maskCanvasRef.current, 0, 0);
        }
        bufferCtx.restore();

        // Composite buffer to main canvas
        if (currentTool === 'eraser') {
          ctx.globalCompositeOperation = 'destination-out';
        } else {
          ctx.globalCompositeOperation = 'source-over';
        }
        ctx.drawImage(bufferCanvasRef.current, 0, 0);
        ctx.globalCompositeOperation = 'source-over';
      },
      [brushSize, brushShape, currentBiome, currentTool, selectionActive, canvasSize],
    );

    const handleWheel = useCallback(
      (e: React.WheelEvent) => {
        if (e.ctrlKey && setBrushSize) {
          e.preventDefault();
          const delta = e.deltaY > 0 ? -1 : 1;
          const nextSize = Math.max(1, brushSize + delta);
          setBrushSize(nextSize);
          updateCursorPos(e.clientX, e.clientY, nextSize, zoom);
          return;
        }

        const delta = e.deltaY > 0 ? 0.9 : 1.1;
        const newZoom = Math.min(Math.max(zoom * delta, 0.1), 50);
        const container = containerRef.current;
        if (container) {
          const rect = container.getBoundingClientRect();
          const mouseX = e.clientX - rect.left - rect.width / 2;
          const mouseY = e.clientY - rect.top - rect.height / 2;
          const newOffsetX = mouseX - (mouseX - offset.x) * (newZoom / zoom);
          const newOffsetY = mouseY - (mouseY - offset.y) * (newZoom / zoom);
          const newOffset = { x: newOffsetX, y: newOffsetY };
          setZoom(newZoom);
          setOffset(newOffset);

          // Update status and cursor immediately during zoom
          updateCursorPos(e.clientX, e.clientY, brushSize, newZoom);
        }
      },
      [zoom, offset, brushSize, setBrushSize, updateCursorPos],
    );

    const screenToCanvas = (screenX: number, screenY: number) => {
      const canvas = canvasRef.current;
      if (!canvas) return { x: 0, y: 0 };
      const rect = canvas.getBoundingClientRect();
      const x = (screenX - rect.left) / (rect.width / canvasSize.w);
      const y = (screenY - rect.top) / (rect.height / canvasSize.h);
      return { x: Math.floor(x), y: Math.floor(y) };
    };

    const saveState = () => {
      const ctx = canvasRef.current?.getContext('2d');
      if (ctx) {
        undoStack.current.push(ctx.getImageData(0, 0, canvasSize.w, canvasSize.h));
        if (undoStack.current.length > 30) undoStack.current.shift();
      }
    };

    const handleMouseDown = useCallback(
      (e: React.MouseEvent) => {
        const pos = screenToCanvas(e.clientX, e.clientY);
        if (e.button === 1 || (e.button === 0 && e.altKey)) {
          setIsPanning(true);
          setLastMousePos({ x: e.clientX, y: e.clientY });
          return;
        }

        if (e.button === 0) {
          if (currentTool === 'move') {
            setIsPanning(true);
            setLastMousePos({ x: e.clientX, y: e.clientY });
            return;
          }

          saveState();

          if (currentTool === 'inspector' && onInspect) {
            const rect = canvasRef.current?.getBoundingClientRect();
            if (!rect) return;
            const x = Math.floor((e.clientX - rect.left) / zoom);
            const y = Math.floor((e.clientY - rect.top) / zoom);
            const ctx = canvasRef.current?.getContext('2d');
            if (ctx) {
              const pixel = ctx.getImageData(x, y, 1, 1).data;
              const hex = `#${((1 << 24) | (pixel[0] << 16) | (pixel[1] << 8) | pixel[2]).toString(16).slice(1)}`;
              onInspect(hex);
            }
            return;
          }

          if (currentTool === 'reference') {
            setIsPanning(true);
            return;
          }

          if (currentTool === 'rect' || currentTool === 'wand') {
            setIsDrawing(true);
            setLastDrawPos(pos);
            if (currentTool === 'wand') applyWand(pos.x, pos.y);
          } else if (currentTool === 'brush' || currentTool === 'eraser') {
            setIsDrawing(true);
            setLastDrawPos(pos);
            draw(pos.x, pos.y);
          } else if (currentTool === 'poly_lasso') {
            if (!selectionActive && lassoPoints.length === 0) {
              setIsDrawing(true);
              setLassoPoints([pos]);
            } else {
              // Check if clicking near first point
              const dist = Math.sqrt(
                Math.pow(pos.x - lassoPoints[0].x, 2) + Math.pow(pos.y - lassoPoints[0].y, 2),
              );
              if (dist < 10 / zoom && lassoPoints.length > 2) {
                finalizeLasso();
              } else {
                setLassoPoints((prev) => [...prev, pos]);
              }
            }
          }
        }
      },
      [currentTool, zoom, onInspect, selectionActive, lassoPoints, draw, applyWand, finalizeLasso],
    );

    const handleMouseMove = useCallback(
      (e: MouseEvent | React.MouseEvent) => {
        updateCursorPos(e.clientX, e.clientY, brushSize, zoom);
        const pos = screenToCanvas(e.clientX, e.clientY);

        if (isPanning) {
          const dx = (e.clientX - lastMousePos.x) / zoom;
          const dy = (e.clientY - lastMousePos.y) / zoom;
          if (currentTool === 'reference') {
            setRefImage?.({ ...refImage, pos: { x: refImage.pos.x + dx, y: refImage.pos.y + dy } });
          } else {
            setOffset((prev) => ({
              x: prev.x + (e.clientX - lastMousePos.x),
              y: prev.y + (e.clientY - lastMousePos.y),
            }));
          }
        } else if (isResizing) {
          const dx = (e.clientX - lastMousePos.x) / zoom;
          const dy = (e.clientY - lastMousePos.y) / zoom;
          const factor = (dx + dy) / 100;
          setRefImage?.({ ...refImage, scale: Math.max(0.1, refImage.scale + factor) });
        } else if (isDrawing) {
          if (currentTool !== 'rect' && currentTool !== 'wand') {
            draw(pos.x, pos.y, lastDrawPos || undefined);
            setLastDrawPos(pos);
          }

          // Auto-panning logic
          const container = containerRef.current;
          if (container) {
            const rect = container.getBoundingClientRect();
            const margin = 50;
            let px = 0;
            let py = 0;

            if (e.clientX < rect.left + margin) px = -1;
            else if (e.clientX > rect.right - margin) px = 1;

            if (e.clientY < rect.top + margin) py = -1;
            else if (e.clientY > rect.bottom - margin) py = 1;

            setPanSpeed({ x: px, y: py });
          }
        }
        setLastMousePos({ x: e.clientX, y: e.clientY });
      },
      [
        isPanning,
        isResizing,
        isDrawing,
        currentTool,
        brushSize,
        zoom,
        offset,
        lastMousePos,
        refImage,
        lastDrawPos,
        draw,
        updateCursorPos,
        setRefImage,
      ],
    );

    const handleMouseUp = useCallback(() => {
      if (isDrawing && currentTool === 'rect' && lastDrawPos) {
        const pos = screenToCanvas(lastMousePos.x, lastMousePos.y);
        applyRectSelection(lastDrawPos, pos);
      }
      if (isDrawing && (currentTool === 'brush' || currentTool === 'eraser')) {
        onModified?.();
      }
      setIsPanning(false);
      setIsDrawing(false);
      setIsResizing(null);
      setLastDrawPos(null);
      setPanSpeed({ x: 0, y: 0 });
    }, [isDrawing, currentTool, lastDrawPos, lastMousePos, applyRectSelection, onModified]);

    // Global mouse events
    useEffect(() => {
      if (isDrawing || isPanning || isResizing) {
        window.addEventListener('mousemove', handleMouseMove);
        window.addEventListener('mouseup', handleMouseUp);
        return () => {
          window.removeEventListener('mousemove', handleMouseMove);
          window.removeEventListener('mouseup', handleMouseUp);
        };
      }
      return undefined;
    }, [isDrawing, isPanning, isResizing, handleMouseMove, handleMouseUp]);

    useImperativeHandle(ref, () => ({
      getDataURL: () => canvasRef.current?.toDataURL('image/png') || '',
      loadImage: (dataURL: string) => {
        const img = new Image();
        img.onload = () => {
          const ctx = canvasRef.current?.getContext('2d');
          ctx?.drawImage(img, 0, 0);
        };
        img.src = dataURL;
      },
      clearSelection: () => {
        const maskCtx = maskCanvasRef.current.getContext('2d');
        maskCtx?.clearRect(0, 0, canvasSize.w, canvasSize.h);
        setSelectionActive(false);
        setLassoPoints([]);
        setActiveSelectionRect(null);
      },
      clearCanvas: () => {
        const ctx = canvasRef.current?.getContext('2d');
        ctx?.clearRect(0, 0, canvasSize.w, canvasSize.h);
        undoStack.current = [];
      },
      resetView: () => {
        setZoom(1);
        setOffset({ x: 0, y: 0 });
      },
      undo: () => {
        const ctx = canvasRef.current?.getContext('2d');
        const lastState = undoStack.current.pop();
        if (ctx && lastState) {
          ctx.putImageData(lastState, 0, 0);
          onModified?.();
        }
      },
    }));

    return (
      <div
        ref={containerRef}
        className="flex-1 relative bg-[#090909] flex items-center justify-center overflow-hidden"
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseEnter={() => setMouseInCanvas(true)}
        onMouseLeave={() => setMouseInCanvas(false)}
        onDoubleClick={() => {
          if (currentTool === 'poly_lasso' && lassoPoints.length > 2) {
            finalizeLasso();
          }
        }}
        onContextMenu={(e) => e.preventDefault()}
        style={{
          cursor:
            currentTool === 'brush' || currentTool === 'eraser' || currentTool === 'rect'
              ? 'none'
              : 'default',
        }}
      >
        <div
          className="relative shadow-2xl"
          style={{
            transform: `translate(${offset.x}px, ${offset.y}px) scale(${zoom})`,
            width: `1024px`,
            height: `1024px`,
          }}
        >
          <canvas
            ref={canvasRef}
            className="w-full h-full"
            style={{
              imageRendering: 'pixelated',
              opacity: 0.8,
              background:
                'conic-gradient(#ccc 25%, #eee 25% 50%, #ccc 50% 75%, #eee 75%) 0 0 / 2px 2px',
            }}
          />
          <canvas
            ref={selectionCanvasRef}
            className="absolute inset-0 w-full h-full pointer-events-none"
            style={{ imageRendering: 'pixelated' }}
          />
          {/* Reference Image Layer */}
          {refImage.dataURL && (
            <div
              className="absolute"
              style={{
                left: `${refImage.pos.x}px`,
                top: `${refImage.pos.y}px`,
                transform: `scale(${refImage.scale})`,
                opacity: refImage.opacity / 100,
                imageRendering: 'pixelated',
              }}
            >
              <img
                src={refImage.dataURL}
                className="pointer-events-none"
                style={{ maxWidth: 'none' }}
              />

              {/* Handles - only visible in reference tool */}
              {currentTool === 'reference' && (
                <div className="absolute inset-0 border border-[var(--accent-color)] pointer-events-none">
                  {[
                    { id: 'tl', class: '-top-1.5 -left-1.5 cursor-nwse-resize' },
                    { id: 'tr', class: '-top-1.5 -right-1.5 cursor-nesw-resize' },
                    { id: 'bl', class: '-bottom-1.5 -left-1.5 cursor-nesw-resize' },
                    { id: 'br', class: '-bottom-1.5 -right-1.5 cursor-nwse-resize' },
                    { id: 'tc', class: '-top-1.5 left-1/2 -ml-1.5 cursor-ns-resize' },
                    { id: 'bc', class: '-bottom-1.5 left-1/2 -ml-1.5 cursor-ns-resize' },
                    { id: 'ml', class: 'top-1/2 -mt-1.5 -left-1.5 cursor-ew-resize' },
                    { id: 'mr', class: 'top-1/2 -mt-1.5 -right-1.5 cursor-ew-resize' },
                  ].map((h) => (
                    <div
                      key={h.id}
                      onMouseDown={(e) => {
                        e.stopPropagation();
                        setIsResizing(h.id);
                      }}
                      className={`absolute w-3 h-3 bg-[var(--bg-btn-active)] border border-white rounded-sm pointer-events-auto shadow-md ${h.class}`}
                    />
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Custom Cursors */}
        {mouseInCanvas && (
          <>
            {/* Brush & Eraser Cursor */}
            {(currentTool === 'brush' || currentTool === 'eraser') && (
              <div
                className="absolute pointer-events-none border-white mix-blend-difference shadow-[0_0_2px_rgba(0,0,0,0.5)] z-50"
                style={{
                  left: `${screenCursorPos.x}px`,
                  top: `${screenCursorPos.y}px`,
                  width: `${brushSize * zoom}px`,
                  height: `${brushSize * zoom}px`,
                  transform: 'translate(-50%, -50%)',
                  borderRadius: brushShape === 'round' ? '50%' : '0px',
                  borderWidth: '1px',
                  borderStyle: 'solid',
                }}
              />
            )}

            {/* Marquee Tool Cursor (Minimize icon) */}
            {currentTool === 'rect' && (
              <div
                className="absolute pointer-events-none flex items-center justify-center mix-blend-difference z-50 text-white"
                style={{
                  left: `${lastMousePos.x - containerRef.current!.getBoundingClientRect().left}px`,
                  top: `${lastMousePos.y - containerRef.current!.getBoundingClientRect().top}px`,
                  transform: 'translate(-50%, -50%)',
                }}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M8 3v3a2 2 0 0 1-2 2H3" />
                  <path d="M21 8h-3a2 2 0 0 1-2-2V3" />
                  <path d="M3 16h3a2 2 0 0 1 2 2v3" />
                  <path d="M16 21v-3a2 2 0 0 1 2-2h3" />
                </svg>
              </div>
            )}
          </>
        )}
      </div>
    );
  },
);

export default BiomeCanvas;
