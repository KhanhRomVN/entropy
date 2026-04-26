import React, { useEffect, useCallback, CSSProperties } from 'react';
import { X } from 'lucide-react';
import { ModalProps } from './Modal.types';
import {
  getModalSizeStyles,
  getModalPositionStyles,
  getModalAnimationClasses,
  validateModalProps,
  mergeModalStyles,
} from './Modal.utils';
import { cn } from '../../../../shared/utils/cn';

const Modal: React.FC<ModalProps> = ({
  open,
  onClose,
  title,
  children,
  footer,
  size = 'md',
  position = 'center',
  className = '',
  overlayClassName = '',
  contentClassName = '',
  closeOnOverlayClick = true,
  showCloseButton = true,
  closeOnEsc = true,
  animation = 'fade',
  style,
  overlayStyle,
  contentStyle,
  bodyClassName = '',
  bodyStyle,
}) => {
  // Validate props
  const validation = validateModalProps({ open, onClose, children });
  if (!validation.isValid) {
    console.error('Modal validation errors:', validation.errors);
    return null;
  }

  // Handle ESC key press
  const handleKeyDown = useCallback(
    (event: KeyboardEvent) => {
      if (closeOnEsc && event.key === 'Escape' && open) {
        onClose();
      }
    },
    [closeOnEsc, open, onClose],
  );

  // Handle overlay click
  const handleOverlayClick = (event: React.MouseEvent<HTMLDivElement>) => {
    if (closeOnOverlayClick && event.target === event.currentTarget) {
      onClose();
    }
  };

  // Add/remove event listeners
  useEffect(() => {
    if (open && closeOnEsc) {
      document.addEventListener('keydown', handleKeyDown);
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      document.body.style.overflow = 'unset';
    };
  }, [open, closeOnEsc, handleKeyDown]);

  // Don't render if not open
  if (!open) return null;

  // Get styles and classes
  const sizeStyles = getModalSizeStyles(size);
  const positionStyles = getModalPositionStyles(position);
  const animationClasses = getModalAnimationClasses(animation, open);

  const baseOverlayStyles: CSSProperties = {
    ...positionStyles,
  };

  const baseContentStyles: CSSProperties = {
    ...sizeStyles,
  };

  const finalOverlayStyles = mergeModalStyles(baseOverlayStyles, overlayStyle);
  const finalContentStyles = mergeModalStyles(baseContentStyles, contentStyle);

  return (
    <div
      className={cn(
        'modal-overlay fixed inset-0 bg-black/60 backdrop-blur-xl z-[1000]',
        overlayClassName,
        animationClasses,
      )}
      style={finalOverlayStyles}
      onClick={handleOverlayClick}
      role="dialog"
      aria-modal="true"
    >
      <div
        className={cn(
          'modal-content bg-dialog-background text-text-primary rounded-xl shadow-dialog-shadow overflow-hidden max-h-[90vh] flex flex-col w-full mx-4 border border-border',
          contentClassName,
          className,
        )}
        style={{ ...finalContentStyles, ...style }}
      >
        {/* Header */}
        {(title || showCloseButton) && (
          <div className="flex items-center justify-between px-6 py-4 border-b border-border shrink-0">
            {title && (
              <div className="flex-1 min-w-0 mr-4">
                {typeof title === 'string' ? (
                  <h2 className="text-lg font-semibold tracking-tight truncate">{title}</h2>
                ) : (
                  title
                )}
              </div>
            )}
            {showCloseButton && (
              <button
                className="p-2 text-muted-foreground hover:text-red-500 hover:bg-red-500/10 rounded-xl transition-all active:scale-95 focus:outline-none"
                onClick={onClose}
                aria-label="Close modal"
              >
                <X className="w-5 h-5" />
              </button>
            )}
          </div>
        )}

        {/* Body */}
        <div
          className={cn('p-6 overflow-y-auto custom-scrollbar', bodyClassName)}
          style={bodyStyle}
        >
          {children}
        </div>

        {/* Footer */}
        {footer && <div className="px-6 py-4 border-t border-border shrink-0">{footer}</div>}
      </div>
    </div>
  );
};

export default Modal;
