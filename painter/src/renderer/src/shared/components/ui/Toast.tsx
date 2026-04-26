import React, { useEffect, useState } from 'react';
import { cn } from '../../../shared/lib/utils';
import { AlertCircle, CheckCircle2, Info, X } from 'lucide-react';

export type ToastType = 'info' | 'success' | 'error' | 'warning';

interface ToastProps {
  message: string;
  type?: ToastType;
  duration?: number;
  onClose: () => void;
  visible: boolean;
}

const Toast: React.FC<ToastProps> = ({
  message,
  type = 'info',
  duration = 3000,
  onClose,
  visible,
}) => {
  useEffect(() => {
    if (visible && duration > 0) {
      const timer = setTimeout(() => {
        onClose();
      }, duration);
      return () => clearTimeout(timer);
    }
  }, [visible, duration, onClose]);

  const icons = {
    info: <Info className="w-4 h-4 text-blue-400" />,
    success: <CheckCircle2 className="w-4 h-4 text-green-400" />,
    error: <AlertCircle className="w-4 h-4 text-red-400" />,
    warning: <AlertCircle className="w-4 h-4 text-amber-400" />,
  };

  const backgrounds = {
    info: 'bg-blue-500/10 border-blue-500/20',
    success: 'bg-green-500/10 border-green-500/20',
    error: 'bg-red-500/10 border-red-500/20',
    warning: 'bg-amber-500/10 border-amber-500/20',
  };

  return (
    <div
      className={cn(
        'fixed bottom-6 left-6 z-[9999] flex items-center gap-3 px-4 py-3 rounded-2xl border backdrop-blur-xl transition-all duration-500 transform',
        visible
          ? 'translate-y-0 opacity-100 scale-100'
          : 'translate-y-10 opacity-0 scale-95 pointer-events-none',
        backgrounds[type],
      )}
    >
      <div className="shrink-0">{icons[type]}</div>
      <p className="text-sm font-medium text-foreground tracking-tight">{message}</p>
      <button
        onClick={onClose}
        className="ml-2 p-1 hover:bg-foreground/5 rounded-lg transition-colors"
      >
        <X className="w-4 h-4 text-muted-foreground/50" />
      </button>
    </div>
  );
};

export default Toast;
